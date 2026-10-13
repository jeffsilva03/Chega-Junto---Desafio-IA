from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request

from app.api.dependencies import DatabaseSession
from app.api.operator_dependencies import CurrentOperator, current_operator
from app.schemas.appointments import FacilityRead
from app.schemas.auth import Email
from app.schemas.common import DatabaseId, Page, PagingFilter
from app.schemas.operator import OperatorIdentity, OperatorLogin, OperatorSession
from app.schemas.simulator import (
    SimulatorAppointment,
    SimulatorCreate,
    SimulatorDetail,
    SimulatorFilter,
    SimulatorPatch,
    SimulatorUser,
)
from app.services.operator_auth import OperatorAuthService
from app.services.simulator import SchedulingService

router = APIRouter(prefix="/operator", tags=["Operator — demonstrativo, não oficial"])
management = APIRouter(dependencies=[Depends(current_operator)])


@router.post("/auth/login", response_model=OperatorSession)
def login(payload: OperatorLogin, request: Request, session: DatabaseSession):
    return OperatorAuthService(session, request.app.state.settings).login(payload)


@router.get("/auth/me", response_model=OperatorIdentity)
def me(operator: CurrentOperator):
    return operator


@management.get("/users/search", response_model=SimulatorUser)
def search_user(session: DatabaseSession, email: Annotated[Email, Query()]):
    return SchedulingService(session).user(email=email)


@management.get("/facilities", response_model=Page[FacilityRead])
def facilities(session: DatabaseSession, filters: Annotated[PagingFilter, Query()]):
    return SchedulingService(session).facilities(filters)


@management.get("/appointments", response_model=Page[SimulatorAppointment])
def appointments(session: DatabaseSession, filters: Annotated[SimulatorFilter, Query()]):
    return SchedulingService(session).list(filters)


@management.post("/appointments", response_model=SimulatorDetail, status_code=201)
def create(session: DatabaseSession, payload: SimulatorCreate):
    return SchedulingService(session).create(payload)


@management.get("/appointments/{appointment_id}", response_model=SimulatorDetail)
def detail(session: DatabaseSession, appointment_id: DatabaseId):
    return SchedulingService(session).get(appointment_id)


@management.patch("/appointments/{appointment_id}", response_model=SimulatorDetail)
def patch(session: DatabaseSession, appointment_id: DatabaseId, payload: SimulatorPatch):
    return SchedulingService(session).patch(appointment_id, payload)


@management.post("/appointments/{appointment_id}/cancel", response_model=SimulatorDetail)
def cancel(session: DatabaseSession, appointment_id: DatabaseId):
    return SchedulingService(session).cancel(appointment_id)


router.include_router(management)
