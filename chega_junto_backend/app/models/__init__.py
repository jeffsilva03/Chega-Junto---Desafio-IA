"""Importar todos os models registra as tabelas no metadata do Alembic."""

from app.models.ai_usage import AiUsageEvent
from app.models.appointments import Appointment, AppointmentChecklistItem, Facility, Reminder
from app.models.health import Allergy, HealthRecord, HealthRecordDocument, Medication
from app.models.notifications import Notification
from app.models.operators import Operator
from app.models.preferences import AccessibilityPreferences, NotificationPreferences
from app.models.reports import PreVisitReport, ReportQuestion, ReportSection
from app.models.users import User, UserProfile

__all__ = [
    "AiUsageEvent",
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
    "Operator",
    "PreVisitReport",
    "Reminder",
    "ReportQuestion",
    "ReportSection",
    "User",
    "UserProfile",
]
