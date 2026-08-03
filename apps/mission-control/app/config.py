from __future__ import annotations

import os
from dataclasses import dataclass


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Variável obrigatória ausente: {name}")
    return value


@dataclass(frozen=True)
class Settings:
    database_url: str
    redis_url: str
    rabbitmq_url: str
    minio_base_url: str
    ollama_base_url: str
    admin_username: str
    admin_password_hash: str
    session_secret: str
    session_max_age_seconds: int
    cookie_secure: bool
    environment: str


settings = Settings(
    database_url=required_env("DATABASE_URL"),
    redis_url=required_env("REDIS_URL"),
    rabbitmq_url=required_env("RABBITMQ_URL"),
    minio_base_url=os.getenv("MINIO_BASE_URL", "http://minio:9000").rstrip("/"),
    ollama_base_url=os.getenv(
        "OLLAMA_BASE_URL",
        "http://host.docker.internal:11434",
    ).rstrip("/"),
    admin_username=required_env("SSC_ADMIN_USERNAME"),
    admin_password_hash=required_env("SSC_ADMIN_PASSWORD_HASH"),
    session_secret=required_env("SSC_SESSION_SECRET"),
    session_max_age_seconds=int(
        os.getenv("SSC_SESSION_MAX_AGE_SECONDS", "28800")
    ),
    cookie_secure=os.getenv(
        "SSC_COOKIE_SECURE",
        "false",
    ).strip().lower() == "true",
    environment=os.getenv("SSC_ENVIRONMENT", "development"),
)
