from pathlib import Path

import pytest
from pydantic import ValidationError

from app.core.config import Settings, load_settings
from app.core.errors import ConfigurationError


def test_defaults_allow_unconfigured_local_app():
    settings = Settings(_env_file=None)
    assert not settings.database_configured
    assert settings.database_ssl_mode == "VERIFY_IDENTITY"
    assert (settings.database_pool_size, settings.database_max_overflow) == (3, 2)
    assert settings.database_pool_pre_ping is True
    assert settings.cors_allowed_origins == []


def test_env_file_and_environment_precedence(tmp_path, monkeypatch):
    path = tmp_path / ".env"
    path.write_text(
        "APP_ENV=test\nDATABASE_POOL_SIZE=4\nDATABASE_POOL_PRE_PING=true\n"
        'CORS_ALLOWED_ORIGINS=["http://localhost:5173"]\n',
        encoding="utf-8",
    )
    monkeypatch.setenv("DATABASE_POOL_SIZE", "5")
    settings = Settings(_env_file=path)
    assert settings.database_pool_size == 5
    assert settings.app_env == "test"
    assert settings.cors_allowed_origins == ["http://localhost:5173"]


def test_safe_example_can_be_loaded_without_database():
    root = Path(__file__).resolve().parents[1]
    settings = Settings(_env_file=root / ".env.example")
    assert not settings.database_configured


@pytest.mark.parametrize(
    "values",
    [
        {"database_host": "private-host"},
        {"database_port": 0},
        {"database_port": 65536},
        {"database_ssl_mode": "DISABLED"},
        {"database_ssl_mode": "REQUIRED"},
        {"database_pool_size": 0},
        {"database_max_overflow": -1},
        {"database_connect_timeout": 0},
        {"database_read_timeout": 0},
        {"database_write_timeout": 0},
        {"database_pool_recycle": 0},
        {"app_timezone": "invalid-zone"},
        {"demo_user_id": 0},
        {"app_env": "production"},
        {"cors_allowed_origins": ["*"]},
        {"cors_allowed_origins": ["https://*.example.test"]},
        {"cors_allowed_origins": ["https://example.test/path"]},
        {"cors_allowed_origins": ["https://example.test?x=1"]},
        {"cors_allowed_origins": ["https://name:password@example.test"]},
        {"cors_allowed_origins": ["ftp://example.test"]},
        {"cors_allowed_origins": ["http://localhost:99999"]},
    ],
)
def test_invalid_config_is_rejected_without_echoing_inputs(values):
    with pytest.raises(ValidationError) as error:
        Settings(_env_file=None, **values)
    assert "input_value" not in str(error.value)
    assert "private-host" not in str(error.value)


def test_invalid_environment_error_is_generic(monkeypatch):
    monkeypatch.setenv("DATABASE_PASSWORD", "sensitive-sentinel")
    with pytest.raises(ConfigurationError) as error:
        load_settings()
    assert "sensitive-sentinel" not in str(error.value)


def test_malformed_origins_json_is_sanitized(monkeypatch):
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "[malformed")
    with pytest.raises(ConfigurationError):
        load_settings()


def test_database_url_escapes_credentials_and_hides_secret(tmp_path):
    ca = tmp_path / "ca.pem"
    ca.write_text("CA placeholder for URL-only test", encoding="utf-8")
    settings = Settings(
        _env_file=None,
        database_host="db.example.test",
        database_port=12345,
        database_name="defaultdb",
        database_user="demo",
        database_password="p@ss:/%word",
        database_ssl_ca_path=ca,
    )
    url = settings.database_url()
    assert url.drivername == "mysql+pymysql"
    assert url.password == "p@ss:/%word"
    assert "p@ss" not in repr(settings)
    assert "p@ss" not in str(url)
    assert "database_password" not in settings.model_dump()


def test_nonexistent_ca_is_rejected(tmp_path):
    with pytest.raises(ValidationError):
        Settings(
            _env_file=None,
            database_host="db.example.test",
            database_port=12345,
            database_name="defaultdb",
            database_user="demo",
            database_password="test-only",
            database_ssl_ca_path=tmp_path / "missing.pem",
        )
