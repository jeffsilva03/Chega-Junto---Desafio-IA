"""Complemento orientado ao relato; preserva integralmente os relatórios V8."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision = "20261013_0006"
down_revision = "20261013_0005"
branch_labels = None
depends_on = None


def upgrade():
    for name in ("clarifications_source_hash", "clarification_request_id"):
        op.add_column(
            "pre_visit_reports",
            sa.Column(
                name,
                sa.CHAR(64 if name.endswith("hash") else 36, collation="utf8mb4_bin"),
                nullable=True,
            ),
        )
    for name in ("clarifications_completed_at", "clarification_requested_at"):
        op.add_column("pre_visit_reports", sa.Column(name, mysql.DATETIME(fsp=6), nullable=True))
    op.create_table(
        "report_clarifications",
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("report_id", mysql.BIGINT(unsigned=True), nullable=False),
        sa.Column("question_text", sa.String(700), nullable=False),
        sa.Column("source_hash", sa.CHAR(64, collation="utf8mb4_bin"), nullable=False),
        sa.Column("answer_mode", sa.String(20), nullable=False),
        sa.Column("options", mysql.JSON(), nullable=False),
        sa.Column("answer_kind", sa.String(24), nullable=True),
        sa.Column("answer_text", sa.Text(), nullable=True),
        sa.Column("position", mysql.SMALLINT(unsigned=True), nullable=False),
        sa.Column("answered_at", mysql.DATETIME(fsp=6), nullable=True),
        sa.Column("created_at", mysql.DATETIME(fsp=6), nullable=False),
        sa.Column("updated_at", mysql.DATETIME(fsp=6), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_report_clarifications")),
        sa.ForeignKeyConstraint(
            ["report_id"],
            ["pre_visit_reports.id"],
            ondelete="CASCADE",
            name=op.f("fk_report_clarifications_report_id_pre_visit_reports"),
        ),
        sa.UniqueConstraint(
            "report_id", "position", name="uq_report_clarifications_report_position"
        ),
        sa.CheckConstraint(
            "position BETWEEN 0 AND 2", name=op.f("ck_report_clarifications_position")
        ),
        sa.CheckConstraint(
            "answer_mode IN ('free_text', 'single_choice')",
            name=op.f("ck_report_clarifications_answer_mode"),
        ),
        sa.CheckConstraint(
            "(answer_kind IS NULL) = (answered_at IS NULL)",
            name=op.f("ck_report_clarifications_answered_pair"),
        ),
        sa.CheckConstraint(
            "JSON_TYPE(options) = 'ARRAY'", name=op.f("ck_report_clarifications_options_array")
        ),
        sa.CheckConstraint(
            "(answer_kind IS NULL AND answer_text IS NULL AND answered_at IS NULL) OR "
            "(answer_kind IN ('text', 'option') AND answer_text IS NOT NULL "
            "AND answered_at IS NOT NULL) OR "
            "(answer_kind IN ('dont_know', 'dont_remember', 'prefer_not_to_answer') "
            "AND answer_text IS NULL AND answered_at IS NOT NULL)",
            name=op.f("ck_report_clarifications_answer_state"),
        ),
        mysql_engine="InnoDB",
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.drop_constraint(op.f("ck_ai_usage_events_operation"), "ai_usage_events", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_usage_events_operation"),
        "ai_usage_events",
        "operation IN ('organize', 'transcribe', 'clarify')",
    )


def downgrade():
    if op.get_context().as_sql:
        raise RuntimeError("Downgrade exige verificação online de ausência de dados V9.")
    connection = op.get_bind()
    for query in (
        "SELECT 1 FROM report_clarifications LIMIT 1",
        "SELECT 1 FROM pre_visit_reports WHERE clarifications_source_hash IS NOT NULL "
        "OR clarifications_completed_at IS NOT NULL OR clarification_request_id IS NOT NULL "
        "OR clarification_requested_at IS NOT NULL LIMIT 1",
        "SELECT 1 FROM ai_usage_events WHERE operation = 'clarify' LIMIT 1",
    ):
        if connection.execute(sa.text(query)).first():
            raise RuntimeError("Dados V9 existentes impedem downgrade sem perda de dados.")
    op.drop_constraint(op.f("ck_ai_usage_events_operation"), "ai_usage_events", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_usage_events_operation"),
        "ai_usage_events",
        "operation IN ('organize', 'transcribe')",
    )
    op.drop_table("report_clarifications")
    for name in (
        "clarifications_source_hash",
        "clarifications_completed_at",
        "clarification_request_id",
        "clarification_requested_at",
    ):
        op.drop_column("pre_visit_reports", name)
