from typing import Annotated

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DatabaseSession
from app.schemas.common import DatabaseId
from app.schemas.notifications import (
    NotificationFilter,
    NotificationPage,
    NotificationRead,
    NotificationWrite,
)
from app.services.notifications import NotificationService

router = APIRouter(prefix="/me/notifications", tags=["Notifications"])


@router.get(
    "",
    response_model=NotificationPage,
    summary="Listar cartões internos visíveis",
    description=(
        "unread_count é global entre cartões visíveis, independente de página/filtros. "
        "GET não materializa notificações."
    ),
)
def notifications(
    filters: Annotated[NotificationFilter, Query()], session: DatabaseSession, user: CurrentUser
):
    return NotificationService(session, user).list(filters)


@router.patch(
    "/{notification_id}", response_model=NotificationRead, summary="Marcar notificação como lida"
)
def read_notification(
    notification_id: DatabaseId,
    payload: NotificationWrite,
    session: DatabaseSession,
    user: CurrentUser,
):
    return NotificationService(session, user).mark_read(notification_id)
