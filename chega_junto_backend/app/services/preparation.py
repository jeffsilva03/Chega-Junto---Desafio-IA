from datetime import datetime, time
from zoneinfo import ZoneInfo

from app.core.errors import not_found
from app.database.base import utc_now
from app.repositories.appointments import AppointmentRepository
from app.repositories.reports import ReportRepository
from app.repositories.users import UserRepository
from app.schemas.appointments import AppointmentRead, AttendanceRead, ChecklistRead, FacilityRead
from app.schemas.preparation import (
    ChecklistResponse,
    ChecklistSummary,
    OverviewRead,
    PreparationRead,
    Progress,
    UserSummary,
)
from app.services.reports import report_state


def checklist_summary(items):
    required = [item for item in items if item.is_required]
    completed = sum(item.is_completed for item in required)
    fraction = completed / len(required) if required else 1.0
    return ChecklistSummary(
        required_count=len(required),
        required_completed_count=completed,
        fraction=fraction,
        percentage=round(fraction * 100),
    )


def preparation_progress(items, attendance, report, sections):
    documents = all(item.is_completed for item in items if item.is_required)
    state = report_state(report, sections)
    flags = (
        documents,
        attendance == "confirmed",
        bool(report and report.original_text.strip()),
        state.final_done,
    )
    count = sum(flags)
    return Progress(
        documents_done=flags[0],
        attendance_done=flags[1],
        report_done=flags[2],
        final_done=flags[3],
        completed_count=count,
        fraction=count / 4,
        percentage=count * 25,
    )


def appointment_dto(appointment, facility, schema=AppointmentRead):
    fields = {
        name: getattr(appointment, name) for name in schema.model_fields if name != "facility"
    }
    return schema(**fields, facility=FacilityRead.model_validate(facility))


class PreparationService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = AppointmentRepository(session)

    def get(self, appointment_id, *, lock=False):
        pair = self.repository.details(self.user.id, appointment_id, lock=lock)
        if pair is None:
            raise not_found()
        appointment, facility = pair
        items = self.repository.checklist(appointment_id, lock=lock)
        reports = ReportRepository(self.session)
        report = reports.report(appointment_id, lock=lock)
        sections = reports.children(report.id, lock=lock)[0] if report else []
        return PreparationRead(
            appointment=appointment_dto(appointment, facility),
            progress=preparation_progress(items, appointment.attendance_status, report, sections),
            checklist=checklist_summary(items),
            attendance=AttendanceRead(
                appointment_id=appointment.id,
                attendance_status=appointment.attendance_status,
                attendance_responded_at=appointment.attendance_responded_at,
            ),
            report=report_state(report, sections),
        )

    def checklist(self, appointment_id, *, lock=False):
        preparation = self.get(appointment_id, lock=lock)
        return ChecklistResponse(
            **preparation.checklist.model_dump(),
            items=[
                ChecklistRead.model_validate(row)
                for row in self.repository.checklist(appointment_id, lock=lock)
            ],
            progress=preparation.progress,
        )

    def overview(self):
        user = UserRepository(self.session).profile(self.user.id)
        if user is None:
            raise not_found()
        today = (
            utc_now()
            .replace(tzinfo=ZoneInfo("UTC"))
            .astimezone(ZoneInfo(self.user.timezone))
            .date()
        )
        start = (
            datetime.combine(today, time.min, ZoneInfo(self.user.timezone))
            .astimezone(ZoneInfo("UTC"))
            .replace(tzinfo=None)
        )
        next_appointment = self.repository.next_appointment(self.user.id, start)
        preparation = self.get(next_appointment.id) if next_appointment else None
        return OverviewRead(
            user=UserSummary(
                id=self.user.id,
                full_name=user.full_name,
                first_name=user.full_name.split()[0],
                timezone=self.user.timezone,
            ),
            reference_date=today,
            next_appointment=preparation.appointment if preparation else None,
            preparation=preparation,
        )
