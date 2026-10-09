from datetime import date

from sqlalchemy import CHAR, Boolean, ForeignKey, String
from sqlalchemy.dialects.mysql import BIGINT
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class User(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "users"
    timezone: Mapped[str] = mapped_column(String(64), default="America/Sao_Paulo")
    email: Mapped[str | None] = mapped_column(String(254, collation="utf8mb4_bin"), unique=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="1")


class UserProfile(TimestampMixin, Base):
    __tablename__ = "user_profiles"
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        primary_key=True,
        autoincrement=False,
    )
    full_name: Mapped[str] = mapped_column(String(160))
    phone: Mapped[str | None] = mapped_column(String(20))
    sus_card_number: Mapped[str | None] = mapped_column(CHAR(15))
    birth_date: Mapped[date | None]
    cpf: Mapped[str | None] = mapped_column(CHAR(11))
    postcode: Mapped[str | None] = mapped_column(CHAR(8))
    street: Mapped[str | None] = mapped_column(String(200))
    number: Mapped[str | None] = mapped_column(String(20))
    complement: Mapped[str | None] = mapped_column(String(100))
    neighborhood: Mapped[str | None] = mapped_column(String(100))
    city: Mapped[str | None] = mapped_column(String(100))
    state_code: Mapped[str | None] = mapped_column(CHAR(2))
    emergency_name: Mapped[str | None] = mapped_column(String(160))
    emergency_relationship: Mapped[str | None] = mapped_column(String(80))
    emergency_phone: Mapped[str | None] = mapped_column(String(20))
