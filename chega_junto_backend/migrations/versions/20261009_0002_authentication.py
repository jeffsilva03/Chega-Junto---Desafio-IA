"""Credenciais canônicas e perfil inicial opcional; preserva os dados existentes."""

import sqlalchemy as sa
from alembic import op

revision = "20261009_0002"
down_revision = "20261009_0001"
branch_labels = None
depends_on = None

OPTIONAL = {
    "phone": sa.String(20),
    "birth_date": sa.Date(),
    "cpf": sa.CHAR(11),
    "postcode": sa.CHAR(8),
    "street": sa.String(200),
    "number": sa.String(20),
    "neighborhood": sa.String(100),
    "city": sa.String(100),
    "state_code": sa.CHAR(2),
    "emergency_name": sa.String(160),
    "emergency_relationship": sa.String(80),
    "emergency_phone": sa.String(20),
}


def upgrade():
    if not op.get_context().as_sql:
        duplicate = (
            op.get_bind()
            .execute(
                sa.text(
                    "SELECT 1 FROM user_profiles GROUP BY LOWER(TRIM(email)) "
                    "HAVING COUNT(*) > 1 LIMIT 1"
                )
            )
            .first()
        )
        if duplicate:
            raise RuntimeError(
                "E-mails existentes equivalentes; resolver antes de aplicar a migration."
            )
    op.add_column(
        "users", sa.Column("email", sa.String(254, collation="utf8mb4_bin"), nullable=True)
    )
    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))
    op.add_column(
        "users", sa.Column("is_active", sa.Boolean(), server_default=sa.text("1"), nullable=False)
    )
    op.execute(
        "UPDATE users AS u JOIN user_profiles AS p ON p.user_id = u.id "
        "SET u.email = LOWER(TRIM(p.email))"
    )
    op.create_unique_constraint("uq_users_email", "users", ["email"])
    for name, kind in OPTIONAL.items():
        op.alter_column("user_profiles", name, existing_type=kind, nullable=True)
    op.drop_column("user_profiles", "email")


def downgrade():
    if not op.get_context().as_sql:
        missing = " OR ".join(f"p.{name} IS NULL" for name in OPTIONAL)
        if (
            op.get_bind()
            .execute(
                sa.text(
                    "SELECT 1 FROM user_profiles p JOIN users u ON u.id=p.user_id "
                    f"WHERE u.email IS NULL OR {missing} LIMIT 1"
                )
            )
            .first()
        ):
            raise RuntimeError("Perfis incompletos impedem downgrade sem perda de dados.")
    op.add_column("user_profiles", sa.Column("email", sa.String(254), nullable=True))
    op.execute(
        "UPDATE user_profiles AS p JOIN users AS u ON u.id = p.user_id SET p.email = u.email"
    )
    op.alter_column("user_profiles", "email", existing_type=sa.String(254), nullable=False)
    for name, kind in OPTIONAL.items():
        op.alter_column("user_profiles", name, existing_type=kind, nullable=False)
    op.drop_constraint("uq_users_email", "users", type_="unique")
    for name in ("is_active", "password_hash", "email"):
        op.drop_column("users", name)
