import pytest

GETS = [
    "/health",
    "/api/v1/me/profile",
    "/api/v1/facilities",
    "/api/v1/facilities/1",
    "/api/v1/appointments",
    "/api/v1/appointments/1",
    "/api/v1/preparation/overview",
    "/api/v1/appointments/1/preparation",
    "/api/v1/appointments/1/checklist",
    "/api/v1/appointments/1/attendance",
    "/api/v1/reminders",
    "/api/v1/me/health-items",
    "/api/v1/me/health-records",
    "/api/v1/me/health-records/1",
    "/api/v1/appointments/1/report",
    "/api/v1/me/notifications",
    "/api/v1/me/notification-preferences",
    "/api/v1/me/accessibility-preferences",
]


def assert_ids(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if (
                key == "id" or key.endswith("_id") or key.endswith("_revision")
            ) and item is not None:
                assert isinstance(item, str) and item.isdecimal()
            assert_ids(item)
    elif isinstance(value, list):
        for item in value:
            assert_ids(item)


@pytest.mark.parametrize("path", GETS)
def test_all_essential_gets_return_canonical_dtos(client, path):
    response = client.get(path)
    assert response.status_code == 200, response.text
    assert_ids(response.json())


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/appointments/99",
        "/api/v1/appointments/99/preparation",
        "/api/v1/appointments/99/checklist",
        "/api/v1/appointments/99/attendance",
        "/api/v1/appointments/99/report",
        "/api/v1/me/health-records/99",
        "/api/v1/facilities/3",
        "/api/v1/appointments/9999",
        "/api/v1/facilities/9999",
        "/api/v1/me/health-records/9999",
        "/api/v1/appointments/2/report",
    ],
)
def test_missing_or_foreign_resource_does_not_leak_existence(client, path):
    response = client.get(path)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "resource_not_found"
    assert "Privado" not in response.text


@pytest.mark.parametrize(
    "path", ["appointments", "reminders", "me/health-records", "me/notifications", "facilities"]
)
@pytest.mark.parametrize("query", ["limit=0", "limit=101", "offset=-1", "user_id=2"])
def test_pagination_and_identity_cannot_be_injected(client, path, query):
    assert client.get(f"/api/v1/{path}?{query}").status_code in {400, 422}


@pytest.mark.parametrize(
    "path,total", [("appointments", 3), ("facilities", 2), ("me/health-records", 6)]
)
def test_pagination_is_scoped_deterministic_and_has_total(client, path, total):
    first = client.get(f"/api/v1/{path}?limit=1&offset=0").json()
    second = client.get(f"/api/v1/{path}?limit=1&offset=1").json()
    assert first["pagination"] == {"limit": 1, "offset": 0, "total": total}
    assert first["items"][0]["id"] != second["items"][0]["id"]


def test_filters_use_local_day_and_reject_naive_instants(client):
    result = client.get("/api/v1/appointments?from=2026-10-09&to=2026-10-09").json()
    assert [row["id"] for row in result["items"]] == ["1"]
    assert result["items"][0]["scheduled_at"] == "2026-10-09T11:00:00Z"
    assert client.get("/api/v1/appointments?type=exam").json()["pagination"]["total"] == 1
    assert client.get("/api/v1/appointments?query=clínica").json()["pagination"]["total"] == 2
    assert client.get("/api/v1/appointments?query=%25").json()["pagination"]["total"] == 0
    assert client.get("/api/v1/appointments?from=2026-10-10&to=2026-10-09").status_code == 400
    assert client.get("/api/v1/appointments?from=2026-10-09T10:00:00").status_code == 422
    assert client.get("/api/v1/appointments?type=cancelled").status_code == 422
    assert client.get("/api/v1/me/health-records?type=exam").json()["pagination"]["total"] == 2
    assert client.get("/api/v1/reminders?appointment_id=99").status_code == 404


def test_demo_context_is_backend_only_and_does_not_autocreate(api_database):
    client, database, application = api_database
    from sqlalchemy import func, select

    from app.models import User

    application.state.settings.demo_user_id = 12345
    assert client.get("/api/v1/me/profile").status_code == 503
    with database.session() as session:
        assert session.scalar(select(func.count()).select_from(User)) == 2
    application.state.settings.demo_user_id = 1
    application.state.settings.demo_mode = False
    assert client.get("/api/v1/me/profile").json()["error"]["code"] == "demo_disabled"


def test_overview_empty_and_local_today_boundary(api_database, monkeypatch):
    from datetime import datetime

    from app.services import preparation

    client = api_database[0]
    monkeypatch.setattr(preparation, "utc_now", lambda: datetime(2026, 10, 10, 1, 0))
    result = client.get("/api/v1/preparation/overview").json()
    assert result["reference_date"] == "2026-10-09"
    assert result["next_appointment"]["id"] == "1"
    assert result["preparation"]["progress"]["percentage"] == 75
    monkeypatch.setattr(preparation, "utc_now", lambda: datetime(2027, 1, 1, 12))
    result = client.get("/api/v1/preparation/overview").json()
    assert result["next_appointment"] is None and result["preparation"] is None


@pytest.mark.parametrize(
    "method,path",
    [
        ("post", "/api/v1/appointments"),
        ("patch", "/api/v1/appointments/1"),
        ("patch", "/api/v1/reminders/1"),
        ("delete", "/api/v1/reminders/1"),
        ("delete", "/api/v1/appointments/1/report"),
    ],
)
def test_deferred_routes_remain_absent(client, method, path):
    assert getattr(client, method)(path).status_code in {404, 405}


def test_openapi_exactly_matches_approved_surface(client):
    specification = client.get("/openapi.json").json()
    from collections import Counter

    counts = Counter(method for methods in specification["paths"].values() for method in methods)
    assert counts == {"get": 19, "post": 4, "put": 7, "patch": 2, "delete": 1}
    assert (
        specification["components"]["schemas"]["AppointmentRead"]["properties"]["id"]["type"]
        == "string"
    )
    assert client.get("/docs").status_code == 200
    schemas = specification["components"]["schemas"]
    assert schemas["ReportWrite"]["properties"]["expected_revision"]["type"] == "string"
    assert schemas["RevisionCommand"]["properties"]["expected_revision"]["type"] == "string"
