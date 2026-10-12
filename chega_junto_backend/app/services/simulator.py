from uuid import uuid4

from app.core.errors import ApiError, not_found
from app.models import AppointmentChecklistItem, Facility
from app.repositories.appointments import AppointmentRepository
from app.repositories.common import park_positions
from app.repositories.simulator import SimulatorRepository
from app.schemas.appointments import ChecklistRead, FacilityRead
from app.schemas.common import Page
from app.schemas.simulator import SimulatorAppointment, SimulatorDetail, SimulatorUser
from app.services.common import pagination, transaction, validate_child_ids
from app.services.preparation import appointment_dto


class SimulatorService:
    def __init__(self, session):
        self.session = session
        self.repository = SimulatorRepository(session)
        self.appointments = AppointmentRepository(session)

    def user(self, **query):
        row = self.repository.user(**query)
        if row is None:
            raise not_found()
        return SimulatorUser.model_validate(row)

    def facilities(self, filters):
        rows, total = self.repository.facilities(filters)
        return Page[FacilityRead](
            items=[FacilityRead.model_validate(row[0]) for row in rows],
            pagination=pagination(filters, total),
        )

    def list(self, filters):
        rows, total = self.repository.appointments(filters)
        return Page[SimulatorAppointment](
            items=[
                SimulatorAppointment(
                    **appointment_dto(row[0], row[1]).model_dump(),
                    patient=SimulatorUser(
                        id=row[2], full_name=row[3], email=row[4], is_active=row[5]
                    ),
                )
                for row in rows
            ],
            pagination=pagination(filters, total),
        )

    def owned_row(self, appointment_id, *, lock=False):
        row = self.repository.appointment(appointment_id, lock=lock)
        if row is None:
            raise not_found()
        return row

    def get(self, appointment_id):
        row = self.owned_row(appointment_id)
        facility = self.session.get(Facility, row.facility_id)
        return SimulatorDetail(
            **appointment_dto(row, facility).model_dump(),
            patient=self.user(user_id=row.user_id),
            instructions=row.instructions,
            checklist=[
                ChecklistRead.model_validate(item) for item in self.appointments.checklist(row.id)
            ],
        )

    def validate_facility(self, facility_id):
        if self.repository.facility(facility_id) is None:
            raise not_found()

    @staticmethod
    def title(row):
        prefix = {"consultation": "Consulta", "exam": "Exame", "return": "Retorno"}[row.type]
        return f"{prefix} — {row.specialty}"[:160]

    def replace_checklist(self, row, desired):
        existing = self.appointments.checklist(row.id, lock=True)
        validate_child_ids(existing, desired)
        by_id = {item.id: item for item in existing}
        park_positions(self.session, existing)
        kept = {item.id for item in desired if item.id is not None}
        for item in existing:
            if item.id not in kept:
                self.session.delete(item)
        self.session.flush()
        for position, item in enumerate(desired):
            target = by_id.get(item.id)
            if target is None:
                target = AppointmentChecklistItem(
                    appointment_id=row.id,
                    item_key=uuid4().hex,
                    section="documents",
                    is_completed=False,
                )
                self.session.add(target)
            elif target.title != item.description:
                target.is_completed = False
            target.title = item.description
            target.is_required = item.required
            target.position = position
        self.session.flush()

    def create(self, payload):
        with transaction(self.session):
            user = self.user(user_id=payload.user_id)
            if not user.is_active:
                raise ApiError(409, "state_conflict", "Usuário inativo.")
            self.validate_facility(payload.facility_id)
            row = self.repository.add(
                **payload.model_dump(exclude={"checklist", "scheduled_at"}),
                scheduled_at=payload.scheduled_at.replace(tzinfo=None),
                timezone="America/Sao_Paulo",
                title="",
                status="scheduled",
            )
            row.title = self.title(row)
            self.replace_checklist(row, payload.checklist)
            result = self.get(row.id)
        return result

    def patch(self, appointment_id, payload):
        with transaction(self.session):
            row = self.owned_row(appointment_id, lock=True)
            if row.status != "scheduled":
                raise ApiError(
                    409, "state_conflict", "Somente consultas agendadas podem ser editadas."
                )
            if payload.facility_id is not None:
                self.validate_facility(payload.facility_id)
            for field, value in payload.model_dump(
                exclude_unset=True, exclude={"checklist"}
            ).items():
                setattr(
                    row, field, value.replace(tzinfo=None) if field == "scheduled_at" else value
                )
            row.title = self.title(row)
            if payload.checklist is not None:
                self.replace_checklist(row, payload.checklist)
            self.session.flush()
            result = self.get(row.id)
        return result

    def cancel(self, appointment_id):
        with transaction(self.session):
            row = self.owned_row(appointment_id, lock=True)
            if row.status == "completed":
                raise ApiError(409, "state_conflict", "Consulta concluída não pode ser cancelada.")
            row.status = "cancelled"
            self.session.flush()
            result = self.get(row.id)
        return result
