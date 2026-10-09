from typing import Annotated, Literal

from pydantic import Field, model_validator

from app.schemas.common import DTO, DatabaseId, ListFilter, NonEmpty, UtcDatetime


class HealthItemWrite(DTO):
    id: DatabaseId | None = None
    name: Annotated[NonEmpty, Field(max_length=80)]
    details: str = Field(max_length=160)


class HealthItemRead(HealthItemWrite):
    id: DatabaseId
    position: int


class HealthItemsWrite(DTO):
    medications: list[HealthItemWrite] = Field(max_length=200)
    allergies: list[HealthItemWrite] = Field(max_length=200)

    @model_validator(mode="after")
    def unique_ids(self):
        for items in (self.medications, self.allergies):
            ids = [item.id for item in items if item.id is not None]
            if len(ids) != len(set(ids)):
                raise ValueError("IDs duplicados na lista.")
        return self


class HealthItemsRead(DTO):
    medications: list[HealthItemRead]
    allergies: list[HealthItemRead]


class HistoryFilter(ListFilter):
    type: Literal["consultation", "exam", "medication", "allergy", "diagnosis"] | None = None


class HistoryRead(DTO):
    id: DatabaseId
    type: Literal["consultation", "exam", "medication", "allergy", "diagnosis"]
    occurred_at: UtcDatetime
    title: str
    subtitle: str


class DocumentRead(DTO):
    id: DatabaseId
    title: str
    content_text: str
    position: int


class HistoryDetail(HistoryRead):
    professional_text: str | None
    facility_text: str | None
    reason: str
    summary: str
    notes: list[str]
    documents: list[DocumentRead]
