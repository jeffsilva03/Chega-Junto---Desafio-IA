"""Importar todos os models registra as 16 tabelas no metadata do Alembic."""

from app.models.appointments import Appointment, AppointmentChecklistItem, Facility, Reminder
from app.models.health import Allergy, HealthRecord, HealthRecordDocument, Medication
from app.models.notifications import Notification
from app.models.preferences import AccessibilityPreferences, NotificationPreferences
from app.models.reports import PreVisitReport, ReportQuestion, ReportSection
from app.models.users import User, UserProfile

__all__ = [
    "AccessibilityPreferences",
    "Allergy",
    "Appointment",
    "AppointmentChecklistItem",
    "Facility",
    "HealthRecord",
    "HealthRecordDocument",
    "Medication",
    "Notification",
    "NotificationPreferences",
    "PreVisitReport",
    "Reminder",
    "ReportQuestion",
    "ReportSection",
    "User",
    "UserProfile",
]
