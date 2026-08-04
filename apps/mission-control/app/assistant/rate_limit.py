from __future__ import annotations

import threading
import time
from collections import defaultdict, deque
from dataclasses import dataclass

import redis

from app.config import settings


@dataclass(frozen=True)
class RateLimitResult:
    allowed: bool
    remaining: int
    backend: str


_local_lock = threading.Lock()
_local_requests: dict[str, deque[float]] = defaultdict(deque)


def _local_limit(
    user_id: str,
    *,
    limit: int,
    window_seconds: int,
) -> RateLimitResult:
    now = time.monotonic()
    threshold = now - window_seconds

    with _local_lock:
        requests = _local_requests[user_id]

        while requests and requests[0] <= threshold:
            requests.popleft()

        if len(requests) >= limit:
            return RateLimitResult(
                allowed=False,
                remaining=0,
                backend="memory",
            )

        requests.append(now)

        return RateLimitResult(
            allowed=True,
            remaining=max(0, limit - len(requests)),
            backend="memory",
        )


def consume(
    user_id: str,
    *,
    limit: int = 20,
    window_seconds: int = 60,
) -> RateLimitResult:
    window = int(time.time() // window_seconds)
    key = f"ssc:rate:assistant:{user_id}:{window}"
    client: redis.Redis | None = None

    try:
        client = redis.Redis.from_url(
            settings.redis_url,
            socket_connect_timeout=1,
            socket_timeout=1,
            decode_responses=True,
        )

        pipeline = client.pipeline(transaction=True)
        pipeline.incr(key)
        pipeline.expire(key, window_seconds + 5)
        count, _ = pipeline.execute()
        numeric_count = int(count)

        return RateLimitResult(
            allowed=numeric_count <= limit,
            remaining=max(0, limit - numeric_count),
            backend="redis",
        )
    except Exception:
        return _local_limit(
            user_id,
            limit=limit,
            window_seconds=window_seconds,
        )
    finally:
        if client is not None:
            client.close()
