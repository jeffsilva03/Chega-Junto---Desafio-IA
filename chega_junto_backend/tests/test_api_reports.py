from copy import deepcopy

import pytest
from sqlalchemy import event
from sqlalchemy.dialects import mysql

from app.repositories.appointments import AppointmentRepository
from app.repositories.reports import ReportRepository
from app.repositories.users import UserRepository
from app.services.reports import source_hash

ROOT = "/api/v1/appointments/1"


def write_payload(report, **changes):
    result = {
        "expected_revision": report["content_revision"],
        "original_text": report["original_text"],
        "sections": [
            {k: v for k, v in row.items() if k != "position"} for row in report["sections"]
        ],
        "questions": [
            {k: v for k, v in row.items() if k != "position"} for row in report["questions"]
        ],
    }
    result.update(changes)
    return result


def save(client, payload, appointment=1):
    response = client.put(f"/api/v1/appointments/{appointment}/report", json=payload)
    assert response.status_code == 200, response.text
    return response.json()


def organized(client):
    initial = client.get(f"{ROOT}/report").json()
    payload = write_payload(
        initial, intent="organize", organization_source_text=initial["original_text"]
    )
    if not payload["sections"]:
        payload["sections"] = [
            {"section_key": key, "title": key, "text": ""}
            for key in ("reason", "points", "context", "other")
        ]
    payload["sections"][0]["text"] = "Relato organizado fictício."
    payload["questions"] = [
        {"text": "Primeira pergunta?", "is_selected": True},
        {"text": "Segunda pergunta?", "is_selected": False},
    ]
    return save(client, payload)


def review(client, report):
    response = client.post(
        f"{ROOT}/report/review", json={"expected_revision": report["content_revision"]}
    )
    assert response.status_code == 200, response.text
    return response.json()


def final(client, report, completed=True):
    response = client.put(
        f"{ROOT}/final-review",
        json={"expected_revision": report["content_revision"], "completed": completed},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_report_complete_lifecycle_and_stale_client(client, api_database):
    initial = client.get(f"{ROOT}/report").json()
    assert initial["content_revision"] == "1" and not initial["reviewed"]
    assert save(client, write_payload(initial)) == initial
    current = organized(client)
    assert current["content_revision"] == "2" and current["organization_current"]
    assert client.get(f"{ROOT}/report").json() == current
    assert (
        save(
            client,
            write_payload(
                current, intent="organize", organization_source_text=current["original_text"]
            ),
        )
        == current
    )
    assert "organized_source_hash" not in current
    with api_database[1].session() as session:
        row = ReportRepository(session).report(1)
        assert row.organized_source_hash == source_hash(current["original_text"])
    # Manual section edits keep the source hash, but require a new human review.
    payload = write_payload(current)
    payload["sections"][0]["text"] += " Edição manual."
    current = save(client, payload)
    assert current["content_revision"] == "3" and current["organization_current"]
    current = final(client, review(client, current))
    assert current["final_done"]
    assert final(client, current) == current
    reopened = final(client, current, False)
    assert not reopened["final_done"] and reopened["final_review_at"] is None
    assert final(client, reopened, False) == reopened
    current = final(client, reopened)
    stale = write_payload(current)
    payload = write_payload(current, original_text=current["original_text"] + " Outra informação.")
    current = save(client, payload)
    assert current["content_revision"] == "4"
    assert not current["organization_current"] and not current["reviewed"]
    assert not current["final_done"] and current["final_review_revision"] == "3"
    assert not client.get(f"{ROOT}/preparation").json()["progress"]["final_done"]
    for revision in ("3", "4"):
        response = client.post(f"{ROOT}/report/review", json={"expected_revision": revision})
        assert response.status_code == 409
    assert client.put(f"{ROOT}/report", json=stale).status_code == 409
    current = save(
        client,
        write_payload(
            current, intent="organize", organization_source_text=current["original_text"]
        ),
    )
    # Organizing the same effective content only refreshes provenance, not the revision.
    assert current["content_revision"] == "4" and current["organization_current"]
    current = review(client, current)
    assert review(client, current) == current
    current = final(client, current)
    payload = write_payload(current)
    payload["questions"].reverse()
    current = save(client, payload)
    assert current["content_revision"] == "5" and not current["final_done"]
    payload = write_payload(current)
    for question in payload["questions"]:
        question["is_selected"] = False
    current = save(client, payload)
    assert current["content_revision"] == "6"
    current = final(client, review(client, current))
    assert current["final_done"]  # No selected questions is explicitly allowed.
    payload = write_payload(current)
    payload["questions"].pop()
    current = save(client, payload)
    assert current["content_revision"] == "7" and not current["final_done"]
    payload = write_payload(current)
    payload["questions"].append({"text": "Nova pergunta?", "is_selected": True})
    current = save(client, payload)
    assert current["content_revision"] == "8"
    original = current["original_text"]
    response = client.delete(
        f"{ROOT}/report/summary", params={"expected_revision": current["content_revision"]}
    )
    assert response.status_code == 200
    cleared = response.json()
    assert cleared["content_revision"] == "9" and cleared["original_text"] == original
    assert cleared["id"] == initial["id"] and len(cleared["sections"]) == 4
    assert not cleared["questions"] and all(row["text"] == "" for row in cleared["sections"])
    assert not cleared["reviewed"] and not cleared["final_done"]
    assert cleared["organized_at"] is None and not cleared["organization_current"]
    assert (
        client.delete(f"{ROOT}/report/summary", params={"expected_revision": "9"}).json() == cleared
    )
    assert (
        client.delete(f"{ROOT}/report/summary", params={"expected_revision": "8"}).status_code
        == 409
    )
    assert client.get(f"{ROOT}/report").json() == cleared


def test_create_missing_report_and_conflicting_initial_revision(client):
    assert client.get("/api/v1/appointments/2/report").status_code == 404
    payload = {
        "expected_revision": "1",
        "original_text": "Fictício",
        "sections": [],
        "questions": [],
    }
    assert client.put("/api/v1/appointments/2/report", json=payload).status_code == 409
    payload["expected_revision"] = "0"
    current = save(client, payload, appointment=2)
    assert current["content_revision"] == "1" and current["sections"] == []
    assert client.put("/api/v1/appointments/2/report", json=payload).status_code == 409
    assert client.get("/api/v1/appointments/2/preparation").json()["progress"]["report_done"]


def test_manual_section_save_does_not_claim_organization(client):
    current = client.get(f"{ROOT}/report").json()
    payload = write_payload(current)
    payload["sections"] = [
        {"section_key": "reason", "title": "Motivo", "text": "Edição manual sem organização."}
    ]
    current = save(client, payload)
    assert current["has_content"] and not current["organization_current"]
    assert (
        client.post(
            f"{ROOT}/report/review", json={"expected_revision": current["content_revision"]}
        ).status_code
        == 409
    )
    assert (
        client.put(
            f"{ROOT}/final-review",
            json={"expected_revision": current["content_revision"], "completed": True},
        ).status_code
        == 409
    )


def test_empty_organized_sections_cannot_be_reviewed(client):
    current = organized(client)
    payload = write_payload(current, questions=[])
    for section in payload["sections"]:
        section["text"] = "   "
    current = save(client, payload)
    assert current["organization_current"] and not current["has_content"]
    assert (
        client.post(
            f"{ROOT}/report/review", json={"expected_revision": current["content_revision"]}
        ).status_code
        == 409
    )


def test_reorder_both_lists_under_immediate_unique_constraints(client, api_database):
    current = organized(client)
    sql_updates = []
    engine = api_database[1].engine

    def capture(_connection, _cursor, statement, parameters, _context, _many):
        if statement.startswith("UPDATE report_sections") or statement.startswith(
            "UPDATE report_questions"
        ):
            sql_updates.append((statement, parameters))

    event.listen(engine, "before_cursor_execute", capture)
    try:
        payload = write_payload(current)
        payload["sections"].reverse()
        payload["questions"].reverse()
        reordered = save(client, payload)
    finally:
        event.remove(engine, "before_cursor_execute", capture)
    assert [row["id"] for row in reordered["sections"]] == [
        row["id"] for row in reversed(current["sections"])
    ]
    assert [row["id"] for row in reordered["questions"]] == [
        row["id"] for row in reversed(current["questions"])
    ]
    assert [row["position"] for row in reordered["sections"]] == list(range(4))
    assert [row["position"] for row in reordered["questions"]] == [0, 1]
    # SQL trace confirms a separate flush parks positions before assigning 0..N-1.
    assert "65535" in str(sql_updates) and "65534" in str(sql_updates)
    assert save(client, write_payload(reordered)) == reordered


def test_mutating_reads_compile_mysql_for_update_and_owner_scope():
    class Capture:
        def __init__(self):
            self.statements = []

        def scalar(self, statement):
            self.statements.append(str(statement.compile(dialect=mysql.dialect())))

    session = Capture()
    AppointmentRepository(session).appointment(1, 1, lock=True)
    ReportRepository(session).report(1, lock=True)
    UserRepository(session).user(1, lock=True)
    assert all(statement.endswith("FOR UPDATE") for statement in session.statements)
    assert "appointments.user_id = %s" in session.statements[0]


@pytest.mark.parametrize("field", ["sections", "questions"])
def test_foreign_report_child_ids_are_404_and_atomic(client, field):
    current = organized(client)
    payload = write_payload(current)
    payload[field][0]["id"] = "99"
    assert client.put(f"{ROOT}/report", json=payload).status_code == 404
    assert client.get(f"{ROOT}/report").json() == current


@pytest.mark.parametrize(
    "method,suffix",
    [
        ("put", "/report"),
        ("post", "/report/review"),
        ("put", "/final-review"),
        ("delete", "/report/summary"),
    ],
)
def test_report_mutations_hide_foreign_appointment(client, method, suffix):
    current = client.get(f"{ROOT}/report").json()
    path = f"/api/v1/appointments/99{suffix}"
    kwargs = (
        {"params": {"expected_revision": "1"}}
        if method == "delete"
        else {
            "json": write_payload(current)
            if suffix == "/report"
            else {
                "expected_revision": "1",
                **({"completed": True} if suffix == "/final-review" else {}),
            }
        }
    )
    assert getattr(client, method)(path, **kwargs).status_code == 404
    assert client.get(f"{ROOT}/report").json() == current


@pytest.mark.parametrize(
    "field,value",
    [
        ("organized_source_hash", "fake"),
        ("reviewed_revision", "1"),
        ("final_review_revision", "1"),
        ("reviewed_at", "2026-10-09T00:00:00Z"),
        ("transcription_text", "Fake"),
        ("user_id", "2"),
        ("intent", "ai"),
        ("original_text", "x" * 20001),
        ("expected_revision", "-1"),
    ],
)
def test_report_input_server_fields_and_limits(client, field, value):
    current = client.get(f"{ROOT}/report").json()
    payload = write_payload(current)
    payload[field] = value
    assert client.put(f"{ROOT}/report", json=payload).status_code == 422
    assert client.get(f"{ROOT}/report").json() == current


@pytest.mark.parametrize(
    "mutation",
    [
        "source",
        "empty_source",
        "duplicate_section",
        "duplicate_question",
        "position",
        "question_size",
        "aggregate_size",
        "question_count",
        "section_count",
    ],
)
def test_report_nested_validation(client, mutation):
    current = organized(client)
    payload = write_payload(current)
    if mutation == "source":
        payload.update(intent="organize", organization_source_text="Original diferente")
    elif mutation == "empty_source":
        payload.update(intent="organize", original_text=" ", organization_source_text=" ")
    elif mutation == "duplicate_section":
        payload["sections"].append(deepcopy(payload["sections"][0]))
    elif mutation == "duplicate_question":
        payload["questions"].append(deepcopy(payload["questions"][0]))
    elif mutation == "position":
        payload["sections"][0]["position"] = 1
    elif mutation == "question_size":
        payload["questions"][0]["text"] = "x" * 4001
    elif mutation == "aggregate_size":
        payload["sections"] = [
            {"section_key": f"key_{i}", "title": "Título", "text": "x" * 20000} for i in range(6)
        ]
    elif mutation == "question_count":
        payload["questions"] = [{"text": "Pergunta?", "is_selected": False}] * 201
    else:
        payload["sections"] = [
            {"section_key": f"key_{i}", "title": "Título", "text": ""} for i in range(65)
        ]
    assert client.put(f"{ROOT}/report", json=payload).status_code == 422
    assert client.get(f"{ROOT}/report").json() == current


def test_report_over_500_characters_is_preserved(client):
    current = client.get(f"{ROOT}/report").json()
    text = "Informação fictícia. " * 400
    current = save(client, write_payload(current, original_text=text))
    assert current["original_text"] == text and len(text) > 500


def test_section_key_is_stable_for_existing_id(client):
    current = organized(client)
    payload = write_payload(current)
    payload["sections"][0]["section_key"] = "another_key"
    assert client.put(f"{ROOT}/report", json=payload).status_code == 400
    assert client.get(f"{ROOT}/report").json() == current


def test_report_all_children_and_revision_roll_back_after_flush(client, monkeypatch):
    current = organized(client)
    replace = ReportRepository.replace

    def fail_after_replace(self, *args):
        replace(self, *args)
        raise RuntimeError("private-database-connection-and-payload")

    monkeypatch.setattr(ReportRepository, "replace", fail_after_replace)
    payload = write_payload(current, original_text="Uma alteração fictícia.")
    payload["sections"].reverse()
    payload["questions"] = [{"text": "Outra pergunta?", "is_selected": True}]
    response = client.put(f"{ROOT}/report", json=payload)
    assert response.status_code == 500 and "private" not in response.text
    assert client.get(f"{ROOT}/report").json() == current


@pytest.mark.parametrize(
    "suffix,method,payload",
    [
        ("/report/review", "post", {"expected_revision": "1", "reviewed_at": "fake"}),
        ("/final-review", "put", {"expected_revision": "1", "completed": "true"}),
        ("/final-review", "put", {"expected_revision": "1", "completed": True, "user_id": "2"}),
        ("/report/summary", "delete", None),
    ],
)
def test_review_commands_require_clean_payloads_and_version(client, suffix, method, payload):
    kwargs = {"json": payload} if payload is not None else {}
    assert getattr(client, method)(ROOT + suffix, **kwargs).status_code == 422
