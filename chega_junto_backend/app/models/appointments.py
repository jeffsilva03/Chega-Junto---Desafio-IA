from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.dialects.mysql import BIGINT, DATETIME, JSON, SMALLINT
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class Facility(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "facilities"
    name: Mapped[str] = mapped_column(String(160))
    address_text: Mapped[str] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Appointment(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "appointments"
    __table_args__ = (
        CheckConstraint("type IN ('consultation', 'exam')", name="type_values"),
        CheckConstraint(
            "attendance_status IN ('confirmed', 'undecided', 'unable')",
            name="attendance_values",
        ),
        CheckConstraint("JSON_TYPE(instructions) = 'ARRAY'", name="instructions_array"),
        Index("ix_appointments_user_date", "user_id", "scheduled_at"),
        Index("ix_appointments_facility_id", "facility_id"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
    )
    facility_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("facilities.id", ondelete="RESTRICT"),
    )
    type: Mapped[str] = mapped_column(String(20, collation="utf8mb4_bin"))
    title: Mapped[str] = mapped_column(String(160))
    specialty: Mapped[str] = mapped_column(String(120))
    professional_name: Mapped[str] = mapped_column(String(160))
    scheduled_at: Mapped[datetime] = mapped_column(DATETIME(fsp=6))
    timezone: Mapped[str] = mapped_column(String(64), default="America/Sao_Paulo")
    instructions: Mapped[list[str]] = mapped_column(JSON, default=list)
    attendance_status: Mapped[str] = mapped_column(
        String(20, collation="utf8mb4_bin"),
        default="undecided",
    )
    attendance_responded_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))


class AppointmentChecklistItem(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "appointment_checklist_items"
    __table_args__ = (
        UniqueConstraint("appointment_id", "item_key"),
        UniqueConstraint("appointment_id", "position", name="uq_checklist_appointment_position"),
        CheckConstraint(
            "section IN ('documents', 'reminders', 'conversation')",
            name="section_values",
        ),
        Base.__table_args__,
    )
    appointment_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("appointments.id", ondelete="RESTRICT"),
    )
    item_key: Mapped[str] = mapped_column(String(64, collation="utf8mb4_bin"))
    title: Mapped[str] = mapped_column(String(200))
    section: Mapped[str] = mapped_column(String(20, collation="utf8mb4_bin"))
    is_required: Mapped[bool] = mapped_column(Boolean, default=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    position: Mapped[int] = mapped_column(SMALLINT(unsigned=True))


class Reminder(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "reminders"
    __table_args__ = (
        Index("ix_reminders_user_date", "user_id", "remind_at"),
        Index("ix_reminders_appointment_id", "appointment_id"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
    )
    appointment_id: Mapped[int | None] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("appointments.id", ondelete="RESTRICT"),
    )
    title: Mapped[str] = mapped_column(String(80))
    remind_at: Mapped[datetime] = mapped_column(DATETIME(fsp=6))
