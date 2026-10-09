import re
from typing import Annotated, Literal

from pydantic import BeforeValidator, Field, SecretStr, field_validator

from app.schemas.common import DTO, DatabaseId, NonEmpty


def normalize_email(value):
    if not isinstance(value, str):
        raise ValueError("E-mail inválido.")
    value = value.strip().lower()
    if len(value) > 254 or not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
        raise ValueError("E-mail inválido.")
    return value


Email = Annotated[str, BeforeValidator(normalize_email)]


class LoginWrite(DTO):
    email: Email
    password: SecretStr

    @field_validator("password")
    @classmethod
    def password_bounds(cls, value):
        if not 8 <= len(value.get_secret_value()) <= 128:
            raise ValueError("A senha deve ter entre 8 e 128 caracteres.")
        return value


class RegisterWrite(LoginWrite):
    full_name: Annotated[NonEmpty, Field(max_length=160)]


class AuthUser(DTO):
    id: DatabaseId
    full_name: str
    email: str


class AuthSession(DTO):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    user: AuthUser
