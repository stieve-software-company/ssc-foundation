from __future__ import annotations

import json
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import Any, Callable

import pika
import redis
from sqlalchemy import text

from app.config import settings
from app.database import engine


@dataclass(frozen=True)
class ServiceStatus:
    name: str
    status: str
    detail: str
    latency_ms: int | None


def measured_check(
    name: str,
    operation: Callable[[], str],
) -> ServiceStatus:
    started = time.perf_counter()

    try:
        detail = operation()
        elapsed = int((time.perf_counter() - started) * 1000)
        return ServiceStatus(
            name=name,
            status="healthy",
            detail=detail,
            latency_ms=elapsed,
        )
    except Exception as exc:
        elapsed = int((time.perf_counter() - started) * 1000)
        message = str(exc).strip() or type(exc).__name__
        return ServiceStatus(
            name=name,
            status="unavailable",
            detail=message[:180],
            latency_ms=elapsed,
        )


def check_postgres() -> ServiceStatus:
    def operation() -> str:
        with engine.connect() as connection:
            return str(connection.execute(text("SELECT 1")).scalar_one())

    return measured_check("PostgreSQL", operation)


def check_redis() -> ServiceStatus:
    def operation() -> str:
        client = redis.Redis.from_url(
            settings.redis_url,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        return "PONG" if client.ping() else "sem resposta"

    return measured_check("Redis", operation)


def check_rabbitmq() -> ServiceStatus:
    def operation() -> str:
        parameters = pika.URLParameters(settings.rabbitmq_url)
        parameters.socket_timeout = 2
        parameters.blocked_connection_timeout = 2
        parameters.connection_attempts = 1
        connection = pika.BlockingConnection(parameters)
        connection.close()
        return "conexão AMQP aceita"

    return measured_check("RabbitMQ", operation)


def fetch_json(url: str, timeout: int = 3) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "SSC-Mission-Control/0.2"},
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        if response.status >= 400:
            raise RuntimeError(f"HTTP {response.status}")

        payload = json.load(response)

    if not isinstance(payload, dict):
        raise RuntimeError("resposta JSON inválida")

    return payload


def check_http(
    name: str,
    url: str,
    success_detail: str,
) -> ServiceStatus:
    def operation() -> str:
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "SSC-Mission-Control/0.2"},
        )

        with urllib.request.urlopen(request, timeout=3) as response:
            if response.status >= 400:
                raise RuntimeError(f"HTTP {response.status}")

        return success_detail

    return measured_check(name, operation)


def check_ollama() -> ServiceStatus:
    def operation() -> str:
        if settings.ai_provider != "ollama":
            return f"provedor configurado: {settings.ai_provider}"

        timeout = min(
            settings.ollama_request_timeout_seconds,
            5,
        )

        version_payload = fetch_json(
            f"{settings.ollama_base_url}/api/version",
            timeout=timeout,
        )
        tags_payload = fetch_json(
            f"{settings.ollama_base_url}/api/tags",
            timeout=timeout,
        )

        version = str(version_payload.get("version", "desconhecida"))
        models = tags_payload.get("models", [])

        if not isinstance(models, list):
            raise RuntimeError("lista de modelos inválida")

        installed_names = {
            str(item.get("name") or item.get("model") or "")
            for item in models
            if isinstance(item, dict)
        }

        if (
            settings.ollama_verify_model
            and settings.ollama_model not in installed_names
        ):
            raise RuntimeError(
                f"modelo não instalado: {settings.ollama_model}"
            )

        return (
            f"{settings.ollama_model} disponível "
            f"· Ollama {version}"
        )

    return measured_check("Ollama", operation)


def collect_statuses() -> list[ServiceStatus]:
    checks: list[Callable[[], ServiceStatus]] = [
        check_postgres,
        check_redis,
        check_rabbitmq,
        lambda: check_http(
            "MinIO",
            f"{settings.minio_base_url}/minio/health/live",
            "API disponível",
        ),
        check_ollama,
    ]

    with ThreadPoolExecutor(max_workers=len(checks)) as executor:
        return list(executor.map(lambda check: check(), checks))
