"""Criação manual: executar no terminal privado do operador, nunca via chat."""

import getpass
import sys
import warnings

from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import load_settings
from app.core.errors import ApiError, ConfigurationError
from app.database.session import Database
from app.schemas.operator import OperatorCreate
from app.services.operator_auth import create_operator


def main():
    database = None
    try:
        if not sys.stdin.isatty():
            print("Execute em seu próprio terminal interativo; não envie senhas pelo chat.")
            return 1
        name = input("Nome fictício do operador: ")
        email = input("E-mail do operador: ")
        # Recusa fallback que ecoa senha quando getpass não consegue ocultar entrada.
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            password = getpass.getpass("Senha (8 a 128 caracteres): ")
            confirmation = getpass.getpass("Confirme a senha: ")
        if password != confirmation:
            print("Senhas diferentes. Nenhum operador criado.")
            return 1
        payload = OperatorCreate(full_name=name, email=email, password=password)
        database = Database(load_settings())
        with database.session() as session:
            create_operator(session, payload)
        print("Operador demonstrativo criado com sucesso.")
        return 0
    except (ValidationError, ConfigurationError, SQLAlchemyError, ApiError, getpass.GetPassWarning):
        print(
            "Não foi possível criar o operador. Confira os campos, duplicidade e conexão privada."
        )
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Operação interrompida. Nenhuma credencial divulgada.")
        return 1
    finally:
        if database is not None:
            database.dispose()


if __name__ == "__main__":
    raise SystemExit(main())
