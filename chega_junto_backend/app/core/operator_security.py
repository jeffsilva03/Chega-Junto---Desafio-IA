"""Domínio criptográfico próprio; nunca aceita tokens de paciente."""

import re
from datetime import UTC, datetime, timedelta

import jwt

from app.core.security import ALGORITHM, unauthorized

ISSUER = "chega-junto-operator"


def signing_key(settings):
    settings.validate_operator_auth()
    if not settings.operator_portal_enabled:
        raise unauthorized()
    return settings.operator_auth_secret_key.get_secret_value()


def create_operator_token(settings, operator_id):
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(operator_id),
            "iat": now,
            "exp": now + timedelta(minutes=settings.operator_auth_access_token_expire_minutes),
            "iss": ISSUER,
            "actor_type": "operator",
        },
        signing_key(settings),
        algorithm=ALGORITHM,
    )


def operator_subject(settings, token):
    try:
        claims = jwt.decode(
            token,
            signing_key(settings),
            algorithms=[ALGORITHM],
            issuer=ISSUER,
            options={"require": ["sub", "iat", "exp", "iss", "actor_type"]},
        )
        subject = claims["sub"]
        if (
            claims["actor_type"] != "operator"
            or not isinstance(subject, str)
            or not re.fullmatch(r"[1-9][0-9]{0,19}", subject)
            or int(subject) > 18446744073709551615
        ):
            raise ValueError()
        return int(subject)
    except (jwt.InvalidTokenError, ValueError, TypeError):
        raise unauthorized() from None
