"""Somente testes: SQLite em memória, com FK/CHECK/UNIQUE imediatos.

Não é fallback da aplicação. Tipos MySQL têm compilação específica para este dialeto.
"""

import json

from sqlalchemy import create_engine, event
from sqlalchemy.dialects.mysql import BIGINT, MEDIUMTEXT
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.pool import StaticPool


@compiles(BIGINT, "sqlite")
def compile_bigint(_type, _compiler, **_kw):
    return "INTEGER"


@compiles(MEDIUMTEXT, "sqlite")
def compile_mediumtext(_type, _compiler, **_kw):
    return "TEXT"


def isolated_engine():
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )

    @event.listens_for(engine, "connect")
    def configure(connection, _record):
        connection.execute("PRAGMA foreign_keys=ON")
        connection.create_collation("utf8mb4_bin", lambda a, b: (a > b) - (a < b))
        connection.create_collation(
            "utf8mb4_unicode_ci",
            lambda a, b: (a.casefold() > b.casefold()) - (a.casefold() < b.casefold()),
        )
        connection.create_function(
            "JSON_TYPE",
            1,
            lambda value: "ARRAY" if isinstance(json.loads(value), list) else "OBJECT",
        )

    return engine
