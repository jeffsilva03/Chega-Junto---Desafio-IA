from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.appointments import ReminderFilter, ReminderRead, ReminderWrite
from app.schemas.common import Page
from app.services.appointments import AppointmentService

router = APIRouter(prefix="/reminders", tags=["Reminders"])


@router.get("", response_model=Page[ReminderRead], summary="Listar lembretes pessoais")
def reminders(
    filters: Annotated[ReminderFilter, Query()], session: DatabaseSession, user: CurrentUser
):
    return AppointmentService(session, user).reminders(filters)


@router.post(
    "",
    response_model=ReminderRead,
    status_code=201,
    summary="Salvar lembrete com horário absoluto",
    description=(
        "Sem alarme, push ou scheduler. POST não possui deduplicação por retry nesta versão."
    ),
)
def create_reminder(payload: ReminderWrite, session: DatabaseSession, user: CurrentUser):
    return AppointmentService(session, user).create_reminder(payload)
