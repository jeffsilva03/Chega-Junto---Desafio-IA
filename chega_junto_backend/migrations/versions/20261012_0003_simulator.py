"""Status independente de presença e tipo retorno; nenhuma tabela nova."""

import sqlalchemy as sa
from alembic import op

revision = "20261012_0003"
down_revision = "20261009_0002"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "appointments",
        sa.Column(
            "status",
            sa.String(20, collation="utf8mb4_bin"),
            nullable=False,
            server_default="scheduled",
        ),
    )
    op.create_check_constraint(
        op.f("ck_appointments_status_values"),
        "appointments",
        "status IN ('scheduled', 'cancelled', 'completed')",
    )
    op.drop_constraint(op.f("ck_appointments_type_values"), "appointments", type_="check")
    op.create_check_constraint(
        op.f("ck_appointments_type_values"),
        "appointments",
        "type IN ('consultation', 'exam', 'return')",
    )


def downgrade():
    if not op.get_context().as_sql:
        if (
            op.get_bind()
            .execute(
                sa.text(
                    "SELECT 1 FROM appointments "
                    "WHERE type = 'return' OR status <> 'scheduled' LIMIT 1"
                )
            )
            .first()
        ):
            raise RuntimeError("Downgrade perderia tipo/status; operação recusada.")
    op.drop_constraint(op.f("ck_appointments_type_values"), "appointments", type_="check")
    op.create_check_constraint(
        op.f("ck_appointments_type_values"), "appointments", "type IN ('consultation', 'exam')"
    )
    op.drop_constraint(op.f("ck_appointments_status_values"), "appointments", type_="check")
    op.drop_column("appointments", "status")
