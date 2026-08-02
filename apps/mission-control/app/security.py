from __future__ import annotations

import base64
import hashlib
import hmac
from dataclasses import dataclass


@dataclass(frozen=True)
class PasswordHash:
    algorithm: str
    iterations: int
    salt: bytes
    digest: bytes


def _decode_urlsafe(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def parse_password_hash(encoded: str) -> PasswordHash:
    try:
        algorithm, iterations_raw, salt_raw, digest_raw = encoded.split("$", 3)
        iterations = int(iterations_raw)
        salt = _decode_urlsafe(salt_raw)
        digest = _decode_urlsafe(digest_raw)
    except (ValueError, TypeError) as exc:
        raise ValueError("Formato de hash de senha inválido.") from exc

    if algorithm != "pbkdf2_sha256":
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
