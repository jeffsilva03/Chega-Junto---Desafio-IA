"""Operador isolado: nunca usa Aiven nem credenciais reais."""

import secrets
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import ApiError, ConfigurationError
from app.core.operator_security import ISSUER
from app.core.security import password_hasher
from app.main import create_app
from app.models import Operator
from app.schemas.operator import OperatorCreate
from app.services.operator_auth import create_operator
from tests.test_simulator import account, payload

PREFIX = "/api/v1/operator"


@pytest.fixture
def operator_api(api_database):
    database = api_database[1]
    settings = Settings(
        _env_file=None,
        auth_mode="jwt",
        operator_portal_enabled=True,
        operator_auth_secret_key=secrets.token_urlsafe(32),
        cors_allowed_origins=["https://portal.example.test"],
    )
    credentials = {"email": "operator@example.test", "password": secrets.token_urlsafe(24)}
    with database.session() as session:
        identity = create_operator(
            session, OperatorCreate(full_name="Operador Fictício", **credentials)
        )
    application = create_app(settings, database)
    with TestClient(application) as client:
        yield client, database, application, credentials, identity


def login(client, credentials):
    response = client.post(PREFIX + "/auth/login", json=credentials)
    assert response.status_code == 200
    return response.json()


def auth(result):
    return {"Authorization": "Bearer " + result["access_token"]}


def test_login_me_hash_identity_and_no_signup(operator_api):
    client, database, app, credentials, identity = operator_api
    result = login(client, {**credentials, "email": " OPERATOR@EXAMPLE.TEST "})
    assert set(result) == {"access_token", "token_type", "operator"}
    assert result["operator"] == identity.model_dump(mode="json")
    assert client.get(PREFIX + "/auth/me", headers=auth(result)).json() == result["operator"]
    claims = jwt.decode(
        result["access_token"],
        app.state.settings.operator_auth_secret_key.get_secret_value(),
        algorithms=["HS256"],
        issuer=ISSUER,
    )
    assert set(claims) == {"sub", "iat", "exp", "iss", "actor_type"}
    assert claims["exp"] - claims["iat"] == 3600
    with database.session() as session:
        row = session.get(Operator, int(identity.id))
        assert row.password_hash.startswith("$argon2id$")
        assert password_hasher.verify(row.password_hash, credentials["password"])
    assert client.post(PREFIX + "/register", json=credentials).status_code == 404
    assert client.post(PREFIX + "/auth/register", json=credentials).status_code == 404
    contract = client.get("/openapi.json").json()
    assert "OperatorBearer" in contract["components"]["securitySchemes"]
    assert contract["paths"][PREFIX + "/appointments"]["get"]["security"] == [
        {"OperatorBearer": []}
    ]
    assert all("simulator" not in key for key in contract["paths"])


@pytest.mark.parametrize("kind", ["wrong_password", "unknown", "inactive"])
def test_generic_login_and_dummy_verify(operator_api, monkeypatch, kind):
    client, database, _, credentials, identity = operator_api
    from app.services import operator_auth

    original = operator_auth.verify_password
    calls = []

    def verify(encoded, password):
        calls.append(encoded is None)
        return original(encoded, password)

    monkeypatch.setattr(operator_auth, "verify_password", verify)
    values = credentials.copy()
    if kind == "unknown":
        values["email"] = "absent@example.test"
    elif kind == "wrong_password":
        values["password"] = secrets.token_urlsafe(24)
    else:
        with database.session() as session:
            session.get(Operator, int(identity.id)).is_active = False
            session.commit()
    response = client.post(PREFIX + "/auth/login", json=values)
    assert response.status_code == 401
    assert response.json()["error"] == {
        "code": "invalid_credentials",
        "message": "E-mail ou senha inválidos.",
    }
    assert calls == [kind == "unknown"]


@pytest.mark.parametrize(
    "kind",
    ["expired", "issuer", "signature", "actor", "missing", "algorithm", "subject", "invalid"],
)
def test_invalid_tokens(operator_api, kind):
    client, _, app, _, identity = operator_api
    now = datetime.now(UTC)
    claims = {
        "sub": str(identity.id),
        "iat": now,
        "exp": now + timedelta(minutes=10),
        "iss": ISSUER,
        "actor_type": "operator",
    }
    key = app.state.settings.operator_auth_secret_key.get_secret_value()
    algorithm = "HS256"
    if kind == "expired":
        claims["exp"] = now - timedelta(seconds=1)
    if kind == "issuer":
        claims["iss"] = "chega-junto"
    if kind == "signature":
        key = secrets.token_urlsafe(32)
    if kind == "actor":
        claims["actor_type"] = "patient"
    if kind == "missing":
        claims.pop("iat")
    if kind == "algorithm":
        algorithm = "HS384"
        key = secrets.token_urlsafe(64)
    if kind == "subject":
        claims["sub"] = "18446744073709551616"
    token = "invalid" if kind == "invalid" else jwt.encode(claims, key, algorithm=algorithm)
    response = client.get(PREFIX + "/auth/me", headers={"Authorization": "Bearer " + token})
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize(
    "path",
    [
        "/auth/me",
        "/users/search?email=a@example.test",
        "/facilities",
        "/appointments",
        "/appointments/1",
    ],
)
def test_missing_token(operator_api, path):
    assert operator_api[0].get(PREFIX + path).status_code == 401


def test_tokens_are_blocked_in_both_directions_and_disabled_after_login(operator_api):
    client, database, _, credentials, identity = operator_api
    patient, _ = account(client)
    operator = login(client, credentials)
    for path in ("/auth/me", "/appointments", "/facilities"):
        assert client.get(PREFIX + path, headers=auth(patient)).status_code == 401
    for path in ("/me/profile", "/appointments", "/auth/me", "/preparation/overview"):
        assert client.get("/api/v1" + path, headers=auth(operator)).status_code == 401
    with database.session() as session:
        session.get(Operator, int(identity.id)).is_active = False
        session.commit()
    assert client.get(PREFIX + "/auth/me", headers=auth(operator)).status_code == 401


def test_disabled_before_db_and_openapi(api_database):
    client = api_database[0]
    for method, path in (
        ("GET", "/auth/me"),
        ("POST", "/auth/login"),
        ("POST", "/appointments"),
        ("GET", "/appointments"),
    ):
        assert client.request(method, PREFIX + path).status_code == 404
    assert all("/operator" not in path for path in client.get("/openapi.json").json()["paths"])


def test_enabled_requires_independent_secret():
    for key in (None, "short"):
        for environment in ("development", "production"):
            with pytest.raises(ConfigurationError):
                Settings(
                    _env_file=None,
                    app_env=environment,
                    operator_portal_enabled=True,
                    operator_auth_secret_key=key,
                )
    key = secrets.token_urlsafe(32)
    with pytest.raises(ConfigurationError):
        Settings(
            _env_file=None,
            operator_portal_enabled=True,
            operator_auth_secret_key=key,
            auth_secret_key=key,
        )
    settings = Settings(_env_file=None)
    settings.operator_portal_enabled = True
    with pytest.raises(ConfigurationError):
        settings.validate_operator_auth()


def test_creation_validation_and_duplicate(operator_api):
    _, database, _, credentials, _ = operator_api
    with database.session() as session, pytest.raises(ApiError):
        create_operator(session, OperatorCreate(full_name="Duplicado", **credentials))
    for password in ("a" * 7, "a" * 129):
        with pytest.raises(ValidationError):
            OperatorCreate(full_name="Fictício", email="a@example.test", password=password)


@pytest.mark.parametrize("length", [8, 128])
def test_operator_password_boundaries_and_gmail_login(operator_api, length):
    client, database, _, _, _ = operator_api
    password = secrets.token_urlsafe(96)[:length]
    credentials = {"email": "  OPERATOR.DEMO@GMAIL.COM  ", "password": password}
    with database.session() as session:
        identity = create_operator(
            session, OperatorCreate(full_name="Operador Fictício", **credentials)
        )
    result = login(client, credentials)
    assert result["operator"]["email"] == "operator.demo@gmail.com"
    assert result["operator"] == identity.model_dump(mode="json")
    assert client.get(PREFIX + "/auth/me", headers=auth(result)).status_code == 200


def test_operator_e2e_create_prepare_edit_cancel(operator_api):
    client, _, _, credentials, _ = operator_api
    patient, password = account(client)
    operator = auth(login(client, credentials))
    user = patient["user"]
    assert client.get(
        PREFIX + "/users/search", params={"email": user["email"]}, headers=operator
    ).json() == user | {"is_active": True}
    record = client.post(
        PREFIX + "/appointments", headers=operator, json=payload(user["id"])
    ).json()
    patient_login = client.post(
        "/api/v1/auth/login", json={"email": user["email"], "password": password}
    ).json()
    patient_auth = auth(patient_login)
    assert (
        client.get("/api/v1/appointments", headers=patient_auth).json()["items"][0]["id"]
        == record["id"]
    )
    url = f"/api/v1/appointments/{record['id']}"
    item = record["checklist"][0]
    assert (
        client.patch(
            url + f"/checklist/{item['id']}", headers=patient_auth, json={"is_completed": True}
        ).status_code
        == 200
    )
    assert client.get(url + "/preparation", headers=patient_auth).json()["progress"][
        "documents_done"
    ]
    new_date = (datetime.now(UTC) + timedelta(days=8)).isoformat()
    assert (
        client.patch(
            PREFIX + f"/appointments/{record['id']}",
            headers=operator,
            json={"scheduled_at": new_date},
        ).status_code
        == 200
    )
    assert client.get(url, headers=patient_auth).json()["scheduled_at"] == new_date.replace(
        "+00:00", "Z"
    )
    assert (
        client.post(PREFIX + f"/appointments/{record['id']}/cancel", headers=operator).status_code
        == 200
    )
    assert (
        client.get("/api/v1/preparation/overview", headers=patient_auth).json()["next_appointment"]
        is None
    )


def test_cors_exact_and_no_clinical_routes(operator_api):
    client, _, _, credentials, _ = operator_api
    headers = auth(login(client, credentials))
    for path in (
        "/me/profile",
        "/me/health-items",
        "/health-records",
        "/notifications",
        "/appointments/1/report",
    ):
        assert client.get(PREFIX + path, headers=headers).status_code == 404
    for origin, expected in (
        ("https://portal.example.test", 200),
        ("https://other.example.test", 400),
    ):
        response = client.options(
            PREFIX + "/appointments",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type",
            },
        )
        assert response.status_code == expected
        assert response.headers.get("access-control-allow-origin") == (
            origin if expected == 200 else None
        )
