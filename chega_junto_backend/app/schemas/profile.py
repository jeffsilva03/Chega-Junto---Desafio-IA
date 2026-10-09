import re
from datetime import date
from typing import Annotated

from pydantic import Field, field_validator

from app.schemas.auth import Email
from app.schemas.common import DTO, DatabaseId, NonEmpty, UtcDatetime


class ProfileWrite(DTO):
    full_name: Annotated[NonEmpty, Field(max_length=160)]
    email: Email
    phone: str | None = None
    birth_date: date | None = None
    cpf: str | None = None
    postcode: str | None = None
    street: Annotated[NonEmpty, Field(max_length=200)] | None = None
    number: Annotated[NonEmpty, Field(max_length=20)] | None = None
    complement: str | None = Field(default=None, max_length=100)
    neighborhood: Annotated[NonEmpty, Field(max_length=100)] | None = None
    city: Annotated[NonEmpty, Field(max_length=100)] | None = None
    state_code: str | None = None
    emergency_name: Annotated[NonEmpty, Field(max_length=160)] | None = None
    emergency_relationship: Annotated[NonEmpty, Field(max_length=80)] | None = None
    emergency_phone: str | None = None

    @field_validator("cpf", "postcode", "phone", "emergency_phone", mode="before")
    @classmethod
    def digits(cls, value, info):
        if value is None:
            return None
        if not isinstance(value, str):
            raise ValueError("Informe texto com dígitos.")
        value = re.sub(r"[\s.\-()/+]", "", value)
        lengths = {"cpf": {11}, "postcode": {8}}.get(info.field_name, {10, 11, 12, 13})
        if not value.isascii() or not value.isdigit() or len(value) not in lengths:
            raise ValueError("Formato inválido.")
        if (
            info.field_name in {"phone", "emergency_phone"}
            and len(value) > 11
            and not value.startswith("55")
        ):
            raise ValueError("Código de país inválido.")
        return value

    @field_validator("birth_date")
    @classmethod
    def valid_birth(cls, value):
        if value is None:
            return None
        if value.year < 1000 or value > date.today():
            raise ValueError("Nascimento não pode ser futuro.")
        return value

    @field_validator("state_code")
    @classmethod
    def state(cls, value):
        if value is None:
            return None
        value = value.strip().upper()
        states = (
            "AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO"
        ).split()
        if value not in states:
            raise ValueError("UF inválida.")
        return value

    @field_validator("complement", mode="before")
    @classmethod
    def empty_complement(cls, value):
        return value.strip() or None if isinstance(value, str) else value


class ProfileRead(ProfileWrite):
    id: DatabaseId
    sus_card_number: str | None
    created_at: UtcDatetime
    updated_at: UtcDatetime
