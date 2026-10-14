from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import DTO


class OrganizationRequest(DTO):
    original_text: str = Field(min_length=1, max_length=20000)

    @field_validator("original_text")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("Relato vazio.")
        return value


class AiContent(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, hide_input_in_errors=True)
    reason: str = Field(max_length=20000)
    points: str = Field(max_length=20000)
    context: str = Field(max_length=20000)
    other: str = Field(max_length=20000)
    questions: list[Annotated[str, Field(min_length=1, max_length=500)]] = Field(max_length=5)

    @field_validator("questions")
    @classmethod
    def question_content(cls, value):
        if any(not text.strip() for text in value):
            raise ValueError("Pergunta vazia.")
        return value


class GeneratedSection(DTO):
    section_key: str
    title: str
    text: str


class GeneratedQuestion(DTO):
    text: str
    is_selected: bool = False


class OrganizationResponse(DTO):
    sections: list[GeneratedSection]
    questions: list[GeneratedQuestion]
    source_hash: str | None = None


class TranscriptionResponse(DTO):
    text: str
