from typing import Annotated, Self

from pydantic import AwareDatetime, Field, StrictBool, field_validator, model_validator

from app.schemas.appointments import (
    AppointmentRead,
    AppointmentStatus,
    AppointmentType,
    ChecklistRead,
)
from app.schemas.common import DTO, DatabaseId, ListFilter, NonEmpty, utc

Specialty = Annotated[NonEmpty, Field(max_length=120)]
Professional = Annotated[NonEmpty, Field(max_length=160)]
Instructions = Annotated[list[Annotated[NonEmpty, Field(max_length=500)]], Field(max_length=50)]


class SimulatorUser(DTO):
    id: DatabaseId
    full_name: str
    email: str | None
    is_active: bool


class SimulatorChecklistWrite(DTO):
    id: DatabaseId | None = None
    description: Annotated[NonEmpty, Field(max_length=200)]
    required: StrictBool


class SimulatorPatch(DTO):
    specialty: Specialty | None = None
    professional_name: Professional | None = None
    facility_id: DatabaseId | None = None
    scheduled_at: AwareDatetime | None = None
    type: AppointmentType | None = None
    instructions: Instructions | None = None
    checklist: list[SimulatorChecklistWrite] | None = Field(default=None, max_length=200)

    @field_validator("scheduled_at")
    @classmethod
    def valid_instant(cls, value):
        if value is None:
            return value
        try:
            result = utc(value)
            if not 1000 <= result.year <= 9998:
                raise ValueError()
        except (ValueError, OverflowError):
            raise ValueError("Data fora do intervalo operacional.") from None
        return result

    @model_validator(mode="after")
    def valid_patch(self) -> Self:
        if any(getattr(self, name) is None for name in self.model_fields_set):
            raise ValueError("Campos enviados não podem ser null.")
        ids = [item.id for item in self.checklist or [] if item.id is not None]
        if len(ids) != len(set(ids)):
            raise ValueError("IDs de checklist duplicados.")
        return self


class SimulatorCreate(SimulatorPatch):
    user_id: DatabaseId
    specialty: Specialty
    professional_name: Professional
    facility_id: DatabaseId
    scheduled_at: AwareDatetime
    type: AppointmentType = "consultation"
    instructions: Instructions = Field(default_factory=list)
    checklist: list[SimulatorChecklistWrite] = Field(default_factory=list, max_length=200)

    @model_validator(mode="after")
    def new_children(self) -> Self:
        if any(item.id is not None for item in self.checklist):
            raise ValueError("Novo checklist não aceita IDs existentes.")
        return self


class SimulatorFilter(ListFilter):
    user_id: DatabaseId | None = None
    patient: str | None = Field(default=None, max_length=160)
    facility_id: DatabaseId | None = None
    specialty: str | None = Field(default=None, max_length=120)
    status: AppointmentStatus | None = None


class SimulatorAppointment(AppointmentRead):
    patient: SimulatorUser


class SimulatorDetail(SimulatorAppointment):
    instructions: list[str]
    checklist: list[ChecklistRead]
