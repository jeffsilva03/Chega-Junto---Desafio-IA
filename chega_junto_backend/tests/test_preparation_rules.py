from datetime import datetime
from types import SimpleNamespace

import pytest

from app.services.preparation import checklist_summary, preparation_progress
from app.services.reports import source_hash


def item(required, completed):
    return SimpleNamespace(is_required=required, is_completed=completed)


def report(original="Original", revision=2, reviewed=2, final=2, current=True):
    return SimpleNamespace(
        original_text=original,
        content_revision=revision,
        reviewed_revision=reviewed,
        reviewed_at=datetime(2026, 10, 9),
        final_review_revision=final,
        final_review_at=datetime(2026, 10, 9),
        organized_source_hash=source_hash(original if current else "Antigo"),
    )


@pytest.mark.parametrize(
    "items,expected",
    [
        ([], True),
        ([item(False, False)], True),
        ([item(True, True), item(False, False)], True),
        ([item(True, False), item(False, True)], False),
    ],
)
def test_required_checklist_semantics(items, expected):
    progress = preparation_progress(items, "undecided", None, [])
    summary = checklist_summary(items)
    assert progress.documents_done is expected
    assert summary.fraction == (1 if expected else 0)
    assert progress.percentage == (25 if expected else 0)


@pytest.mark.parametrize(
    "attendance,completed", [("confirmed", True), ("undecided", False), ("unable", False)]
)
def test_attendance_done_only_confirmed(attendance, completed):
    assert preparation_progress([], attendance, None, []).attendance_done is completed


@pytest.mark.parametrize("original,done", [("", False), (" \n ", False), (" Fictício ", True)])
def test_report_done_depends_on_nonempty_original(original, done):
    assert preparation_progress([], "undecided", report(original), []).report_done is done


@pytest.mark.parametrize(
    "overrides,final_done",
    [
        ({}, True),
        ({"revision": 3}, False),
        ({"reviewed": 1}, False),
        ({"final": 1}, False),
        ({"current": False}, False),
    ],
)
def test_final_review_requires_current_provenance_and_all_revisions(overrides, final_done):
    progress = preparation_progress(
        [], "confirmed", report(**overrides), [SimpleNamespace(text="Conteúdo fictício")]
    )
    assert progress.final_done is final_done
    assert progress.completed_count == (4 if final_done else 3)
    assert progress.fraction == progress.completed_count / 4
    assert progress.percentage == progress.completed_count * 25


def test_final_review_requires_actual_section_content():
    for sections in ([], [SimpleNamespace(text="  ")]):
        assert not preparation_progress([], "confirmed", report(), sections).final_done
