from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.preparation import OverviewRead
from app.services.preparation import PreparationService

router = APIRouter(tags=["Preparation"])


@router.get(
    "/preparation/overview",
    response_model=OverviewRead,
    summary="Carregar preparo para a Home",
    description=(
        "Inclui atendimentos de hoje no fuso do titular. Sem próximo atendimento, "
        "retorna next_appointment/preparation null."
    ),
)
def overview(session: DatabaseSession, user: CurrentUser):
    return PreparationService(session, user).overview()
