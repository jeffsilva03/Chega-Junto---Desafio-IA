from typing import Literal

from pydantic import StrictBool

from app.schemas.common import DTO


class NotificationPreferencesDTO(DTO):
    active: StrictBool
    appointments: StrictBool
    exams: StrictBool
    medications: StrictBool
    documents: StrictBool
    confirmations: StrictBool
    system: StrictBool
    in_app: StrictBool


class AccessibilityPreferencesDTO(DTO):
    text_size: Literal["small", "medium", "large", "extra_large"]
    appearance: Literal["light", "dark", "system"]
    high_contrast: StrictBool
    speech: StrictBool
    descriptions: StrictBool
    simple_language: StrictBool
    haptics: StrictBool
    reduce_motion: StrictBool
