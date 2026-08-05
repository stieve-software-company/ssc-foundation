#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPORT_ROOT="${PROJECT_ROOT}/infrastructure/backups/local-artifacts"
readonly TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly REPORT_DIR="${REPORT_ROOT}/mission-control-v0-4-foundation-v1-1-test-${TIMESTAMP}"
readonly REPORT_FILE="${REPORT_DIR}/mission-control-v0-4-foundation-v1-1-test.txt"

FAILURES=0

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file .env \
      -f compose.yaml \
      -f compose.access.yaml \
      -f compose.observability.yaml \
      --profile observability \
      "$@"
  )
}

pass() {
  printf '[PASS] %s\n' "$*"
}

fail_check() {
  printf '[FAIL] %s\n' "$*"
  FAILURES=$((FAILURES + 1))
}

section() {
  printf '\n'
  printf '============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

initialize_report() {
  install -d -m 0700 "${REPORT_DIR}"
  : > "${REPORT_FILE}"
  chmod 0600 "${REPORT_FILE}"

  exec > >(tee "${REPORT_FILE}") 2>&1
}

test_container() {
  section "CONTAINER"

  local id
  id="$(compose ps -q mission-control)"

  if [[ -z "${id}" ]]; then
    fail_check "Container ausente."
    return
  fi

  local state
  local health

  state="$(
    docker inspect \
      --format '{{.State.Status}}' \
      "${id}"
  )"

  health="$(
    docker inspect \
      --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "${id}"
  )"

  if [[ "${state}" == "running" && "${health}" == "healthy" ]]; then
    pass "Mission Control running / healthy."
  else
    fail_check "Mission Control ${state} / ${health}."
  fi

  local socket
  socket="$(
    docker inspect \
      --format \
      '{{range .Mounts}}{{if eq .Destination "/var/run/docker.sock"}}yes{{end}}{{end}}' \
      "${id}"
  )"

  if [[ -z "${socket}" ]]; then
    pass "Mission Control sem Docker Socket."
  else
    fail_check "Mission Control possui Docker Socket."
  fi

  if docker inspect \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    "${id}" |
    grep -Eq \
      '^(POSTGRES_MIGRATOR_PASSWORD|SSC_MIGRATION_ROLE)='; then
    fail_check "Runtime recebeu credencial de migração."
  else
    pass "Runtime sem credencial de migração."
  fi
}

test_health() {
  section "HEALTH"

  local payload

  payload="$(
    curl \
      --silent \
      --show-error \
      --fail \
      --max-time 10 \
      http://127.0.0.1:8080/health
  )"

  printf '%s\n' "${payload}"

  if grep -Fq '"version":"0.4.0"' <<< "${payload}"; then
    pass "Health reporta versão 0.4.0."
  else
    fail_check "Versão 0.4.0 ausente."
  fi

  if grep -Fq '"database":"connected"' <<< "${payload}"; then
    pass "Banco conectado."
  else
    fail_check "Banco não conectado."
  fi
}

test_unauthenticated_api() {
  section "UNAUTHENTICATED API"

  local endpoint
  local code

  for endpoint in \
    /api/v1/me \
    /api/v1/system/summary \
    /api/v1/system/events; do
    code="$(
      curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --max-time 10 \
        "http://127.0.0.1:8080${endpoint}"
    )"

    if [[ "${code}" == "401" ]]; then
      pass "${endpoint} protege autenticação."
    else
      fail_check "${endpoint} retornou HTTP ${code}."
    fi
  done
}

test_internal_runtime() {
  section "INTERNAL APPLICATION"

  local id
  id="$(compose ps -q mission-control)"

  if docker exec -i "${id}" python - <<'PY'
from __future__ import annotations

import json
import time
import urllib.request

from sqlalchemy import func, select

from app.auth import COOKIE_NAME, create_session_token
from app.database import SessionLocal
from app.foundation.collector import get_status_summary
from app.migration_manager import (
    HEAD_REVISION,
    current_revision,
)
from app.models import ServiceDefinition, User


deadline = time.monotonic() + 35
summary = {}

while time.monotonic() < deadline:
    summary = get_status_summary()

    if (
        summary.get("state") == "ready"
        and summary.get("cache_backend") == "redis"
    ):
        break

    time.sleep(1)

result = {
    "migration": {
        "current": current_revision(),
        "expected": HEAD_REVISION,
    },
    "service_definitions": 0,
    "summary": summary,
    "http": {},
}

with SessionLocal() as db:
    result["service_definitions"] = int(
        db.scalar(
            select(func.count(ServiceDefinition.id))
        )
        or 0
    )

    user = db.scalar(
        select(User)
        .where(User.is_active.is_(True))
        .order_by(User.created_at)
        .limit(1)
    )

    if user is None:
        raise RuntimeError("Nenhum usuário ativo.")

    token = create_session_token(user)

headers = {
    "Cookie": f"{COOKIE_NAME}={token}",
    "User-Agent": "SSC-Foundation-Test/1.1",
}

for endpoint in (
    "/api/v1/me",
    "/api/v1/system/summary",
    "/app",
    "/system",
    "/assistant",
    "/branding",
):
    request = urllib.request.Request(
        f"http://127.0.0.1:8080{endpoint}",
        headers=headers,
    )
    started = time.perf_counter()

    with urllib.request.urlopen(
        request,
        timeout=15,
    ) as response:
        body = response.read()
        result["http"][endpoint] = {
            "status": response.status,
            "elapsed_ms": round(
                (time.perf_counter() - started) * 1000,
                2,
            ),
            "bytes": len(body),
        }

request = urllib.request.Request(
    "http://127.0.0.1:8080/api/v1/system/events",
    headers=headers,
)

with urllib.request.urlopen(
    request,
    timeout=15,
) as response:
    event_lines = []

    for _ in range(20):
        line = response.readline().decode(
            "utf-8",
            errors="replace",
        )
        event_lines.append(line)

        if "event: system.summary" in "".join(event_lines):
            break

    result["sse"] = {
        "status": response.status,
        "system_summary_event": (
            "event: system.summary"
            in "".join(event_lines)
        ),
    }

print(json.dumps(result, indent=2))

if result["migration"]["current"] != HEAD_REVISION:
    raise SystemExit(10)

if result["service_definitions"] != 5:
    raise SystemExit(11)

if result["summary"].get("state") != "ready":
    raise SystemExit(12)

if result["summary"].get("cache_backend") != "redis":
    raise SystemExit(13)

if len(result["summary"].get("services", [])) != 5:
    raise SystemExit(14)

for endpoint, data in result["http"].items():
    if data["status"] != 200:
        raise SystemExit(15)

if not result["sse"]["system_summary_event"]:
    raise SystemExit(16)
PY
  then
    pass "Migração, registry, cache, páginas, API e SSE validados."
  else
    fail_check "Validação interna falhou."
  fi
}

test_postgresql_security() {
  section "POSTGRESQL SECURITY"

  local postgres_id
  postgres_id="$(compose ps -q postgres)"

  if docker exec -i "${postgres_id}" sh -ec '
    exec psql \
      --no-psqlrc \
      --set ON_ERROR_STOP=1 \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --tuples-only \
      --no-align
  ' <<'SQL'
SELECT
    'database_owner='
    || pg_get_userbyid(datdba)
FROM pg_database
WHERE datname = current_database();

SELECT
    tablename || '=' || tableowner
FROM pg_tables
WHERE
    schemaname = 'public'
    AND tablename IN (
        'permissions',
        'roles',
        'role_permissions',
        'users',
        'audit_events',
        'branding_settings',
        'alembic_version',
        'service_definitions'
    )
ORDER BY tablename;

SELECT
    'app_create='
    || has_schema_privilege(
        'companyos_app',
        'public',
        'CREATE'
    );

SELECT
    'app_service_select='
    || has_table_privilege(
        'companyos_app',
        'public.service_definitions',
        'SELECT'
    );

SELECT
    'app_alembic_insert='
    || has_table_privilege(
        'companyos_app',
        'public.alembic_version',
        'INSERT'
    );

SELECT
    'migrator='
    || rolcanlogin
    || ','
    || rolsuper
    || ','
    || rolcreatedb
    || ','
    || rolcreaterole
    || ','
    || rolinherit
FROM pg_roles
WHERE rolname = 'companyos_migrator';
SQL
  then
    pass "Privilégios e propriedades consultados."
  else
    fail_check "Consulta de segurança PostgreSQL falhou."
    return
  fi

  local checks

  checks="$(
    docker exec -i "${postgres_id}" sh -ec '
      exec psql \
        --no-psqlrc \
        --set ON_ERROR_STOP=1 \
        --username "$POSTGRES_USER" \
        --dbname "$POSTGRES_DB" \
        --tuples-only \
        --no-align
    ' <<'SQL'
SELECT
    (
        SELECT pg_get_userbyid(datdba)
        FROM pg_database
        WHERE datname = current_database()
    ) = 'companyos_owner';

SELECT count(*) = 8
FROM pg_tables
WHERE
    schemaname = 'public'
    AND tableowner = 'companyos_owner'
    AND tablename IN (
        'permissions',
        'roles',
        'role_permissions',
        'users',
        'audit_events',
        'branding_settings',
        'alembic_version',
        'service_definitions'
    );

SELECT NOT has_schema_privilege(
    'companyos_app',
    'public',
    'CREATE'
);

SELECT has_table_privilege(
    'companyos_app',
    'public.service_definitions',
    'SELECT,INSERT,UPDATE,DELETE'
);

SELECT NOT has_table_privilege(
    'companyos_app',
    'public.alembic_version',
    'INSERT'
);

SELECT
    rolcanlogin
    AND NOT rolsuper
    AND NOT rolcreatedb
    AND NOT rolcreaterole
    AND NOT rolinherit
FROM pg_roles
WHERE rolname = 'companyos_migrator';
SQL
  )"

  if [[ "$(grep -c '^t$' <<< "${checks}")" -eq 6 ]]; then
    pass "Modelo owner/migrator/runtime validado."
  else
    printf '%s\n' "${checks}"
    fail_check "Modelo PostgreSQL divergente."
  fi
}

test_source() {
  section "SOURCE"

  if grep -Fq \
    'service_statuses = collect_statuses()' \
    "${PROJECT_ROOT}/apps/mission-control/app/main.py"; then
    fail_check "Dashboard ainda executa collect_statuses."
  else
    pass "Dashboard usa snapshot em cache."
  fi

  if grep -Fq \
    'Base.metadata.create_all' \
    "${PROJECT_ROOT}/apps/mission-control/app/bootstrap.py"; then
    fail_check "Bootstrap ainda usa create_all."
  else
    pass "Bootstrap sem DDL."
  fi

  if grep -Fq \
    'upgrade_database()' \
    "${PROJECT_ROOT}/apps/mission-control/app/bootstrap.py"; then
    fail_check "Startup ainda executa migração."
  else
    pass "Migração fora do startup."
  fi

  if [[ -f \
    "${PROJECT_ROOT}/apps/mission-control/app/static/dashboard-live.js" ]]; then
    pass "Cliente SSE presente."
  else
    fail_check "Cliente SSE ausente."
  fi
}

summary() {
  section "FINAL RESULT"

  printf 'failures=%d\n' "${FAILURES}"

  if (( FAILURES == 0 )); then
    printf 'FINAL_RESULT=PASS\n'
  else
    printf 'FINAL_RESULT=FAIL\n'
  fi

  printf 'report=%s\n' "${REPORT_FILE}"
}

main() {
  initialize_report

  printf 'SSC Mission Control v0.4 Foundation Test v1.1\n'
  printf 'generated_at=%s\n' "$(date --iso-8601=seconds)"

  test_container
  test_health
  test_unauthenticated_api
  test_internal_runtime
  test_postgresql_security
  test_source
  summary

  if (( FAILURES > 0 )); then
    exit 1
  fi
}

main "$@"
