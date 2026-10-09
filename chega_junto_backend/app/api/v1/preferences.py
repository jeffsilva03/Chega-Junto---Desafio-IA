from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.preferences import AccessibilityPreferencesDTO, NotificationPreferencesDTO
from app.services.preferences import PreferencesService

router = APIRouter(prefix="/me", tags=["Preferences"])


@router.get(
    "/notification-preferences",
    response_model=NotificationPreferencesDTO,
    summary="Carregar preferências da central interna",
)
def notification_preferences(session: DatabaseSession, user: CurrentUser):
    return PreferencesService(session, user).get()


@router.put(
    "/notification-preferences",
    response_model=NotificationPreferencesDTO,
    summary="Salvar preferências sem apagar cartões",
)
def put_notification_preferences(
    payload: NotificationPreferencesDTO, session: DatabaseSession, user: CurrentUser
):
    return PreferencesService(session, user).put(payload)


@router.get(
    "/accessibility-preferences",
    response_model=AccessibilityPreferencesDTO,
    summary="Carregar preferências de acessibilidade",
)
def accessibility_preferences(session: DatabaseSession, user: CurrentUser):
    return PreferencesService(session, user).get(accessibility=True)


@router.put(
    "/accessibility-preferences",
    response_model=AccessibilityPreferencesDTO,
    summary="Salvar preferências de apresentação",
)
def put_accessibility_preferences(
    payload: AccessibilityPreferencesDTO, session: DatabaseSession, user: CurrentUser
):
    return PreferencesService(session, user).put(payload, accessibility=True)
