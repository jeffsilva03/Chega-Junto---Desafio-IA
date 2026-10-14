"""Reserva confirmada antes da rede. Falhas e reservas incertas consomem quota."""

from contextlib import nullcontext
from datetime import timedelta
from threading import RLock

from sqlalchemy import func, insert, select, text, update

from app.core.errors import ApiError
from app.database.base import utc_now
from app.models.ai_usage import AiUsageEvent

_test_lock = RLock()  # SQLite existe somente nos testes; produção usa lock MySQL.


class AiQuota:
    def __init__(self, engine, settings):
        self.engine, self.settings = engine, settings

    def reserve(self, user_id, operation, *, now=None):
        now = now or utc_now()
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=1)
        table = AiUsageEvent.__table__
        mysql = self.engine.dialect.name == "mysql"
        # GET_LOCK é por conexão, não por transação: manter esta conexão até liberar.
        guard = nullcontext() if mysql else _test_lock
        with guard, self.engine.connect() as connection:
            locked = False
            try:
                if mysql:
                    locked = (
                        connection.scalar(
                            text("SELECT GET_LOCK(:name, 5)"),
                            {"name": "chega_junto_ai_quota_" + operation},
                        )
                        == 1
                    )
                    if not locked:
                        raise ApiError(
                            503, "ai_unavailable", "Não foi possível processar com IA agora."
                        )
                where = (
                    table.c.operation == operation,
                    table.c.created_at >= start,
                    table.c.created_at < end,
                )
                global_count = connection.scalar(
                    select(func.count()).select_from(table).where(*where)
                )
                user_count = connection.scalar(
                    select(func.count())
                    .select_from(table)
                    .where(*where, table.c.user_id == user_id)
                )
                if global_count >= getattr(
                    self.settings, f"ai_{operation}_global_daily_limit"
                ) or user_count >= getattr(self.settings, f"ai_{operation}_user_daily_limit"):
                    raise ApiError(
                        429,
                        "ai_daily_limit_reached",
                        "Limite diário da demonstração atingido. Tente novamente mais tarde.",
                    )
                model = (
                    self.settings.openai_text_model
                    if operation in {"organize", "clarify"}
                    else self.settings.openai_transcription_model
                )
                event = connection.execute(
                    insert(table).values(
                        user_id=user_id,
                        operation=operation,
                        provider="openai",
                        model=model,
                        outcome="started",
                        created_at=now,
                    )
                )
                event_id = event.inserted_primary_key[0]
                connection.commit()
                return event_id
            finally:
                connection.rollback()
                if locked:
                    try:
                        connection.execute(
                            text("SELECT RELEASE_LOCK(:name)"),
                            {"name": "chega_junto_ai_quota_" + operation},
                        )
                        connection.commit()
                    except Exception:
                        connection.invalidate()  # Não devolver conexão com lock ao pool.
                        raise

    def complete(self, event_id, outcome, input_units=None, output_units=None):
        with self.engine.begin() as connection:
            connection.execute(
                update(AiUsageEvent)
                .where(AiUsageEvent.id == event_id)
                .values(
                    outcome=outcome,
                    completed_at=utc_now(),
                    input_units=input_units,
                    output_units=output_units,
                )
            )
