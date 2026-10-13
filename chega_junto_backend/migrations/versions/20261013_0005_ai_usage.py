"""Reservas persistentes de quota de IA, sem conteúdo."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision = "20261013_0005"
down_revision = "20261012_0004"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "ai_usage_events",
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("user_id", mysql.BIGINT(unsigned=True), nullable=False),
        sa.Column("operation", sa.String(16), nullable=False),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("model", sa.String(200), nullable=False),
        sa.Column("outcome", sa.String(16), nullable=False),
        sa.Column("input_units", mysql.BIGINT(unsigned=True), nullable=True),
        sa.Column("output_units", mysql.BIGINT(unsigned=True), nullable=True),
        sa.Column("created_at", mysql.DATETIME(fsp=6), nullable=False),
        sa.Column("completed_at", mysql.DATETIME(fsp=6), nullable=True),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_usage_events")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name=op.f("fk_ai_usage_events_user_id_users"),
        ),
        sa.CheckConstraint(
            "operation IN ('organize', 'transcribe')", name=op.f("ck_ai_usage_events_operation")
        ),
        sa.CheckConstraint(
            "outcome IN ('started', 'succeeded', 'failed')", name=op.f("ck_ai_usage_events_outcome")
        ),
        mysql_engine="InnoDB",
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_ai_usage_user_operation_created",
        "ai_usage_events",
        ["user_id", "operation", "created_at"],
    )
    op.create_index("ix_ai_usage_operation_created", "ai_usage_events", ["operation", "created_at"])


def downgrade():
    if not op.get_context().as_sql:
        if op.get_bind().execute(sa.text("SELECT 1 FROM ai_usage_events LIMIT 1")).first():
            raise RuntimeError("Uso existente impede downgrade sem perda de dados.")
    op.drop_table("ai_usage_events")
