"""Erros seguros: não incluir valores de configuração ou exceções do driver."""


class ConfigurationError(RuntimeError):
    def __init__(self) -> None:
        super().__init__("Configuração inválida. Confira o .env local e o README do backend.")


class DatabaseUnavailable(RuntimeError):
    def __init__(self) -> None:
        super().__init__("Banco indisponível.")


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str) -> None:
        self.status, self.code, self.message = status, code, message
        super().__init__(message)


def not_found() -> ApiError:
    return ApiError(404, "resource_not_found", "Recurso não encontrado.")


def conflict() -> ApiError:
    return ApiError(409, "revision_conflict", "O relato mudou. Carregue a versão atual.")
