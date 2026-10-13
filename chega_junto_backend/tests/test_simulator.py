import secrets
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import event, func, select

from app.core.config import Settings
from app.main import create_app
from app.models import Appointment, AppointmentChecklistItem, Facility, User
from app.repositories.simulator import SimulatorRepository
from app.services.simulator import SimulatorService

PREFIX = "/api/v1/simulator"
HEADERS = {"X-Simulator-Request": "local", "Origin": "http://127.0.0.1:5500"}


@pytest.fixture
def simulator(api_database):
    _, database, _ = api_database
    settings = Settings(_env_file=None, simulator_mode=True, auth_mode="jwt")
    application = create_app(settings, database)
    with TestClient(
        application, base_url="http://127.0.0.1", client=("127.0.0.1", 50000), headers=HEADERS
    ) as client:
        yield client, database, application


@pytest.fixture(params=["simulator", "operator"])
def scheduling(request, api_database, monkeypatch):
    if request.param == "simulator":
        yield request.getfixturevalue("simulator")
        return
    from app.schemas.operator import OperatorCreate
    from app.services.operator_auth import create_operator

    database = api_database[1]
    settings = Settings(
        _env_file=None,
        auth_mode="jwt",
        operator_portal_enabled=True,
        operator_auth_secret_key=secrets.token_urlsafe(32),
    )
    credentials = {"email": "operator@example.test", "password": secrets.token_urlsafe(24)}
    with database.session() as session:
        create_operator(session, OperatorCreate(full_name="Operador Fictício", **credentials))
    application = create_app(settings, database)
    monkeypatch.setattr(__import__(__name__, fromlist=["PREFIX"]), "PREFIX", "/api/v1/operator")
    with TestClient(application) as client:
        result = client.post("/api/v1/operator/auth/login", json=credentials)
        assert result.status_code == 200
        client.headers["Authorization"] = "Bearer " + result.json()["access_token"]
        yield client, database, application


def account(client):
    password = secrets.token_urlsafe(20)
    email = f"sim-{secrets.token_hex(5)}@example.test"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Paciente A Fictício", "email": email, "password": password},
    )
    assert response.status_code == 201
    return response.json(), password


def payload(owner_id, **changes):
    result = {
        "user_id": owner_id,
        "facility_id": "1",
        "specialty": "Clínica Geral",
        "professional_name": "Dra. Ana Teste",
        "type": "consultation",
        "scheduled_at": (datetime.now(UTC) + timedelta(days=7))
        .replace(hour=12, minute=30)
        .isoformat(),
        "instructions": ["Chegar com 20 minutos de antecedência."],
        "checklist": [
            {"description": "Documento com foto", "required": True},
            {"description": "Cartão SUS", "required": False},
        ],
    }
    return result | changes


def create(client, **changes):
    session, _ = account(client)
    result = client.post(PREFIX + "/appointments", json=payload(session["user"]["id"], **changes))
    assert result.status_code == 201, result.text
    return session, result.json()


@pytest.mark.parametrize(
    "method,path",
    [
        ("GET", "/users/search?email=none@example.test"),
        ("GET", "/appointments"),
        ("GET", "/facilities"),
        ("POST", "/appointments"),
        ("GET", "/appointments/1"),
        ("PATCH", "/appointments/1"),
        ("POST", "/appointments/1/cancel"),
    ],
)
def test_disabled_routes_are_unavailable(api_database, method, path):
    client = api_database[0]
    assert client.request(method, PREFIX + path, headers=HEADERS).status_code == 404
    assert all("/simulator" not in key for key in client.get("/openapi.json").json()["paths"])


def test_configuration_prohibits_production_and_remote_origins():
    with pytest.raises(ValidationError):
        Settings(_env_file=None, app_env="production", simulator_mode=True)
    with pytest.raises(ValidationError):
        Settings(_env_file=None, simulator_allowed_origins=["https://external.example.test"])
    assert Settings(_env_file=None).simulator_mode is False


@pytest.mark.parametrize("kind", ["peer", "host", "origin", "header", "forwarded"])
def test_local_guard_before_database(simulator, kind):
    _, database, application = simulator
    headers = HEADERS.copy()
    base_url = "http://127.0.0.1"
    peer = ("127.0.0.1", 50001)
    if kind in {"peer", "forwarded"}:
        peer = ("203.0.113.10", 50001)
    if kind == "forwarded":
        headers["X-Forwarded-For"] = "127.0.0.1"
    if kind == "host":
        base_url = "http://rebind.example.test"
    if kind == "origin":
        headers["Origin"] = "https://external.example.test"
    if kind == "header":
        headers.pop("X-Simulator-Request")
    queries = []

    def capture(*args):
        queries.append(args[2])

    event.listen(database.engine, "before_cursor_execute", capture)
    try:
        with TestClient(application, base_url=base_url, client=peer, headers=headers) as client:
            assert client.get(PREFIX + "/appointments").status_code == 403
        assert queries == []
    finally:
        event.remove(database.engine, "before_cursor_execute", capture)


def test_cors_preserves_app_and_exact_portal_origins(api_database):
    settings = Settings(
        _env_file=None, simulator_mode=True, cors_allowed_origins=["http://127.0.0.1:5173"]
    )
    with TestClient(create_app(settings, api_database[1])) as client:
        for origin in ("http://127.0.0.1:5500", "http://127.0.0.1:5173"):
            response = client.options(
                PREFIX + "/appointments",
                headers={
                    "Origin": origin,
                    "Access-Control-Request-Method": "POST",
                    "Access-Control-Request-Headers": "content-type,x-simulator-request",
                },
            )
            assert response.status_code == 200
            assert response.headers["access-control-allow-origin"] == origin
        assert (
            client.options(
                PREFIX + "/appointments",
                headers={
                    "Origin": "https://bad.example.test",
                    "Access-Control-Request-Method": "POST",
                },
            ).status_code
            == 400
        )


def test_search_minimal_normalized_and_unknown(scheduling):
    client, database, _ = scheduling
    session, _ = account(client)
    queries = []

    def capture(_conn, _cursor, sql, *_args):
        queries.append(sql)

    event.listen(database.engine, "before_cursor_execute", capture)
    try:
        response = client.get(
            PREFIX + "/users/search",
            params={"email": "  " + session["user"]["email"].upper() + "  "},
        )
    finally:
        event.remove(database.engine, "before_cursor_execute", capture)
    assert response.status_code == 200
    assert response.json() == session["user"] | {"is_active": True}
    assert all("password_hash" not in sql and "cpf" not in sql for sql in queries)
    assert (
        client.get(PREFIX + "/users/search", params={"email": "absent@example.test"}).status_code
        == 404
    )
    assert client.get(PREFIX + "/users/search", params={"email": "invalid"}).status_code == 422


def test_end_to_end_data_new_account_create_prepare_cancel(scheduling):
    client, database, _ = scheduling
    session, password = account(client)
    user_id = session["user"]["id"]
    auth = {"Authorization": "Bearer " + session["access_token"]}
    assert client.get("/api/v1/appointments", headers=auth).json()["pagination"]["total"] == 0
    assert (
        client.get("/api/v1/preparation/overview", headers=auth).json()["next_appointment"] is None
    )
    created = client.post(PREFIX + "/appointments", json=payload(user_id))
    assert created.status_code == 201
    record = created.json()
    assert set(record["patient"]) == {"id", "full_name", "email", "is_active"}
    login = client.post(
        "/api/v1/auth/login", json={"email": session["user"]["email"], "password": password}
    ).json()
    auth = {"Authorization": "Bearer " + login["access_token"]}
    listing = client.get("/api/v1/appointments", headers=auth).json()
    assert listing["items"][0]["id"] == record["id"]
    assert listing["items"][0]["status"] == "scheduled"
    detail = client.get(f"/api/v1/appointments/{record['id']}", headers=auth).json()
    assert detail["instructions"] == payload(user_id)["instructions"]
    overview = client.get("/api/v1/preparation/overview", headers=auth).json()
    assert overview["next_appointment"]["id"] == record["id"]
    assert overview["preparation"]["progress"]["documents_done"] is False
    checklist_url = f"/api/v1/appointments/{record['id']}/checklist"
    checklist = client.get(checklist_url, headers=auth).json()
    assert checklist["required_count"] == 1 and len(checklist["items"]) == 2
    optional = next(item for item in checklist["items"] if not item["is_required"])
    required = next(item for item in checklist["items"] if item["is_required"])
    client.patch(f"{checklist_url}/{optional['id']}", headers=auth, json={"is_completed": True})
    assert client.get(checklist_url, headers=auth).json()["percentage"] == 0
    client.patch(f"{checklist_url}/{required['id']}", headers=auth, json={"is_completed": True})
    assert client.get(checklist_url, headers=auth).json()["progress"]["documents_done"] is True
    assert client.post(f"{PREFIX}/appointments/{record['id']}/cancel").status_code == 200
    assert (
        client.get("/api/v1/preparation/overview", headers=auth).json()["next_appointment"] is None
    )
    assert (
        client.get("/api/v1/appointments", headers=auth).json()["items"][0]["status"] == "cancelled"
    )
    assert len(client.get(checklist_url, headers=auth).json()["items"]) == 2
    # Cancelamento idempotente, sem DELETE em pai/filhos.
    before = client.get(f"{PREFIX}/appointments/{record['id']}").json()
    assert client.post(f"{PREFIX}/appointments/{record['id']}/cancel").json() == before
    with database.session() as db:
        assert db.get(Appointment, int(record["id"])) is not None


@pytest.mark.parametrize("items", [[], [{"description": "Opcional", "required": False}]])
def test_zero_required_documents_done(scheduling, items):
    client = scheduling[0]
    session, record = create(client, checklist=items)
    response = client.get(
        f"/api/v1/appointments/{record['id']}/preparation",
        headers={"Authorization": "Bearer " + session["access_token"]},
    ).json()
    assert response["progress"]["documents_done"] is True
    assert response["checklist"]["percentage"] == 100


@pytest.mark.parametrize(
    "changes",
    [
        {"user_id": "99999"},
        {"facility_id": "99999"},
        {"scheduled_at": "2026-10-15T09:30:00"},
        {"scheduled_at": "2026-02-30T09:30:00-03:00"},
        {"scheduled_at": "0999-01-01T00:00:00Z"},
        {"scheduled_at": "2026-10-15T25:00:00-03:00"},
        {"specialty": " "},
        {"type": "unknown"},
        {"status": "cancelled"},
        {"timezone": "UTC"},
        {"checklist": [{"description": "Documento", "required": "true"}]},
        {"checklist": [{"id": "1", "description": "Documento", "required": True}]},
    ],
)
def test_invalid_creation(scheduling, changes):
    client = scheduling[0]
    session, _ = account(client)
    result = client.post(PREFIX + "/appointments", json=payload(session["user"]["id"], **changes))
    assert result.status_code in {404, 422}


def test_inactive_user_and_facility(scheduling):
    client, database, _ = scheduling
    session, _ = account(client)
    with database.session() as db:
        db.get(User, int(session["user"]["id"])).is_active = False
        db.commit()
    assert (
        client.post(PREFIX + "/appointments", json=payload(session["user"]["id"])).status_code
        == 409
    )
    with database.session() as db:
        db.get(User, int(session["user"]["id"])).is_active = True
        db.get(Facility, 1).is_active = False
        db.commit()
    assert (
        client.post(PREFIX + "/appointments", json=payload(session["user"]["id"])).status_code
        == 404
    )


@pytest.mark.parametrize("stage", ["checklist", "commit"])
def test_creation_rollback(scheduling, monkeypatch, stage):
    client, database, _ = scheduling
    session, _ = account(client)
    with database.session() as db:
        before = db.scalar(select(func.count()).select_from(Appointment))
        children = db.scalar(select(func.count()).select_from(AppointmentChecklistItem))
    if stage == "checklist":
        original = SimulatorService.replace_checklist

        def fail(self, row, desired):
            original(self, row, desired)
            raise RuntimeError("injected failure after children flush")

        monkeypatch.setattr(SimulatorService, "replace_checklist", fail)
    else:
        from sqlalchemy.orm import Session

        monkeypatch.setattr(
            Session,
            "commit",
            lambda _self: (_ for _ in ()).throw(RuntimeError("injected commit failure")),
        )
    assert (
        client.post(PREFIX + "/appointments", json=payload(session["user"]["id"])).status_code
        == 500
    )
    with database.session() as db:
        assert db.scalar(select(func.count()).select_from(Appointment)) == before
        assert db.scalar(select(func.count()).select_from(AppointmentChecklistItem)) == children


def test_patch_fields_checklist_preserve_ids_and_completion(scheduling):
    client = scheduling[0]
    session, record = create(client, scheduled_at="2026-10-20T09:30:00-03:00")
    assert record["scheduled_at"] == "2026-10-20T12:30:00Z"
    url = f"{PREFIX}/appointments/{record['id']}"
    item = record["checklist"][0]
    auth = {"Authorization": "Bearer " + session["access_token"]}
    client.patch(
        f"/api/v1/appointments/{record['id']}/checklist/{item['id']}",
        headers=auth,
        json={"is_completed": True},
    )
    result = client.patch(
        url,
        json={
            "specialty": "Retorno Fictício",
            "professional_name": "Dr. Teste",
            "type": "return",
            "facility_id": "2",
            "scheduled_at": "2026-10-21T10:45:00-03:00",
            "instructions": ["Orientação de teste"],
            "checklist": [{"id": item["id"], "description": item["title"], "required": True}],
        },
    ).json()
    assert result["patient"]["id"] == session["user"]["id"]
    assert result["type"] == "return" and result["facility"]["id"] == "2"
    assert result["scheduled_at"] == "2026-10-21T13:45:00Z"
    assert result["checklist"][0]["is_completed"] is True
    result = client.patch(
        url,
        json={
            "checklist": [{"id": item["id"], "description": "Descrição alterada", "required": True}]
        },
    ).json()
    assert result["checklist"][0]["is_completed"] is False
    assert client.patch(url, json={"checklist": []}).json()["checklist"] == []


@pytest.mark.parametrize(
    "changes",
    [
        {"user_id": "2"},
        {"status": "completed"},
        {"facility_id": None},
        {"checklist": None},
        {"specialty": None},
        {"facility_id": "99999"},
        {"checklist": [{"id": "99", "description": "Outro", "required": True}]},
    ],
)
def test_patch_cannot_change_owner_or_invalid_children(scheduling, changes):
    client = scheduling[0]
    _, record = create(client)
    url = f"{PREFIX}/appointments/{record['id']}"
    assert client.patch(url, json=changes).status_code in {404, 422}
    assert client.get(url).json() == record


def test_patch_rollback_and_reorder(scheduling, monkeypatch):
    client = scheduling[0]
    _, record = create(client)
    url = f"{PREFIX}/appointments/{record['id']}"
    items = [
        {"id": item["id"], "description": item["title"], "required": item["is_required"]}
        for item in reversed(record["checklist"])
    ]
    assert client.patch(url, json={"checklist": items}).status_code == 200
    before = client.get(url).json()
    original = SimulatorService.replace_checklist

    def fail(self, row, desired):
        original(self, row, desired)
        raise RuntimeError("injected")

    monkeypatch.setattr(SimulatorService, "replace_checklist", fail)
    assert client.patch(url, json={"specialty": "Não salvar", "checklist": []}).status_code == 500
    assert client.get(url).json() == before


def test_cancel_rejects_edit_and_completed(scheduling):
    client, database, _ = scheduling
    _, record = create(client)
    url = f"{PREFIX}/appointments/{record['id']}"
    assert client.post(url + "/cancel").status_code == 200
    assert client.patch(url, json={"specialty": "Mudança"}).status_code == 409
    with database.session() as db:
        db.get(Appointment, int(record["id"])).status = "completed"
        db.commit()
    assert client.post(url + "/cancel").status_code == 409


def test_pagination_filters_and_facilities(scheduling):
    client = scheduling[0]
    session, record = create(client, scheduled_at="2026-10-20T09:30:00-03:00")
    user_id = session["user"]["id"]
    client.post(
        PREFIX + "/appointments", json=payload(user_id, scheduled_at="2026-10-20T23:30:00-03:00")
    )
    client.post(
        PREFIX + "/appointments",
        json=payload(
            user_id, specialty="Outra Especialidade", scheduled_at="2026-10-21T00:00:00-03:00"
        ),
    )
    filters = {
        "user_id": user_id,
        "patient": "Paciente A",
        "specialty": "Clínica",
        "facility_id": "1",
        "status": "scheduled",
        "from": "2026-10-20",
        "to": "2026-10-20",
        "limit": 1,
    }
    first = client.get(PREFIX + "/appointments", params=filters).json()
    assert first["pagination"]["total"] == 2 and len(first["items"]) == 1
    second = client.get(PREFIX + "/appointments", params=filters | {"offset": 1}).json()
    assert second["items"][0]["id"] != first["items"][0]["id"]
    assert (
        client.get(PREFIX + "/appointments", params=filters | {"patient": "%"}).json()["items"]
        == []
    )
    assert client.get(PREFIX + "/appointments", params={"limit": 101}).status_code == 422
    assert (
        client.get(
            PREFIX + "/appointments", params={"from": "2026-10-22", "to": "2026-10-20"}
        ).status_code
        == 400
    )
    assert (
        client.get(PREFIX + "/facilities", params={"limit": 1}).json()["pagination"]["total"] == 3
    )
    assert client.get(PREFIX + "/appointments/99999").status_code == 404
    assert client.post(PREFIX + "/appointments/99999/cancel").status_code == 404
    assert client.delete(f"{PREFIX}/appointments/{record['id']}").status_code == 405


def test_simulator_has_no_clinical_surface_and_app_is_still_isolated(scheduling):
    client = scheduling[0]
    session, record = create(client)
    other, _ = account(client)
    assert (
        client.get(
            f"/api/v1/appointments/{record['id']}",
            headers={"Authorization": "Bearer " + other["access_token"]},
        ).status_code
        == 404
    )
    for path in ("/me/health-items", "/reports", "/users/1", "/appointments/1/report"):
        assert client.get(PREFIX + path).status_code == 404
    assert client.get("/api/v1/appointments").status_code == 401
    assert set(SimulatorRepository.user_columns()[i].key for i in range(4)) == {
        "id",
        "full_name",
        "email",
        "is_active",
    }
