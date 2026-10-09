from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated
from zoneinfo import ZoneInfo

from pydantic import (
    AfterValidator,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    PlainSerializer,
    WithJsonSchema,
)

# Reutilizar nos DTOs futuros: nenhuma PK BIGINT será emitida como número JSON.
DatabaseId = Annotated[
    int,
    Field(gt=0, le=18446744073709551615),
    WithJsonSchema(
        {"type": "string", "pattern": r"^[1-9][0-9]*$", "maxLength": 20}, mode="validation"
    ),
    PlainSerializer(str, return_type=str, when_used="json"),
]

Revision = Annotated[
    int,
    Field(ge=0, le=18446744073709551615),
    WithJsonSchema(
        {"type": "string", "pattern": r"^(0|[1-9][0-9]*)$", "maxLength": 20}, mode="validation"
    ),
    PlainSerializer(str, return_type=str, when_used="json"),
]


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


UtcDatetime = Annotated[datetime, AfterValidator(utc)]
NonEmpty = Annotated[
    str,
    BeforeValidator(lambda value: value.strip() if isinstance(value, str) else value),
    Field(min_length=1),
]


class DTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")


class Pagination(DTO):
    limit: int
    offset: int
    total: int


class Page[T](DTO):
    items: list[T]
    pagination: Pagination


def parse_boundary(value: object) -> date | datetime | None:
    if value is None or isinstance(value, (date, datetime)):
        result = value
    elif isinstance(value, str) and len(value) == 10:
        result = date.fromisoformat(value)
    elif isinstance(value, str):
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    else:
        raise ValueError("Use data ISO ou instante com fuso.")
    if isinstance(result, datetime) and (result.tzinfo is None or result.utcoffset() is None):
        raise ValueError("Instantes exigem fuso horário.")
    if result is not None and not 1000 <= result.year <= 9998:
        raise ValueError("Data fora do intervalo operacional do MySQL.")
    return result


Boundary = Annotated[date | datetime, BeforeValidator(parse_boundary)]


class PagingFilter(DTO):
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0, le=100000)


class ListFilter(PagingFilter):
    from_: Boundary | None = Field(default=None, alias="from")
    to: Boundary | None = None

    def bounds(self, timezone: str) -> tuple[datetime | None, datetime | None]:
        def convert(value, end=False):
            if value is None:
                return None
            if not isinstance(value, datetime):
                value = datetime.combine(
                    value + (timedelta(days=1) if end else timedelta()),
                    time.min,
                    ZoneInfo(timezone),
                )
            return utc(value).replace(tzinfo=None)

        start, end = convert(self.from_), convert(self.to, True)
        if start is not None and end is not None and start >= end:
            from app.core.errors import ApiError

            raise ApiError(400, "invalid_period", "O início deve anteceder o fim do período.")
        return start, end


class ErrorBody(DTO):
    code: str
    message: str


class ErrorResponse(DTO):
    error: ErrorBody
