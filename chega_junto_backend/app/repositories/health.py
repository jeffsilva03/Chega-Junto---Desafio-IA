from sqlalchemy import text
from sqlalchemy.orm import Session


def ping_database(session: Session) -> bool:
    return session.execute(text("SELECT 1")).scalar_one() == 1
