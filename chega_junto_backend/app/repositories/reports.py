from sqlalchemy import select

from app.models import PreVisitReport, ReportQuestion, ReportSection
from app.repositories.common import replace_ordered


class ReportRepository:
    def __init__(self, session):
        self.session = session

    def report(self, appointment_id, *, lock=False):
        statement = select(PreVisitReport).where(PreVisitReport.appointment_id == appointment_id)
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))

    def children(self, report_id, *, lock=False):
        result = []
        for model in (ReportSection, ReportQuestion):
            statement = (
                select(model).where(model.report_id == report_id).order_by(model.position, model.id)
            )
            if lock:
                statement = statement.with_for_update()
            result.append(
                list(self.session.scalars(statement.execution_options(populate_existing=True)))
            )
        return tuple(result)

    def create(self, appointment_id, original_text):
        report = PreVisitReport(
            appointment_id=appointment_id, original_text=original_text, content_revision=1
        )
        self.session.add(report)
        self.session.flush()
        return report

    def replace(self, report, sections, questions, payload):
        sections = replace_ordered(
            self.session,
            ReportSection,
            sections,
            payload.sections,
            "report_id",
            report.id,
            ("section_key", "title", "text"),
            logical_key="section_key",
        )
        questions = replace_ordered(
            self.session,
            ReportQuestion,
            questions,
            payload.questions,
            "report_id",
            report.id,
            ("text", "is_selected"),
        )
        return sections, questions

    def clear_summary(self, sections, questions):
        for section in sections:
            section.text = ""
        for question in questions:
            self.session.delete(question)
        self.session.flush()
