from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator, model_validator

from app.schemas.common import DTO, DatabaseId, UtcDatetime

AnswerKind = Literal["text", "option", "dont_know", "dont_remember", "prefer_not_to_answer"]
AnswerMode = Literal["free_text", "single_choice"]


class ClarificationContent(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, hide_input_in_errors=True)
    done: StrictBool
    question: str = Field(max_length=700)
    answer_mode: AnswerMode
    options: list[Annotated[str, Field(min_length=1, max_length=200)]] = Field(max_length=4)

    @field_validator("options")
    @classmethod
    def options_unique(cls, options):
        values = [value.strip() for value in options]
        if any(not value for value in values) or len(
            set(value.casefold() for value in values)
        ) != len(values):
            raise ValueError("Opções vazias ou duplicadas.")
        return values

    @model_validator(mode="after")
    def coherent(self):
        if self.done:
            if self.question or self.options or self.answer_mode != "free_text":
                raise ValueError("Conclusão não contém pergunta.")
        elif not self.question.strip() or self.question.count("?") > 1:
            raise ValueError("Uma pergunta por chamada.")
        elif self.answer_mode == "single_choice" and not 2 <= len(self.options) <= 4:
            raise ValueError("Escolha exige entre duas e quatro opções.")
        elif self.answer_mode == "free_text" and self.options:
            raise ValueError("Resposta livre não contém opções.")
        return self


class ClarificationAnswer(DTO):
    answer_kind: AnswerKind
    answer_text: str | None = Field(default=None, max_length=2000)
    expected_revision: DatabaseId | None = None

    @model_validator(mode="after")
    def coherent(self):
        if self.answer_kind in {"text", "option"}:
            if self.answer_text is None or not self.answer_text.strip():
                raise ValueError("Informe uma resposta.")
            if self.answer_kind == "text":
                self.answer_text = self.answer_text.strip()
        elif self.answer_text is not None:
            raise ValueError("Esta opção não recebe texto.")
        return self


class ClarificationRead(DTO):
    id: DatabaseId
    question_text: str
    answer_mode: AnswerMode
    options: list[str]
    answer_kind: AnswerKind | None
    answer_text: str | None
    position: int
    answered_at: UtcDatetime | None


class ClarificationNext(DTO):
    done: bool
    clarification: ClarificationRead | None
