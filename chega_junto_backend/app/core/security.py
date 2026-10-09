"""Credenciais e tokens nunca são incluídos em logs ou exceções públicas."""

import re
import secrets
from datetime import UTC, datetime, timedelta
from functools import lru_cache

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.errors import ApiError

ALGORITHM = "HS256"
ISSUER = "chega-junto"
password_hasher = PasswordHasher()


def unauthorized(code="invalid_token", message="Sua sessão expirou. Entre novamente."):
    return ApiError(401, code, message)


@lru_cache(maxsize=1)
def dummy_hash():
    return password_hasher.hash(secrets.token_urlsafe(32))


def verify_password(encoded, password):
    try:
        return password_hasher.verify(encoded or dummy_hash(), password)
    except (VerificationError, InvalidHashError):
        return False


def signing_key(settings):
    settings.validate_auth()
    if (
        settings.auth_secret_key is None
        or len(settings.auth_secret_key.get_secret_value().encode()) < 32
    ):
        raise ApiError(503, "auth_not_configured", "Autenticação indisponível.")
    return settings.auth_secret_key.get_secret_value()


def create_token(settings, user_id):
    key = signing_key(settings)
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(user_id),
            "iat": now,
            "exp": now + timedelta(minutes=settings.auth_access_token_expire_minutes),
            "iss": ISSUER,
        },
        key,
        algorithm=ALGORITHM,
    )


def token_subject(settings, token):
    key = signing_key(settings)
    try:
        claims = jwt.decode(
            token,
            key,
            algorithms=[ALGORITHM],
            issuer=ISSUER,
            options={"require": ["sub", "iat", "exp", "iss"]},
        )
        subject = claims["sub"]
        if not isinstance(subject, str) or not re.fullmatch(r"[1-9][0-9]{0,19}", subject):
            raise ValueError()
        identifier = int(subject)
        if identifier > 18446744073709551615:
            raise ValueError()
        return identifier
    except (jwt.InvalidTokenError, ValueError, TypeError):
        raise unauthorized() from None
