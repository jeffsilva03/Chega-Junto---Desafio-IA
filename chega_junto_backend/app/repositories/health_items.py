from sqlalchemy import select

from app.models import Allergy, HealthRecord, HealthRecordDocument, Medication
from app.repositories.common import paginate, replace_ordered


class HealthRepository:
    def __init__(self, session):
        self.session = session

    def items(self, user_id, model, *, lock=False):
        statement = select(model).where(model.user_id == user_id).order_by(model.position, model.id)
        if lock:
            statement = statement.with_for_update()
        return list(self.session.scalars(statement.execution_options(populate_existing=True)))

    def aggregate(self, user_id, *, lock=False):
        return self.items(user_id, Medication, lock=lock), self.items(user_id, Allergy, lock=lock)

    def replace(self, user_id, model, existing, desired):
        return replace_ordered(
            self.session, model, existing, desired, "user_id", user_id, ("name", "details")
        )

    def records(self, user_id, filters, bounds):
        statement = select(HealthRecord).where(HealthRecord.user_id == user_id)
        start, end = bounds
        if start is not None:
            statement = statement.where(HealthRecord.occurred_at >= start)
        if end is not None:
            statement = statement.where(HealthRecord.occurred_at < end)
        if filters.type:
            statement = statement.where(HealthRecord.type == filters.type)
        return paginate(
            self.session,
            statement.order_by(HealthRecord.occurred_at.desc(), HealthRecord.id.desc()),
            filters,
        )

    def record(self, user_id, record_id):
        return self.session.scalar(
            select(HealthRecord).where(
                HealthRecord.id == record_id, HealthRecord.user_id == user_id
            )
        )

    def documents(self, record_id):
        return list(
            self.session.scalars(
                select(HealthRecordDocument)
                .where(HealthRecordDocument.health_record_id == record_id)
                .order_by(HealthRecordDocument.position, HealthRecordDocument.id)
            )
        )
