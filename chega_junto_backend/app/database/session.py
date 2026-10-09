"""Engine síncrona, TLS obrigatório e sessão por request/unidade de trabalho."""

import ssl
from collections.abc import Iterator
from contextlib import contextmanager

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings
from app.core.errors import ConfigurationError, DatabaseUnavailable


def build_engine(settings: Settings) -> Engine:
    if not settings.database_configured:
        raise ConfigurationError()
    try:
        context = ssl.create_default_context(cafile=str(settings.database_ssl_ca_path))
    except (OSError, ssl.SSLError):
        raise ConfigurationError() from None
    context.check_hostname = True
    context.verify_mode = ssl.CERT_REQUIRED
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    engine = create_engine(
        settings.database_url(),
        connect_args={
            "ssl": context,
            "connect_timeout": settings.database_connect_timeout,
            "read_timeout": settings.database_read_timeout,
            "write_timeout": settings.database_write_timeout,
        },
        pool_size=settings.database_pool_size,
        max_overflow=settings.database_max_overflow,
        pool_timeout=settings.database_pool_timeout,
        pool_pre_ping=settings.database_pool_pre_ping,
        pool_recycle=settings.database_pool_recycle,
        echo=False,
        hide_parameters=True,
    )

    @event.listens_for(engine, "connect")
    def initialize_connection(dbapi_connection: object, _record: object) -> None:
        with dbapi_connection.cursor() as cursor:
            cursor.execute("SET time_zone = '+00:00'")

    return engine


class Database:
    def __init__(self, settings: Settings) -> None:
        self.engine = build_engine(settings) if settings.database_configured else None
        self.session_factory = (
            sessionmaker(bind=self.engine, expire_on_commit=False) if self.engine else None
        )

    @contextmanager
    def session(self) -> Iterator[Session]:
        if self.session_factory is None:
            raise DatabaseUnavailable()
        session = self.session_factory()
        try:
            yield session
        except BaseException:
            session.rollback()
            raise
        finally:
            session.close()

    def dispose(self) -> None:
        if self.engine is not None:
            self.engine.dispose()
