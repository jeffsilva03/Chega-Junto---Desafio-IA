from typing import Annotated

from fastapi import APIRouter, Depends, File, Request, UploadFile

from app.api.dependencies import AuthenticatedUser, DatabaseSession
from app.core.errors import ApiError
from app.schemas.ai import OrganizationRequest, OrganizationResponse, TranscriptionResponse
from app.schemas.clarifications import ClarificationAnswer, ClarificationNext
from app.schemas.common import DatabaseId
from app.schemas.reports import ReportRead
from app.services.ai_provider import AiProvider
from app.services.clarifications import ClarificationService
from app.services.report_ai import AUDIO_MAX_BYTES, ReportAiService, audio_format

router = APIRouter(prefix="/appointments/{appointment_id}/report", tags=["Report AI"])


def get_ai_provider(request: Request) -> AiProvider:
    return request.app.state.ai_provider


Provider = Annotated[AiProvider, Depends(get_ai_provider)]


@router.post("/clarifications/next", response_model=ClarificationNext)
def next_clarification(
    appointment_id: DatabaseId,
    session: DatabaseSession,
    user: AuthenticatedUser,
    request: Request,
    provider: Provider,
):
    return ClarificationService(session, user, request.app.state.settings, provider).next(
        appointment_id
    )


@router.put("/clarifications/{clarification_id}", response_model=ReportRead)
def answer_clarification(
    appointment_id: DatabaseId,
    clarification_id: DatabaseId,
    payload: ClarificationAnswer,
    session: DatabaseSession,
    user: AuthenticatedUser,
    request: Request,
    provider: Provider,
):
    return ClarificationService(session, user, request.app.state.settings, provider).answer(
        appointment_id, clarification_id, payload
    )


@router.post("/clarifications/skip", response_model=ReportRead)
def skip_clarifications(
    appointment_id: DatabaseId,
    session: DatabaseSession,
    user: AuthenticatedUser,
    request: Request,
    provider: Provider,
):
    return ClarificationService(session, user, request.app.state.settings, provider).skip(
        appointment_id
    )


@router.post(
    "/organization",
    response_model=OrganizationResponse,
    summary="Organizar relato sem salvar automaticamente",
)
def organization(
    appointment_id: DatabaseId,
    payload: OrganizationRequest,
    session: DatabaseSession,
    user: AuthenticatedUser,
    request: Request,
    provider: Provider,
):
    return ReportAiService(session, user, request.app.state.settings, provider).organize(
        appointment_id, payload.original_text
    )


@router.post(
    "/transcription",
    response_model=TranscriptionResponse,
    summary="Transcrever áudio temporário para revisão humana",
)
def transcription(
    appointment_id: DatabaseId,
    session: DatabaseSession,
    user: AuthenticatedUser,
    request: Request,
    provider: Provider,
    file: Annotated[UploadFile, File()],
):
    try:
        content = file.file.read(AUDIO_MAX_BYTES + 1)
        if len(content) > AUDIO_MAX_BYTES:
            raise ApiError(413, "audio_too_large", "O áudio deve ter no máximo 10 MB.")
        extension, mime = audio_format(file.filename, file.content_type, content)
        return ReportAiService(session, user, request.app.state.settings, provider).transcribe(
            appointment_id, content, extension, mime
        )
    finally:
        file.file.close()
