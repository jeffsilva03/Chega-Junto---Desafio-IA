"""Fake determinístico: nunca abre rede nem usa saldo."""

from app.schemas.ai import AiContent
from app.schemas.clarifications import ClarificationContent
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
        self.clarification = ClarificationContent(
            done=False, question="Quando você percebeu isso?", answer_mode="free_text", options=[]
        )
        self.clarification_results = []

    def organize_report(self, original_text, clarifications=None):
        self.before_call()
        self.calls.append(
            ("organize", original_text, clarifications)
            if clarifications
            else ("organize", original_text)
        )
        if self.error:
            raise self.error
        return ProviderResult(self.organization, 20, 10)

    def next_clarification(self, original_text, clarifications):
        self.before_call()
        self.calls.append(("clarify", original_text, clarifications))
        if self.error:
            raise self.error
        result = (
            self.clarification_results.pop(0) if self.clarification_results else self.clarification
        )
        return ProviderResult(result, 30, 12)

    def transcribe_audio(self, content, extension, mime):
        self.before_call()
        self.calls.append(("transcribe", extension, mime, len(content)))
        if self.error:
            raise self.error
        return ProviderResult(self.transcript)
