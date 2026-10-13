from typing import Annotated, Literal

from pydantic import Field

from app.schemas.auth import AuthUser, LoginWrite
from app.schemas.common import DTO, NonEmpty


class OperatorLogin(LoginWrite):
    pass


class OperatorCreate(OperatorLogin):
    full_name: Annotated[NonEmpty, Field(max_length=160)]


class OperatorIdentity(AuthUser):
    pass


class OperatorSession(DTO):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    operator: OperatorIdentity
