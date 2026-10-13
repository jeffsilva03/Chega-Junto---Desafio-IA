from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.errors import ApiError
from app.core.operator_security import create_operator_token, operator_subject
from app.core.security import password_hasher, unauthorized, verify_password
from app.models import Operator
from app.schemas.operator import OperatorIdentity, OperatorSession
from app.services.common import transaction


def create_operator(session, payload):
    """Somente script administrativo; nenhuma rota HTTP de cadastro."""
    try:
        with transaction(session):
            if session.scalar(select(Operator.id).where(Operator.email == payload.email)):
                raise ApiError(409, "operator_exists", "Operador já cadastrado.")
            operator = Operator(
                full_name=payload.full_name,
                email=payload.email,
                password_hash=password_hasher.hash(payload.password.get_secret_value()),
            )
            session.add(operator)
            session.flush()
            identity = OperatorIdentity.model_validate(operator)
        return identity
    except IntegrityError:
        raise ApiError(
            409, "operator_exists", "Operador já cadastrado ou conflito de cadastro."
        ) from None


class OperatorAuthService:
    def __init__(self, session, settings):
        self.session, self.settings = session, settings

    def resolve(self, token):
        if token is None:
            raise unauthorized()
        operator = (
            self.session.execute(
                select(Operator.id, Operator.full_name, Operator.email, Operator.is_active).where(
                    Operator.id == operator_subject(self.settings, token)
                )
            )
            .mappings()
            .first()
        )
        if operator is None or not operator["is_active"]:
            raise unauthorized()
        return OperatorIdentity.model_validate(
            {key: operator[key] for key in ("id", "full_name", "email")}
        )

    def login(self, payload):
        operator = self.session.scalar(select(Operator).where(Operator.email == payload.email))
        verified = verify_password(
            operator.password_hash if operator else None, payload.password.get_secret_value()
        )
        if operator is None or not verified or not operator.is_active:
            raise unauthorized("invalid_credentials", "E-mail ou senha inválidos.")
        if password_hasher.check_needs_rehash(operator.password_hash):
            with transaction(self.session):
                operator.password_hash = password_hasher.hash(payload.password.get_secret_value())
        return OperatorSession(
            access_token=create_operator_token(self.settings, operator.id),
            operator=OperatorIdentity.model_validate(operator),
        )
