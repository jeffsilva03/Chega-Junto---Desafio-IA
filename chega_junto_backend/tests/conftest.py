import os
import secrets

import pytest

from app.core.config import Settings


@pytest.fixture(autouse=True)
def isolate_environment(monkeypatch):
    # Nenhum teste herda credenciais reais do desenvolvedor.
    # Arquivos de configuração de teste continuam possíveis via _env_file explícito.
    monkeypatch.setitem(Settings.model_config, "env_file", None)
    for key in os.environ:
        if key.startswith(("DATABASE_", "APP_", "DEMO_", "CORS_", "AUTH_")) or key == "LOG_LEVEL":
            monkeypatch.delenv(key, raising=False)

    monkeypatch.setenv("AUTH_SECRET_KEY", secrets.token_urlsafe(32))


@pytest.fixture
def api_database():
    from fastapi.testclient import TestClient
    from sqlalchemy.orm import Session, sessionmaker

    from app.database.base import Base
    from app.database.session import Database
    from app.main import create_app
    from app.models import (
        Allergy,
        Appointment,
        AppointmentChecklistItem,
        Facility,
        HealthRecord,
        Medication,
        Notification,
        PreVisitReport,
        ReportQuestion,
        ReportSection,
        User,
    )
    from scripts.seed_demo import demo_time, populate_demo
    from tests.isolated_database import isolated_engine

    engine = isolated_engine()
    Base.metadata.create_all(engine)  # Exclusivamente no banco efêmero de teste.
    with Session(engine) as session, session.begin():
        populate_demo(session, 1)
        session.add_all(
            [
                User(id=2),
                Facility(
                    id=3, name="Unidade privada do outro titular", address_text="Endereço fictício"
                ),
            ]
        )
        session.flush()
        session.add_all(
            [
                Appointment(
                    id=99,
                    user_id=2,
                    facility_id=3,
                    type="exam",
                    title="Privado",
                    specialty="Outro",
                    professional_name="Equipe",
                    scheduled_at=demo_time(20),
                ),
                Medication(id=99, user_id=2, name="Outro", details="Privado", position=0),
                Allergy(id=99, user_id=2, name="Outra", details="Privado", position=0),
                HealthRecord(
                    id=99,
                    user_id=2,
                    type="exam",
                    occurred_at=demo_time(2),
                    title="Privado",
                    subtitle="Privado",
                    reason="Privado",
                    summary="Privado",
                ),
            ]
        )
        session.flush()
        session.add_all(
            [
                AppointmentChecklistItem(
                    id=99,
                    appointment_id=99,
                    item_key="private",
                    title="Privado",
                    section="documents",
                    position=0,
                ),
                PreVisitReport(
                    id=99, appointment_id=99, original_text="Privado", content_revision=1
                ),
                Notification(
                    id=99,
                    user_id=2,
                    source_key="private",
                    title="Privado",
                    message="Privado",
                    published_at=demo_time(9),
                    category="exam",
                    preference_key="exams",
                    destination="appointment",
                    appointment_id=99,
                ),
            ]
        )
        session.flush()
        session.add_all(
            [
                ReportSection(
                    id=99,
                    report_id=99,
                    section_key="reason",
                    title="Privado",
                    text="Privado",
                    position=0,
                ),
                ReportQuestion(id=99, report_id=99, text="Privado", is_selected=True, position=0),
            ]
        )
    settings = Settings(_env_file=None, auth_mode="demo")
    database = Database(settings)
    database.engine = engine
    database.session_factory = sessionmaker(engine, expire_on_commit=False)
    application = create_app(settings, database)
    with TestClient(application) as client:
        yield client, database, application
    engine.dispose()


@pytest.fixture
def client(api_database):
    return api_database[0]
