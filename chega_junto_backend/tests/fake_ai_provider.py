"""Fake determinístico: nunca abre rede nem usa saldo."""

from app.schemas.ai import AiContent
from app.services.ai_provider import ProviderResult


class FakeAiProvider:
    def __init__(self):
        self.calls = []
        self.error = None
        self.organization = AiContent(
            reason="Relato fictício",
            points="",
            context="",
            other="",
            questions=["O que seria importante conversar na consulta?"],
        )
        self.transcript = "Texto fictício para revisar."
        self.before_call = lambda: None

    def organize_report(self, original_text):
        self.before_call()
        self.calls.append(("organize", original_text))
        if self.error:
            raise self.error
        return ProviderResult(self.organization, 20, 10)

    def transcribe_audio(self, content, extension, mime):
        self.before_call()
        self.calls.append(("transcribe", extension, mime, len(content)))
        if self.error:
            raise self.error
        return ProviderResult(self.transcript)
