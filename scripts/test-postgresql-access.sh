#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly SECRET_CONTAINER_PATH="/tmp/ssc-postgresql-access-test.env"

SECRET_HOST_FILE=""
POSTGRES_CONTAINER_ID=""
MISSION_CONTROL_CONTAINER_ID=""
MISSION_CONTROL_UID=""
MISSION_CONTROL_GID=""

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

env_get() {
  local key=$1

  python3 - "${ENV_FILE}" "${key}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
target = sys.argv[2]

for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()

    if not line or line.startswith("#") or "=" not in line:
        continue

    key, value = line.split("=", 1)

    if key.strip() == target:
        value = value.strip()

        if (
            len(value) >= 2
            and value[0] == value[-1]
            and value[0] in {'"', "'"}
        ):
            value = value[1:-1]

        print(value)
        break
PY
}

cleanup() {
  if [[ -n "${POSTGRES_CONTAINER_ID}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      rm -f "${SECRET_CONTAINER_PATH}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${MISSION_CONTROL_CONTAINER_ID}" ]]; then
    docker exec \
      "${MISSION_CONTROL_CONTAINER_ID}" \
      rm -f "${SECRET_CONTAINER_PATH}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${SECRET_HOST_FILE}" ]]; then
    rm -f "${SECRET_HOST_FILE}" || true
  fi
}

trap cleanup EXIT

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose config --quiet \
    || fail "Docker Compose integrado inválido."

  POSTGRES_CONTAINER_ID="$(compose ps -q postgres)"
  MISSION_CONTROL_CONTAINER_ID="$(compose ps -q mission-control)"

  [[ -n "${POSTGRES_CONTAINER_ID}" ]] \
    || fail "Container PostgreSQL não encontrado."

  [[ -n "${MISSION_CONTROL_CONTAINER_ID}" ]] \
    || fail "Container Mission Control não encontrado."

  MISSION_CONTROL_UID="$(
    docker exec "${MISSION_CONTROL_CONTAINER_ID}" id -u
  )"
  MISSION_CONTROL_GID="$(
    docker exec "${MISSION_CONTROL_CONTAINER_ID}" id -g
  )"

  local service
  local container_id
  local health

  for service in postgres mission-control; do
    container_id="$(compose ps -q "${service}")"
    health="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "${container_id}"
    )"

    [[ "${health}" == "healthy" ]] \
      || fail "${service} não está healthy: ${health}"
  done
}

prepare_secret_file() {
  local db_name
  local app_user
  local app_password
  local monitor_user
  local monitor_password
  local app_dsn
  local monitor_dsn

  db_name="$(env_get POSTGRES_DB)"
  app_user="$(env_get POSTGRES_APP_USER)"
  app_password="$(env_get POSTGRES_APP_PASSWORD)"
  monitor_user="$(env_get POSTGRES_MONITOR_USER)"
  monitor_password="$(env_get POSTGRES_MONITOR_PASSWORD)"

  [[ -n "${db_name}" ]] \
    || fail "POSTGRES_DB não configurado."

  [[ -n "${app_user}" ]] \
    || fail "POSTGRES_APP_USER não configurado."

  [[ -n "${app_password}" ]] \
    || fail "POSTGRES_APP_PASSWORD não configurado."

  [[ -n "${monitor_user}" ]] \
    || fail "POSTGRES_MONITOR_USER não configurado."

  [[ -n "${monitor_password}" ]] \
    || fail "POSTGRES_MONITOR_PASSWORD não configurado."

  case "${app_password}:${monitor_password}" in
    *CHANGE_ME_*)
      fail "Existem credenciais PostgreSQL de exemplo no .env."
      ;;
  esac

  app_dsn="$(
    python3 - \
      "${app_user}" \
      "${app_password}" \
      "${db_name}" <<'PY'
from urllib.parse import quote
import sys

print(
    "postgresql://"
    + quote(sys.argv[1], safe="")
    + ":"
    + quote(sys.argv[2], safe="")
    + "@postgres:5432/"
    + quote(sys.argv[3], safe="")
)
PY
  )"

  monitor_dsn="$(
    python3 - \
      "${monitor_user}" \
      "${monitor_password}" \
      "${db_name}" <<'PY'
from urllib.parse import quote
import sys

print(
    "postgresql://"
    + quote(sys.argv[1], safe="")
    + ":"
    + quote(sys.argv[2], safe="")
    + "@postgres:5432/"
    + quote(sys.argv[3], safe="")
)
PY
  )"

  SECRET_HOST_FILE="$(mktemp)"

  {
    printf 'SSC_DB_NAME=%s\n' "${db_name}"
    printf 'SSC_APP_USER=%s\n' "${app_user}"
    printf 'SSC_APP_DSN=%s\n' "${app_dsn}"
    printf 'SSC_MONITOR_USER=%s\n' "${monitor_user}"
    printf 'SSC_MONITOR_DSN=%s\n' "${monitor_dsn}"
  } > "${SECRET_HOST_FILE}"

  chmod 0600 "${SECRET_HOST_FILE}"

  docker cp \
    "${SECRET_HOST_FILE}" \
    "${POSTGRES_CONTAINER_ID}:${SECRET_CONTAINER_PATH}" \
    >/dev/null

  docker cp \
    "${SECRET_HOST_FILE}" \
    "${MISSION_CONTROL_CONTAINER_ID}:${SECRET_CONTAINER_PATH}" \
    >/dev/null

  docker exec \
    --user 0 \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    chown \
      "${MISSION_CONTROL_UID}:${MISSION_CONTROL_GID}" \
      "${SECRET_CONTAINER_PATH}"

  docker exec \
    --user 0 \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    chmod 0600 "${SECRET_CONTAINER_PATH}"
}

test_role_catalog() {
  info "Validando atributos e privilégios no catálogo."

  docker exec \
    -i \
    "${POSTGRES_CONTAINER_ID}" \
    sh -s <<'SSC_CONTAINER_SHELL'
set -Eeuo pipefail

set -a
. /tmp/ssc-postgresql-access-test.env
set +a

psql \
  -X \
  -v ON_ERROR_STOP=1 \
  -P pager=off \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" <<'SQL'
\getenv db_name SSC_DB_NAME
\getenv app_user SSC_APP_USER
\getenv monitor_user SSC_MONITOR_USER

SELECT
  rolname,
  rolsuper,
  rolcreatedb,
  rolcreaterole,
  rolinherit,
  rolcanlogin,
  rolreplication,
  rolbypassrls,
  rolconnlimit
FROM pg_roles
WHERE rolname IN (
  :'app_user',
  :'monitor_user'
)
ORDER BY rolname;

SELECT
  EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'app_user'
      AND NOT rolsuper
      AND NOT rolcreatedb
      AND NOT rolcreaterole
      AND NOT rolinherit
      AND rolcanlogin
      AND NOT rolreplication
      AND NOT rolbypassrls
      AND rolconnlimit = 20
  ) AS app_role_ok
\gset

\if :app_role_ok
\else
  \echo 'Atributos de companyos_app inválidos.'
  \quit 3
\endif

SELECT
  EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'monitor_user'
      AND NOT rolsuper
      AND NOT rolcreatedb
      AND NOT rolcreaterole
      AND rolinherit
      AND rolcanlogin
      AND NOT rolreplication
      AND NOT rolbypassrls
      AND rolconnlimit = 5
  ) AS monitor_role_ok
\gset

\if :monitor_role_ok
\else
  \echo 'Atributos de companyos_monitor inválidos.'
  \quit 3
\endif

SELECT
  has_database_privilege(
    :'app_user',
    :'db_name',
    'CONNECT'
  )
  AND NOT has_database_privilege(
    :'app_user',
    :'db_name',
    'TEMPORARY'
  )
  AND has_schema_privilege(
    :'app_user',
    'public',
    'USAGE'
  )
  AND NOT has_schema_privilege(
    :'app_user',
    'public',
    'CREATE'
  ) AS app_scope_ok
\gset

\if :app_scope_ok
\else
  \echo 'Escopo de banco ou schema inválido.'
  \quit 4
\endif

SELECT
  count(*) > 0
  AND count(*) = count(*) FILTER (
    WHERE has_table_privilege(
      :'app_user',
      quote_ident(schemaname)
      || '.'
      || quote_ident(tablename),
      'SELECT'
    )
    AND has_table_privilege(
      :'app_user',
      quote_ident(schemaname)
      || '.'
      || quote_ident(tablename),
      'INSERT'
    )
    AND has_table_privilege(
      :'app_user',
      quote_ident(schemaname)
      || '.'
      || quote_ident(tablename),
      'UPDATE'
    )
    AND has_table_privilege(
      :'app_user',
      quote_ident(schemaname)
      || '.'
      || quote_ident(tablename),
      'DELETE'
    )
    AND NOT has_table_privilege(
      :'app_user',
      quote_ident(schemaname)
      || '.'
      || quote_ident(tablename),
      'TRUNCATE'
    )
  ) AS app_tables_ok
FROM pg_tables
WHERE schemaname = 'public'
\gset

\if :app_tables_ok
\else
  \echo 'Privilégios de tabelas inválidos.'
  \quit 5
\endif

SELECT
  count(*) > 0
  AND count(*) = count(*) FILTER (
    WHERE has_sequence_privilege(
      :'app_user',
      quote_ident(sequence_schema)
      || '.'
      || quote_ident(sequence_name),
      'USAGE'
    )
    AND has_sequence_privilege(
      :'app_user',
      quote_ident(sequence_schema)
      || '.'
      || quote_ident(sequence_name),
      'SELECT'
    )
  ) AS app_sequences_ok
FROM information_schema.sequences
WHERE sequence_schema = 'public'
\gset

\if :app_sequences_ok
\else
  \echo 'Privilégios de sequências inválidos.'
  \quit 6
\endif

SELECT
  pg_has_role(
    :'monitor_user',
    'pg_monitor',
    'USAGE'
  )
  AND NOT has_table_privilege(
    :'monitor_user',
    'public.users',
    'SELECT'
  ) AS monitor_scope_ok
\gset

\if :monitor_scope_ok
\else
  \echo 'Escopo do monitor inválido.'
  \quit 7
\endif
SQL
SSC_CONTAINER_SHELL

  ok "Catálogo de papéis e privilégios validado."
}

test_connections() {
  info "Testando conexões da aplicação e do monitor."

  docker exec \
    -i \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    sh -s <<'SSC_CONTAINER_SHELL'
set -Eeuo pipefail

set -a
. /tmp/ssc-postgresql-access-test.env
set +a

python - <<'PY'
from __future__ import annotations

import os
from urllib.parse import urlsplit
import urllib.request

import psycopg
from psycopg import errors
from sqlalchemy import text

from app.database import engine


app_user = os.environ["SSC_APP_USER"]
monitor_user = os.environ["SSC_MONITOR_USER"]

with engine.connect() as connection:
    current_user = connection.execute(
        text("select current_user")
    ).scalar_one()

    assert current_user == app_user, (
        f"Mission Control usa {current_user}, "
        f"esperado {app_user}"
    )

    connection.execute(
        text("select count(*) from public.users")
    ).scalar_one()

with psycopg.connect(
    os.environ["SSC_APP_DSN"],
    autocommit=True,
) as connection:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
              current_user,
              current_setting('statement_timeout')::interval
                = interval '30 seconds',
              current_setting('lock_timeout')::interval
                = interval '5 seconds',
              current_setting(
                'idle_in_transaction_session_timeout'
              )::interval = interval '60 seconds',
              rolsuper,
              rolcreatedb,
              rolcreaterole,
              rolinherit,
              rolreplication,
              rolbypassrls,
              rolconnlimit
            FROM pg_roles
            WHERE rolname = current_user
            """
        )

        assert cursor.fetchone() == (
            app_user,
            True,
            True,
            True,
            False,
            False,
            False,
            False,
            False,
            False,
            20,
        )

        cursor.execute(
            """
            SELECT
              has_database_privilege(
                current_user,
                current_database(),
                'CONNECT'
              ),
              has_database_privilege(
                current_user,
                current_database(),
                'TEMPORARY'
              ),
              has_schema_privilege(
                current_user,
                'public',
                'USAGE'
              ),
              has_schema_privilege(
                current_user,
                'public',
                'CREATE'
              ),
              has_table_privilege(
                current_user,
                'public.users',
                'SELECT'
              ),
              has_table_privilege(
                current_user,
                'public.users',
                'INSERT'
              ),
              has_table_privilege(
                current_user,
                'public.users',
                'UPDATE'
              ),
              has_table_privilege(
                current_user,
                'public.users',
                'DELETE'
              ),
              has_table_privilege(
                current_user,
                'public.users',
                'TRUNCATE'
              )
            """
        )

        assert cursor.fetchone() == (
            True,
            False,
            True,
            False,
            True,
            True,
            True,
            True,
            False,
        )

        try:
            cursor.execute(
                """
                CREATE TABLE public.ssc_forbidden_test (
                  id integer
                )
                """
            )
        except errors.InsufficientPrivilege:
            pass
        else:
            cursor.execute(
                "DROP TABLE public.ssc_forbidden_test"
            )
            raise AssertionError(
                "Usuário da aplicação conseguiu criar tabela."
            )

with psycopg.connect(
    os.environ["SSC_MONITOR_DSN"],
    autocommit=True,
) as connection:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
              current_user,
              current_setting(
                'transaction_read_only'
              ),
              pg_has_role(
                current_user,
                'pg_monitor',
                'MEMBER'
              ),
              pg_has_role(
                current_user,
                'pg_monitor',
                'USAGE'
              ),
              rolinherit,
              rolconnlimit
            FROM pg_roles
            WHERE rolname = current_user
            """
        )

        assert cursor.fetchone() == (
            monitor_user,
            "on",
            True,
            True,
            True,
            5,
        )

        try:
            cursor.execute(
                "SELECT count(*) FROM public.users"
            )
        except errors.InsufficientPrivilege:
            pass
        else:
            raise AssertionError(
                "companyos_monitor conseguiu acessar "
                "uma tabela de negócio."
            )

        cursor.execute(
            "SELECT count(*) FROM pg_stat_activity"
        )
        assert cursor.fetchone()[0] >= 1

with urllib.request.urlopen(
    "http://127.0.0.1:8080/health",
    timeout=5,
) as response:
    assert response.status == 200

with urllib.request.urlopen(
    "http://127.0.0.1:8080/branding/theme.css",
    timeout=5,
) as response:
    assert response.status == 200
    assert response.headers.get_content_type() == "text/css"

with urllib.request.urlopen(
    "http://127.0.0.1:8080/branding/logo",
    timeout=5,
) as response:
    assert response.status == 200
    assert response.headers.get_content_type().startswith(
        "image/"
    )
    assert response.read(16)

configured_url = os.environ.get("DATABASE_URL", "")
parsed = urlsplit(configured_url)
assert parsed.username == app_user

print("[OK] Mission Control conectado com privilégio mínimo.")
print("[OK] Monitoramento conectado em modo somente leitura.")
print("[OK] Health check e Aparência preservados.")
PY
SSC_CONTAINER_SHELL

  ok "Conexões e aplicação validadas."
}

main() {
  check_requirements
  prepare_secret_file
  test_role_catalog
  test_connections

  printf '\n'
  ok "Acesso operacional do PostgreSQL validado."
}

main "$@"
