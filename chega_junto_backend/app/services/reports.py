from app.core.errors import ApiError, conflict, not_found
from app.database.base import utc_now
from app.repositories.appointments import AppointmentRepository
from app.repositories.reports import ReportRepository
from app.schemas.clarifications import ClarificationRead
from app.schemas.report_content import QuestionContent, ReportContent, SectionContent
from app.schemas.reports import QuestionRead, ReportRead, ReportState, SectionRead
from app.services.common import transaction, validate_child_ids
from app.services.report_revision import advance_content_revision
from app.services.report_source import (
    clarifications_current,
    current_clarifications,
    organization_source_hash,
)
from app.services.report_source import (
    source_hash as source_hash,
)


def report_state(report, sections):
    current = bool(report and report.organized_source_hash == organization_source_hash(report))
    content = any(section.text.strip() for section in sections)
    reviewed = bool(
        report
        and current
        and content
        and report.reviewed_revision == report.content_revision
        and report.reviewed_at
    )
    final = bool(
        reviewed
        and report.final_review_revision == report.content_revision
        and report.final_review_at
    )
    return ReportState(
        organization_current=current, has_content=content, reviewed=reviewed, final_done=final
    )


def snapshot(original, sections, questions):
    return ReportContent(
        original_text=original,
        sections=tuple(
            SectionContent(key=s.section_key, title=s.title, text=s.text, position=i)
            for i, s in enumerate(sections)
        ),
        questions=tuple(
            QuestionContent(text=q.text, is_selected=q.is_selected, position=i)
            for i, q in enumerate(questions)
        ),
    )


class ReportService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = ReportRepository(session)
        self.appointments = AppointmentRepository(session)

    def load(self, appointment_id, *, lock=False, required=True):
        if self.appointments.appointment(self.user.id, appointment_id, lock=lock) is None:
            raise not_found()
        report = self.repository.report(appointment_id, lock=lock)
        if report is None:
            if required:
                raise not_found()
            return None, [], []
        sections, questions = self.repository.children(report.id, lock=lock)
        return report, sections, questions

    @staticmethod
    def dto(report, sections, questions):
        state = report_state(report, sections)
        fields = {
            field: getattr(report, field)
            for field in ReportRead.model_fields
            if field
            not in {
                *ReportState.model_fields,
                "sections",
                "questions",
                "current_source_hash",
                "clarifications_current",
                "clarifications_completed",
                "clarifications",
            }
        }
        return ReportRead(
            **fields,
            **state.model_dump(),
            sections=[SectionRead.model_validate(row) for row in sections],
            questions=[QuestionRead.model_validate(row) for row in questions],
            current_source_hash=organization_source_hash(report),
            clarifications_current=clarifications_current(report),
            clarifications_completed=bool(
                clarifications_current(report) and report.clarifications_completed_at
            ),
            clarifications=[
                ClarificationRead.model_validate(row) for row in current_clarifications(report)
            ],
        )

    def get(self, appointment_id):
        return self.dto(*self.load(appointment_id))

    @staticmethod
    def check_version(report, expected_revision):
        if report.content_revision != expected_revision:
            raise conflict()

    def put(self, appointment_id, payload):
        with transaction(self.session):
            report, sections, questions = self.load(appointment_id, lock=True, required=False)
            if report is None:
                if payload.expected_revision != 0:
                    raise conflict()
                validate_child_ids([], [*payload.sections, *payload.questions])
                report = self.repository.create(appointment_id, payload.original_text)
                changed = True
            else:
                self.check_version(report, payload.expected_revision)
                validate_child_ids(sections, payload.sections)
                validate_child_ids(questions, payload.questions)
                sections_by_id = {section.id: section for section in sections}
                for section in payload.sections:
                    if (
                        section.id is not None
                        and sections_by_id[section.id].section_key != section.section_key
                    ):
                        raise ApiError(
                            400,
                            "section_key_immutable",
                            "A chave de uma seção existente não pode mudar.",
                        )
                changed = advance_content_revision(
                    report,
                    snapshot(report.original_text, sections, questions),
                    snapshot(payload.original_text, payload.sections, payload.questions),
                    expected_revision=payload.expected_revision,
                )
            if changed:
                if report.original_text != payload.original_text:
                    report.clarification_request_id = report.clarification_requested_at = None
                report.original_text = payload.original_text
                sections, questions = self.repository.replace(report, sections, questions, payload)
                report.updated_at = utc_now()
            if payload.intent == "organize":
                digest = organization_source_hash(report)
                if (
                    payload.organization_source_hash is not None
                    and payload.organization_source_hash != digest
                ):
                    raise conflict()
                if report.organized_source_hash != digest:
                    report.organized_source_hash, report.organized_at = digest, utc_now()
                    report.updated_at = utc_now()
            self.session.flush()
            result = self.dto(report, sections, questions)
        return result

    def clear_summary(self, appointment_id, expected_revision):
        with transaction(self.session):
            report, sections, questions = self.load(appointment_id, lock=True)
            self.check_version(report, expected_revision)
            if any(section.text != "" for section in sections) or questions:
                report.content_revision += 1
                self.repository.clear_summary(sections, questions)
                questions = []
                report.updated_at = utc_now()
            if report.organized_source_hash is not None:
                report.organized_source_hash = report.organized_at = None
                report.updated_at = utc_now()
            self.session.flush()
            result = self.dto(report, sections, questions)
        return result

    def review(self, appointment_id, expected_revision):
        with transaction(self.session):
            report, sections, questions = self.load(appointment_id, lock=True)
            self.check_version(report, expected_revision)
            state = report_state(report, sections)
            if not state.organization_current or not state.has_content:
                raise ApiError(
                    409, "report_not_ready", "Revise uma organização atual com conteúdo."
                )
            if not state.reviewed:
                report.reviewed_revision, report.reviewed_at = report.content_revision, utc_now()
            self.session.flush()
            result = self.dto(report, sections, questions)
        return result

    def final_review(self, appointment_id, payload):
        with transaction(self.session):
            report, sections, questions = self.load(appointment_id, lock=True)
            self.check_version(report, payload.expected_revision)
            state = report_state(report, sections)
            if payload.completed:
                if not state.reviewed:
                    raise ApiError(
                        409,
                        "report_not_reviewed",
                        "Confirme a revisão do relato atual antes de concluir.",
                    )
                if not state.final_done:
                    report.final_review_revision = report.content_revision
                    report.final_review_at = utc_now()
            elif report.final_review_revision is not None:
                report.final_review_revision = report.final_review_at = None
            self.session.flush()
            result = self.dto(report, sections, questions)
        return result
