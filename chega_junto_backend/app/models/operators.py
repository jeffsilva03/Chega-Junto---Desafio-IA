from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class Operator(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "operators"
    full_name: Mapped[str] = mapped_column(String(160))
    email: Mapped[str] = mapped_column(String(254, collation="utf8mb4_bin"), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="1")
