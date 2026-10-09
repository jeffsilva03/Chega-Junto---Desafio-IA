from fastapi import APIRouter

from app.api.v1 import (
    appointments,
    auth,
    health_items,
    notifications,
    preferences,
    preparation,
    profile,
    reminders,
    reports,
)
from app.schemas.common import ErrorResponse

# Contratos funcionais serão adicionados por módulo, nas próximas fases aprovadas.
router = APIRouter(
    responses={code: {"model": ErrorResponse} for code in (400, 401, 404, 409, 422, 500, 503)}
)
for domain in (
    auth,
    profile,
    appointments,
    preparation,
    reminders,
    health_items,
    reports,
    notifications,
    preferences,
):
    router.include_router(domain.router)
