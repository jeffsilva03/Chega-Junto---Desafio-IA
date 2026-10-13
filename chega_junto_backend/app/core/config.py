"""Configuração compartilhada por aplicação, Alembic e seed."""

from pathlib import Path
from typing import Literal, Self
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, SecretStr, ValidationError, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict, SettingsError
from sqlalchemy import URL

from app.core.errors import ConfigurationError

BACKEND_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_ROOT / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="forbid",
        hide_input_in_errors=True,
    )

    app_env: Literal["development", "test", "demo", "production"] = "development"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    database_host: str | None = Field(default=None, repr=False)
    database_port: int | None = Field(default=None, ge=1, le=65535)
    database_name: str | None = Field(default=None, repr=False)
    database_user: str | None = Field(default=None, repr=False)
    database_password: SecretStr | None = Field(default=None, repr=False, exclude=True)
    database_ssl_mode: Literal["VERIFY_IDENTITY"] = "VERIFY_IDENTITY"
    database_ssl_ca_path: Path | None = Field(default=None, repr=False)
    database_connect_timeout: int = Field(default=5, ge=1, le=30)
    database_read_timeout: int = Field(default=5, ge=1, le=30)
    database_write_timeout: int = Field(default=5, ge=1, le=30)
    database_pool_size: int = Field(default=3, ge=1, le=20)
    database_max_overflow: int = Field(default=2, ge=0, le=20)
    database_pool_timeout: int = Field(default=10, ge=1, le=60)
    database_pool_pre_ping: bool = True
    database_pool_recycle: int = Field(default=300, ge=1, le=3600)
    cors_allowed_origins: list[str] = Field(default_factory=list)
    app_timezone: str = "America/Sao_Paulo"
    demo_mode: bool = True
    simulator_mode: bool = False
    simulator_allowed_origins: list[str] = Field(default_factory=lambda: ["http://127.0.0.1:5500"])
    demo_user_id: int = Field(default=1, ge=1, le=18446744073709551615)
    auth_mode: Literal["jwt", "demo"] = "jwt"
    auth_secret_key: SecretStr | None = Field(default=None, repr=False, exclude=True)
    auth_access_token_expire_minutes: int = Field(default=60, ge=1, le=1440)
    operator_portal_enabled: bool = False
    operator_auth_secret_key: SecretStr | None = Field(default=None, repr=False, exclude=True)
    operator_auth_access_token_expire_minutes: int = Field(default=60, ge=1, le=1440)
    ai_enabled: bool = False
    openai_api_key: SecretStr | None = Field(default=None, repr=False, exclude=True)
    openai_text_model: str = Field(default="", max_length=200)
    openai_transcription_model: str = Field(default="", max_length=200)
    openai_timeout_seconds: int = Field(default=45, ge=10, le=120)
    ai_organize_user_daily_limit: int = Field(default=10, ge=0, le=1000)
    ai_organize_global_daily_limit: int = Field(default=50, ge=0, le=10000)
    ai_transcribe_user_daily_limit: int = Field(default=3, ge=0, le=1000)
    ai_transcribe_global_daily_limit: int = Field(default=10, ge=0, le=10000)

    def validate_ai(self) -> None:
        if self.ai_enabled and (
            self.openai_api_key is None
            or not self.openai_api_key.get_secret_value().strip()
            or not self.openai_text_model.strip()
            or not self.openai_transcription_model.strip()
        ):
            raise ConfigurationError()

    def validate_operator_auth(self) -> None:
        if not self.operator_portal_enabled:
            return
        key = self.operator_auth_secret_key
        if key is None or len(key.get_secret_value().encode()) < 32:
            raise ConfigurationError()
        if (
            self.auth_secret_key
            and key.get_secret_value() == self.auth_secret_key.get_secret_value()
        ):
            raise ConfigurationError()

    def validate_auth(self) -> None:
        from app.core.errors import ConfigurationError

        if self.auth_mode == "demo":
            if self.app_env == "production":
                raise ConfigurationError()
            return
        if (
            self.auth_secret_key is None
            or len(self.auth_secret_key.get_secret_value().encode()) < 32
        ):
            raise ConfigurationError()

    @field_validator(
        "database_host",
        "database_port",
        "database_name",
        "database_user",
        "database_password",
        "database_ssl_ca_path",
        mode="before",
    )
    @classmethod
    def blank_database_value(cls, value: object) -> object:
        return None if isinstance(value, str) and not value.strip() else value

    @field_validator("app_timezone")
    @classmethod
    def valid_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError("APP_TIMEZONE deve ser uma zona IANA válida") from None
        return value

    @field_validator("cors_allowed_origins", "simulator_allowed_origins")
    @classmethod
    def valid_origins(cls, values: list[str]) -> list[str]:
        for value in values:
            try:
                parsed = urlsplit(value)
                valid = (
                    parsed.scheme in {"http", "https"}
                    and parsed.hostname
                    and not parsed.username
                    and not parsed.password
                    and not parsed.path
                    and not parsed.query
                    and not parsed.fragment
                    and "*" not in value
                )
                _ = parsed.port
            except ValueError:
                valid = False
            if not valid:
                raise ValueError("CORS exige origens HTTP(S) exatas, sem path ou wildcard")
        return list(dict.fromkeys(values))

    @model_validator(mode="after")
    def complete_database_configuration(self) -> Self:
        self.validate_operator_auth()
        if self.simulator_mode and self.app_env == "production":
            raise ValueError("Simulador proibido em produção")
        for origin in self.simulator_allowed_origins:
            if urlsplit(origin).hostname not in {"127.0.0.1", "localhost", "::1"}:
                raise ValueError("Simulador exige origens de loopback")
        fields = (
            self.database_host,
            self.database_port,
            self.database_name,
            self.database_user,
            self.database_password,
            self.database_ssl_ca_path,
        )
        if any(value is not None for value in fields):
            if not all(value is not None for value in fields):
                raise ValueError("Configuração MySQL parcial; preencher conexão, senha e CA")
            if not self.database_password.get_secret_value():
                raise ValueError("Senha MySQL vazia")
            ca = self.database_ssl_ca_path
            if not ca.is_absolute():
                ca = BACKEND_ROOT / ca
            if not ca.is_file():
                raise ValueError("Certificado CA não encontrado")
            self.database_ssl_ca_path = ca.resolve()
        elif self.app_env == "production":
            raise ValueError("Produção exige conexão MySQL configurada")
        return self

    @property
    def database_configured(self) -> bool:
        return self.database_host is not None

    def database_url(self) -> URL:
        if not self.database_configured:
            raise ConfigurationError()
        return URL.create(
            "mysql+pymysql",
            username=self.database_user,
            password=self.database_password.get_secret_value(),
            host=self.database_host,
            port=self.database_port,
            database=self.database_name,
            query={"charset": "utf8mb4"},
        )


def load_settings() -> Settings:
    try:
        return Settings()
    except (ValidationError, SettingsError, ValueError, OSError):
        raise ConfigurationError() from None
