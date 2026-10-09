from dataclasses import dataclass

from app.core.errors import ApiError
from app.core.security import token_subject, unauthorized
from app.repositories.users import UserRepository


@dataclass(frozen=True)
class UserContext:
    id: int
    timezone: str


def resolve_current_user(session, settings, token=None, *, allow_demo=True):
    if token is not None:
        user = UserRepository(session).user(token_subject(settings, token))
        if user is None or not user.is_active:
            raise unauthorized()
        return UserContext(user.id, user.timezone)
    if settings.auth_mode != "demo" or not allow_demo:
        raise unauthorized()
    if not settings.demo_mode:
        raise ApiError(503, "demo_disabled", "O contexto de demonstração está desativado.")
    user = UserRepository(session).user(settings.demo_user_id)
    if user is None:
        raise ApiError(503, "demo_user_unavailable", "Usuário de demonstração indisponível.")
    return UserContext(user.id, user.timezone)
