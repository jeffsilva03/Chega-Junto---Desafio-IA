from app.core.errors import not_found
from app.models import Allergy, Medication
from app.repositories.health_items import HealthRepository
from app.repositories.users import UserRepository
from app.schemas.common import Page
from app.schemas.health_items import (
    DocumentRead,
    HealthItemRead,
    HealthItemsRead,
    HistoryDetail,
    HistoryRead,
)
from app.services.common import pagination, transaction, validate_child_ids


def health_dto(medications, allergies):
    return HealthItemsRead(
        medications=[HealthItemRead.model_validate(row) for row in medications],
        allergies=[HealthItemRead.model_validate(row) for row in allergies],
    )


class HealthService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = HealthRepository(session)

    def get(self):
        return health_dto(*self.repository.aggregate(self.user.id))

    def put(self, payload):
        with transaction(self.session):
            UserRepository(self.session).user(self.user.id, lock=True)
            medications, allergies = self.repository.aggregate(self.user.id, lock=True)
            validate_child_ids(medications, payload.medications)
            validate_child_ids(allergies, payload.allergies)
            medications = self.repository.replace(
                self.user.id, Medication, medications, payload.medications
            )
            allergies = self.repository.replace(self.user.id, Allergy, allergies, payload.allergies)
            result = health_dto(medications, allergies)
        return result

    def records(self, filters):
        rows, total = self.repository.records(
            self.user.id, filters, filters.bounds(self.user.timezone)
        )
        return Page[HistoryRead](
            items=[HistoryRead.model_validate(row[0]) for row in rows],
            pagination=pagination(filters, total),
        )

    def record(self, record_id):
        row = self.repository.record(self.user.id, record_id)
        if row is None:
            raise not_found()
        values = {
            field: getattr(row, field)
            for field in HistoryDetail.model_fields
            if field != "documents"
        }
        return HistoryDetail(
            **values,
            documents=[
                DocumentRead.model_validate(doc) for doc in self.repository.documents(record_id)
            ],
        )
