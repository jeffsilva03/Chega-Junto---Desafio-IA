from typing import Annotated, Literal

from pydantic import Field, StrictBool, model_validator

from app.schemas.clarifications import ClarificationRead
from app.schemas.common import DTO, DatabaseId, NonEmpty, Revision, UtcDatetime


class SectionWrite(DTO):
    id: DatabaseId | None = None
    section_key: str = Field(min_length=1, max_length=64, pattern=r"^[a-z][a-z0-9_]*$")
    title: Annotated[NonEmpty, Field(max_length=160)]
    text: str = Field(max_length=20000)


class QuestionWrite(DTO):
    id: DatabaseId | None = None
    text: Annotated[NonEmpty, Field(max_length=4000)]
    is_selected: StrictBool


class ReportWrite(DTO):
    expected_revision: Revision
    original_text: str = Field(max_length=20000)
    sections: list[SectionWrite] = Field(max_length=64)
    questions: list[QuestionWrite] = Field(max_length=200)
    intent: Literal["edit", "organize"] = "edit"
    organization_source_text: str | None = Field(default=None, max_length=20000)
    organization_source_hash: str | None = Field(default=None, pattern=r"^[a-f0-9]{64}$")

    @model_validator(mode="after")
    def validate_aggregate(self):
        for items in (self.sections, self.questions):
            ids = [item.id for item in items if item.id is not None]
            if len(ids) != len(set(ids)):
                raise ValueError("IDs de filhos duplicados.")
        keys = [item.section_key for item in self.sections]
        if len(keys) != len(set(keys)):
            raise ValueError("Chaves de seção duplicadas.")
        if self.intent == "organize":
            if self.organization_source_text != self.original_text:
                raise ValueError("Fonte da organização deve corresponder ao original enviado.")
            if not self.original_text.strip() or not self.sections:
                raise ValueError("Organização exige original e seções.")
        elif self.organization_source_text is not None or self.organization_source_hash is not None:
            raise ValueError("Fonte de organização exige intent=organize.")
        if sum(len(item.text) for item in [*self.sections, *self.questions]) > 100000:
            raise ValueError("Conteúdo agregado excede o limite operacional.")
        return self


class RevisionCommand(DTO):
    expected_revision: DatabaseId


class FinalReviewWrite(RevisionCommand):
    completed: StrictBool


class SectionRead(DTO):
    id: DatabaseId
    section_key: str
    title: str
    text: str
    position: int


class QuestionRead(DTO):
    id: DatabaseId
    text: str
    is_selected: bool
    position: int


class ReportState(DTO):
    organization_current: bool
    has_content: bool
    reviewed: bool
    final_done: bool


class ReportRead(ReportState):
    id: DatabaseId
    appointment_id: DatabaseId
    original_text: str
    organized_at: UtcDatetime | None
    content_revision: DatabaseId
    reviewed_revision: DatabaseId | None
    reviewed_at: UtcDatetime | None
    final_review_revision: DatabaseId | None
    final_review_at: UtcDatetime | None
    updated_at: UtcDatetime
    sections: list[SectionRead]
    questions: list[QuestionRead]
    current_source_hash: str
    clarifications_current: bool
    clarifications_completed: bool
    clarifications: list[ClarificationRead]
