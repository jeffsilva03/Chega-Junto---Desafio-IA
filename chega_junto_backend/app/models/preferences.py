from sqlalchemy import Boolean, CheckConstraint, ForeignKey, String
from sqlalchemy.dialects.mysql import BIGINT
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, TimestampMixin


class NotificationPreferences(TimestampMixin, Base):
    __tablename__ = "notification_preferences"
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        primary_key=True,
        autoincrement=False,
    )
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    appointments: Mapped[bool] = mapped_column(Boolean, default=True)
    exams: Mapped[bool] = mapped_column(Boolean, default=True)
    medications: Mapped[bool] = mapped_column(Boolean, default=True)
    documents: Mapped[bool] = mapped_column(Boolean, default=True)
    confirmations: Mapped[bool] = mapped_column(Boolean, default=True)
    system: Mapped[bool] = mapped_column(Boolean, default=False)
    in_app: Mapped[bool] = mapped_column(Boolean, default=True)


class AccessibilityPreferences(TimestampMixin, Base):
    __tablename__ = "accessibility_preferences"
    __table_args__ = (
        CheckConstraint(
            "text_size IN ('small', 'medium', 'large', 'extra_large')",
            name="text_size_values",
        ),
        CheckConstraint("appearance IN ('light', 'dark', 'system')", name="appearance_values"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        primary_key=True,
        autoincrement=False,
    )
    text_size: Mapped[str] = mapped_column(
        String(20, collation="utf8mb4_bin"),
        default="medium",
    )
    appearance: Mapped[str] = mapped_column(
        String(12, collation="utf8mb4_bin"),
        default="light",
    )
    high_contrast: Mapped[bool] = mapped_column(Boolean, default=False)
    speech: Mapped[bool] = mapped_column(Boolean, default=False)
    descriptions: Mapped[bool] = mapped_column(Boolean, default=True)
    simple_language: Mapped[bool] = mapped_column(Boolean, default=True)
    haptics: Mapped[bool] = mapped_column(Boolean, default=True)
    reduce_motion: Mapped[bool] = mapped_column(Boolean, default=False)
