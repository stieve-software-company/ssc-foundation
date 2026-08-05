from __future__ import annotations

import json
import threading
from copy import deepcopy
from datetime import datetime, timezone
from typing import Any

import redis

from app.config import settings


CACHE_KEY = (
    f"ssc:mission-control:{settings.environment}:"
    "service-status:v1"
)

_memory_lock = threading.Lock()
_memory_snapshot: dict[str, Any] | None = None


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(
        settings.redis_url,
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )


def save_snapshot(snapshot: dict[str, Any]) -> str:
    global _memory_snapshot

    with _memory_lock:
        _memory_snapshot = deepcopy(snapshot)

    try:
        redis_client().set(
            CACHE_KEY,
            json.dumps(
                snapshot,
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            ex=settings.status_cache_ttl_seconds,
        )
        return "redis"
    except Exception:
        return "memory"


def load_snapshot() -> tuple[dict[str, Any] | None, str]:
    try:
        payload = redis_client().get(CACHE_KEY)

        if payload:
            parsed = json.loads(payload)

            if isinstance(parsed, dict):
                return parsed, "redis"
    except Exception:
        pass

    with _memory_lock:
        if _memory_snapshot is not None:
            return deepcopy(_memory_snapshot), "memory"

    return None, "empty"


def is_stale(snapshot: dict[str, Any]) -> bool:
    value = snapshot.get("generated_at")

    if not value:
        return True

    try:
        generated = datetime.fromisoformat(
            str(value).replace("Z", "+00:00")
        )
    except ValueError:
        return True

    age = (
        datetime.now(timezone.utc) - generated
    ).total_seconds()

    return age > settings.status_cache_ttl_seconds
