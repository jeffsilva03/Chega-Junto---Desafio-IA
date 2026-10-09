from datetime import date

from app.schemas.appointments import AppointmentRead, AttendanceRead, ChecklistRead
from app.schemas.common import DTO, DatabaseId
from app.schemas.reports import ReportState


class Progress(DTO):
    documents_done: bool
    attendance_done: bool
    report_done: bool
    final_done: bool
    completed_count: int
    total_count: int = 4
    fraction: float
    percentage: int


class ChecklistSummary(DTO):
    required_count: int
    required_completed_count: int
    fraction: float
    percentage: int


class ChecklistResponse(ChecklistSummary):
    items: list[ChecklistRead]
    progress: Progress


class PreparationRead(DTO):
    appointment: AppointmentRead
    progress: Progress
    checklist: ChecklistSummary
    attendance: AttendanceRead
    report: ReportState


class UserSummary(DTO):
    id: DatabaseId
    full_name: str
    first_name: str
    timezone: str


class OverviewRead(DTO):
    user: UserSummary
    reference_date: date
    next_appointment: AppointmentRead | None
    preparation: PreparationRead | None
