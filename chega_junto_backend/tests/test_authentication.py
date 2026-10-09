"""Autenticação e isolamento somente no SQLite efêmero; nunca escrevem no Aiven."""

import secrets
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select
from sqlalchemy.exc import IntegrityError

from app.core.config import Settings
from app.core.errors import ConfigurationError
from app.core.security import ALGORITHM, ISSUER, password_hasher
from app.models import AccessibilityPreferences, NotificationPreferences, User, UserProfile


@pytest.fixture
def authenticated_api(api_database):
    client, database, app = api_database
    app.state.settings.auth_mode = "jwt"
    return client, database, app


def credentials(email="person@example.test"):
    return {"full_name": "Pessoa fictícia", "email": email, "password": secrets.token_urlsafe(24)}


def register(client, payload=None):
    payload = payload or credentials()
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    return response.json(), payload


def bearer(result):
    return {"Authorization": "Bearer " + result["access_token"]}


def counts(database):
    with database.session() as session:
        return {
            table.name: session.scalar(select(func.count()).select_from(table))
            for table in User.metadata.sorted_tables
        }


def test_register_atomic_minimal_identity_hash_and_defaults(authenticated_api):
    client, database, app = authenticated_api
    before = counts(database)
    result, payload = register(client, credentials(" Person@Example.Test "))
    assert set(result) == {"access_token", "token_type", "user"}
    assert result["token_type"] == "bearer"
    assert isinstance(result["user"]["id"], str)
    assert result["user"]["email"] == "person@example.test"
    claims = jwt.decode(
        result["access_token"],
        app.state.settings.auth_secret_key.get_secret_value(),
        algorithms=[ALGORITHM],
        issuer=ISSUER,
    )
    assert set(claims) == {"sub", "iat", "exp", "iss"}
    assert claims["exp"] - claims["iat"] == 3600
    with database.session() as session:
        user = session.get(User, int(result["user"]["id"]))
        assert user.is_active and user.password_hash.startswith("$argon2id$")
        assert user.password_hash != payload["password"]
        assert password_hasher.verify(user.password_hash, payload["password"])
        profile = session.get(UserProfile, user.id)
        assert profile.full_name == payload["full_name"]
        assert all(
            getattr(profile, name) is None
            for name in (
                "cpf",
                "birth_date",
                "phone",
                "sus_card_number",
                "street",
                "city",
                "postcode",
            )
        )
        assert session.get(NotificationPreferences, user.id).active
        assert session.get(AccessibilityPreferences, user.id).text_size == "medium"
    after = counts(database)
    for name in before:
        assert after[name] - before[name] == (
            1
            if name
            in {"users", "user_profiles", "notification_preferences", "accessibility_preferences"}
            else 0
        )
    assert client.get("/api/v1/auth/me", headers=bearer(result)).json() == result["user"]


@pytest.mark.parametrize(
    "field,value",
    [
        ("email", "invalid"),
        ("email", "a@b"),
        ("email", "a b@example.test"),
        ("email", "x" * 255 + "@example.test"),
        ("password", "short"),
        ("password", "x" * 129),
        ("password", 123456789),
        ("full_name", " "),
        ("full_name", "x" * 161),
        ("user_id", "1"),
        ("is_active", True),
        ("password_hash", "forbidden"),
        ("confirm_password", "forbidden"),
    ],
)
def test_register_validation_has_no_side_effects(authenticated_api, field, value):
    client, database, _ = authenticated_api
    before = counts(database)
    payload = credentials()
    payload[field] = value
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert counts(database) == before


def test_email_normalization_duplicate_and_database_unique(authenticated_api):
    client, database, _ = authenticated_api
    register(client)
    before = counts(database)
    response = client.post("/api/v1/auth/register", json=credentials(" PERSON@EXAMPLE.TEST "))
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_already_registered"
    assert counts(database) == before
    with database.session() as session:
        session.add(User(email="person@example.test"))
        with pytest.raises(IntegrityError):
            session.flush()


def test_concurrent_constraint_collision_is_mapped(authenticated_api, monkeypatch):
    """Simula perdedor da corrida: precheck vazio, UNIQUE falha, titular visível após rollback."""
    from app.schemas.auth import RegisterWrite
    from app.services.auth import AuthService

    client, database, app = authenticated_api
    result, _ = register(client)
    with database.session() as session:
        scalar = session.scalar
        calls = 0

        def simulated_precheck(statement, *args, **kwargs):
            nonlocal calls
            calls += 1
            return None if calls == 1 else scalar(statement, *args, **kwargs)

        monkeypatch.setattr(session, "scalar", simulated_precheck)
        with pytest.raises(Exception) as error:
            AuthService(session, app.state.settings).register(RegisterWrite(**credentials()))
        assert error.value.code == "email_already_registered"
        assert error.value.status == 409
    assert client.get("/api/v1/auth/me", headers=bearer(result)).status_code == 200


def test_registration_rolls_back_every_row_on_preference_failure(authenticated_api):
    client, database, _ = authenticated_api
    before = counts(database)

    def fail(_mapper, _connection, _target):
        raise RuntimeError("Controlled fixture failure")

    event.listen(AccessibilityPreferences, "before_insert", fail)
    try:
        assert client.post("/api/v1/auth/register", json=credentials()).status_code == 500
    finally:
        event.remove(AccessibilityPreferences, "before_insert", fail)
    assert counts(database) == before


def test_login_normalized_email_and_profile_email_are_canonical(authenticated_api):
    client, database, _ = authenticated_api
    _, payload = register(client)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": " PERSON@EXAMPLE.TEST ", "password": payload["password"]},
    )
    assert login.status_code == 200
    headers = bearer(login.json())
    saved = client.put(
        "/api/v1/me/profile",
        headers=headers,
        json={"full_name": "Nome editado", "email": " Changed@Example.Test "},
    )
    assert saved.status_code == 200
    assert saved.json()["email"] == "changed@example.test" and saved.json()["phone"] is None
    assert client.get("/api/v1/auth/me", headers=headers).json()["email"] == "changed@example.test"
    assert (
        client.post(
            "/api/v1/auth/login", json={"email": payload["email"], "password": payload["password"]}
        ).status_code
        == 401
    )
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "changed@example.test", "password": payload["password"]},
        ).status_code
        == 200
    )
    assert "email" not in UserProfile.__table__.columns


def test_email_update_collision_rolls_back_profile(authenticated_api):
    client, _, _ = authenticated_api
    first, _ = register(client)
    second, _ = register(client, credentials("second@example.test"))
    headers = bearer(second)
    before = client.get("/api/v1/me/profile", headers=headers).json()
    response = client.put(
        "/api/v1/me/profile",
        headers=headers,
        json={"full_name": "Não deve salvar", "email": first["user"]["email"]},
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_already_registered"
    assert client.get("/api/v1/me/profile", headers=headers).json() == before


@pytest.mark.parametrize("kind", ["absent", "wrong", "inactive", "legacy", "invalid_hash"])
def test_login_failures_are_indistinguishable(authenticated_api, kind):
    client, database, _ = authenticated_api
    result, payload = register(client)
    with database.session() as session, session.begin():
        user = session.get(User, int(result["user"]["id"]))
        if kind == "inactive":
            user.is_active = False
        if kind == "legacy":
            user.password_hash = None
        if kind == "invalid_hash":
            user.password_hash = "invalid"
    if kind == "absent":
        payload["email"] = "absent@example.test"
    if kind == "wrong":
        payload["password"] = secrets.token_urlsafe(24)
    response = client.post(
        "/api/v1/auth/login", json={k: payload[k] for k in ("email", "password")}
    )
    assert response.status_code == 401
    assert response.json() == {
        "error": {"code": "invalid_credentials", "message": "E-mail ou senha inválidos."}
    }
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize(
    "kind",
    [
        "expired",
        "tampered",
        "unknown",
        "inactive",
        "algorithm",
        "no_exp",
        "bad_sub",
        "future_iat",
        "missing",
        "basic",
    ],
)
def test_invalid_tokens_never_fall_back_to_demo(authenticated_api, kind):
    client, database, app = authenticated_api
    result, _ = register(client)
    settings = app.state.settings
    now = datetime.now(UTC)
    claims = {
        "sub": result["user"]["id"],
        "iat": now,
        "exp": now + timedelta(hours=1),
        "iss": ISSUER,
    }
    if kind == "expired":
        claims.update(iat=now - timedelta(hours=2), exp=now - timedelta(hours=1))
    if kind == "unknown":
        claims["sub"] = "999999"
    if kind == "bad_sub":
        claims["sub"] = "1 OR 1=1"
    if kind == "future_iat":
        claims["iat"] = now + timedelta(hours=1)
    if kind == "no_exp":
        claims.pop("exp")
    if kind == "inactive":
        with database.session() as session, session.begin():
            session.get(User, int(result["user"]["id"])).is_active = False
    token = jwt.encode(
        claims,
        secrets.token_urlsafe(32)
        if kind == "tampered"
        else settings.auth_secret_key.get_secret_value()
        + ("padding-for-algorithm-test" if kind == "algorithm" else ""),
        algorithm="HS384" if kind == "algorithm" else ALGORITHM,
    )
    headers = (
        {}
        if kind == "missing"
        else {"Authorization": "Basic invalid" if kind == "basic" else "Bearer " + token}
    )
    for path in ("/api/v1/auth/me", "/api/v1/me/profile", "/api/v1/preparation/overview"):
        response = client.get(path, headers=headers)
        assert response.status_code == 401
        assert response.headers["www-authenticate"] == "Bearer"


def test_every_product_operation_requires_bearer_and_openapi_documents_it(authenticated_api):
    client, _, _ = authenticated_api
    spec = client.get("/openapi.json").json()
    operations = 0
    for path, methods in spec["paths"].items():
        if not path.startswith("/api/v1/") or path.startswith("/api/v1/auth/"):
            continue
        for method, operation in methods.items():
            operations += 1
            assert operation["security"] == [{"HTTPBearer": []}]
            concrete = path
            for key in ("appointment_id", "facility_id", "item_id", "record_id", "notification_id"):
                concrete = concrete.replace("{" + key + "}", "1")
            response = client.request(method, concrete, json={})
            assert response.status_code == 401
    assert operations == 29
    assert "security" not in spec["paths"]["/health"]["get"]
    assert "security" not in spec["paths"]["/api/v1/auth/register"]["post"]
    assert client.get("/health").status_code == 200


@pytest.mark.parametrize(
    "path", ["appointments", "facilities", "reminders", "me/health-records", "me/notifications"]
)
def test_new_account_lists_start_empty(authenticated_api, path):
    client, _, _ = authenticated_api
    result, _ = register(client)
    response = client.get("/api/v1/" + path, headers=bearer(result))
    assert response.status_code == 200
    assert response.json()["items"] == [] and response.json()["pagination"]["total"] == 0
    if path == "me/notifications":
        assert response.json()["unread_count"] == 0


def test_new_account_overview_health_preferences_and_minimal_profile(authenticated_api):
    client, _, _ = authenticated_api
    result, _ = register(client)
    headers = bearer(result)
    overview = client.get("/api/v1/preparation/overview", headers=headers).json()
    assert overview["next_appointment"] is None
    assert overview["user"]["id"] == result["user"]["id"]
    assert client.get("/api/v1/me/health-items", headers=headers).json() == {
        "medications": [],
        "allergies": [],
    }
    for path in ("notification-preferences", "accessibility-preferences", "profile"):
        assert client.get("/api/v1/me/" + path, headers=headers).status_code == 200


@pytest.mark.parametrize(
    "method,path,payload",
    [
        ("get", "/appointments/1", None),
        ("get", "/appointments/1/preparation", None),
        ("get", "/appointments/1/checklist", None),
        ("patch", "/appointments/1/checklist/1", {"is_completed": False}),
        ("get", "/appointments/1/attendance", None),
        ("put", "/appointments/1/attendance", {"attendance_status": "confirmed"}),
        ("get", "/appointments/1/report", None),
        (
            "put",
            "/appointments/1/report",
            {
                "expected_revision": "1",
                "intent": "edit",
                "original_text": "Privado",
                "sections": [],
                "questions": [],
            },
        ),
        ("post", "/appointments/1/report/review", {"expected_revision": "1"}),
        ("put", "/appointments/1/final-review", {"completed": True, "expected_revision": "1"}),
        ("delete", "/appointments/1/report/summary?expected_revision=1", None),
        ("get", "/facilities/1", None),
        ("get", "/me/health-records/1", None),
        ("patch", "/me/notifications/1", {"is_read": True}),
        (
            "post",
            "/reminders",
            {"appointment_id": "1", "title": "Privado", "remind_at": "2030-01-01T10:00:00Z"},
        ),
        (
            "put",
            "/me/health-items",
            {
                "medications": [{"id": "1", "name": "Privado", "details": "Privado"}],
                "allergies": [],
            },
        ),
    ],
)
def test_bearer_owner_cannot_read_or_mutate_demo_resources(
    authenticated_api, method, path, payload
):
    client, database, _ = authenticated_api
    result, _ = register(client)
    before = counts(database)
    response = client.request(method, "/api/v1" + path, headers=bearer(result), json=payload)
    assert response.status_code == 404
    assert counts(database) == before


def test_two_authenticated_users_are_isolated_for_mutable_account_resources(authenticated_api):
    client, _, _ = authenticated_api
    first, _ = register(client)
    second, _ = register(client, credentials("second@example.test"))
    one, two = bearer(first), bearer(second)
    assert (
        client.put(
            "/api/v1/me/health-items",
            headers=one,
            json={"medications": [{"name": "Fictício A", "details": "Texto"}], "allergies": []},
        ).status_code
        == 200
    )
    assert client.get("/api/v1/me/health-items", headers=two).json()["medications"] == []
    for module, field, value in (
        ("accessibility-preferences", "high_contrast", True),
        ("notification-preferences", "active", False),
    ):
        original = client.get("/api/v1/me/" + module, headers=two).json()
        changed = dict(original, **{field: value})
        assert client.put("/api/v1/me/" + module, headers=one, json=changed).status_code == 200
        assert client.get("/api/v1/me/" + module, headers=two).json() == original
    assert client.get("/api/v1/me/profile?user_id=1", headers=two).status_code == 400


def test_missing_or_short_key_fails_startup_without_disclosure(monkeypatch):
    from app.main import create_app

    for value in (None, "short"):
        monkeypatch.delenv("AUTH_SECRET_KEY", raising=False)
        settings = Settings(_env_file=None, auth_secret_key=value)
        with pytest.raises(ConfigurationError):
            with TestClient(create_app(settings)):
                pass
        assert "auth_secret_key" not in settings.model_dump()
    with pytest.raises(ConfigurationError):
        Settings(_env_file=None, app_env="test", auth_mode="demo").model_copy(
            update={"app_env": "production"}
        ).validate_auth()


def test_two_bearer_owners_see_only_their_appointments_reports_history_notifications_reminders(
    authenticated_api,
):
    from sqlalchemy import update

    from app.models import Allergy, Appointment, HealthRecord, Medication, Notification, Reminder

    client, database, _ = authenticated_api
    first, _ = register(client)
    second, _ = register(client, credentials("second@example.test"))
    one, two = bearer(first), bearer(second)
    # Transferência exclusivamente na fixture SQLite efêmera, para exercitar dois
    # titulares autenticados com recursos existentes em ambos os lados.
    with database.session() as session, session.begin():
        for model in (Appointment, HealthRecord, Medication, Allergy, Notification, Reminder):
            for legacy, account in ((1, first), (2, second)):
                session.execute(
                    update(model)
                    .where(model.user_id == legacy)
                    .values(user_id=int(account["user"]["id"]))
                )
    for owner, other, identifier in ((one, two, "1"), (two, one, "99")):
        for resource in (
            f"appointments/{identifier}",
            f"appointments/{identifier}/preparation",
            f"appointments/{identifier}/report",
            f"me/health-records/{identifier}",
        ):
            assert client.get("/api/v1/" + resource, headers=owner).status_code == 200
            assert client.get("/api/v1/" + resource, headers=other).status_code == 404
        assert (
            client.patch(
                f"/api/v1/me/notifications/{identifier}", headers=other, json={"is_read": True}
            ).status_code
            == 404
        )
        assert (
            client.patch(
                f"/api/v1/me/notifications/{identifier}", headers=owner, json={"is_read": True}
            ).status_code
            == 200
        )
    for headers, expected_id in ((one, first["user"]["id"]), (two, second["user"]["id"])):
        assert client.get("/api/v1/me/profile", headers=headers).json()["id"] == expected_id
    created = client.post(
        "/api/v1/reminders",
        headers=two,
        json={"title": "Fixture B", "appointment_id": "99", "remind_at": "2030-01-01T10:00:00Z"},
    )
    assert created.status_code == 201
    first_ids = {row["id"] for row in client.get("/api/v1/reminders", headers=one).json()["items"]}
    second_ids = {row["id"] for row in client.get("/api/v1/reminders", headers=two).json()["items"]}
    assert first_ids and second_ids and first_ids.isdisjoint(second_ids)
    assert created.json()["id"] in second_ids


def test_auth_cors_preflight_allows_authorization_without_wildcard(authenticated_api):
    client, _, app = authenticated_api
    # Mesmo conjunto de headers do middleware, testado em uma app com origem fictícia exata.
    from app.main import create_app

    settings = app.state.settings.model_copy(
        update={"cors_allowed_origins": ["http://web.example.test"]}
    )
    with TestClient(create_app(settings, app.state.database)) as cors:
        response = cors.options(
            "/api/v1/auth/me",
            headers={
                "Origin": "http://web.example.test",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
        assert response.status_code == 200
        assert response.headers["access-control-allow-origin"] == "http://web.example.test"
        assert "authorization" in response.headers["access-control-allow-headers"].lower()
