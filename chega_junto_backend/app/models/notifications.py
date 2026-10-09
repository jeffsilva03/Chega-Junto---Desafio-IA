from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.dialects.mysql import BIGINT, DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class Notification(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "notifications"
    __table_args__ = (
        UniqueConstraint("user_id", "source_key"),
        CheckConstraint(
            "category IN ('reminder', 'consultation', 'exam', 'system')",
            name="category_values",
        ),
        CheckConstraint(
            "preference_key IN ('appointments', 'exams', 'medications', 'documents', "
            "'confirmations', 'system')",
            name="preference_values",
        ),
        CheckConstraint(
            "(destination IN ('appointment', 'documents') AND appointment_id IS NOT NULL "
            "AND health_record_id IS NULL) OR "
            "(destination = 'history' AND health_record_id IS NOT NULL "
            "AND appointment_id IS NULL) OR "
            "(destination = 'medications' AND appointment_id IS NULL AND health_record_id IS NULL)",
            name="destination_target",
        ),
        Index("ix_notifications_user_published", "user_id", "published_at"),
        Index("ix_notifications_user_read", "user_id", "read_at"),
        Index("ix_notifications_appointment_id", "appointment_id"),
        Index("ix_notifications_health_record_id", "health_record_id"),
        Index("ix_notifications_reminder_id", "reminder_id"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
    )
    source_key: Mapped[str] = mapped_column(String(100, collation="utf8mb4_bin"))
    title: Mapped[str] = mapped_column(String(160))
    message: Mapped[str] = mapped_column(Text)
    published_at: Mapped[datetime] = mapped_column(DATETIME(fsp=6))
    category: Mapped[str] = mapped_column(String(20, collation="utf8mb4_bin"))
    preference_key: Mapped[str] = mapped_column(String(24, collation="utf8mb4_bin"))
    destination: Mapped[str] = mapped_column(String(20, collation="utf8mb4_bin"))
    appointment_id: Mapped[int | None] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("appointments.id", ondelete="RESTRICT"),
    )
    health_record_id: Mapped[int | None] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("health_records.id", ondelete="RESTRICT"),
    )
    reminder_id: Mapped[int | None] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("reminders.id", ondelete="RESTRICT"),
    )
    read_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))
