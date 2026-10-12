from sqlalchemy import select

from app.models import Appointment, AppointmentChecklistItem, Facility, Reminder
from app.repositories.common import paginate


class AppointmentRepository:
    def __init__(self, session):
        self.session = session

    def appointment(self, user_id, appointment_id, *, lock=False):
        statement = select(Appointment).where(
            Appointment.id == appointment_id, Appointment.user_id == user_id
        )
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))

    def details(self, user_id, appointment_id, *, lock=False):
        statement = (
            select(Appointment, Facility)
            .join(Facility)
            .where(Appointment.id == appointment_id, Appointment.user_id == user_id)
        )
        if lock:
            statement = statement.with_for_update()
        return self.session.execute(statement.execution_options(populate_existing=True)).first()

    def appointments(self, user_id, filters, bounds):
        statement = (
            select(Appointment, Facility).join(Facility).where(Appointment.user_id == user_id)
        )
        start, end = bounds
        if start is not None:
            statement = statement.where(Appointment.scheduled_at >= start)
        if end is not None:
            statement = statement.where(Appointment.scheduled_at < end)
        if filters.type:
            statement = statement.where(Appointment.type == filters.type)
        if filters.query and filters.query.strip():
            statement = statement.where(
                Appointment.title.contains(filters.query.strip(), autoescape=True)
                | Appointment.specialty.contains(filters.query.strip(), autoescape=True)
                | Facility.name.contains(filters.query.strip(), autoescape=True)
            )
        return paginate(
            self.session, statement.order_by(Appointment.scheduled_at, Appointment.id), filters
        )

    def next_appointment(self, user_id, start):
        return self.session.scalar(
            select(Appointment)
            .where(
                Appointment.user_id == user_id,
                Appointment.scheduled_at >= start,
                Appointment.status == "scheduled",
            )
            .order_by(Appointment.scheduled_at, Appointment.id)
            .limit(1)
        )

    def facilities(self, user_id, filters):
        statement = (
            select(Facility)
            .where(
                select(Appointment.id)
                .where(Appointment.facility_id == Facility.id, Appointment.user_id == user_id)
                .exists()
            )
            .order_by(Facility.name, Facility.id)
        )
        return paginate(self.session, statement, filters)

    def facility(self, user_id, facility_id):
        return self.session.scalar(
            select(Facility).where(
                Facility.id == facility_id,
                select(Appointment.id)
                .where(Appointment.facility_id == Facility.id, Appointment.user_id == user_id)
                .exists(),
            )
        )

    def checklist(self, appointment_id, *, lock=False):
        statement = (
            select(AppointmentChecklistItem)
            .where(AppointmentChecklistItem.appointment_id == appointment_id)
            .order_by(AppointmentChecklistItem.position, AppointmentChecklistItem.id)
        )
        if lock:
            statement = statement.with_for_update()
        return list(self.session.scalars(statement.execution_options(populate_existing=True)))

    def checklist_item(self, appointment_id, item_id):
        return self.session.scalar(
            select(AppointmentChecklistItem)
            .where(
                AppointmentChecklistItem.appointment_id == appointment_id,
                AppointmentChecklistItem.id == item_id,
            )
            .with_for_update()
        )

    def reminders(self, user_id, filters, bounds):
        statement = select(Reminder).where(Reminder.user_id == user_id)
        start, end = bounds
        if start is not None:
            statement = statement.where(Reminder.remind_at >= start)
        if end is not None:
            statement = statement.where(Reminder.remind_at < end)
        if filters.appointment_id is not None:
            statement = statement.where(Reminder.appointment_id == filters.appointment_id)
        return paginate(self.session, statement.order_by(Reminder.remind_at, Reminder.id), filters)

    def add_reminder(self, **values):
        row = Reminder(**values)
        self.session.add(row)
        self.session.flush()
        return row
