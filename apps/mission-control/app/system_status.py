from __future__ import annotations

import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import Callable

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
        return ServiceStatus(
            name=name,
            status="unavailable",
            detail=type(exc).__name__,
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
        lambda: check_http(
            "Ollama",
            f"{settings.ollama_base_url}/api/tags",
            "API local disponível",
        ),
    ]

    with ThreadPoolExecutor(max_workers=len(checks)) as executor:
        return list(executor.map(lambda check: check(), checks))
