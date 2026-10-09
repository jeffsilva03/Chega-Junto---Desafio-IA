from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.errors import DatabaseUnavailable
from app.repositories.health import ping_database


def check_database(session: Session) -> None:
    try:
        if not ping_database(session):
            raise DatabaseUnavailable()
    except SQLAlchemyError:
        raise DatabaseUnavailable() from None
