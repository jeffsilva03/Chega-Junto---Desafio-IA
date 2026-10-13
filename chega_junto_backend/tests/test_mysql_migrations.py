"""Opt-in: ensaio no container MySQL descartável local, nunca no Aiven."""

import os
from pathlib import Path

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import create_engine, inspect, text

import app.models  # noqa: F401
from app.database.base import Base


@pytest.mark.skipif(
    os.environ.get("RUN_MYSQL_MIGRATION_QA") != "1", reason="MySQL descartável opt-in"
)
def test_full_mysql_chain_and_metadata():
    engine = create_engine("mysql+pymysql://root@127.0.0.1:33070/chega_junto_v7_qa")
    try:
        with engine.connect() as connection:
            assert connection.scalar(text("SELECT DATABASE()")) == "chega_junto_v7_qa"
            assert inspect(connection).get_table_names() == []
            connection.commit()
            config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
            config.attributes["connection"] = connection
            command.upgrade(config, "head")
            assert (
                connection.scalar(text("SELECT version_num FROM alembic_version"))
                == "20261012_0004"
            )
            context = MigrationContext.configure(connection, opts={"compare_type": True})
            assert compare_metadata(context, Base.metadata) == []
            assert set(inspect(connection).get_table_names()) == set(Base.metadata.tables) | {
                "alembic_version"
            }
            assert all(
                connection.scalar(text(f"SELECT COUNT(*) FROM `{name}`")) == 0
                for name in Base.metadata.tables
            )
            command.downgrade(config, "20261012_0003")
            assert "operators" not in inspect(connection).get_table_names()
            command.upgrade(config, "head")
            assert compare_metadata(MigrationContext.configure(connection), Base.metadata) == []
            connection.commit()
    finally:
        engine.dispose()
