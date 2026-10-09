from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.dialects.mysql import BIGINT, DATETIME, JSON, MEDIUMTEXT, SMALLINT
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class HealthItemMixin(IdentityMixin, TimestampMixin):
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
    )
    name: Mapped[str] = mapped_column(String(80))
    details: Mapped[str] = mapped_column(String(160))
    position: Mapped[int] = mapped_column(SMALLINT(unsigned=True))


class Medication(HealthItemMixin, Base):
    __tablename__ = "medications"
    __table_args__ = (UniqueConstraint("user_id", "position"), Base.__table_args__)


class Allergy(HealthItemMixin, Base):
    __tablename__ = "allergies"
    __table_args__ = (UniqueConstraint("user_id", "position"), Base.__table_args__)


class HealthRecord(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "health_records"
    __table_args__ = (
        CheckConstraint(
            "type IN ('consultation', 'exam', 'medication', 'allergy', 'diagnosis')",
            name="type_values",
        ),
        CheckConstraint("JSON_TYPE(notes) = 'ARRAY'", name="notes_array"),
        Index("ix_health_records_user_date", "user_id", "occurred_at"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
    )
    type: Mapped[str] = mapped_column(String(24, collation="utf8mb4_bin"))
    occurred_at: Mapped[datetime] = mapped_column(DATETIME(fsp=6))
    title: Mapped[str] = mapped_column(String(200))
    subtitle: Mapped[str] = mapped_column(String(250))
    professional_text: Mapped[str | None] = mapped_column(String(160))
    facility_text: Mapped[str | None] = mapped_column(String(160))
    reason: Mapped[str] = mapped_column(Text)
    summary: Mapped[str] = mapped_column(MEDIUMTEXT)
    notes: Mapped[list[str]] = mapped_column(JSON, default=list)


class HealthRecordDocument(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "health_record_documents"
    __table_args__ = (UniqueConstraint("health_record_id", "position"), Base.__table_args__)
    health_record_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("health_records.id", ondelete="CASCADE"),
    )
    title: Mapped[str] = mapped_column(String(200))
    content_text: Mapped[str] = mapped_column(MEDIUMTEXT)
    position: Mapped[int] = mapped_column(SMALLINT(unsigned=True))
