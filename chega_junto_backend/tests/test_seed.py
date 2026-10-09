from unittest.mock import Mock

import pytest

from app.models import Appointment, AppointmentChecklistItem, PreVisitReport, User, UserProfile
from scripts.seed_demo import DEMO_EMAIL, SeedConflict, demo_time, populate_demo


def test_seed_builds_fictitious_aggregate_without_external_connection():
    session = Mock()
    session.get.return_value = None
    session.execute.return_value.first.return_value = None
    added = []
    session.add.side_effect = added.append
    session.add_all.side_effect = added.extend
    assert populate_demo(session, 1) == "created"
    assert len([item for item in added if isinstance(item, Appointment)]) == 3
    checklist = [item for item in added if isinstance(item, AppointmentChecklistItem)]
    assert len(checklist) == 7
    assert all(item.is_completed for item in checklist if item.is_required)
    report = next(item for item in added if isinstance(item, PreVisitReport))
    assert report.original_text.strip()
    assert report.final_review_revision is None
    assert not hasattr(report, "transcription_text")
    session.commit.assert_not_called()  # Transação pertence ao chamador.
    assert demo_time(9, 8).hour == 11  # Horário fictício local convertido para UTC.


def test_seed_repeat_does_not_overwrite_saved_content():
    session = Mock()
    existing = {
        User: User(id=1, email=DEMO_EMAIL),
        UserProfile: UserProfile(user_id=1),
        Appointment: Appointment(id=1, user_id=1),
    }
    session.get.side_effect = lambda model, _id: existing[model]
    assert populate_demo(session, 1) == "already_exists"
    session.add.assert_not_called()
    session.add_all.assert_not_called()


def test_seed_refuses_conflicting_existing_data():
    session = Mock()
    session.get.return_value = None
    session.execute.return_value.first.return_value = ("existing",)
    with pytest.raises(SeedConflict):
        populate_demo(session, 1)
    session.add.assert_not_called()
