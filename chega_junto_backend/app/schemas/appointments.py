from typing import Annotated, Literal

from pydantic import AwareDatetime, Field, StrictBool, field_validator

from app.schemas.common import DTO, DatabaseId, ListFilter, NonEmpty, UtcDatetime, utc

AttendanceStatus = Literal["confirmed", "undecided", "unable"]
AppointmentStatus = Literal["scheduled", "cancelled", "completed"]
AppointmentType = Literal["consultation", "exam", "return"]


class FacilityRead(DTO):
    id: DatabaseId
    name: str
    address_text: str
    is_active: bool


class AppointmentFilter(ListFilter):
    type: AppointmentType | None = None
    query: str | None = Field(default=None, max_length=120)


class AppointmentRead(DTO):
    id: DatabaseId
    type: AppointmentType
    status: AppointmentStatus
    title: str
    specialty: str
    professional_name: str
    scheduled_at: UtcDatetime
    timezone: str
    facility: FacilityRead
    attendance_status: AttendanceStatus


class AppointmentDetail(AppointmentRead):
    instructions: list[str]
    attendance_responded_at: UtcDatetime | None


class ChecklistRead(DTO):
    id: DatabaseId
    item_key: str
    title: str
    section: Literal["documents", "reminders", "conversation"]
    is_required: bool
    is_completed: bool
    position: int


class ChecklistWrite(DTO):
    is_completed: StrictBool


class AttendanceWrite(DTO):
    attendance_status: AttendanceStatus


class AttendanceRead(AttendanceWrite):
    appointment_id: DatabaseId
    attendance_responded_at: UtcDatetime | None


class ReminderFilter(ListFilter):
    appointment_id: DatabaseId | None = None


class ReminderWrite(DTO):
    title: Annotated[NonEmpty, Field(max_length=80)]
    remind_at: AwareDatetime
    appointment_id: DatabaseId | None = None

    @field_validator("remind_at")
    @classmethod
    def mysql_instant(cls, value):
        try:
            result = utc(value)
        except (ValueError, OverflowError):
            raise ValueError("Instante fora do intervalo do MySQL.") from None
        if result.year < 1000:
            raise ValueError("Instante fora do intervalo do MySQL.")
        return result


class ReminderRead(DTO):
    id: DatabaseId
    title: str
    remind_at: UtcDatetime
    appointment_id: DatabaseId | None
    created_at: UtcDatetime
