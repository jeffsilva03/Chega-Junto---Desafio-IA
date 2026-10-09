from app.core.errors import not_found
from app.models import AccessibilityPreferences, NotificationPreferences
from app.repositories.preferences import PreferencesRepository
from app.repositories.users import UserRepository
from app.schemas.preferences import AccessibilityPreferencesDTO, NotificationPreferencesDTO
from app.services.common import transaction


class PreferencesService:
    def __init__(self, session, user):
        self.session, self.user = session, user
        self.repository = PreferencesRepository(session)

    def get(self, accessibility=False):
        model, schema = (
            (AccessibilityPreferences, AccessibilityPreferencesDTO)
            if accessibility
            else (NotificationPreferences, NotificationPreferencesDTO)
        )
        row = self.repository.get(model, self.user.id)
        if row is None:
            raise not_found()
        return schema.model_validate(row)

    def put(self, payload, accessibility=False):
        model = AccessibilityPreferences if accessibility else NotificationPreferences
        with transaction(self.session):
            UserRepository(self.session).user(self.user.id, lock=True)
            row = self.repository.save(model, self.user.id, payload.model_dump())
            result = type(payload).model_validate(row)
        return result
