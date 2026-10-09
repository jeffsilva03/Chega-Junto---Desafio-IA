import importlib.util
from io import StringIO
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from pydantic import BaseModel
from sqlalchemy.dialects import mysql

import app.models  # noqa: F401
from app.database.base import Base
from app.models import PreVisitReport
from app.schemas.common import DatabaseId

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_TABLES = {
    "users",
    "user_profiles",
    "facilities",
    "appointments",
    "appointment_checklist_items",
    "reminders",
    "medications",
    "allergies",
    "health_records",
    "health_record_documents",
    "pre_visit_reports",
    "report_sections",
    "report_questions",
    "notifications",
    "notification_preferences",
    "accessibility_preferences",
}


def load_initial_migration():
    path = ROOT / "migrations/versions/20261009_0001_initial_schema.py"
    spec = importlib.util.spec_from_file_location("initial_migration", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_auth_migration():
    path = ROOT / "migrations/versions/20261009_0002_authentication.py"
    spec = importlib.util.spec_from_file_location("auth_migration", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RecordingOperations:
    """Captura o snapshot estático da migration sem executar SQL em qualquer banco."""

    def __init__(self):
        self.metadata = sa.MetaData()

    @staticmethod
    def f(name):
        return sa.schema.conv(name)

    def create_table(self, name, *columns, **kwargs):
        return sa.Table(name, self.metadata, *columns, **kwargs)

    def create_index(self, name, table_name, columns, **kwargs):
        table = self.metadata.tables[table_name]
        sa.Index(name, *[table.c[column] for column in columns], **kwargs)

    def drop_index(self, name, table_name):
        table = self.metadata.tables[table_name]
        index = next(index for index in table.indexes if index.name == name)
        table.indexes.remove(index)

    def drop_table(self, name):
        for table in self.metadata.tables.values():
            if table.name != name:
                assert all(fk.target_fullname.split(".")[0] != name for fk in table.foreign_keys)
        self.metadata.remove(self.metadata.tables[name])

    def get_context(self):
        from types import SimpleNamespace

        return SimpleNamespace(as_sql=True)

    def add_column(self, name, column):
        self.metadata.tables[name].append_column(column)

    def alter_column(self, name, column, **kwargs):
        self.metadata.tables[name].c[column].nullable = kwargs["nullable"]

    def drop_column(self, name, column):
        self.metadata.tables[name]._columns.remove(self.metadata.tables[name].c[column])

    def create_unique_constraint(self, name, table, columns):
        self.metadata.tables[table].append_constraint(sa.UniqueConstraint(*columns, name=name))

    def drop_constraint(self, name, table, **kwargs):
        target = self.metadata.tables[table]
        target.constraints.remove(next(c for c in target.constraints if c.name == name))

    def execute(self, sql):
        assert str(sql).startswith("UPDATE ")


def constraint_signature(table):
    signatures = set()
    for constraint in table.constraints:
        if isinstance(constraint, sa.CheckConstraint):
            signatures.add(("check", str(constraint.name), str(constraint.sqltext)))
        elif isinstance(constraint, sa.ForeignKeyConstraint):
            signatures.add(
                (
                    "fk",
                    str(constraint.name),
                    tuple(
                        (fk.parent.name, fk.target_fullname, fk.ondelete)
                        for fk in constraint.elements
                    ),
                )
            )
        elif isinstance(constraint, (sa.UniqueConstraint, sa.PrimaryKeyConstraint)):
            signatures.add(
                (
                    type(constraint).__name__,
                    str(constraint.name),
                    tuple(column.name for column in constraint.columns),
                )
            )
    return signatures


def test_mysql_schema_and_frozen_migration_agree(monkeypatch):
    migration = load_initial_migration()
    operations = RecordingOperations()
    monkeypatch.setattr(migration, "op", operations)
    migration.upgrade()
    authentication = load_auth_migration()
    monkeypatch.setattr(authentication, "op", operations)
    authentication.upgrade()
    assert set(operations.metadata.tables) == EXPECTED_TABLES == set(Base.metadata.tables)
    for name, expected in Base.metadata.tables.items():
        actual = operations.metadata.tables[name]

        def signature(table):
            return {
                column.name: (column.type.compile(dialect=mysql.dialect()), column.nullable)
                for column in table.columns
            }

        assert signature(actual) == signature(expected), name
        assert constraint_signature(actual) == constraint_signature(expected), name
        assert dict(actual.dialect_options["mysql"]) == dict(expected.dialect_options["mysql"])
        assert {(i.name, tuple(c.name for c in i.columns)) for i in actual.indexes} == {
            (i.name, tuple(c.name for c in i.columns)) for i in expected.indexes
        }
        assert all(len(str(c.name)) <= 64 for c in actual.constraints)
    authentication.downgrade()
    migration.downgrade()
    assert not operations.metadata.tables


def test_no_transcription_progress_or_secrets_in_business_schema():
    for table in Base.metadata.tables.values():
        assert {"created_at", "updated_at"}.issubset(table.c.keys())
        assert not {
            "transcription_text",
            "transcription_used_at",
            "percentage",
            "deleted_at",
            "password",
            "api_key",
            "prompt",
        }.intersection(table.c.keys())
        for column in table.primary_key.columns:
            assert isinstance(column.type, mysql.BIGINT) and column.type.unsigned
        if "id" in table.c:
            assert table.c.id.autoincrement is True
    assert PreVisitReport.__mapper__.version_id_col is PreVisitReport.__table__.c.content_revision
    assert PreVisitReport.__mapper__.version_id_generator is False


def test_alembic_offline_compiles_mysql_without_credentials():
    output = StringIO()
    config = Config(str(ROOT / "alembic.ini"), output_buffer=output)
    command.upgrade(config, "head", sql=True)
    ddl = output.getvalue()
    assert ddl.count("CREATE TABLE ") == 17  # 16 de domínio + controle alembic_version.
    assert "BIGINT UNSIGNED" in ddl and "AUTO_INCREMENT" in ddl
    assert "ENGINE=InnoDB" in ddl and "utf8mb4" in ddl
    assert "transcription_text" not in ddl and "INSERT INTO users" not in ddl
    assert "20261009_0001" in ddl


def test_bigint_ids_serialize_as_decimal_strings():
    class Example(BaseModel):
        id: DatabaseId

    assert Example(id=18446744073709551615).model_dump(mode="json") == {
        "id": "18446744073709551615",
    }
