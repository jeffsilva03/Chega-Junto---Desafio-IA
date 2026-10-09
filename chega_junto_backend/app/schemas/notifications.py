from typing import Literal

from pydantic import field_validator

from app.schemas.common import DTO, DatabaseId, ListFilter, Page, UtcDatetime


class NotificationFilter(ListFilter):
    category: Literal["reminder", "consultation", "exam", "system"] | None = None
    unread: bool | None = None


class NotificationWrite(DTO):
    is_read: Literal[True]

    @field_validator("is_read", mode="before")
    @classmethod
    def only_true(cls, value):
        if value is not True:
            raise ValueError("Use o booleano true para marcar como lida.")
        return value


class NotificationRead(DTO):
    id: DatabaseId
    title: str
    message: str
    published_at: UtcDatetime
    category: str
    destination: str
    appointment_id: DatabaseId | None
    health_record_id: DatabaseId | None
    reminder_id: DatabaseId | None
    read_at: UtcDatetime | None
    is_read: bool


class NotificationPage(Page[NotificationRead]):
    unread_count: int
