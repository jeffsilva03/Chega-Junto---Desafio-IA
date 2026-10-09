"""Snapshot interno do agregado; não é contrato CRUD exposto nesta fase."""

from pydantic import BaseModel, ConfigDict


class SectionContent(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    key: str
    title: str
    text: str
    position: int


class QuestionContent(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    text: str
    is_selected: bool
    position: int


class ReportContent(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    original_text: str
    sections: tuple[SectionContent, ...] = ()
    questions: tuple[QuestionContent, ...] = ()
