from pathlib import PurePath

from pydantic import ValidationError

from app.core.errors import ApiError
from app.repositories.reports import ReportRepository
from app.schemas.ai import (
    AiContent,
    GeneratedQuestion,
    GeneratedSection,
    OrganizationResponse,
    TranscriptionResponse,
)
from app.services.ai_provider import AiProviderError
from app.services.ai_quota import AiQuota
from app.services.appointments import AppointmentService
from app.services.report_source import (
    answered_context,
    clarifications_current,
    organization_source_hash,
    source_hash,
)

AUDIO_MAX_BYTES = 10 * 1024 * 1024
SECTIONS = (
    ("reason", "Motivo da consulta"),
    ("points", "Pontos relatados"),
    ("context", "Contexto informado"),
    ("other", "Outros pontos importantes"),
)
AUDIO_MIMES = {
    "webm": {"audio/webm", "video/webm"},
    "m4a": {"audio/mp4", "audio/m4a", "audio/x-m4a"},
    "mp4": {"audio/mp4", "video/mp4"},
    "wav": {"audio/wav", "audio/x-wav", "audio/wave"},
    "mp3": {"audio/mpeg", "audio/mp3"},
}


def audio_format(filename, mime, content):
    extension = PurePath(filename or "").suffix.lower().lstrip(".")
    mime = (mime or "").split(";", 1)[0].strip().lower()
    valid = extension in AUDIO_MIMES and mime in AUDIO_MIMES[extension] and bool(content)
    if valid:
        valid = {
            "webm": content.startswith(b"\x1aE\xdf\xa3"),
            "m4a": content[4:8] == b"ftyp",
            "mp4": content[4:8] == b"ftyp",
            "wav": content.startswith(b"RIFF") and content[8:12] == b"WAVE",
            "mp3": content.startswith(b"ID3")
            or (len(content) > 1 and content[0] == 255 and content[1] & 224 == 224),
        }[extension]
    if not valid:
        raise ApiError(
            422, "audio_invalid", "Áudio inválido. Grave novamente em um formato compatível."
        )
    return extension, mime


class ReportAiService:
    def __init__(self, session, user, settings, provider):
        self.session, self.user = session, user
        self.settings, self.provider = settings, provider
        self.quota = AiQuota(session.get_bind(), settings)

    def owned(self, appointment_id):
        AppointmentService(self.session, self.user).owned(appointment_id)
        self.session.rollback()  # Encerrar também a leitura de autenticação/titularidade.

    def run(self, operation, action, validate):
        event_id = self.quota.reserve(self.user.id, operation)
        result = None
        try:
            result = action()
            value = validate(result.content)
        except Exception as error:
            self.quota.complete(
                event_id,
                "failed",
                getattr(result or error, "input_units", None),
                getattr(result or error, "output_units", None),
            )
            if isinstance(error, ApiError):
                raise
            code = error.code if isinstance(error, AiProviderError) else "ai_invalid_output"
            raise ApiError(
                503, code, "Não foi possível processar com IA agora. Tente novamente mais tarde."
            ) from None
        self.quota.complete(event_id, "succeeded", result.input_units, result.output_units)
        return value

    def organize(self, appointment_id, original_text):
        self.owned(appointment_id)
        report = ReportRepository(self.session).report(appointment_id)
        context = []
        digest = source_hash(original_text)
        if report and report.original_text == original_text:
            if clarifications_current(report) and not report.clarifications_completed_at:
                self.session.rollback()
                raise ApiError(
                    409,
                    "clarification_pending",
                    "Conclua ou pule o complemento antes de organizar.",
                )
            context = answered_context(report)
            digest = organization_source_hash(report)
        self.session.rollback()

        def validate(value):
            try:
                content = AiContent.model_validate(value)
            except ValidationError:
                raise AiProviderError("ai_invalid_output") from None
            if not any(getattr(content, key).strip() for key, _ in SECTIONS):
                raise AiProviderError("ai_invalid_output")
            return OrganizationResponse(
                sections=[
                    GeneratedSection(section_key=key, title=title, text=getattr(content, key))
                    for key, title in SECTIONS
                ],
                questions=[GeneratedQuestion(text=text) for text in content.questions],
                source_hash=digest,
            )

        return self.run(
            "organize",
            lambda: (
                self.provider.organize_report(original_text, context)
                if context
                else self.provider.organize_report(original_text)
            ),
            validate,
        )

    def transcribe(self, appointment_id, content, extension, mime):
        self.owned(appointment_id)

        def validate(value):
            if not isinstance(value, str) or not value.strip():
                raise AiProviderError("transcription_failed")
            if len(value) > 20000:
                raise ApiError(
                    422,
                    "transcription_too_long",
                    "Transcrição muito longa. Faça uma gravação menor.",
                )
            return TranscriptionResponse(text=value)

        return self.run(
            "transcribe", lambda: self.provider.transcribe_audio(content, extension, mime), validate
        )
