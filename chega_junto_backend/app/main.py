import logging
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from urllib.parse import urlsplit

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError, InterfaceError, OperationalError, SQLAlchemyError
from sqlalchemy.exc import TimeoutError as PoolTimeout
from sqlalchemy.orm.exc import StaleDataError
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.responses import Response

from app.api.dependencies import DatabaseSession
from app.api.v1.router import router as v1_router
from app.core.config import Settings, load_settings
from app.core.errors import ApiError, DatabaseUnavailable
from app.database.session import Database
from app.schemas.health import HealthResponse
from app.services.health import check_database

logger = logging.getLogger("chega_junto")


def error_response(status, code, message):
    return JSONResponse(status_code=status, content={"error": {"code": code, "message": message}})


def create_app(settings: Settings | None = None, database: Database | None = None) -> FastAPI:
    settings = settings or load_settings()

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        settings.validate_auth()
        settings.validate_operator_auth()
        application.state.database = database if database is not None else Database(settings)
        try:
            yield
        finally:
            if database is None:
                application.state.database.dispose()

    application = FastAPI(
        title="Chega Junto — Backend V3",
        version="0.1.0",
        debug=False,
        lifespan=lifespan,
    )
    application.state.settings = settings
    logger.setLevel(settings.log_level)

    @application.middleware("http")
    async def local_simulator(request: Request, call_next):
        if request.url.path.startswith("/api/v1/simulator"):
            if not settings.simulator_mode or settings.app_env == "production":
                return error_response(404, "resource_not_found", "Recurso não encontrado.")
            host = urlsplit("//" + request.headers.get("host", "")).hostname
            origin = request.headers.get("origin")
            if (
                request.client is None
                or request.client.host not in {"127.0.0.1", "::1"}
                or host not in {"127.0.0.1", "localhost", "::1"}
                or (origin is not None and origin not in settings.simulator_allowed_origins)
                or request.headers.get("X-Simulator-Request") != "local"
            ):
                return error_response(
                    403, "simulator_local_only", "Simulador disponível somente no PC local."
                )
        return await call_next(request)

    @application.middleware("http")
    async def safe_errors(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        try:
            return await call_next(request)
        except Exception:
            # Não imprimir traceback do driver/URL ou conteúdo de request nos logs.
            logger.error("Falha interna na requisição.")
            if request.url.path == "/health":
                return JSONResponse(status_code=500, content={"detail": "Erro interno."})
            return error_response(500, "internal_error", "Erro interno.")

    # CORS envolve também a resposta sanitizada de erro inesperado.
    application.add_middleware(
        CORSMiddleware,
        allow_origins=list(
            dict.fromkeys(
                settings.cors_allowed_origins
                + (settings.simulator_allowed_origins if settings.simulator_mode else [])
            )
        ),
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Content-Type", "Accept", "Authorization", "X-Simulator-Request"],
    )

    @application.exception_handler(DatabaseUnavailable)
    async def database_unavailable(_request: Request, _error: DatabaseUnavailable) -> JSONResponse:
        if _request.url.path != "/health":
            return error_response(
                503, "dependency_unavailable", "Serviço temporariamente indisponível."
            )
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable", "database": "unavailable"},
        )

    @application.exception_handler(ApiError)
    async def api_error(_request: Request, error: ApiError):
        response = error_response(error.status, error.code, error.message)
        if error.status == 401:
            response.headers["WWW-Authenticate"] = "Bearer"
        return response

    @application.exception_handler(RequestValidationError)
    async def validation_error(_request: Request, _error: RequestValidationError):
        return error_response(
            422, "validation_error", "Dados inválidos. Confira os campos e limites do contrato."
        )

    @application.exception_handler(StarletteHTTPException)
    async def http_error(_request: Request, error: StarletteHTTPException):
        code = "method_not_allowed" if error.status_code == 405 else "resource_not_found"
        return error_response(
            error.status_code,
            code,
            "Método não permitido." if error.status_code == 405 else "Recurso não encontrado.",
        )

    @application.exception_handler(SQLAlchemyError)
    async def database_error(_request: Request, error: SQLAlchemyError):
        if isinstance(error, (OperationalError, InterfaceError, PoolTimeout)):
            return error_response(
                503, "dependency_unavailable", "Serviço temporariamente indisponível."
            )
        if isinstance(error, (IntegrityError, StaleDataError)):
            return error_response(
                409, "state_conflict", "Conflito ao salvar. Recarregue o recurso."
            )
        return error_response(500, "internal_error", "Erro interno.")

    @application.exception_handler(StaleDataError)
    async def stale_error(_request: Request, _error: StaleDataError):
        return error_response(409, "revision_conflict", "O relato mudou. Carregue a versão atual.")

    @application.get(
        "/health",
        response_model=HealthResponse,
        tags=["Infraestrutura"],
        responses={503: {"model": HealthResponse, "description": "Banco indisponível"}},
    )
    def health(session: DatabaseSession) -> HealthResponse:
        check_database(session)
        return HealthResponse(status="ok", database="ok")

    application.include_router(v1_router, prefix="/api/v1")
    if settings.operator_portal_enabled:
        from app.api.v1.operator import router as operator_router

        application.include_router(operator_router, prefix="/api/v1")
    if settings.simulator_mode:
        from app.api.v1.simulator import router as simulator_router

        application.include_router(simulator_router, prefix="/api/v1")
    return application


app = create_app()
