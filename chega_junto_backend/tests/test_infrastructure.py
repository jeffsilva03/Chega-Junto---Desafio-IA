import ssl
from unittest.mock import Mock

import certifi
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ConfigurationError
from app.database.session import Database, build_engine
from app.main import create_app


def database_double():
    database = Database(Settings(_env_file=None))
    session = Mock(spec=Session)
    session.execute.return_value.scalar_one.return_value = 1
    database.session_factory = Mock(return_value=session)
    return database, session


def test_health_ok_uses_light_query_and_closes_session():
    database, session = database_double()
    with TestClient(create_app(Settings(_env_file=None), database)) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}
    assert str(session.execute.call_args.args[0]) == "SELECT 1"
    session.close.assert_called_once()
    session.commit.assert_not_called()


def test_missing_database_returns_503_and_still_creates_app():
    application = create_app(Settings(_env_file=None))
    with TestClient(application) as client:
        response = client.get("/health")
        assert response.status_code == 503
        assert response.json() == {"status": "unavailable", "database": "unavailable"}
        assert client.get("/api/v1/appointments").status_code == 503
        assert "/health" in client.get("/openapi.json").json()["paths"]


def test_database_error_rolls_back_and_does_not_leak(caplog):
    database, session = database_double()
    sentinel = "PRIVATE_HOST_USER_PASSWORD_CONNECTION_STRING"
    session.execute.side_effect = OperationalError("SELECT 1", {}, RuntimeError(sentinel))
    with TestClient(create_app(Settings(_env_file=None), database)) as client:
        response = client.get("/health")
    assert response.status_code == 503
    assert sentinel not in response.text + caplog.text
    assert "Traceback" not in response.text + caplog.text
    session.rollback.assert_called_once()
    session.close.assert_called_once()


def test_unexpected_request_error_is_controlled(caplog):
    database, session = database_double()
    session.execute.side_effect = RuntimeError("private-secret-sentinel")
    with TestClient(create_app(Settings(_env_file=None), database)) as client:
        response = client.get("/health")
    assert response.status_code == 500
    assert response.json() == {"detail": "Erro interno."}
    assert "private-secret-sentinel" not in response.text + caplog.text
    session.rollback.assert_called_once()
    session.close.assert_called_once()


def test_cors_header_on_unexpected_failure():
    database, session = database_double()
    session.execute.side_effect = RuntimeError("private-secret-sentinel")
    settings = Settings(_env_file=None, cors_allowed_origins=["http://localhost:5173"])
    with TestClient(create_app(settings, database)) as client:
        response = client.get("/health", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 500
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


@pytest.mark.parametrize(
    "origin,expected",
    [
        ("http://localhost:5173", 200),
        ("https://unapproved.example.test", 400),
    ],
)
def test_cors_preflight(origin, expected):
    settings = Settings(_env_file=None, cors_allowed_origins=["http://localhost:5173"])
    with TestClient(create_app(settings)) as client:
        response = client.options(
            "/health",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "GET",
            },
        )
    assert response.status_code == expected
    assert response.headers.get("access-control-allow-origin") == (
        origin if expected == 200 else None
    )
    assert "access-control-allow-credentials" not in response.headers


def test_cors_header_on_controlled_database_failure():
    settings = Settings(_env_file=None, cors_allowed_origins=["http://localhost:5173"])
    with TestClient(create_app(settings)) as client:
        response = client.get("/health", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 503
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_engine_uses_verified_tls_and_small_pool_without_connecting(monkeypatch):
    from app.database import session as module

    captured = {}
    fake_engine = Mock()
    monkeypatch.setattr(
        module,
        "create_engine",
        lambda url, **kw: (
            captured.update(
                url=url,
                **kw,
            )
            or fake_engine
        ),
    )
    monkeypatch.setattr(module.event, "listens_for", lambda *args: lambda fn: fn)
    settings = Settings(
        _env_file=None,
        database_host="db.example.test",
        database_port=12345,
        database_name="defaultdb",
        database_user="demo",
        database_password="test-only",
        database_ssl_ca_path=certifi.where(),
    )
    assert build_engine(settings) is fake_engine
    context = captured["connect_args"]["ssl"]
    assert context.check_hostname is True
    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.minimum_version >= ssl.TLSVersion.TLSv1_2
    assert (captured["pool_size"], captured["max_overflow"]) == (3, 2)
    assert captured["pool_pre_ping"] is True
    assert captured["hide_parameters"] is True
    assert captured["echo"] is False


def test_untrusted_ca_does_not_disable_tls(tmp_path):
    ca = tmp_path / "bad.pem"
    ca.write_text("not a certificate", encoding="utf-8")
    settings = Settings(
        _env_file=None,
        database_host="db.example.test",
        database_port=12345,
        database_name="defaultdb",
        database_user="demo",
        database_password="test-only",
        database_ssl_ca_path=ca,
    )
    with pytest.raises(ConfigurationError):
        build_engine(settings)


def test_session_error_rolls_back_and_closes():
    database, session = database_double()
    with pytest.raises(ValueError), database.session():
        raise ValueError("test")
    session.rollback.assert_called_once()
    session.close.assert_called_once()
