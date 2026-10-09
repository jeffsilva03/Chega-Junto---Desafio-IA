from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.profile import ProfileRead, ProfileWrite
from app.services.profile import ProfileService

router = APIRouter(prefix="/me/profile", tags=["Profile"])


@router.get("", response_model=ProfileRead, summary="Carregar perfil do usuário demo")
def get_profile(session: DatabaseSession, user: CurrentUser):
    return ProfileService(session, user).get()


@router.put("", response_model=ProfileRead, summary="Salvar perfil completo")
def put_profile(payload: ProfileWrite, session: DatabaseSession, user: CurrentUser):
    return ProfileService(session, user).put(payload)
