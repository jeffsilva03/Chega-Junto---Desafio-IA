"""Uma pergunta por chamada, lease persistente e nenhuma transação durante IA."""

from datetime import timedelta
from uuid import uuid4

from app.core.errors import ApiError, conflict, not_found
from app.database.base import utc_now
from app.models import ReportClarification
from app.schemas.clarifications import ClarificationContent, ClarificationNext, ClarificationRead
from app.services.ai_provider import AiProviderError
from app.services.common import transaction
from app.services.report_ai import ReportAiService
from app.services.report_source import (
    answered_context,
    clarifications_current,
    current_clarifications,
    organization_source_hash,
    source_hash,
)
from app.services.reports import ReportService


class ClarificationService:
    def __init__(self, session, user, settings, provider):
        self.session, self.user, self.settings, self.provider = session, user, settings, provider
        self.reports = ReportService(session, user)
        self.ai = ReportAiService(session, user, settings, provider)

    @staticmethod
    def bump(report):
        report.content_revision += 1
        report.updated_at = utc_now()

    @staticmethod
    def clear_request(report):
        report.clarification_request_id = report.clarification_requested_at = None

    def next(self, appointment_id):
        request_id = str(uuid4())
        with transaction(self.session):
            report, _, _ = self.reports.load(appointment_id, lock=True)
            if not report.original_text.strip():
                raise ApiError(
                    422, "report_empty", "Escreva ou revise seu relato antes de continuar."
                )
            current = current_clarifications(report)
            pending = next((row for row in current if row.answer_kind is None), None)
            if pending:
                return ClarificationNext(
                    done=False, clarification=ClarificationRead.model_validate(pending)
                )
            if clarifications_current(report) and (
                report.clarifications_completed_at or len(current) >= 3
            ):
                if report.clarifications_completed_at is None:
                    report.clarifications_completed_at = utc_now()
                return ClarificationNext(done=True, clarification=None)
            if (
                report.clarification_request_id
                and report.clarification_requested_at > utc_now() - timedelta(seconds=180)
            ):
                raise ApiError(
                    409,
                    "clarification_busy",
                    "Uma pergunta está sendo preparada. Aguarde e confira novamente.",
                )
            original = report.original_text
            context = answered_context(report)
            fingerprint = organization_source_hash(report)
            report.clarification_request_id = request_id
            report.clarification_requested_at = utc_now()

        # A reserva da quota também confirma e libera seu lock antes do SDK.
        def validate(value):
            parsed = ClarificationContent.model_validate(value)
            if not parsed.done and any(
                parsed.question.strip().casefold() == item["question_text"].strip().casefold()
                for item in context
            ):
                raise AiProviderError("ai_invalid_output")
            return parsed

        try:
            result = self.ai.run(
                "clarify", lambda: self.provider.next_clarification(original, context), validate
            )
            with transaction(self.session):
                report, _, _ = self.reports.load(appointment_id, lock=True)
                if (
                    report.clarification_request_id != request_id
                    or organization_source_hash(report) != fingerprint
                ):
                    raise conflict()
                self.clear_request(report)
                if not clarifications_current(report):
                    report.clarifications.clear()
                    self.session.flush()
                report.clarifications_source_hash = source_hash(original)
                report.clarifications_completed_at = utc_now() if result.done else None
                if result.done:
                    return ClarificationNext(done=True, clarification=None)
                rows = current_clarifications(report)
                if len(rows) >= 3:
                    raise conflict()
                question = ReportClarification(
                    question_text=result.question,
                    source_hash=source_hash(original),
                    answer_mode=result.answer_mode,
                    options=result.options,
                    position=len(rows),
                )
                report.clarifications.append(question)
                self.bump(report)
                self.session.flush()
                return ClarificationNext(
                    done=False, clarification=ClarificationRead.model_validate(question)
                )
        finally:
            with transaction(self.session):
                report, _, _ = self.reports.load(appointment_id, lock=True)
                if report.clarification_request_id == request_id:
                    self.clear_request(report)

    def answer(self, appointment_id, clarification_id, payload):
        with transaction(self.session):
            report, sections, questions = self.reports.load(appointment_id, lock=True)
            if payload.expected_revision is not None:
                self.reports.check_version(report, payload.expected_revision)
            if not clarifications_current(report):
                raise ApiError(
                    409, "clarifications_stale", "O relato mudou. Retome o complemento atualizado."
                )
            current = current_clarifications(report)
            row = next((item for item in current if item.id == clarification_id), None)
            if row is None:
                raise not_found()
            if payload.answer_kind == "option" and (
                row.answer_mode != "single_choice" or payload.answer_text not in row.options
            ):
                raise ApiError(
                    422,
                    "clarification_option_invalid",
                    "Escolha uma opção disponível ou responda com suas palavras.",
                )
            if (row.answer_kind, row.answer_text) != (payload.answer_kind, payload.answer_text):
                row.answer_kind, row.answer_text = payload.answer_kind, payload.answer_text
                row.answered_at = utc_now()
                self.clear_request(report)
                self.bump(report)
            if len(current) >= 3 and all(item.answer_kind is not None for item in current):
                report.clarifications_completed_at = report.clarifications_completed_at or utc_now()
            self.session.flush()
            result = self.reports.dto(report, sections, questions)
        return result

    def skip(self, appointment_id):
        with transaction(self.session):
            report, sections, questions = self.reports.load(appointment_id, lock=True)
            if not report.original_text.strip():
                raise ApiError(422, "report_empty", "Escreva seu relato antes de continuar.")
            changed = False
            for row in current_clarifications(report):
                if row.answer_kind is None:
                    row.answer_kind, row.answer_text, row.answered_at = (
                        "prefer_not_to_answer",
                        None,
                        utc_now(),
                    )
                    changed = True
            # Source por linha permite preservar respostas stale ao pular um novo ciclo.
            was_current = clarifications_current(report)
            report.clarifications_source_hash = source_hash(report.original_text)
            report.clarifications_completed_at = (
                report.clarifications_completed_at
                if was_current and report.clarifications_completed_at
                else utc_now()
            )
            self.clear_request(report)
            if changed:
                self.bump(report)
            self.session.flush()
            result = self.reports.dto(report, sections, questions)
        return result
