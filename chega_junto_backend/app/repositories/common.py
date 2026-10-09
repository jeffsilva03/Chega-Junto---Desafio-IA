from sqlalchemy import func, select


def paginate(session, statement, filters):
    total = session.scalar(select(func.count()).select_from(statement.order_by(None).subquery()))
    return session.execute(statement.limit(filters.limit).offset(filters.offset)).all(), total


def park_positions(session, rows):
    """UNIQUE do MySQL é imediato: liberar posições finais antes de reordenar."""
    occupied = {row.position for row in rows}
    candidate = 65535
    for row in rows:
        while candidate in occupied:
            candidate -= 1
        row.position = candidate
        occupied.add(candidate)
        candidate -= 1
    session.flush()


def replace_ordered(
    session, model, existing, desired, parent_field, parent_id, fields, *, logical_key=None
):
    """Apenas persistência; titularidade e validações pertencem ao service."""
    by_id = {row.id: row for row in existing}
    by_key = {getattr(row, logical_key): row for row in existing} if logical_key else {}
    chosen, used = [], set()
    for position, item in enumerate(desired):
        row = by_id.get(item.id) if item.id is not None else None
        if row is None and logical_key:
            row = by_key.get(getattr(item, logical_key))
        if row is None and position < len(existing):
            candidate = existing[position]
            if (
                item.id is None
                and candidate.id not in used
                and all(getattr(candidate, field) == getattr(item, field) for field in fields)
            ):
                row = candidate
        if row is not None:
            used.add(row.id)
        chosen.append(row)
    park_positions(session, existing)
    for row in existing:
        if row.id not in used:
            session.delete(row)
    session.flush()
    result = []
    for position, (item, row) in enumerate(zip(desired, chosen, strict=True)):
        if row is None:
            row = model(**{parent_field: parent_id})
            session.add(row)
        for field in fields:
            setattr(row, field, getattr(item, field))
        row.position = position
        result.append(row)
    session.flush()
    return result
