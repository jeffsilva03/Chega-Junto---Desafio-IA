from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.appointments import (
    AppointmentDetail,
    AppointmentFilter,
    AppointmentRead,
    AttendanceRead,
    AttendanceWrite,
    ChecklistWrite,
    FacilityRead,
)
from app.schemas.common import DatabaseId, Page, PagingFilter
from app.schemas.preparation import ChecklistResponse, PreparationRead
from app.services.appointments import AppointmentService
from app.services.preparation import PreparationService

router = APIRouter()


@router.get(
    "/facilities",
    response_model=Page[FacilityRead],
    tags=["Facilities"],
    summary="Listar unidades vinculadas à agenda",
)
def facilities(
    filters: Annotated[PagingFilter, Query()], session: DatabaseSession, user: CurrentUser
):
    return AppointmentService(session, user).facilities(filters)


@router.get(
    "/facilities/{facility_id}",
    response_model=FacilityRead,
    tags=["Facilities"],
    summary="Consultar unidade acessível",
)
def facility(facility_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return AppointmentService(session, user).facility(facility_id)


@router.get(
    "/appointments",
    response_model=Page[AppointmentRead],
    tags=["Appointments"],
    summary="Listar agenda do titular",
    description=(
        "Datas são interpretadas no fuso do usuário; instantes exigem offset. "
        "Ordenação por scheduled_at e id."
    ),
)
def appointments(
    filters: Annotated[AppointmentFilter, Query()], session: DatabaseSession, user: CurrentUser
):
    return AppointmentService(session, user).list(filters)


@router.get(
    "/appointments/{appointment_id}",
    response_model=AppointmentDetail,
    tags=["Appointments"],
    summary="Consultar atendimento e orientações",
)
def appointment(appointment_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return AppointmentService(session, user).get(appointment_id)


@router.get(
    "/appointments/{appointment_id}/preparation",
    response_model=PreparationRead,
    tags=["Preparation"],
    summary="Calcular as quatro etapas de preparo",
)
def preparation(appointment_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return PreparationService(session, user).get(appointment_id)


@router.get(
    "/appointments/{appointment_id}/checklist",
    response_model=ChecklistResponse,
    tags=["Preparation"],
    summary="Carregar checklist e progresso derivado",
)
def checklist(appointment_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return PreparationService(session, user).checklist(appointment_id)


@router.patch(
    "/appointments/{appointment_id}/checklist/{item_id}",
    response_model=ChecklistResponse,
    tags=["Preparation"],
    summary="Marcar um item do checklist",
)
def patch_checklist(
    appointment_id: DatabaseId,
    item_id: DatabaseId,
    payload: ChecklistWrite,
    session: DatabaseSession,
    user: CurrentUser,
):
    return AppointmentService(session, user).set_checklist(appointment_id, item_id, payload)


@router.get(
    "/appointments/{appointment_id}/attendance",
    response_model=AttendanceRead,
    tags=["Preparation"],
    summary="Carregar intenção de comparecimento",
)
def attendance(appointment_id: DatabaseId, session: DatabaseSession, user: CurrentUser):
    return AppointmentService(session, user).attendance(appointment_id)


@router.put(
    "/appointments/{appointment_id}/attendance",
    response_model=AttendanceRead,
    tags=["Preparation"],
    summary="Registrar presença no aplicativo",
    description=(
        "unable não cancela nem avisa a unidade. Horário da resposta é definido pelo servidor."
    ),
)
def put_attendance(
    appointment_id: DatabaseId,
    payload: AttendanceWrite,
    session: DatabaseSession,
    user: CurrentUser,
):
    return AppointmentService(session, user).set_attendance(appointment_id, payload)
