from sqlalchemy import select

from app.models import Appointment, Facility, User, UserProfile
from app.repositories.common import paginate


class SimulatorRepository:
    def __init__(self, session):
        self.session = session

    @staticmethod
    def user_columns():
        # Projeção explícita: jamais carregar hash ou perfil completo.
        return User.id, UserProfile.full_name, User.email, User.is_active

    def user(self, *, email=None, user_id=None):
        statement = select(*self.user_columns()).join(UserProfile, UserProfile.user_id == User.id)
        statement = (
            statement.where(User.email == email)
            if email is not None
            else statement.where(User.id == user_id)
        )
        return self.session.execute(statement).mappings().first()

    def facility(self, facility_id):
        return self.session.scalar(
            select(Facility).where(Facility.id == facility_id, Facility.is_active.is_(True))
        )

    def facilities(self, filters):
        return paginate(
            self.session,
            select(Facility)
            .where(Facility.is_active.is_(True))
            .order_by(Facility.name, Facility.id),
            filters,
        )

    def appointment(self, appointment_id, *, lock=False):
        statement = select(Appointment).where(Appointment.id == appointment_id)
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))

    def appointments(self, filters):
        statement = (
            select(Appointment, Facility, *self.user_columns())
            .join(Facility)
            .join(User, User.id == Appointment.user_id)
            .join(UserProfile, UserProfile.user_id == User.id)
        )
        for field in ("user_id", "facility_id", "status"):
            value = getattr(filters, field)
            if value is not None:
                statement = statement.where(getattr(Appointment, field) == value)
        if filters.patient and filters.patient.strip():
            text = filters.patient.strip()
            statement = statement.where(
                UserProfile.full_name.contains(text, autoescape=True)
                | User.email.contains(text, autoescape=True)
            )
        if filters.specialty and filters.specialty.strip():
            statement = statement.where(
                Appointment.specialty.contains(filters.specialty.strip(), autoescape=True)
            )
        start, end = filters.bounds("America/Sao_Paulo")
        if start is not None:
            statement = statement.where(Appointment.scheduled_at >= start)
        if end is not None:
            statement = statement.where(Appointment.scheduled_at < end)
        return paginate(
            self.session, statement.order_by(Appointment.scheduled_at, Appointment.id), filters
        )

    def add(self, **values):
        row = Appointment(**values)
        self.session.add(row)
        self.session.flush()
        return row
