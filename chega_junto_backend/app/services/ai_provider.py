"""Contrato independente do SDK. Conteúdo não entra em logs nem telemetria."""

from dataclasses import dataclass
from typing import Protocol

from app.schemas.ai import AiContent


@dataclass(frozen=True)
class ProviderResult:
    content: AiContent | str
    input_units: int | None = None
    output_units: int | None = None


class AiProviderError(Exception):
    def __init__(self, code="ai_unavailable", *, input_units=None, output_units=None):
        self.code = code
        self.input_units, self.output_units = input_units, output_units
        super().__init__("Processamento de IA indisponível.")


class AiProvider(Protocol):
    def organize_report(self, original_text: str) -> ProviderResult: ...

    def transcribe_audio(self, content: bytes, extension: str, mime: str) -> ProviderResult: ...
