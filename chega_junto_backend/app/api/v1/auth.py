from fastapi import APIRouter, Request

from app.api.dependencies import AuthenticatedUser, DatabaseSession
from app.schemas.auth import AuthSession, AuthUser, LoginWrite, RegisterWrite
from app.services.auth import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=AuthSession, status_code=201)
def register(payload: RegisterWrite, request: Request, session: DatabaseSession):
    return AuthService(session, request.app.state.settings).register(payload)


@router.post("/login", response_model=AuthSession)
def login(payload: LoginWrite, request: Request, session: DatabaseSession):
    return AuthService(session, request.app.state.settings).login(payload)


@router.get("/me", response_model=AuthUser)
def me(request: Request, session: DatabaseSession, user: AuthenticatedUser):
    return AuthService(session, request.app.state.settings).me(user.id)
