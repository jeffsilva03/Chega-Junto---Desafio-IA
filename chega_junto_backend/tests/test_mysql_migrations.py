"""Opt-in: ensaio no container MySQL descartável local, nunca no Aiven."""

import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session

import app.models  # noqa: F401
from app.core.config import Settings
from app.core.errors import ApiError
from app.database.base import Base
from app.models import User
from app.services.ai_quota import AiQuota


@pytest.mark.skipif(
    os.environ.get("RUN_MYSQL_MIGRATION_QA") != "1", reason="MySQL descartável opt-in"
)
def test_full_mysql_chain_and_metadata():
    engine = create_engine("mysql+pymysql://root@127.0.0.1:33070/chega_junto_v8_qa")
    try:
        with engine.connect() as connection:
            assert connection.scalar(text("SELECT DATABASE()")) == "chega_junto_v8_qa"
            assert inspect(connection).get_table_names() == []
            connection.commit()
            config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
            config.attributes["connection"] = connection
            command.upgrade(config, "head")
            assert (
                connection.scalar(text("SELECT version_num FROM alembic_version"))
                == "20261013_0005"
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
            command.downgrade(config, "20261012_0004")
            assert "ai_usage_events" not in inspect(connection).get_table_names()
            assert "operators" in inspect(connection).get_table_names()
            command.upgrade(config, "head")
            assert compare_metadata(MigrationContext.configure(connection), Base.metadata) == []
            connection.commit()
        with Session(engine) as session, session.begin():
            session.add(User(id=1))
        settings = Settings(
            _env_file=None,
            ai_organize_global_daily_limit=2,
            openai_text_model="test-text",
            openai_transcription_model="test-audio",
        )
        quota = AiQuota(engine, settings)

        def reserve(_):
            try:
                return quota.reserve(1, "organize")
            except ApiError as error:
                assert error.status == 429
                return None

        with ThreadPoolExecutor(max_workers=8) as pool:
            assert sum(value is not None for value in pool.map(reserve, range(12))) == 2
        with engine.connect() as connection:
            assert (
                connection.scalar(text("SELECT IS_FREE_LOCK('chega_junto_ai_quota_organize')")) == 1
            )
            assert connection.scalar(text("SELECT COUNT(*) FROM ai_usage_events")) == 2
    finally:
        engine.dispose()
