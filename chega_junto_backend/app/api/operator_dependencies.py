from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.dependencies import DatabaseSession
from app.schemas.operator import OperatorIdentity
from app.services.operator_auth import OperatorAuthService

operator_bearer = HTTPBearer(auto_error=False, scheme_name="OperatorBearer")
Credentials = Annotated[HTTPAuthorizationCredentials | None, Depends(operator_bearer)]


def current_operator(request: Request, session: DatabaseSession, credentials: Credentials):
    return OperatorAuthService(session, request.app.state.settings).resolve(
        credentials.credentials if credentials else None
    )


CurrentOperator = Annotated[OperatorIdentity, Depends(current_operator)]
