"""Migration offline sem rede; online usa exatamente engine/config TLS do backend."""

from alembic import context
from alembic.util import CommandError
from sqlalchemy.exc import SQLAlchemyError

import app.models  # noqa: F401 — registro do metadata
from app.core.config import load_settings
from app.core.errors import ConfigurationError
from app.database.base import Base
from app.database.session import build_engine

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    load_settings()  # Também rejeita SSL/CORS/configuração inválidos no modo offline.
    context.configure(
        dialect_name="mysql",
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = build_engine(load_settings())
    try:
        with engine.connect() as connection:
            context.configure(
                connection=connection, target_metadata=target_metadata, compare_type=True
            )
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()


try:
    if context.is_offline_mode():
        run_migrations_offline()
    else:
        run_migrations_online()
except (ConfigurationError, SQLAlchemyError, OSError):
    raise CommandError(
        "MySQL indisponível ou configuração inválida. Confira o .env/TLS local."
    ) from None
