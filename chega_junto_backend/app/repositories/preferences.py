from sqlalchemy import select


class PreferencesRepository:
    def __init__(self, session):
        self.session = session

    def get(self, model, user_id, *, lock=False):
        statement = select(model).where(model.user_id == user_id)
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))

    def save(self, model, user_id, values):
        row = self.get(model, user_id, lock=True)
        if row is None:
            row = model(user_id=user_id)
            self.session.add(row)
        for field, value in values.items():
            setattr(row, field, value)
        self.session.flush()
        return row
