from __future__ import annotations

import base64
import hashlib
import hmac
import os
from dataclasses import dataclass


ALGORITHM = "pbkdf2_sha256"
DEFAULT_ITERATIONS = 600_000


@dataclass(frozen=True)
class PasswordHash:
    algorithm: str
    iterations: int
    salt: bytes
    digest: bytes


def _encode_urlsafe(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _decode_urlsafe(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def hash_password(
    password: str,
    *,
    iterations: int = DEFAULT_ITERATIONS,
) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations,
    )

    return "$".join(
        [
            ALGORITHM,
            str(iterations),
            _encode_urlsafe(salt),
            _encode_urlsafe(digest),
        ]
    )


def parse_password_hash(encoded: str) -> PasswordHash:
    try:
        algorithm, iterations_raw, salt_raw, digest_raw = encoded.split("$", 3)
        iterations = int(iterations_raw)
        salt = _decode_urlsafe(salt_raw)
        digest = _decode_urlsafe(digest_raw)
    except (ValueError, TypeError) as exc:
        raise ValueError("Formato de hash de senha inválido.") from exc

    if algorithm != ALGORITHM:
        raise ValueError("Algoritmo de senha não suportado.")

    if iterations < 100_000:
        raise ValueError("Quantidade de iterações insegura.")

    return PasswordHash(
        algorithm=algorithm,
        iterations=iterations,
        salt=salt,
        digest=digest,
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        parsed = parse_password_hash(encoded)
    except ValueError:
        return False

    candidate = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        parsed.salt,
        parsed.iterations,
    )

    return hmac.compare_digest(candidate, parsed.digest)


def validate_password_strength(password: str) -> str | None:
    if len(password) < 12:
        return "A senha precisa ter pelo menos 12 caracteres."

    if not any(character.islower() for character in password):
        return "A senha precisa conter uma letra minúscula."

    if not any(character.isupper() for character in password):
        return "A senha precisa conter uma letra maiúscula."

    if not any(character.isdigit() for character in password):
        return "A senha precisa conter um número."

    return None
