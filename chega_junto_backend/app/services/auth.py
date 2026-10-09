from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.errors import ApiError
from app.core.security import create_token, password_hasher, unauthorized, verify_password
from app.models import AccessibilityPreferences, NotificationPreferences, User, UserProfile
from app.schemas.auth import AuthSession, AuthUser
from app.services.common import transaction


def email_conflict():
    return ApiError(409, "email_already_registered", "Já existe uma conta com este e-mail.")


class AuthService:
    def __init__(self, session, settings):
        self.session, self.settings = session, settings

    def identity(self, user):
        profile = self.session.get(UserProfile, user.id)
        if profile is None or user.email is None:
            raise unauthorized()
        return AuthUser(id=user.id, full_name=profile.full_name, email=user.email)

    def me(self, user_id):
        return self.identity(self.session.get(User, user_id))

    def authenticated(self, user):
        return AuthSession(
            access_token=create_token(self.settings, user.id), user=self.identity(user)
        )

    def register(self, payload):
        self.settings.validate_auth()
        encoded = password_hasher.hash(payload.password.get_secret_value())
        try:
            with transaction(self.session):
                if (
                    self.session.scalar(select(User.id).where(User.email == payload.email))
                    is not None
                ):
                    raise email_conflict()
                user = User(
                    email=payload.email, password_hash=encoded, timezone=self.settings.app_timezone
                )
                self.session.add(user)
                self.session.flush()
                self.session.add_all(
                    [
                        UserProfile(user_id=user.id, full_name=payload.full_name),
                        NotificationPreferences(user_id=user.id),
                        AccessibilityPreferences(user_id=user.id),
                    ]
                )
                self.session.flush()
                result = self.authenticated(user)
            return result
        except IntegrityError:
            # Confirmar a colisão de e-mail após rollback; outras constraints não fingem duplicação.
            if self.session.scalar(select(User.id).where(User.email == payload.email)) is not None:
                raise email_conflict() from None
            raise

    def login(self, payload):
        user = self.session.scalar(select(User).where(User.email == payload.email))
        verified = verify_password(
            user.password_hash if user is not None else None, payload.password.get_secret_value()
        )
        if user is None or not verified or not user.is_active or user.password_hash is None:
            raise unauthorized("invalid_credentials", "E-mail ou senha inválidos.")
        if password_hasher.check_needs_rehash(user.password_hash):
            with transaction(self.session):
                user.password_hash = password_hasher.hash(payload.password.get_secret_value())
        return self.authenticated(user)
