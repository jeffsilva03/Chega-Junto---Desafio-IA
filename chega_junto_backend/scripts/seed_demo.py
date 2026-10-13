"""Fixtures V2 fictícias. Execute após alembic upgrade head; nunca no startup."""

import sys
from datetime import date, datetime
from zoneinfo import ZoneInfo

from alembic.migration import MigrationContext
from sqlalchemy import Connection, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import Settings, load_settings
from app.core.errors import ConfigurationError
from app.database.base import Base
from app.database.session import build_engine
from app.models import (
    AccessibilityPreferences,
    Allergy,
    Appointment,
    AppointmentChecklistItem,
    Facility,
    HealthRecord,
    HealthRecordDocument,
    Medication,
    Notification,
    NotificationPreferences,
    PreVisitReport,
    Reminder,
    User,
    UserProfile,
)

INITIAL_REVISION = "20261012_0004"
DEMO_EMAIL = "maria@example.test"
ZONE = ZoneInfo("America/Sao_Paulo")


class SeedConflict(ValueError):
    pass


def demo_time(day: int, hour: int = 0, minute: int = 0) -> datetime:
    from datetime import UTC

    return datetime(2026, 10, day, hour, minute, tzinfo=ZONE).astimezone(UTC).replace(tzinfo=None)


def populate_demo(session: Session, user_id: int) -> str:
    """Não sobrescrever dados; detectar a fixture por usuário, perfil e consulta inicial."""
    user = session.get(User, user_id)
    if user is not None:
        profile = session.get(UserProfile, user_id)
        appointment = session.get(Appointment, 1)
        if profile and user.email == DEMO_EMAIL and appointment and appointment.user_id == user_id:
            return "already_exists"
        raise SeedConflict("IDs de demonstração ocupados; nenhum dado foi alterado.")
    if any(
        session.execute(select(table).limit(1)).first() for table in Base.metadata.sorted_tables
    ):
        raise SeedConflict("O seed inicial exige banco sem dados de negócio; nenhum dado alterado.")

    session.add(User(id=user_id, timezone="America/Sao_Paulo", email=DEMO_EMAIL))
    session.add_all(
        [
            Facility(
                id=1,
                name="UBS Centro",
                address_text="Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
            ),
            Facility(
                id=2,
                name="Laboratório Municipal",
                address_text="Rua do Cuidado, 45 – Centro, São Paulo – SP",
            ),
        ]
    )
    session.flush()
    session.add(
        UserProfile(
            user_id=user_id,
            full_name="Maria da Silva",
            phone="11999999999",
            sus_card_number="700123456789012",
            birth_date=date(1985, 4, 12),
            cpf="12345678900",
            postcode="01000000",
            street="Av. das Flores",
            number="123",
            complement="Apto 12",
            neighborhood="Centro",
            city="São Paulo",
            state_code="SP",
            emergency_name="João da Silva",
            emergency_relationship="Familiar",
            emergency_phone="11988880000",
        )
    )
    session.add_all(
        [
            Appointment(
                id=1,
                user_id=user_id,
                facility_id=1,
                type="consultation",
                title="Consulta clínica",
                specialty="Clínica geral",
                professional_name="Dra. Ana Beatriz Souza",
                scheduled_at=demo_time(9, 8),
                attendance_status="confirmed",
                attendance_responded_at=demo_time(7, 10),
                instructions=[
                    "Chegue com 15 minutos de antecedência.",
                    "Jejum não é necessário para esta consulta.",
                ],
            ),
            Appointment(
                id=2,
                user_id=user_id,
                facility_id=2,
                type="exam",
                title="Exame de sangue",
                specialty="Exame de sangue",
                professional_name="Equipe do laboratório",
                scheduled_at=demo_time(13, 10),
                instructions=[
                    "Jejum de 8 horas.",
                    "Beba apenas água e evite atividade física intensa.",
                ],
            ),
            Appointment(
                id=3,
                user_id=user_id,
                facility_id=1,
                type="consultation",
                title="Retorno",
                specialty="Clínica geral",
                professional_name="Dra. Ana Beatriz Souza",
                scheduled_at=demo_time(25, 14),
                instructions=["Leve suas anotações e dúvidas."],
            ),
        ]
    )
    session.flush()
    checklist = [
        ("documento", "Documento com foto", True, True, "documents"),
        ("sus", "Cartão do SUS", True, True, "documents"),
        ("exames", "Comprovantes ou exames anteriores", False, True, "documents"),
        ("antecedencia", "Chegar 15 minutos antes", False, False, "reminders"),
        ("duvidas", "Separar dúvidas e sintomas", False, True, "reminders"),
        ("medicamentos", "Levar lista de medicamentos, se usar", False, False, "conversation"),
        ("sintomas", "Contar o que deseja conversar", False, False, "conversation"),
    ]
    for position, (key, title, required, completed, section) in enumerate(checklist):
        session.add(
            AppointmentChecklistItem(
                appointment_id=1,
                item_key=key,
                title=title,
                is_required=required,
                is_completed=completed,
                section=section,
                position=position,
            )
        )
    session.add(
        Reminder(
            id=1,
            user_id=user_id,
            title="Levar documento com foto",
            remind_at=demo_time(9, 7, 30),
        )
    )
    session.add(
        PreVisitReport(
            id=1,
            appointment_id=1,
            original_text=(
                "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas "
                "durante a consulta."
            ),
            content_revision=1,
            updated_at=demo_time(7, 10),
        )
    )
    # Original inicial existe; ainda não há organização, revisão ou perguntas nesta fixture.
    medications = [
        ("Losartana", "50 mg • 1x ao dia"),
        ("Metformina", "850 mg • 2x ao dia"),
        ("Omeprazol", "20 mg • pela manhã"),
        ("Vitamina D", "1 cápsula por semana"),
    ]
    allergies = [
        ("Dipirona", "Reação: coceira"),
        ("Frutos do mar", "Reação: inchaço"),
        ("Látex", "Reação: irritação na pele"),
    ]
    for model, items in [(Medication, medications), (Allergy, allergies)]:
        for position, (name, details) in enumerate(items):
            session.add(model(user_id=user_id, name=name, details=details, position=position))
    session.add_all(
        [
            NotificationPreferences(user_id=user_id),
            AccessibilityPreferences(user_id=user_id),
        ]
    )
    history = [
        HealthRecord(
            id=1,
            user_id=user_id,
            type="consultation",
            occurred_at=demo_time(6, 8),
            title="Clínica geral",
            subtitle="UBS Centro – Dra. Ana Beatriz Souza",
            professional_text="Dra. Ana Beatriz Souza",
            facility_text="UBS Centro",
            reason="Conversa sobre rotina e dúvidas anotadas para o atendimento.",
            summary=(
                "Registro fictício de atendimento anterior, distinto da consulta futura de 9/10."
            ),
            notes=[
                "Anotar o que deseja conversar no próximo atendimento.",
                "Guardar os documentos recebidos.",
            ],
        ),
        HealthRecord(
            id=2,
            user_id=user_id,
            type="exam",
            occurred_at=demo_time(4, 10),
            title="Exame de sangue (hemograma)",
            subtitle="Laboratório Municipal",
            facility_text="Laboratório Municipal",
            reason="Registro de exame anterior.",
            summary="Exame fictício, sem interpretação pelo aplicativo.",
        ),
        HealthRecord(
            id=3,
            user_id=user_id,
            type="medication",
            occurred_at=demo_time(3, 9),
            title="Losartana 50 mg",
            subtitle="Informação cadastrada",
            reason="Registro pessoal de medicamento.",
            summary="Exemplo fictício informado no cadastro, não recomendação do aplicativo.",
        ),
        HealthRecord(
            id=4,
            user_id=user_id,
            type="allergy",
            occurred_at=demo_time(2, 11),
            title="Alergia a Dipirona",
            subtitle="Reação informada: coceira",
            reason="Informação pessoal cadastrada.",
            summary="Registro fictício fornecido pelo titular, sem avaliação pelo aplicativo.",
        ),
        HealthRecord(
            id=5,
            user_id=user_id,
            type="diagnosis",
            occurred_at=demo_time(1, 14),
            title="Hipertensão arterial",
            subtitle="Informação histórica já registrada",
            reason="Diagnóstico preexistente informado no cadastro fictício.",
            summary=(
                "Informação histórica preexistente; Chega Junto e IA não produzem diagnósticos."
            ),
        ),
        HealthRecord(
            id=6,
            user_id=user_id,
            type="exam",
            occurred_at=demo_time(1, 8),
            title="Raio-X de tórax",
            subtitle="Laboratório Municipal",
            facility_text="Laboratório Municipal",
            reason="Registro de exame anterior.",
            summary="Registro fictício sem laudo anexado ou interpretação de exame.",
        ),
    ]
    session.add_all(history)
    session.flush()
    session.add_all(
        [
            HealthRecordDocument(
                health_record_id=1,
                title="Anotações do atendimento",
                position=0,
                content_text="Exemplo fictício: atendimento em 6/10/2026. Anotações pessoais.",
            ),
            HealthRecordDocument(
                health_record_id=1,
                title="Documentos do atendimento",
                position=1,
                content_text="Exemplo fictício, sem receita, laudo ou encaminhamento válido.",
            ),
        ]
    )
    notifications = [
        (
            "consultation",
            "Lembrete de consulta",
            "Consulta clínica em 9/10 às 08:00 na UBS Centro.",
            7,
            7,
            0,
            "reminder",
            "appointments",
            "appointment",
            1,
            None,
            True,
        ),
        (
            "exam",
            "Lembrete de exame",
            "Exame de sangue em 13/10. Confira o preparo cadastrado.",
            7,
            6,
            30,
            "exam",
            "exams",
            "appointment",
            2,
            None,
            True,
        ),
        (
            "confirmation",
            "Presença registrada",
            "Sua resposta para Clínica geral: Vou comparecer.",
            6,
            15,
            20,
            "consultation",
            "confirmations",
            "appointment",
            1,
            None,
            False,
        ),
        (
            "medications",
            "Seus medicamentos",
            "Confira as informações cadastradas por você.",
            6,
            12,
            0,
            "reminder",
            "medications",
            "medications",
            None,
            None,
            False,
        ),
        (
            "documents",
            "Documentos do histórico",
            "Veja os exemplos dos seus registros.",
            6,
            10,
            15,
            "system",
            "documents",
            "history",
            None,
            1,
            False,
        ),
        (
            "earlier",
            "Exame na Agenda",
            "Exame de sangue está na Agenda. Confira data e local.",
            5,
            9,
            0,
            "exam",
            "exams",
            "appointment",
            2,
            None,
            False,
        ),
    ]
    for (
        key,
        title,
        message,
        day,
        hour,
        minute,
        category,
        pref,
        destination,
        appointment_id,
        record_id,
        unread,
    ) in notifications:
        published = demo_time(day, hour, minute)
        session.add(
            Notification(
                user_id=user_id,
                source_key=f"demo-{key}",
                title=title,
                message=message,
                published_at=published,
                category=category,
                preference_key=pref,
                destination=destination,
                appointment_id=appointment_id,
                health_record_id=record_id,
                read_at=None if unread else published,
            )
        )
    session.flush()
    return "created"


def seed_connection(connection: Connection, settings: Settings) -> str:
    if MigrationContext.configure(connection).get_current_revision() != INITIAL_REVISION:
        raise SeedConflict("Execute alembic upgrade head antes do seed inicial.")
    connection.commit()
    locked = connection.scalar(text("SELECT GET_LOCK('chega_junto_seed_demo', 10)"))
    connection.commit()
    if locked != 1:
        raise SeedConflict("Outra execução do seed está em andamento.")
    try:
        with Session(bind=connection) as session, session.begin():
            return populate_demo(session, settings.demo_user_id)
    finally:
        connection.execute(text("SELECT RELEASE_LOCK('chega_junto_seed_demo')"))
        connection.commit()


def main() -> int:
    engine = None
    try:
        settings = load_settings()
        if not settings.demo_mode or settings.app_env not in {"development", "demo"}:
            raise SeedConflict("Seed permitido somente em development/demo com DEMO_MODE=true.")
        engine = build_engine(settings)
        with engine.connect() as connection:
            result = seed_connection(connection, settings)
        print(
            "Fixtures fictícias criadas."
            if result == "created"
            else "Fixture existente detectada; nenhum dado foi sobrescrito."
        )
        return 0
    except SeedConflict as error:
        print(str(error), file=sys.stderr)
        return 1
    except (ConfigurationError, SQLAlchemyError, OSError):
        print(
            "Seed não executado. Confira conexão, migration e TLS no ambiente local.",
            file=sys.stderr,
        )
        return 1
    finally:
        if engine is not None:
            engine.dispose()


if __name__ == "__main__":
    raise SystemExit(main())
