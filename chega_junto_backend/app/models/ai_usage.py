"""Somente contadores e estados; nenhum conteúdo enviado ao provedor."""

from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Index, String
from sqlalchemy.dialects.mysql import BIGINT, DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, utc_now


class AiUsageEvent(IdentityMixin, Base):
    __tablename__ = "ai_usage_events"
    __table_args__ = (
        CheckConstraint("operation IN ('organize', 'transcribe')", name="operation"),
        CheckConstraint("outcome IN ('started', 'succeeded', 'failed')", name="outcome"),
        Index("ix_ai_usage_user_operation_created", "user_id", "operation", "created_at"),
        Index("ix_ai_usage_operation_created", "operation", "created_at"),
        Base.__table_args__,
    )
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True), ForeignKey("users.id", ondelete="RESTRICT")
    )
    operation: Mapped[str] = mapped_column(String(16))
    provider: Mapped[str] = mapped_column(String(32))
    model: Mapped[str] = mapped_column(String(200))
    outcome: Mapped[str] = mapped_column(String(16), default="started")
    input_units: Mapped[int | None] = mapped_column(BIGINT(unsigned=True))
    output_units: Mapped[int | None] = mapped_column(BIGINT(unsigned=True))
    created_at: Mapped[datetime] = mapped_column(DATETIME(fsp=6), default=utc_now)
    completed_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))
