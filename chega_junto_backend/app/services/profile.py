from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.errors import not_found
from app.models import User
from app.repositories.users import UserRepository
from app.schemas.profile import ProfileRead
from app.services.auth import email_conflict
from app.services.common import transaction


class ProfileService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = UserRepository(session)

    @staticmethod
    def dto(row, email):
        return ProfileRead(
            id=row.user_id,
            email=email,
            **{
                field: getattr(row, field)
                for field in ProfileRead.model_fields
                if field not in {"id", "email"}
            },
        )

    def get(self):
        row = self.repository.profile(self.user.id)
        if row is None:
            raise not_found()
        return self.dto(row, self.repository.user(self.user.id).email)

    def put(self, payload):
        try:
            with transaction(self.session):
                account = self.repository.user(self.user.id, lock=True)
                row = self.repository.profile(self.user.id, lock=True)
                if row is None:
                    raise not_found()
                account.email = payload.email
                for field, value in payload.model_dump(exclude={"email"}).items():
                    setattr(row, field, value)
                self.session.flush()
                result = self.dto(row, account.email)
            return result
        except IntegrityError:
            if (
                self.session.scalar(
                    select(User.id).where(User.email == payload.email, User.id != self.user.id)
                )
                is not None
            ):
                raise email_conflict() from None
            raise
