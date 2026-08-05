from __future__ import annotations

import os
from dataclasses import dataclass


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Variável obrigatória ausente: {name}")
    return value


def integer_env(
    name: str,
    default: int,
    *,
    minimum: int,
    maximum: int,
) -> int:
    raw_value = os.getenv(name, str(default)).strip()

    try:
        value = int(raw_value)
    except ValueError as exc:
        raise RuntimeError(
            f"Variável {name} precisa ser um número inteiro."
        ) from exc

    if not minimum <= value <= maximum:
        raise RuntimeError(
            f"Variável {name} precisa estar entre "
            f"{minimum} e {maximum}."
        )

    return value


def boolean_env(name: str, default: bool) -> bool:
    raw_value = os.getenv(
        name,
        "true" if default else "false",
    ).strip().lower()

    if raw_value not in {"true", "false"}:
        raise RuntimeError(
            f"Variável {name} precisa ser true ou false."
        )

    return raw_value == "true"


@dataclass(frozen=True)
class Settings:
    database_url: str
    redis_url: str
    rabbitmq_url: str
    minio_base_url: str
    ai_provider: str
    ollama_base_url: str
    ollama_model: str
    ollama_context_length: int
    ollama_keep_alive: str
    ollama_request_timeout_seconds: int
    ollama_verify_model: bool
    admin_username: str
    admin_password_hash: str
    session_secret: str
    session_max_age_seconds: int
    cookie_secure: bool
    environment: str
    status_collect_interval_seconds: int
    status_cache_ttl_seconds: int
    status_sse_interval_seconds: int


settings = Settings(
    database_url=required_env("DATABASE_URL"),
    redis_url=required_env("REDIS_URL"),
    rabbitmq_url=required_env("RABBITMQ_URL"),
    minio_base_url=os.getenv(
        "MINIO_BASE_URL",
        "http://minio:9000",
    ).rstrip("/"),
    ai_provider=os.getenv(
        "AI_PROVIDER",
        "ollama",
    ).strip().lower(),
    ollama_base_url=os.getenv(
        "OLLAMA_BASE_URL",
        "http://host.docker.internal:11434",
    ).rstrip("/"),
    ollama_model=os.getenv(
        "OLLAMA_MODEL",
        "qwen2.5-coder:3b",
    ).strip(),
    ollama_context_length=integer_env(
        "OLLAMA_CONTEXT_LENGTH",
        4096,
        minimum=512,
        maximum=131072,
    ),
    ollama_keep_alive=os.getenv(
        "OLLAMA_KEEP_ALIVE",
        "10m",
    ).strip(),
    ollama_request_timeout_seconds=integer_env(
        "OLLAMA_REQUEST_TIMEOUT_SECONDS",
        120,
        minimum=5,
        maximum=3600,
    ),
    ollama_verify_model=boolean_env(
        "OLLAMA_VERIFY_MODEL",
        True,
    ),
    admin_username=required_env("SSC_ADMIN_USERNAME"),
    admin_password_hash=required_env("SSC_ADMIN_PASSWORD_HASH"),
    session_secret=required_env("SSC_SESSION_SECRET"),
    session_max_age_seconds=integer_env(
        "SSC_SESSION_MAX_AGE_SECONDS",
        28800,
        minimum=300,
        maximum=2592000,
    ),
    cookie_secure=boolean_env(
        "SSC_COOKIE_SECURE",
        False,
    ),
    environment=os.getenv(
        "SSC_ENVIRONMENT",
        "development",
    ),
    status_collect_interval_seconds=integer_env(
        "MC_STATUS_COLLECT_INTERVAL_SECONDS",
        10,
        minimum=2,
        maximum=300,
    ),
    status_cache_ttl_seconds=integer_env(
        "MC_STATUS_CACHE_TTL_SECONDS",
        30,
        minimum=5,
        maximum=3600,
    ),
    status_sse_interval_seconds=integer_env(
        "MC_STATUS_SSE_INTERVAL_SECONDS",
        3,
        minimum=1,
        maximum=60,
    ),
)
