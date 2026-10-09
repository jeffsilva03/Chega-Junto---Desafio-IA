"""Política de revisão sem acesso a banco/CRUD; serviços futuros usarão o mesmo agregado."""

from app.models.reports import PreVisitReport
from app.schemas.report_content import ReportContent


class RevisionConflict(ValueError):
    def __init__(self) -> None:
        super().__init__("O relato mudou. Carregue a versão atual antes de salvar.")


def advance_content_revision(
    report: PreVisitReport,
    before: ReportContent,
    after: ReportContent,
    *,
    expected_revision: int,
) -> bool:
    if report.content_revision != expected_revision:
        raise RevisionConflict()
    if before == after:
        return False
    report.content_revision += 1
    # Marcos antigos permanecem como metadados; deixam de coincidir com a versão atual.
    return True
