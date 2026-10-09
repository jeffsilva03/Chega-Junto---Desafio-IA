from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.common import DatabaseId
from app.schemas.reports import FinalReviewWrite, ReportRead, ReportWrite, RevisionCommand
from app.services.reports import ReportService

router = APIRouter(prefix="/appointments/{appointment_id}", tags=["Reports"])


@router.get("/report", response_model=ReportRead, summary="Carregar relato estruturado e revisões")
def report(appointment_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return ReportService(session, user).get(appointment_id)


@router.put(
    "/report",
    response_model=ReportRead,
    summary="Salvar conteúdo do relato com versão esperada",
    description=(
        "expected_revision=0 cria um relato ausente; versões antigas geram 409. "
        "intent=organize exige organization_source_text igual ao original enviado; "
        "edit preserva a fonte anterior. Ordem das listas define position."
    ),
)
def put_report(
    appointment_id: DatabaseId, payload: ReportWrite, session: DatabaseSession, user: CurrentUser
):
    return ReportService(session, user).put(appointment_id, payload)


@router.delete(
    "/report/summary",
    response_model=ReportRead,
    summary="Remover resumo preservando relato original",
)
def delete_summary(
    appointment_id: DatabaseId,
    expected_revision: Annotated[DatabaseId, Query()],
    session: DatabaseSession,
    user: CurrentUser,
):
    return ReportService(session, user).clear_summary(appointment_id, expected_revision)


@router.post(
    "/report/review", response_model=ReportRead, summary="Confirmar revisão humana da versão atual"
)
def review(
    appointment_id: DatabaseId,
    payload: RevisionCommand,
    session: DatabaseSession,
    user: CurrentUser,
):
    return ReportService(session, user).review(appointment_id, payload.expected_revision)


@router.put(
    "/final-review", response_model=ReportRead, summary="Concluir ou reabrir a revisão final"
)
def final_review(
    appointment_id: DatabaseId,
    payload: FinalReviewWrite,
    session: DatabaseSession,
    user: CurrentUser,
):
    return ReportService(session, user).final_review(appointment_id, payload)
