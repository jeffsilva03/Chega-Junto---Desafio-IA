import pytest

from app.models import PreVisitReport
from app.schemas.report_content import QuestionContent, ReportContent, SectionContent
from app.services.report_revision import RevisionConflict, advance_content_revision


def test_identical_content_does_not_invalidate_review():
    report = PreVisitReport(content_revision=3, reviewed_revision=3, final_review_revision=3)
    content = ReportContent(original_text="Meu relato.")
    assert not advance_content_revision(report, content, content, expected_revision=3)
    assert report.content_revision == report.final_review_revision == report.reviewed_revision


@pytest.mark.parametrize(
    "after",
    [
        ReportContent(original_text=""),
        ReportContent(original_text="Texto alterado."),
        ReportContent(
            original_text="Meu relato.",
            sections=(SectionContent(key="reason", title="Motivo", text="", position=0),),
        ),
        ReportContent(
            original_text="Meu relato.",
            questions=(QuestionContent(text="Minha pergunta?", is_selected=False, position=0),),
        ),
    ],
)
def test_real_content_change_invalidates_previous_milestones(after):
    report = PreVisitReport(content_revision=3, reviewed_revision=3, final_review_revision=3)
    before = ReportContent(original_text="Meu relato.")
    assert advance_content_revision(report, before, after, expected_revision=3)
    assert report.content_revision == 4
    assert report.reviewed_revision != report.content_revision
    assert report.final_review_revision != report.content_revision


def test_stale_expected_revision_is_rejected_even_for_noop():
    report = PreVisitReport(content_revision=4)
    content = ReportContent(original_text="Meu relato.")
    with pytest.raises(RevisionConflict):
        advance_content_revision(report, content, content, expected_revision=3)


def test_selection_and_order_are_part_of_revision():
    report = PreVisitReport(content_revision=1)
    question = QuestionContent(text="Pergunta?", is_selected=True, position=0)
    before = ReportContent(original_text="Relato", questions=(question,))
    after = before.model_copy(
        update={
            "questions": (
                question.model_copy(
                    update={
                        "is_selected": False,
                        "position": 1,
                    }
                ),
            )
        }
    )
    assert advance_content_revision(report, before, after, expected_revision=1)
    assert report.content_revision == 2
