from __future__ import annotations

import argparse
import asyncio
import re
import secrets
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Callable

from sqlalchemy import select

from app.config import settings
from app.database import SessionLocal
from app.foundation.status_cache import (
    is_stale,
    load_snapshot,
    redis_client,
    save_snapshot,
)
from app.models import ServiceDefinition
from app.system_status import (
    ServiceStatus,
    check_http,
    check_ollama,
    check_postgres,
    check_rabbitmq,
    check_redis,
)


COLLECTOR_LOCK_KEY = (
    f"ssc:mission-control:{settings.environment}:"
    "health-collector-lock:v1"
)

RELEASE_LOCK_SCRIPT = """
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
end
return 0
"""

_task: asyncio.Task | None = None
_stop_event: asyncio.Event | None = None


def utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sanitize_detail(value: str) -> str:
    cleaned = str(value).strip()

    patterns = (
        r"(?i)(postgres(?:ql)?://)[^@\s]+@",
        r"(?i)(redis://)[^@\s]+@",
        r"(?i)(amqps?://)[^@\s]+@",
        r"(?i)(password|token|secret)=([^&\s]+)",
    )

    for pattern in patterns:
        cleaned = re.sub(
            pattern,
            lambda match: (
                f"{match.group(1)}[REDACTED]@"
                if match.lastindex == 1
                else f"{match.group(1)}=[REDACTED]"
            ),
            cleaned,
        )

    return cleaned[:180] or "sem detalhe"


def check_for(
    definition: ServiceDefinition,
) -> ServiceStatus:
    checks: dict[str, Callable[[], ServiceStatus]] = {
        "postgres": check_postgres,
        "redis": check_redis,
        "rabbitmq": check_rabbitmq,
        "minio": lambda: check_http(
            "MinIO",
            (
                f"{settings.minio_base_url}"
                "/minio/health/live"
            ),
            "API disponível",
        ),
        "ollama": check_ollama,
    }

    check = checks.get(definition.check_target)

    if check is None:
        return ServiceStatus(
            name=definition.name,
            status="unavailable",
            detail="Check não cadastrado.",
            latency_ms=None,
        )

    result = check()

    return ServiceStatus(
        name=definition.name,
        status=result.status,
        detail=sanitize_detail(result.detail),
        latency_ms=result.latency_ms,
    )


def load_definitions() -> list[ServiceDefinition]:
    with SessionLocal() as db:
        return list(
            db.scalars(
                select(ServiceDefinition)
                .where(
                    ServiceDefinition.is_enabled.is_(True)
                )
                .order_by(
                    ServiceDefinition.sort_order,
                    ServiceDefinition.name,
                )
            ).all()
        )


def collect_snapshot() -> dict:
    definitions = load_definitions()
    checked_at = utc_iso()

    if not definitions:
        snapshot = {
            "generated_at": checked_at,
            "state": "empty",
            "services": [],
        }
        snapshot["cache_backend"] = save_snapshot(
            snapshot
        )
        return snapshot

    with ThreadPoolExecutor(
        max_workers=min(8, len(definitions))
    ) as executor:
        results = list(
            executor.map(check_for, definitions)
        )

    services = []

    for definition, result in zip(
        definitions,
        results,
        strict=True,
    ):
        services.append(
            {
                "slug": definition.slug,
                "name": definition.name,
                "category": definition.category,
                "criticality": definition.criticality,
                "status": result.status,
                "detail": result.detail,
                "latency_ms": result.latency_ms,
                "checked_at": checked_at,
                "source": definition.source,
            }
        )

    snapshot = {
        "generated_at": checked_at,
        "state": "ready",
        "services": services,
    }
    snapshot["cache_backend"] = save_snapshot(
        snapshot
    )
    return snapshot


def build_summary(
    snapshot: dict,
    *,
    backend: str,
    stale: bool,
) -> dict:
    services = snapshot.get("services", [])

    if not isinstance(services, list):
        services = []

    counts = {
        "healthy": 0,
        "unavailable": 0,
        "collecting": 0,
        "total": len(services),
    }

    for service in services:
        status_value = str(
            service.get("status", "unavailable")
        )

        if status_value in counts:
            counts[status_value] += 1
        else:
            counts["unavailable"] += 1

    return {
        "generated_at": snapshot.get("generated_at"),
        "state": snapshot.get("state", "unknown"),
        "stale": stale,
        "cache_backend": backend,
        "counts": counts,
        "services": services,
    }


def placeholder_summary() -> dict:
    definitions = load_definitions()
    now = utc_iso()

    services = [
        {
            "slug": item.slug,
            "name": item.name,
            "category": item.category,
            "criticality": item.criticality,
            "status": "collecting",
            "detail": "Aguardando a primeira coleta.",
            "latency_ms": None,
            "checked_at": None,
            "source": item.source,
        }
        for item in definitions
    ]

    return build_summary(
        {
            "generated_at": now,
            "state": "collecting",
            "services": services,
        },
        backend="empty",
        stale=True,
    )


def get_status_summary() -> dict:
    snapshot, backend = load_snapshot()

    if snapshot is None:
        return placeholder_summary()

    return build_summary(
        snapshot,
        backend=backend,
        stale=is_stale(snapshot),
    )


def acquire_collector_lock() -> tuple[bool, str | None]:
    token = secrets.token_urlsafe(24)

    try:
        acquired = redis_client().set(
            COLLECTOR_LOCK_KEY,
            token,
            nx=True,
            ex=max(
                10,
                settings.status_collect_interval_seconds * 2,
            ),
        )
        return bool(acquired), token
    except Exception:
        return True, None


def release_collector_lock(token: str | None) -> None:
    if token is None:
        return

    try:
        redis_client().eval(
            RELEASE_LOCK_SCRIPT,
            1,
            COLLECTOR_LOCK_KEY,
            token,
        )
    except Exception:
        pass


async def collector_loop(stop_event: asyncio.Event) -> None:
    while not stop_event.is_set():
        acquired, token = await asyncio.to_thread(
            acquire_collector_lock
        )

        if acquired:
            try:
                await asyncio.to_thread(
                    collect_snapshot
                )
            except Exception:
                pass
            finally:
                await asyncio.to_thread(
                    release_collector_lock,
                    token,
                )

        try:
            await asyncio.wait_for(
                stop_event.wait(),
                timeout=(
                    settings
                    .status_collect_interval_seconds
                ),
            )
        except asyncio.TimeoutError:
            continue


async def start_health_collector() -> None:
    global _task, _stop_event

    if _task is not None and not _task.done():
        return

    _stop_event = asyncio.Event()
    _task = asyncio.create_task(
        collector_loop(_stop_event),
        name="mission-control-health-collector",
    )


async def stop_health_collector() -> None:
    global _task, _stop_event

    if _task is None:
        return

    if _stop_event is not None:
        _stop_event.set()

    try:
        await asyncio.wait_for(_task, timeout=5)
    except asyncio.TimeoutError:
        _task.cancel()
    finally:
        _task = None
        _stop_event = None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action",
        choices=("once", "summary"),
    )
    args = parser.parse_args()

    if args.action == "once":
        print(collect_snapshot())
        return

    print(get_status_summary())


if __name__ == "__main__":
    main()
