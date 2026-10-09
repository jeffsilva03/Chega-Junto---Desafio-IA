from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.security import unauthorized
from app.services.identity import UserContext, resolve_current_user


def get_session(request: Request) -> Iterator[Session]:
    with request.app.state.database.session() as session:
        yield session


DatabaseSession = Annotated[Session, Depends(get_session)]


bearer = HTTPBearer(auto_error=False)
BearerCredentials = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]


def get_current_user(
    request: Request, session: DatabaseSession, credentials: BearerCredentials
) -> UserContext:
    if "user_id" in request.query_params:
        raise ApiError(400, "client_identity_forbidden", "A identidade é definida pelo backend.")
    if request.headers.get("Authorization") and credentials is None:
        raise unauthorized()
    return resolve_current_user(
        session, request.app.state.settings, credentials.credentials if credentials else None
    )


CurrentUser = Annotated[UserContext, Depends(get_current_user)]


def get_authenticated_user(
    request: Request, session: DatabaseSession, credentials: BearerCredentials
) -> UserContext:
    return resolve_current_user(
        session,
        request.app.state.settings,
        credentials.credentials if credentials else None,
        allow_demo=False,
    )


AuthenticatedUser = Annotated[UserContext, Depends(get_authenticated_user)]
