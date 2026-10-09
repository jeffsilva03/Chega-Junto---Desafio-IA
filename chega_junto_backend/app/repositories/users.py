from sqlalchemy import select

from app.models import User, UserProfile


class UserRepository:
    def __init__(self, session):
        self.session = session

    def user(self, user_id, *, lock=False):
        statement = select(User).where(User.id == user_id)
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))

    def profile(self, user_id, *, lock=False):
        statement = select(UserProfile).where(UserProfile.user_id == user_id)
        if lock:
            statement = statement.with_for_update()
        return self.session.scalar(statement.execution_options(populate_existing=True))
