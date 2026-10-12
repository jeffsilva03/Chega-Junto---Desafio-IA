from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import DatabaseSession
from app.schemas.appointments import FacilityRead
from app.schemas.auth import Email
from app.schemas.common import DatabaseId, Page, PagingFilter
from app.schemas.simulator import (
    SimulatorAppointment,
    SimulatorCreate,
    SimulatorDetail,
    SimulatorFilter,
    SimulatorPatch,
    SimulatorUser,
)
from app.services.simulator import SimulatorService

router = APIRouter(prefix="/simulator", tags=["SIMULATOR API — local, não oficial"])


@router.get("/users/search", response_model=SimulatorUser)
def search_user(session: DatabaseSession, email: Annotated[Email, Query()]):
    return SimulatorService(session).user(email=email)


@router.get("/facilities", response_model=Page[FacilityRead])
def facilities(session: DatabaseSession, filters: Annotated[PagingFilter, Query()]):
    return SimulatorService(session).facilities(filters)


@router.get("/appointments", response_model=Page[SimulatorAppointment])
def appointments(session: DatabaseSession, filters: Annotated[SimulatorFilter, Query()]):
    return SimulatorService(session).list(filters)


@router.post("/appointments", response_model=SimulatorDetail, status_code=201)
def create(session: DatabaseSession, payload: SimulatorCreate):
    return SimulatorService(session).create(payload)


@router.get("/appointments/{appointment_id}", response_model=SimulatorDetail)
def detail(session: DatabaseSession, appointment_id: DatabaseId):
    return SimulatorService(session).get(appointment_id)


@router.patch("/appointments/{appointment_id}", response_model=SimulatorDetail)
def patch(session: DatabaseSession, appointment_id: DatabaseId, payload: SimulatorPatch):
    return SimulatorService(session).patch(appointment_id, payload)


@router.post("/appointments/{appointment_id}/cancel", response_model=SimulatorDetail)
def cancel(session: DatabaseSession, appointment_id: DatabaseId):
    return SimulatorService(session).cancel(appointment_id)
