import pytest
from sqlalchemy import event
from sqlalchemy.exc import IntegrityError, OperationalError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.repositories.users import UserRepository
from app.services.identity import UserContext
from tests.test_api_mutations import profile_payload


@pytest.mark.parametrize(
    "error,status",
    [
        (
            OperationalError(
                "private SQL", {"password": "private-secret"}, Exception("private-host")
            ),
            503,
        ),
        (
            IntegrityError(
                "private SQL", {"password": "private-secret"}, Exception("private-host")
            ),
            409,
        ),
        (SQLAlchemyError("private-host private-secret"), 500),
        (RuntimeError("private-host private-secret"), 500),
    ],
)
def test_errors_and_logs_never_expose_driver_or_payload(
    api_database, monkeypatch, caplog, error, status
):
    client, _, application = api_database
    application.dependency_overrides[get_current_user] = lambda: UserContext(1, "America/Sao_Paulo")

    def fail(*args, **kwargs):
        raise error

    monkeypatch.setattr(UserRepository, "profile", fail)
    response = client.get("/api/v1/me/profile")
    assert response.status_code == status
    assert set(response.json()) == {"error"}
    for private in ("private-host", "private-secret", "private SQL", "password"):
        assert private not in response.text and private not in caplog.text


def test_profile_commit_failure_rolls_back_entire_save(client, monkeypatch):
    before = client.get("/api/v1/me/profile").json()
    payload = profile_payload(client)
    payload["full_name"] = "Alteração fictícia que falhará"

    def fail(_self):
        raise RuntimeError("private commit error")

    with monkeypatch.context() as patch:
        patch.setattr(Session, "commit", fail)
        assert client.put("/api/v1/me/profile", json=payload).status_code == 500
    assert client.get("/api/v1/me/profile").json() == before


@pytest.mark.parametrize("query", ["to=9999-12-31", "from=0001-01-01", "to=not-a-date"])
def test_date_boundary_does_not_overflow_or_reach_driver(client, query):
    assert client.get(f"/api/v1/appointments?{query}").status_code == 422


@pytest.mark.parametrize("instant", ["0001-01-01T00:00:00Z", "9999-12-31T23:59:59-03:00"])
def test_reminder_datetimes_fit_mysql_after_utc_conversion(client, instant):
    response = client.post("/api/v1/reminders", json={"title": "Fictício", "remind_at": instant})
    assert response.status_code == 422


@pytest.mark.parametrize(
    "payload",
    [{"is_read": False}, {"is_read": 1}, {"is_read": "true"}, {"is_read": True, "read_at": "fake"}],
)
def test_notification_mark_read_only_accepts_boolean_true(client, payload):
    assert client.patch("/api/v1/me/notifications/1", json=payload).status_code == 422


def test_calendar_queries_do_not_grow_per_item_or_load_sensitive_aggregates(api_database):
    client, database, _ = api_database
    statements = []

    def capture(_connection, _cursor, statement, _parameters, _context, _many):
        statements.append(statement)

    event.listen(database.engine, "before_cursor_execute", capture)
    try:
        assert client.get("/api/v1/appointments?limit=1").status_code == 200
        small = len(statements)
        statements.clear()
        assert client.get("/api/v1/appointments?limit=100").status_code == 200
        assert len(statements) == small
        for sensitive in ("pre_visit_reports", "report_questions", "medications", "health_records"):
            assert not any(sensitive in statement for statement in statements)
    finally:
        event.remove(database.engine, "before_cursor_execute", capture)
