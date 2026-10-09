from sqlalchemy import func, select

from app.models import Notification
from app.repositories.common import paginate


class NotificationRepository:
    def __init__(self, session):
        self.session = session

    def get(self, user_id, notification_id, *, lock=False):
        statement = select(Notification).where(
            Notification.user_id == user_id, Notification.id == notification_id
        )
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def list(self, user_id, filters, bounds, visible_keys):
        visible = select(Notification).where(
            Notification.user_id == user_id, Notification.preference_key.in_(visible_keys)
        )
        unread_count = self.session.scalar(
            select(func.count()).select_from(
                visible.where(Notification.read_at.is_(None)).subquery()
            )
        )
        statement = visible
        if filters.category:
            statement = statement.where(Notification.category == filters.category)
        if filters.unread is not None:
            statement = statement.where(
                Notification.read_at.is_(None)
                if filters.unread
                else Notification.read_at.is_not(None)
            )
        start, end = bounds
        if start is not None:
            statement = statement.where(Notification.published_at >= start)
        if end is not None:
            statement = statement.where(Notification.published_at < end)
        rows, total = paginate(
            self.session,
            statement.order_by(Notification.published_at.desc(), Notification.id.desc()),
            filters,
        )
        return rows, total, unread_count

    def source(self, user_id, source_key):
        return self.session.scalar(
            select(Notification)
            .where(Notification.user_id == user_id, Notification.source_key == source_key)
            .with_for_update()
        )

    def attendance_card(self, user_id, appointment_id):
        return self.session.scalar(
            select(Notification)
            .where(
                Notification.user_id == user_id,
                Notification.appointment_id == appointment_id,
                Notification.preference_key == "confirmations",
            )
            .order_by(Notification.id)
            .limit(1)
            .with_for_update()
        )

    def add(self, **values):
        row = Notification(**values)
        self.session.add(row)
        self.session.flush()
        return row
