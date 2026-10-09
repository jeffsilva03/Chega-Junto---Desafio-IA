from copy import deepcopy

import pytest
from sqlalchemy import func, select

from app.models import Allergy, Appointment, Medication, Notification, Reminder
from app.schemas.profile import ProfileWrite


def profile_payload(client):
    current = client.get("/api/v1/me/profile").json()
    return {field: current[field] for field in ProfileWrite.model_fields}


def health_payload(client):
    current = client.get("/api/v1/me/health-items").json()
    return {
        key: [{k: v for k, v in item.items() if k != "position"} for item in items]
        for key, items in current.items()
    }


def count(database, model):
    with database.session() as session:
        return session.scalar(select(func.count()).select_from(model))


def test_profile_full_save_normalizes_and_reloads(client):
    before = client.get("/api/v1/me/profile").json()
    payload = profile_payload(client)
    payload.update(
        full_name=" Maria Demo ",
        phone="+55 (11) 99999-9999",
        cpf="123.456.789-00",
        postcode="01000-000",
        complement="   ",
        state_code=" sp ",
    )
    response = client.put("/api/v1/me/profile", json=payload)
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["phone"] == "5511999999999" and result["cpf"] == "12345678900"
    assert result["postcode"] == "01000000" and result["complement"] is None
    assert result["full_name"] == "Maria Demo" and result["state_code"] == "SP"
    assert result["id"] == before["id"] and result["sus_card_number"] == before["sus_card_number"]
    assert client.get("/api/v1/me/profile").json() == result
    assert client.put("/api/v1/me/profile", json=payload).json() == result


@pytest.mark.parametrize(
    "field,value",
    [
        ("cpf", "abc12345678900"),
        ("cpf", "123"),
        ("postcode", "12"),
        ("phone", "1"),
        ("emergency_phone", "fake"),
        ("birth_date", "2100-01-01"),
        ("state_code", "XX"),
        ("full_name", " "),
        ("email", "bad"),
        ("user_id", "2"),
        ("updated_at", "2026-10-09T00:00:00Z"),
        ("sus_card_number", "1"),
    ],
)
def test_profile_rejects_invalid_or_server_fields_without_mutation(client, field, value):
    before = client.get("/api/v1/me/profile").json()
    payload = profile_payload(client)
    payload[field] = value
    response = client.put("/api/v1/me/profile", json=payload)
    assert response.status_code == 422
    assert client.get("/api/v1/me/profile").json() == before


def test_checklist_only_required_items_affect_preparation(client):
    before = client.get("/api/v1/appointments/1/checklist").json()
    optional = next(row for row in before["items"] if not row["is_required"])
    result = client.patch(
        f"/api/v1/appointments/1/checklist/{optional['id']}",
        json={"is_completed": not optional["is_completed"]},
    ).json()
    assert result["percentage"] == 100 and result["progress"]["documents_done"]
    required = next(row for row in before["items"] if row["is_required"])
    path = f"/api/v1/appointments/1/checklist/{required['id']}"
    result = client.patch(path, json={"is_completed": False}).json()
    assert result["percentage"] == 50 and result["progress"]["percentage"] == 50
    assert client.patch(path, json={"is_completed": False}).json() == result
    assert client.patch(path, json={"is_completed": True, "is_required": False}).status_code == 422
    assert (
        client.patch("/api/v1/appointments/1/checklist/99", json={"is_completed": True}).status_code
        == 404
    )
    assert (
        client.patch(
            "/api/v1/appointments/99/checklist/99", json={"is_completed": True}
        ).status_code
        == 404
    )
    assert client.get("/api/v1/appointments/1/report").json()["content_revision"] == "1"


@pytest.mark.parametrize(
    "status,done", [("confirmed", True), ("undecided", False), ("unable", False)]
)
def test_attendance_explicit_save_and_notification_preserve_read_state(api_database, status, done):
    client, database, _ = api_database
    with database.session() as session:
        card = session.scalar(
            select(Notification).where(Notification.preference_key == "confirmations")
        )
        card_id, read_at, published_at = card.id, card.read_at, card.published_at
    before_count = count(database, Notification)
    payload = {"attendance_status": status}
    result = client.put("/api/v1/appointments/1/attendance", json=payload)
    assert result.status_code == 200 and result.json()["attendance_responded_at"].endswith("Z")
    assert client.put("/api/v1/appointments/1/attendance", json=payload).status_code == 200
    assert count(database, Notification) == before_count
    with database.session() as session:
        card = session.get(Notification, card_id)
        assert card.read_at == read_at and card.published_at == published_at
        assert "unidade foi avisada" not in card.message
        assert session.get(Appointment, 1).attendance_status == status
    assert (
        client.get("/api/v1/appointments/1/preparation").json()["progress"]["attendance_done"]
        is done
    )
    assert client.get("/api/v1/appointments/1/report").json()["content_revision"] == "1"
    assert (
        client.put(
            "/api/v1/appointments/1/attendance", json={"attendance_status": "cancelled"}
        ).status_code
        == 422
    )
    assert client.put("/api/v1/appointments/99/attendance", json=payload).status_code == 404


def test_reminders_create_linked_and_standalone_are_scoped_and_atomic(api_database):
    client, database, _ = api_database
    before = count(database, Notification)
    payload = {
        "title": "Lembrete fictício",
        "remind_at": "2026-10-13T09:00:00-03:00",
        "appointment_id": "2",
    }
    response = client.post("/api/v1/reminders", json=payload)
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["id"].isdecimal() and result["remind_at"] == "2026-10-13T12:00:00Z"
    assert count(database, Notification) == before + 1
    assert client.get("/api/v1/reminders?appointment_id=2").json()["items"][0] == result
    payload["appointment_id"] = None
    assert client.post("/api/v1/reminders", json=payload).status_code == 201
    assert count(database, Notification) == before + 1
    payload["appointment_id"] = "99"
    assert client.post("/api/v1/reminders", json=payload).status_code == 404
    assert count(database, Reminder) == 3


@pytest.mark.parametrize(
    "update",
    [
        {"remind_at": "2026-10-09T10:00:00"},
        {"title": ""},
        {"title": "a" * 81},
        {"user_id": "2"},
        {"delivery_status": "sent"},
    ],
)
def test_reminder_input_limits_and_server_fields(client, update):
    payload = {"title": "Teste fictício", "remind_at": "2026-10-13T10:00:00Z"} | update
    assert client.post("/api/v1/reminders", json=payload).status_code == 422


def test_health_items_full_replace_reorder_create_remove_and_noop(client):
    payload = health_payload(client)
    payload["medications"] = list(reversed(payload["medications"]))[:2] + [
        {"name": "Item fictício", "details": "Livre"}
    ]
    payload["medications"][0]["details"] = "Edição fictícia"
    payload["allergies"] = []
    response = client.put("/api/v1/me/health-items", json=payload)
    assert response.status_code == 200, response.text
    result = response.json()
    assert len(result["medications"]) == 3 and result["allergies"] == []
    assert [row["position"] for row in result["medications"]] == [0, 1, 2]
    assert result["medications"][2]["id"].isdecimal()
    assert client.put("/api/v1/me/health-items", json=health_payload(client)).json() == result
    assert client.get("/api/v1/me/health-records").json()["pagination"]["total"] == 6


@pytest.mark.parametrize("list_name", ["medications", "allergies"])
def test_health_foreign_ids_rejected_without_changing_either_list(client, list_name):
    before = client.get("/api/v1/me/health-items").json()
    payload = health_payload(client)
    payload["medications"][0]["name"] = "Não deve persistir"
    payload[list_name][0]["id"] = "99"
    assert client.put("/api/v1/me/health-items", json=payload).status_code == 404
    assert client.get("/api/v1/me/health-items").json() == before


@pytest.mark.parametrize(
    "update",
    [
        {"name": "a" * 81},
        {"details": "a" * 161},
        {"user_id": "2"},
        {"position": 1},
    ],
)
def test_health_item_input_limits(client, update):
    payload = health_payload(client)
    payload["medications"][0].update(update)
    assert client.put("/api/v1/me/health-items", json=payload).status_code == 422


def test_health_aggregate_requires_both_lists_and_unique_ids(client):
    payload = health_payload(client)
    assert client.put("/api/v1/me/health-items", json={"medications": []}).status_code == 422
    payload["allergies"].append(deepcopy(payload["allergies"][0]))
    assert client.put("/api/v1/me/health-items", json=payload).status_code == 422


def test_health_rollback_after_medications_flush(api_database, monkeypatch):
    from app.repositories.health_items import HealthRepository

    client, database, _ = api_database
    before = client.get("/api/v1/me/health-items").json()
    payload = health_payload(client)
    payload["medications"][0]["name"] = "Não deve persistir"
    original = HealthRepository.replace

    def fail_second(self, user_id, model, existing, desired):
        if model is Allergy:
            raise RuntimeError("secret-sentinel-health")
        return original(self, user_id, model, existing, desired)

    monkeypatch.setattr(HealthRepository, "replace", fail_second)
    response = client.put("/api/v1/me/health-items", json=payload)
    assert response.status_code == 500 and "secret-sentinel" not in response.text
    assert client.get("/api/v1/me/health-items").json() == before
    assert count(database, Medication) == 5


@pytest.mark.parametrize("operation", ["reminder", "attendance"])
def test_notification_failure_rolls_back_parent(api_database, monkeypatch, operation):
    from app.services.notifications import NotificationService

    client, database, _ = api_database
    old_count = count(database, Reminder)
    old_attendance = client.get("/api/v1/appointments/1/attendance").json()

    def fail(self, _parent):
        self.session.flush()
        raise RuntimeError("secret-sentinel-notification")

    monkeypatch.setattr(NotificationService, operation, fail)
    if operation == "reminder":
        response = client.post(
            "/api/v1/reminders",
            json={
                "title": "Não persistir",
                "remind_at": "2026-10-13T10:00:00Z",
                "appointment_id": "1",
            },
        )
    else:
        response = client.put(
            "/api/v1/appointments/1/attendance", json={"attendance_status": "unable"}
        )
    assert response.status_code == 500
    assert count(database, Reminder) == old_count
    assert client.get("/api/v1/appointments/1/attendance").json() == old_attendance


def test_notifications_read_is_idempotent_global_badge_and_preferences(client, api_database):
    database = api_database[1]
    result = client.get("/api/v1/me/notifications?limit=1&unread=false").json()
    assert result["unread_count"] == 2 and len(result["items"]) == 1
    unread = client.get("/api/v1/me/notifications?unread=true").json()["items"][0]
    path = f"/api/v1/me/notifications/{unread['id']}"
    marked = client.patch(path, json={"is_read": True}).json()
    assert marked["read_at"].endswith("Z") and marked["is_read"]
    assert client.patch(path, json={"is_read": True}).json() == marked
    assert client.get("/api/v1/me/notifications").json()["unread_count"] == 1
    assert client.patch(path, json={"is_read": False}).status_code == 422
    assert client.patch("/api/v1/me/notifications/99", json={"is_read": True}).status_code == 404
    preferences = client.get("/api/v1/me/notification-preferences").json()
    preferences["active"] = False
    assert client.put("/api/v1/me/notification-preferences", json=preferences).status_code == 200
    result = client.get("/api/v1/me/notifications").json()
    assert result["items"] == [] and result["unread_count"] == 0
    assert count(database, Notification) == 7
    preferences["active"] = True
    client.put("/api/v1/me/notification-preferences", json=preferences)
    assert client.get("/api/v1/me/notifications").json()["unread_count"] == 1


@pytest.mark.parametrize("path", ["notification-preferences", "accessibility-preferences"])
def test_preferences_full_save_noop_and_server_fields(client, path):
    route = f"/api/v1/me/{path}"
    payload = client.get(route).json()
    first_field = "active" if path.startswith("notification") else "speech"
    payload[first_field] = not payload[first_field]
    assert client.put(route, json=payload).json() == payload
    assert client.get(route).json() == payload
    assert client.put(route, json=payload).json() == payload
    assert client.put(route, json=payload | {"user_id": "2"}).status_code == 422
    assert client.put(route, json=payload | {first_field: "true"}).status_code == 422
