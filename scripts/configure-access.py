#!/usr/bin/env python3

from __future__ import annotations

import base64
import getpass
import hashlib
import os
import re
import secrets
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"

ITERATIONS = 600_000
MIN_PASSWORD_LENGTH = 12


def fail(message: str) -> None:
    print(f"[ERRO] {message}", file=sys.stderr)
    raise SystemExit(1)


def encode_urlsafe(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def create_password_hash(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        ITERATIONS,
    )

    return "$".join(
        [
            "pbkdf2_sha256",
            str(ITERATIONS),
            encode_urlsafe(salt),
            encode_urlsafe(digest),
        ]
    )


def escape_compose_env_value(value: str) -> str:
    """
    Escapa cifrões para impedir que o Docker Compose interprete partes
    do valor como nomes de variáveis durante a leitura do arquivo .env.

    No container, cada sequência $$ será convertida novamente em $.
    """
    return value.replace("$", "$$")


def replace_or_append(content: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    safe_value = escape_compose_env_value(value)
    line = f"{key}={safe_value}"

    if pattern.search(content):
        return pattern.sub(lambda _: line, content)

    separator = "" if content.endswith("\n") else "\n"
    return f"{content}{separator}{line}\n"


def prompt_username() -> str:
    username = input("Usuário administrativo [admin]: ").strip() or "admin"

    if not re.fullmatch(r"[A-Za-z0-9_.-]{3,64}", username):
        fail(
            "Use de 3 a 64 caracteres: letras, números, ponto, hífen ou sublinhado."
        )

    return username


def prompt_password() -> str:
    password = getpass.getpass(
        f"Senha administrativa (mínimo {MIN_PASSWORD_LENGTH} caracteres): "
    )
    confirmation = getpass.getpass("Confirme a senha: ")

    if password != confirmation:
        fail("As senhas não são iguais.")

    if len(password) < MIN_PASSWORD_LENGTH:
        fail(f"A senha precisa ter pelo menos {MIN_PASSWORD_LENGTH} caracteres.")

    if password.lower() == password or password.upper() == password:
        print(
            "[AVISO] Recomenda-se misturar letras maiúsculas e minúsculas.",
            file=sys.stderr,
        )

    return password


def main() -> None:
    if not ENV_FILE.exists():
        fail(f"Arquivo não encontrado: {ENV_FILE}")

    username = prompt_username()
    password = prompt_password()

    password_hash = create_password_hash(password)
    session_secret = secrets.token_urlsafe(48)

    content = ENV_FILE.read_text(encoding="utf-8")

    values = {
        "SSC_ADMIN_USERNAME": username,
        "SSC_ADMIN_PASSWORD_HASH": password_hash,
        "SSC_SESSION_SECRET": session_secret,
        "SSC_SESSION_MAX_AGE_SECONDS": "28800",
        "SSC_COOKIE_SECURE": "false",
        "SSC_ACCESS_BIND_ADDRESS": "0.0.0.0",
        "SSC_ACCESS_HOST_PORT": "8080",
    }

    for key, value in values.items():
        content = replace_or_append(content, key, value)

    ENV_FILE.write_text(content, encoding="utf-8", newline="\n")
    ENV_FILE.chmod(0o600)

    print()
    print("[OK] Configuração de acesso salva no .env.")
    print("[OK] A senha foi armazenada somente como hash.")
    print("[OK] O hash foi escapado para uso seguro pelo Docker Compose.")
    print("[OK] Um novo segredo de sessão foi criado.")
    print("[OK] O .env permanece com permissão 600.")
    print()
    print(f"Usuário configurado: {username}")
    print("Porta configurada:   8080")
    print()
    print("A senha não foi exibida nem gravada em texto puro.")


if __name__ == "__main__":
    main()
