from datetime import datetime

from sqlalchemy import CHAR, Boolean, CheckConstraint, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.dialects.mysql import BIGINT, DATETIME, MEDIUMTEXT, SMALLINT
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, IdentityMixin, TimestampMixin


class PreVisitReport(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "pre_visit_reports"
    __table_args__ = (
        UniqueConstraint("appointment_id"),
        CheckConstraint("content_revision >= 1", name="positive_revision"),
        CheckConstraint(
            "reviewed_revision IS NULL OR reviewed_revision <= content_revision",
            name="reviewed_revision_bound",
        ),
        CheckConstraint(
            "final_review_revision IS NULL OR final_review_revision <= content_revision",
            name="final_revision_bound",
        ),
        CheckConstraint(
            "(reviewed_revision IS NULL) = (reviewed_at IS NULL)",
            name="reviewed_pair",
        ),
        CheckConstraint(
            "(final_review_revision IS NULL) = (final_review_at IS NULL)",
            name="final_pair",
        ),
        CheckConstraint(
            "(organized_source_hash IS NULL) = (organized_at IS NULL)",
            name="organized_pair",
        ),
        Base.__table_args__,
    )
    appointment_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("appointments.id", ondelete="RESTRICT"),
    )
    original_text: Mapped[str] = mapped_column(MEDIUMTEXT, default="")
    organized_source_hash: Mapped[str | None] = mapped_column(CHAR(64, collation="utf8mb4_bin"))
    organized_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))
    content_revision: Mapped[int] = mapped_column(BIGINT(unsigned=True), default=1)
    reviewed_revision: Mapped[int | None] = mapped_column(BIGINT(unsigned=True))
    reviewed_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))
    final_review_revision: Mapped[int | None] = mapped_column(BIGINT(unsigned=True))
    final_review_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=6))
    # O serviço incrementa só em mudança efetiva, incluindo filhos; ORM verifica conflitos.
    __mapper_args__ = {"version_id_col": content_revision, "version_id_generator": False}


class ReportSection(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "report_sections"
    __table_args__ = (
        UniqueConstraint("report_id", "section_key"),
        UniqueConstraint("report_id", "position", name="uq_report_sections_report_position"),
        Base.__table_args__,
    )
    report_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("pre_visit_reports.id", ondelete="CASCADE"),
    )
    section_key: Mapped[str] = mapped_column(String(64, collation="utf8mb4_bin"))
    title: Mapped[str] = mapped_column(String(160))
    text: Mapped[str] = mapped_column(MEDIUMTEXT, default="")
    position: Mapped[int] = mapped_column(SMALLINT(unsigned=True))


class ReportQuestion(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "report_questions"
    __table_args__ = (UniqueConstraint("report_id", "position"), Base.__table_args__)
    report_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True),
        ForeignKey("pre_visit_reports.id", ondelete="CASCADE"),
    )
    text: Mapped[str] = mapped_column(Text)
    is_selected: Mapped[bool] = mapped_column(Boolean, default=True)
    position: Mapped[int] = mapped_column(SMALLINT(unsigned=True))
