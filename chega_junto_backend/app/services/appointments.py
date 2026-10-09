from app.core.errors import not_found
from app.database.base import utc_now
from app.repositories.appointments import AppointmentRepository
from app.schemas.appointments import (
    AppointmentDetail,
    AppointmentRead,
    AttendanceRead,
    FacilityRead,
    ReminderRead,
)
from app.schemas.common import Page, utc
from app.services.common import pagination, transaction
from app.services.notifications import NotificationService
from app.services.preparation import PreparationService, appointment_dto


class AppointmentService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = AppointmentRepository(session)

    def list(self, filters):
        rows, total = self.repository.appointments(
            self.user.id, filters, filters.bounds(self.user.timezone)
        )
        return Page[AppointmentRead](
            items=[appointment_dto(*row) for row in rows], pagination=pagination(filters, total)
        )

    def get(self, appointment_id):
        pair = self.repository.details(self.user.id, appointment_id)
        if pair is None:
            raise not_found()
        return appointment_dto(*pair, schema=AppointmentDetail)

    def facilities(self, filters):
        rows, total = self.repository.facilities(self.user.id, filters)
        return Page[FacilityRead](
            items=[FacilityRead.model_validate(row[0]) for row in rows],
            pagination=pagination(filters, total),
        )

    def facility(self, facility_id):
        row = self.repository.facility(self.user.id, facility_id)
        if row is None:
            raise not_found()
        return FacilityRead.model_validate(row)

    def owned(self, appointment_id, *, lock=False):
        row = self.repository.appointment(self.user.id, appointment_id, lock=lock)
        if row is None:
            raise not_found()
        return row

    def attendance(self, appointment_id):
        row = self.owned(appointment_id)
        return AttendanceRead(
            appointment_id=row.id,
            attendance_status=row.attendance_status,
            attendance_responded_at=row.attendance_responded_at,
        )

    def set_attendance(self, appointment_id, payload):
        with transaction(self.session):
            row = self.owned(appointment_id, lock=True)
            row.attendance_status = payload.attendance_status
            row.attendance_responded_at = utc_now()
            NotificationService(self.session, self.user).attendance(row)
            self.session.flush()
            result = self.attendance(appointment_id)
        return result

    def set_checklist(self, appointment_id, item_id, payload):
        with transaction(self.session):
            self.owned(appointment_id, lock=True)
            item = self.repository.checklist_item(appointment_id, item_id)
            if item is None:
                raise not_found()
            item.is_completed = payload.is_completed
            self.session.flush()
            result = PreparationService(self.session, self.user).checklist(
                appointment_id, lock=True
            )
        return result

    def reminders(self, filters):
        if filters.appointment_id is not None:
            self.owned(filters.appointment_id)
        rows, total = self.repository.reminders(
            self.user.id, filters, filters.bounds(self.user.timezone)
        )
        return Page[ReminderRead](
            items=[ReminderRead.model_validate(row[0]) for row in rows],
            pagination=pagination(filters, total),
        )

    def create_reminder(self, payload):
        with transaction(self.session):
            if payload.appointment_id is not None:
                self.owned(payload.appointment_id, lock=True)
            row = self.repository.add_reminder(
                user_id=self.user.id,
                title=payload.title,
                remind_at=utc(payload.remind_at).replace(tzinfo=None),
                appointment_id=payload.appointment_id,
            )
            NotificationService(self.session, self.user).reminder(row)
            self.session.flush()
            result = ReminderRead.model_validate(row)
        return result
