#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"

info() {
  printf '[INFO] %s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      "$@"
  )
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose ps --status running redis |
    grep -q redis \
    || fail "Redis não está em execução."

  compose ps --status running mission-control |
    grep -q mission-control \
    || fail "Mission Control não está em execução."
}

run_functional_test() {
  info "Executando testes do Redis pelo Mission Control."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
from __future__ import annotations

import json
import time
import uuid

import redis

from app.config import settings


prefix = f"ssc:test:{uuid.uuid4()}"
created_keys: set[str] = set()


def remember(key: str) -> str:
    created_keys.add(key)
    return key


client = redis.Redis.from_url(
    settings.redis_url,
    decode_responses=True,
    socket_connect_timeout=5,
    socket_timeout=5,
)

try:
    assert client.ping() is True
    print("[OK] Autenticação e PING validados.")

    connection = client.connection_pool.connection_kwargs
    host = str(connection.get("host", "redis"))
    port = int(connection.get("port", 6379))
    db = int(connection.get("db", 0))

    assert db == 0, f"Banco lógico inesperado: {db}"

    unauthenticated = redis.Redis(
        host=host,
        port=port,
        db=db,
        decode_responses=True,
        socket_connect_timeout=3,
        socket_timeout=3,
    )

    try:
        unauthenticated.ping()
    except redis.exceptions.AuthenticationError:
        print("[OK] Acesso sem autenticação foi rejeitado.")
    else:
        raise RuntimeError("Redis aceitou conexão sem senha.")
    finally:
        unauthenticated.close()

    config: dict[str, str] = {}

    for parameter in (
        "appendonly",
        "appendfsync",
        "aof-use-rdb-preamble",
        "maxmemory",
        "maxmemory-policy",
        "protected-mode",
        "bind",
    ):
        config.update(client.config_get(parameter))

    expected = {
        "appendonly": "yes",
        "appendfsync": "everysec",
        "aof-use-rdb-preamble": "yes",
        "maxmemory-policy": "noeviction",
        "protected-mode": "yes",
    }

    for key, value in expected.items():
        actual = str(config.get(key, ""))
        assert actual == value, f"{key}: esperado {value}, atual {actual}"

    assert int(config.get("maxmemory", 0)) > 0
    assert "0.0.0.0" in str(config.get("bind", ""))

    persistence = client.info("persistence")
    assert int(persistence.get("aof_enabled", 0)) == 1
    assert persistence.get("rdb_last_bgsave_status") == "ok"
    assert persistence.get("aof_last_bgrewrite_status") == "ok"

    print("[OK] Persistência, memória e protected mode validados.")

    data_key = remember(f"{prefix}:namespace")
    value = json.dumps(
        {"service": "companyos", "test": "namespace"},
        separators=(",", ":"),
    )

    assert client.set(data_key, value, ex=60) is True
    assert client.get(data_key) == value
    assert client.ttl(data_key) > 0
    print("[OK] Namespace, SET, GET e TTL validados.")

    expiring_key = remember(f"{prefix}:expiration")
    assert client.set(expiring_key, "temporary", ex=2) is True
    assert client.exists(expiring_key) == 1

    time.sleep(2.5)

    assert client.exists(expiring_key) == 0
    print("[OK] Expiração real validada.")

    lock_key = remember(f"{prefix}:lock")
    lock_token = str(uuid.uuid4())

    assert client.set(lock_key, lock_token, nx=True, px=30_000) is True
    assert client.set(lock_key, "other-owner", nx=True, px=30_000) is None

    release_script = """
    if redis.call('get', KEYS[1]) == ARGV[1] then
      return redis.call('del', KEYS[1])
    end
    return 0
    """

    released = client.eval(
        release_script,
        1,
        lock_key,
        lock_token,
    )
    assert released == 1
    created_keys.discard(lock_key)
    print("[OK] Lock NX e liberação por token validados.")

    idempotency_key = remember(f"{prefix}:idempotency")
    assert client.set(
        idempotency_key,
        "processing",
        nx=True,
        ex=86_400,
    ) is True
    assert client.set(
        idempotency_key,
        "duplicate",
        nx=True,
        ex=86_400,
    ) is None
    print("[OK] Controle de idempotência validado.")

    counter_key = remember(f"{prefix}:counter")
    pipeline = client.pipeline(transaction=True)
    pipeline.incr(counter_key)
    pipeline.incr(counter_key)
    pipeline.incr(counter_key)
    pipeline.expire(counter_key, 60)
    results = pipeline.execute()

    assert results[:3] == [1, 2, 3]
    assert results[3] is True
    assert client.get(counter_key) == "3"
    assert client.ttl(counter_key) > 0
    print("[OK] Incremento atômico validado.")

    info = client.info("stats")
    assert int(info.get("evicted_keys", 0)) == 0
    print("[OK] Nenhuma eviction foi registrada.")

finally:
    keys = set(created_keys)
    keys.update(client.scan_iter(match=f"{prefix}:*", count=100))

    if keys:
        client.delete(*keys)

    remaining = list(
        client.scan_iter(match=f"{prefix}:*", count=100)
    )
    assert not remaining, f"Chaves de teste restantes: {remaining}"

    client.close()

print("[OK] Chaves temporárias removidas.")
print("[OK] Testes funcionais Redis concluídos.")
PY
}

test_health() {
  local container_id
  local health

  info "Validando o health check do container."

  container_id="$(compose ps -q redis)"

  [[ -n "${container_id}" ]] \
    || fail "Container Redis não foi encontrado."

  health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${container_id}"
  )"

  [[ "${health}" == "healthy" ]] \
    || fail "Container Redis não está healthy: ${health}"

  ok "Health check do Redis validado."
}

main() {
  check_requirements
  run_functional_test
  test_health

  printf '\n'
  ok "Integração Redis validada."
}

main "$@"
