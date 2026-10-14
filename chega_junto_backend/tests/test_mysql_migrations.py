"""Opt-in: ensaio no container MySQL descartável local, nunca no Aiven."""

import hashlib
import json
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import MetaData, create_engine, inspect, select, text
from sqlalchemy.orm import Session

import app.models  # noqa: F401
from app.core.config import Settings
from app.core.errors import ApiError
from app.database.base import Base, utc_now
from app.models import User
from app.services.ai_quota import AiQuota
from app.services.reports import ReportService


@pytest.mark.skipif(
    os.environ.get("RUN_MYSQL_MIGRATION_QA") != "1", reason="MySQL descartável opt-in"
)
def test_full_mysql_chain_and_metadata():
    engine = create_engine("mysql+pymysql://root@127.0.0.1:33070/chega_junto_v9_qa")
    try:
        with engine.connect() as connection:
            assert connection.scalar(text("SELECT DATABASE()")) == "chega_junto_v9_qa"
            assert inspect(connection).get_table_names() == []
            connection.commit()
            config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
            config.attributes["connection"] = connection
            command.upgrade(config, "head")
            assert (
                connection.scalar(text("SELECT version_num FROM alembic_version"))
                == "20261013_0006"
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
            command.downgrade(config, "20261013_0005")
            assert "report_clarifications" not in inspect(connection).get_table_names()
            assert "ai_usage_events" in inspect(connection).get_table_names()
            assert "operators" in inspect(connection).get_table_names()
            # A V8 já concluída deve atravessar 0006 sem qualquer alteração.
            legacy = MetaData()
            legacy.reflect(connection)
            now = utc_now()
            source = "Relato exclusivamente fictício da V8."
            seeds = {
                "users": {"id": 2, "timezone": "America/Sao_Paulo", "is_active": True},
                "facilities": {
                    "id": 1,
                    "name": "UBS QA",
                    "address_text": "Local fictício",
                    "is_active": True,
                },
                "appointments": {
                    "id": 1,
                    "user_id": 2,
                    "facility_id": 1,
                    "type": "consultation",
                    "status": "scheduled",
                    "title": "Consulta QA",
                    "specialty": "Clínica geral",
                    "professional_name": "Profissional fictício",
                    "scheduled_at": now,
                    "timezone": "America/Sao_Paulo",
                    "instructions": [],
                    "attendance_status": "confirmed",
                },
                "pre_visit_reports": {
                    "id": 1,
                    "appointment_id": 1,
                    "original_text": source,
                    "organized_source_hash": hashlib.sha256(source.encode()).hexdigest(),
                    "organized_at": now,
                    "content_revision": 3,
                    "reviewed_revision": 3,
                    "reviewed_at": now,
                    "final_review_revision": 3,
                    "final_review_at": now,
                },
                "report_sections": {
                    "id": 1,
                    "report_id": 1,
                    "section_key": "reason",
                    "title": "Motivo",
                    "text": source,
                    "position": 0,
                },
                "report_questions": {
                    "id": 1,
                    "report_id": 1,
                    "text": "Minha pergunta fictícia?",
                    "is_selected": True,
                    "position": 0,
                },
            }
            for name, values in seeds.items():
                connection.execute(
                    legacy.tables[name].insert().values(**values, created_at=now, updated_at=now)
                )
            connection.commit()

            def fingerprint(table):
                rows = (
                    connection.execute(select(table).order_by(*table.primary_key.columns))
                    .mappings()
                    .all()
                )
                return hashlib.sha256(
                    json.dumps([dict(row) for row in rows], sort_keys=True, default=str).encode()
                ).hexdigest()

            before = {
                name: fingerprint(table)
                for name, table in legacy.tables.items()
                if name != "alembic_version"
            }
            command.upgrade(config, "head")
            assert compare_metadata(MigrationContext.configure(connection), Base.metadata) == []
            assert all(
                fingerprint(legacy.tables[name]) == digest for name, digest in before.items()
            )
            assert connection.scalar(text("SELECT COUNT(*) FROM report_clarifications")) == 0
            connection.commit()
        with Session(engine) as session:
            report, sections, questions = ReportService(session, session.get(User, 2)).load(1)
            value = ReportService(session, session.get(User, 2)).dto(report, sections, questions)
            assert value.final_done and value.reviewed and value.organization_current
            assert value.clarifications == []
        with Session(engine) as session, session.begin():
            session.add(User(id=1))
        settings = Settings(
            _env_file=None,
            ai_organize_global_daily_limit=2,
            ai_clarify_global_daily_limit=2,
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
        with ThreadPoolExecutor(max_workers=8) as pool:

            def reserve_clarify(_):
                try:
                    return quota.reserve(1, "clarify")
                except ApiError as error:
                    assert error.status == 429
                    return None

            assert sum(value is not None for value in pool.map(reserve_clarify, range(12))) == 2
        with engine.connect() as connection:
            assert (
                connection.scalar(text("SELECT IS_FREE_LOCK('chega_junto_ai_quota_organize')")) == 1
            )
            assert connection.scalar(text("SELECT COUNT(*) FROM ai_usage_events")) == 4
            connection.commit()
            config.attributes["connection"] = connection
            with pytest.raises(RuntimeError, match="Dados V9"):
                command.downgrade(config, "20261013_0005")
            assert (
                connection.scalar(text("SELECT version_num FROM alembic_version"))
                == "20261013_0006"
            )
            assert connection.scalar(text("SELECT COUNT(*) FROM ai_usage_events")) == 4
    finally:
        engine.dispose()
