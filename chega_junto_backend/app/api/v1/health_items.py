from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.common import DatabaseId, Page
from app.schemas.health_items import (
    HealthItemsRead,
    HealthItemsWrite,
    HistoryDetail,
    HistoryFilter,
    HistoryRead,
)
from app.services.health_items import HealthService

router = APIRouter(prefix="/me", tags=["Health"])


@router.get(
    "/health-items", response_model=HealthItemsRead, summary="Carregar medicamentos e alergias"
)
def health_items(session: DatabaseSession, user: CurrentUser):
    return HealthService(session, user).get()


@router.put(
    "/health-items",
    response_model=HealthItemsRead,
    summary="Salvar as duas listas de saúde atomicamente",
    description=(
        "Substituição completa: omitir um item remove-o da lista. "
        "Envie IDs existentes para manter/editar itens; omita o ID de novos itens. "
        "Itens idênticos sem ID podem ser reconciliados na mesma posição."
    ),
)
def put_health_items(payload: HealthItemsWrite, session: DatabaseSession, user: CurrentUser):
    return HealthService(session, user).put(payload)


@router.get(
    "/health-records", response_model=Page[HistoryRead], summary="Listar histórico preexistente"
)
def history(
    filters: Annotated[HistoryFilter, Query()], session: DatabaseSession, user: CurrentUser
):
    return HealthService(session, user).records(filters)


@router.get(
    "/health-records/{record_id}",
    response_model=HistoryDetail,
    summary="Carregar registro e documentos textuais",
)
def history_detail(record_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return HealthService(session, user).record(record_id)
