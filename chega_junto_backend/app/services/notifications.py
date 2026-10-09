from app.core.errors import not_found
from app.database.base import utc_now
from app.models import NotificationPreferences
from app.repositories.notifications import NotificationRepository
from app.repositories.preferences import PreferencesRepository
from app.schemas.notifications import NotificationPage, NotificationRead
from app.services.common import pagination, transaction


def notification_dto(row):
    return NotificationRead(
        **{
            field: getattr(row, field)
            for field in NotificationRead.model_fields
            if field != "is_read"
        },
        is_read=row.read_at is not None,
    )


class NotificationService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = NotificationRepository(session)

    def list(self, filters):
        preferences = PreferencesRepository(self.session).get(NotificationPreferences, self.user.id)
        keys = []
        if preferences and preferences.active and preferences.in_app:
            keys = [
                key
                for key in (
                    "appointments",
                    "exams",
                    "medications",
                    "documents",
                    "confirmations",
                    "system",
                )
                if getattr(preferences, key)
            ]
        rows, total, unread_count = self.repository.list(
            self.user.id, filters, filters.bounds(self.user.timezone), keys
        )
        return NotificationPage(
            items=[notification_dto(row[0]) for row in rows],
            pagination=pagination(filters, total),
            unread_count=unread_count,
        )

    def mark_read(self, notification_id):
        with transaction(self.session):
            row = self.repository.get(self.user.id, notification_id, lock=True)
            if row is None:
                raise not_found()
            if row.read_at is None:
                row.read_at = utc_now()
            self.session.flush()
            result = notification_dto(row)
        return result

    def attendance(self, appointment):
        # O lock do atendimento serializa o upsert e reaproveita o cartão inicial do seed.
        key = f"attendance:{appointment.id}"
        row = self.repository.source(self.user.id, key) or self.repository.attendance_card(
            self.user.id, appointment.id
        )
        label = {
            "confirmed": "Vou comparecer",
            "undecided": "Ainda não sei",
            "unable": "Não consigo ir",
        }[appointment.attendance_status]
        message = f"Sua resposta para {appointment.specialty}: {label}. Registro no aplicativo."
        if row is None:
            self.repository.add(
                user_id=self.user.id,
                source_key=key,
                title="Presença registrada",
                message=message,
                published_at=utc_now(),
                category="consultation",
                preference_key="confirmations",
                destination="appointment",
                appointment_id=appointment.id,
            )
        else:
            row.title, row.message = "Presença registrada", message
            # read_at e published_at não são reabertos em atualização de conteúdo.

    def reminder(self, reminder):
        if reminder.appointment_id is None:
            return  # Como na V2, lembrete sem consulta não tem cartão com destino inventado.
        self.repository.add(
            user_id=self.user.id,
            source_key=f"reminder:{reminder.id}",
            title="Lembrete salvo",
            message=reminder.title,
            published_at=utc_now(),
            category="reminder",
            preference_key="appointments",
            destination="appointment",
            appointment_id=reminder.appointment_id,
            reminder_id=reminder.id,
        )
