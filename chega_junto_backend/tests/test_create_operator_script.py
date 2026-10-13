import secrets
from types import SimpleNamespace

import pytest
from sqlalchemy import func, select

from app.models import Operator
from scripts import create_operator as script


def test_noninteractive_refuses_before_password(monkeypatch, capsys):
    monkeypatch.setattr(script.sys, "stdin", SimpleNamespace(isatty=lambda: False))
    monkeypatch.setattr(script.getpass, "getpass", lambda _: pytest.fail("Não deve pedir senha"))
    assert script.main() == 1
    assert "próprio terminal" in capsys.readouterr().out


@pytest.mark.parametrize(
    "case", ["success", "gmail", "minimum", "mismatch", "weak", "invalid_email", "echo_fallback"]
)
def test_script_safe_entry_and_transaction(api_database, monkeypatch, capsys, case):
    database = api_database[1]
    password = secrets.token_urlsafe(24)
    if case in ("minimum", "weak"):
        password = password[: 8 if case == "minimum" else 7]
    email = "  OPERATOR.DEMO@GMAIL.COM  " if case == "gmail" else "person@example.test"
    if case == "invalid_email":
        email = "invalid-email"
    inputs = iter(["Operador Fictício", email])
    passwords = iter([password, password if case != "mismatch" else "different"])
    monkeypatch.setattr(script.sys, "stdin", SimpleNamespace(isatty=lambda: True))
    monkeypatch.setattr("builtins.input", lambda _: next(inputs))

    def private_input(_):
        if case == "echo_fallback":
            raise script.getpass.GetPassWarning()
        return next(passwords)

    monkeypatch.setattr(script.getpass, "getpass", private_input)
    monkeypatch.setattr(script, "load_settings", lambda: None)
    monkeypatch.setattr(
        script,
        "Database",
        lambda _: SimpleNamespace(session=database.session, dispose=lambda: None),
    )
    success = case in ("success", "gmail", "minimum")
    assert script.main() == (0 if success else 1)
    output = capsys.readouterr().out
    assert password not in output and "$argon2" not in output
    with database.session() as session:
        assert session.scalar(select(func.count()).select_from(Operator)) == (1 if success else 0)
        if success:
            assert session.scalar(select(Operator.email)) == email.strip().lower()
