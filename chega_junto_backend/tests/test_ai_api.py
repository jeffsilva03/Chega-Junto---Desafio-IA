from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta

import pytest
from pydantic import SecretStr
from sqlalchemy import func, select

from app.api.v1.ai import get_ai_provider, router
from app.core.errors import ApiError
from app.core.operator_security import create_operator_token
from app.core.security import create_token
from app.database.base import utc_now
from app.models import AiUsageEvent, PreVisitReport
from app.services.ai_provider import AiProviderError
from app.services.ai_quota import AiQuota
from tests.fake_ai_provider import FakeAiProvider

WAV = b"RIFF" + b"\0" * 4 + b"WAVE" + b"fake-audio"
PATH = "/api/v1/appointments/1/report/"


@pytest.fixture
def ai_api(api_database):
    client, database, app = api_database
    config = app.state.settings
    config.ai_enabled = True
    config.openai_text_model = "test-text"
    config.openai_transcription_model = "test-audio"
    fake = FakeAiProvider()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_ai_provider] = lambda: fake
    headers = {"Authorization": "Bearer " + create_token(config, 1)}
    return client, database, app, fake, headers


def organize(context, **kwargs):
    client, _, _, _, headers = context
    return client.post(
        PATH + "organization", json={"original_text": "Texto fictício"}, headers=headers, **kwargs
    )


@pytest.mark.parametrize("operation", ["organization", "transcription"])
def test_auth_ownership_operator_and_no_demo(ai_api, operation):
    client, database, app, fake, headers = ai_api
    payload = (
        {"json": {"original_text": "Texto"}}
        if operation == "organization"
        else {"files": {"file": ("a.wav", WAV, "audio/wav")}}
    )
    assert client.post(PATH + operation, **payload).status_code == 401
    assert (
        client.post(PATH.replace("/1/", "/99/") + operation, headers=headers, **payload).status_code
        == 404
    )
    app.state.settings.operator_portal_enabled = True
    app.state.settings.operator_auth_secret_key = SecretStr("o" * 40)
    operator = {"Authorization": "Bearer " + create_operator_token(app.state.settings, 1)}
    assert client.post(PATH + operation, headers=operator, **payload).status_code == 401
    assert fake.calls == []
    with database.session() as session:
        assert session.scalar(select(func.count()).select_from(AiUsageEvent)) == 0


@pytest.mark.parametrize("text", ["", "   ", "x" * 20001])
def test_organization_invalid_text_no_call(ai_api, text):
    client, _, _, fake, headers = ai_api
    assert (
        client.post(
            PATH + "organization", headers=headers, json={"original_text": text}
        ).status_code
        == 422
    )
    assert fake.calls == []


def test_organization_valid_no_report_write_and_no_lock_during_provider(ai_api):
    client, database, _, fake, _ = ai_api
    with database.session() as session:
        before = [
            (r.id, r.original_text, r.content_revision)
            for r in session.scalars(select(PreVisitReport))
        ]

    def inspect_reservation():
        with database.session() as session:
            assert session.scalar(select(AiUsageEvent)).outcome == "started"

    fake.before_call = inspect_reservation
    response = organize(ai_api)
    assert response.status_code == 200
    data = response.json()
    assert [s["section_key"] for s in data["sections"]] == ["reason", "points", "context", "other"]
    assert [s["title"] for s in data["sections"]] == [
        "Motivo da consulta",
        "Pontos relatados",
        "Contexto informado",
        "Outros pontos importantes",
    ]
    assert all(q["is_selected"] is False for q in data["questions"])
    with database.session() as session:
        assert before == [
            (r.id, r.original_text, r.content_revision)
            for r in session.scalars(select(PreVisitReport))
        ]
        event = session.scalar(select(AiUsageEvent))
        assert event.outcome == "succeeded" and event.input_units == 20 and event.output_units == 10


@pytest.mark.parametrize("scope", ["user", "global"])
def test_organization_daily_limits_and_failure_counts(ai_api, scope):
    _, database, app, fake, _ = ai_api
    setattr(app.state.settings, f"ai_organize_{scope}_daily_limit", 1)
    fake.error = AiProviderError()
    assert organize(ai_api).status_code == 503
    fake.error = None
    response = organize(ai_api)
    assert (
        response.status_code == 429 and response.json()["error"]["code"] == "ai_daily_limit_reached"
    )
    assert len(fake.calls) == 1
    with database.session() as session:
        assert session.scalar(select(AiUsageEvent)).outcome == "failed"


@pytest.mark.parametrize(
    "name,mime,content,status",
    [
        ("a.wav", "audio/wav", WAV, 200),
        ("a.WAV", "audio/x-wav", WAV, 200),
        ("a.webm", "audio/webm", b"\x1aE\xdf\xa3fake", 200),
        ("a.m4a", "audio/mp4", b"\0\0\0\x20ftypfake", 200),
        ("a.mp4", "video/mp4", b"\0\0\0\x20ftypfake", 200),
        ("a.mp3", "audio/mpeg", b"ID3fake", 200),
        ("a.exe", "audio/wav", WAV, 422),
        ("a.wav", "application/octet-stream", WAV, 422),
        ("a.wav", "audio/wav", b"MZfake", 422),
        ("a.wav", "audio/wav", b"", 422),
        ("a.ogg", "audio/ogg", b"OggSfake", 422),
        ("a.wav", "audio/wav", WAV + b"x" * (10 * 1024 * 1024), 413),
    ],
)
def test_audio_format_limits_and_no_persistence(ai_api, name, mime, content, status):
    client, database, _, fake, headers = ai_api
    response = client.post(
        PATH + "transcription", headers=headers, files={"file": (name, content, mime)}
    )
    assert response.status_code == status
    if status == 200:
        assert response.json() == {"text": fake.transcript}
        with database.session() as session:
            event = session.scalar(select(AiUsageEvent))
            assert event.outcome == "succeeded" and event.input_units is None
    else:
        assert fake.calls == []


@pytest.mark.parametrize(
    "transcript,status,code",
    [("", 503, "transcription_failed"), ("x" * 20001, 422, "transcription_too_long")],
)
def test_transcription_invalid_or_too_long_not_truncated(ai_api, transcript, status, code):
    client, _, _, fake, headers = ai_api
    fake.transcript = transcript
    response = client.post(
        PATH + "transcription", headers=headers, files={"file": ("a.wav", WAV, "audio/wav")}
    )
    assert response.status_code == status and response.json()["error"]["code"] == code


def test_transcription_quota_independent(ai_api):
    client, _, app, fake, headers = ai_api
    app.state.settings.ai_transcribe_user_daily_limit = 0
    response = client.post(
        PATH + "transcription", headers=headers, files={"file": ("a.wav", WAV, "audio/wav")}
    )
    assert response.status_code == 429 and fake.calls == []
    assert organize(ai_api).status_code == 200


def test_disabled_routes_absent(api_database):
    client, _, _ = api_database
    assert client.post(PATH + "organization", json={"original_text": "Texto"}).status_code == 404
    assert not any(
        "organization" in path or "transcription" in path
        for path in client.get("/openapi.json").json()["paths"]
    )


def test_usage_schema_minimizes_data():
    assert set(AiUsageEvent.__table__.columns.keys()) == {
        "id",
        "user_id",
        "operation",
        "provider",
        "model",
        "outcome",
        "input_units",
        "output_units",
        "created_at",
        "completed_at",
    }


def test_quota_global_across_users_and_new_utc_day(ai_api):
    _, database, app, _, _ = ai_api
    app.state.settings.ai_organize_global_daily_limit = 1
    quota = AiQuota(database.engine, app.state.settings)
    now = utc_now()
    quota.reserve(1, "organize", now=now)
    with pytest.raises(ApiError) as error:
        quota.reserve(2, "organize", now=now)
    assert error.value.status == 429
    quota.reserve(2, "organize", now=now + timedelta(days=1))
    quota.reserve(1, "transcribe", now=now)


def test_concurrent_reservations_cannot_exceed_limit(ai_api):
    _, database, app, _, _ = ai_api
    app.state.settings.ai_organize_global_daily_limit = 2
    quota = AiQuota(database.engine, app.state.settings)

    def reserve(_):
        try:
            quota.reserve(1, "organize")
            return True
        except ApiError as error:
            assert error.status == 429
            return False

    with ThreadPoolExecutor(max_workers=8) as pool:
        assert sum(pool.map(reserve, range(10))) == 2
