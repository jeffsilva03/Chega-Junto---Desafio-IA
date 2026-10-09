from contextlib import contextmanager

from app.schemas.common import Pagination


@contextmanager
def transaction(session):
    # A leitura do contexto demo já pode ter iniciado autobegin nesta mesma sessão.
    try:
        yield
        session.commit()
    except BaseException:
        session.rollback()
        raise


def pagination(filters, total):
    return Pagination(limit=filters.limit, offset=filters.offset, total=total)


def validate_child_ids(existing, desired):
    from app.core.errors import not_found

    owned = {row.id for row in existing}
    if any(item.id is not None and item.id not in owned for item in desired):
        raise not_found()
