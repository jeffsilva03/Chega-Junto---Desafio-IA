"""Operadores demonstrativos separados das contas de pacientes."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision = "20261012_0004"
down_revision = "20261012_0003"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "operators",
        sa.Column("full_name", sa.String(160), nullable=False),
        sa.Column("email", sa.String(254, collation="utf8mb4_bin"), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("1"), nullable=False),
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("created_at", mysql.DATETIME(fsp=6), nullable=False),
        sa.Column("updated_at", mysql.DATETIME(fsp=6), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_operators")),
        sa.UniqueConstraint("email", name=op.f("uq_operators_email")),
        mysql_engine="InnoDB",
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )


def downgrade():
    if not op.get_context().as_sql:
        if op.get_bind().execute(sa.text("SELECT 1 FROM operators LIMIT 1")).first():
            raise RuntimeError("Operadores existentes impedem downgrade sem perda de dados.")
    op.drop_table("operators")
