#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly POSTGRES_SECRET_PATH="/tmp/ssc-postgresql-operational.env"
readonly MISSION_CONTROL_SECRET_PATH="/tmp/ssc-postgresql-operational.env"

ENV_BACKUP=""
SECRET_HOST_FILE=""
POSTGRES_CONTAINER_ID=""
MISSION_CONTROL_CONTAINER_ID=""
MISSION_CONTROL_UID=""
MISSION_CONTROL_GID=""
ENV_UPDATED=false
CONFIGURATION_SUCCEEDED=false

info() {
  printf '[INFO] %s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[AVISO] %s\n' "$*" >&2
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
from __future__ import annotations

from pathlib import Path
import sys


path = Path(sys.argv[1])
target = sys.argv[2]
value = ""

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()

    if not line or line.startswith("#") or "=" not in line:
        continue

    key, candidate = line.split("=", 1)

    if key.strip() != target:
        continue

    candidate = candidate.strip()

    if (
        len(candidate) >= 2
        and candidate[0] == candidate[-1]
        and candidate[0] in {'"', "'"}
    ):
        candidate = candidate[1:-1]

    value = candidate

print(value)
PY
}

generate_secret() {
  python3 - <<'PY'
import secrets

print(secrets.token_urlsafe(36))
PY
}

validate_role_name() {
  local value=$1
  local label=$2

  if ! [[ "${value}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]]; then
    fail "${label} possui um nome inválido: ${value}"
  fi
}

cleanup() {
  if [[ -n "${POSTGRES_CONTAINER_ID}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      rm -f "${POSTGRES_SECRET_PATH}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${MISSION_CONTROL_CONTAINER_ID}" ]]; then
    docker exec \
      "${MISSION_CONTROL_CONTAINER_ID}" \
      rm -f "${MISSION_CONTROL_SECRET_PATH}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${SECRET_HOST_FILE}" ]]; then
    rm -f "${SECRET_HOST_FILE}" || true
  fi

  if [[ -n "${ENV_BACKUP}" ]]; then
    rm -f "${ENV_BACKUP}" || true
  fi
}

rollback_env() {
  if [[ "${ENV_UPDATED}" != "true" ]] ||
     [[ -z "${ENV_BACKUP}" ]] ||
     [[ ! -s "${ENV_BACKUP}" ]]; then
    return
  fi

  warn "Restaurando o .env anterior."

  cp "${ENV_BACKUP}" "${ENV_FILE}"
  chmod 0600 "${ENV_FILE}"
  ENV_UPDATED=false

  compose up \
    -d \
    --no-deps \
    --force-recreate \
    --wait \
    --wait-timeout 240 \
    mission-control \
    || warn "O rollback do Mission Control precisa de verificação manual."
}

on_error() {
  local exit_code=$?

  trap - ERR
  warn "A configuração não foi concluída."
  rollback_env
  cleanup
  exit "${exit_code}"
}

on_signal() {
  local exit_code=$1

  trap - ERR INT TERM
  warn "Execução interrompida."
  rollback_env
  cleanup
  exit "${exit_code}"
}

trap on_error ERR
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${BASE_COMPOSE}" ]] \
    || fail "Arquivo ausente ou vazio: ${BASE_COMPOSE}"

  [[ -s "${ACCESS_COMPOSE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ACCESS_COMPOSE}"

  [[ -x "${SCRIPT_DIR}/test-postgresql-access.sh" ]] \
    || fail "Script de teste ausente ou sem execução."

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

  local postgres_health
  local mission_control_health

  postgres_health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${POSTGRES_CONTAINER_ID}"
  )"

  mission_control_health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${MISSION_CONTROL_CONTAINER_ID}"
  )"

  [[ "${postgres_health}" == "healthy" ]] \
    || fail "PostgreSQL não está healthy: ${postgres_health}"

  [[ "${mission_control_health}" == "healthy" ]] \
    || fail "Mission Control não está healthy: ${mission_control_health}"
}

prepare_values() {
  DB_NAME="$(env_get POSTGRES_DB)"
  ADMIN_USER="$(env_get POSTGRES_USER)"
  APP_USER="$(env_get POSTGRES_APP_USER)"
  APP_PASSWORD="$(env_get POSTGRES_APP_PASSWORD)"
  MONITOR_USER="$(env_get POSTGRES_MONITOR_USER)"
  MONITOR_PASSWORD="$(env_get POSTGRES_MONITOR_PASSWORD)"

  DB_NAME="${DB_NAME:-companyos}"
  ADMIN_USER="${ADMIN_USER:-companyos}"
  APP_USER="${APP_USER:-companyos_app}"
  MONITOR_USER="${MONITOR_USER:-companyos_monitor}"

  case "${APP_PASSWORD}" in
    ""|CHANGE_ME_*)
      APP_PASSWORD="$(generate_secret)"
      ;;
  esac

  case "${MONITOR_PASSWORD}" in
    ""|CHANGE_ME_*)
      MONITOR_PASSWORD="$(generate_secret)"
      ;;
  esac

  validate_role_name "${DB_NAME}" "POSTGRES_DB"
  validate_role_name "${ADMIN_USER}" "POSTGRES_USER"
  validate_role_name "${APP_USER}" "POSTGRES_APP_USER"
  validate_role_name "${MONITOR_USER}" "POSTGRES_MONITOR_USER"

  [[ "${APP_USER}" != "${ADMIN_USER}" ]] \
    || fail "O usuário da aplicação não pode ser o administrador."

  [[ "${MONITOR_USER}" != "${ADMIN_USER}" ]] \
    || fail "O usuário de monitoramento não pode ser o administrador."

  [[ "${MONITOR_USER}" != "${APP_USER}" ]] \
    || fail "Aplicação e monitoramento precisam de usuários diferentes."

  APP_DSN="$(
    python3 - \
      "${APP_USER}" \
      "${APP_PASSWORD}" \
      "${DB_NAME}" <<'PY'
from urllib.parse import quote
import sys

user = quote(sys.argv[1], safe="")
password = quote(sys.argv[2], safe="")
database = quote(sys.argv[3], safe="")

print(
    f"postgresql://{user}:{password}"
    f"@postgres:5432/{database}"
)
PY
  )"

  APP_DATABASE_URL="$(
    python3 - \
      "${APP_USER}" \
      "${APP_PASSWORD}" \
      "${DB_NAME}" <<'PY'
from urllib.parse import quote
import sys

user = quote(sys.argv[1], safe="")
password = quote(sys.argv[2], safe="")
database = quote(sys.argv[3], safe="")

print(
    f"postgresql+psycopg://{user}:{password}"
    f"@postgres:5432/{database}"
)
PY
  )"

  MONITOR_DSN="$(
    python3 - \
      "${MONITOR_USER}" \
      "${MONITOR_PASSWORD}" \
      "${DB_NAME}" <<'PY'
from urllib.parse import quote
import sys

user = quote(sys.argv[1], safe="")
password = quote(sys.argv[2], safe="")
database = quote(sys.argv[3], safe="")

print(
    f"postgresql://{user}:{password}"
    f"@postgres:5432/{database}"
)
PY
  )"
}

prepare_secret_file() {
  SECRET_HOST_FILE="$(mktemp)"

  {
    printf 'SSC_DB_NAME=%s\n' "${DB_NAME}"
    printf 'SSC_ADMIN_USER=%s\n' "${ADMIN_USER}"
    printf 'SSC_APP_USER=%s\n' "${APP_USER}"
    printf 'SSC_APP_PASSWORD=%s\n' "${APP_PASSWORD}"
    printf 'SSC_MONITOR_USER=%s\n' "${MONITOR_USER}"
    printf 'SSC_MONITOR_PASSWORD=%s\n' "${MONITOR_PASSWORD}"
    printf 'SSC_APP_DSN=%s\n' "${APP_DSN}"
    printf 'SSC_APP_DATABASE_URL=%s\n' "${APP_DATABASE_URL}"
    printf 'SSC_MONITOR_DSN=%s\n' "${MONITOR_DSN}"
  } > "${SECRET_HOST_FILE}"

  chmod 0600 "${SECRET_HOST_FILE}"

  docker cp \
    "${SECRET_HOST_FILE}" \
    "${POSTGRES_CONTAINER_ID}:${POSTGRES_SECRET_PATH}" \
    >/dev/null

  docker cp \
    "${SECRET_HOST_FILE}" \
    "${MISSION_CONTROL_CONTAINER_ID}:${MISSION_CONTROL_SECRET_PATH}" \
    >/dev/null

  docker exec \
    --user 0 \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    chown \
      "${MISSION_CONTROL_UID}:${MISSION_CONTROL_GID}" \
      "${MISSION_CONTROL_SECRET_PATH}"

  docker exec \
    --user 0 \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    chmod 0600 "${MISSION_CONTROL_SECRET_PATH}"
}

configure_roles() {
  info "Criando e configurando os papéis PostgreSQL."

  docker exec \
    -i \
    "${POSTGRES_CONTAINER_ID}" \
    sh -s <<'SSC_CONTAINER_SHELL'
set -Eeuo pipefail

set -a
. /tmp/ssc-postgresql-operational.env
set +a

psql \
  -X \
  -v ON_ERROR_STOP=1 \
  -P pager=off \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" <<'SQL'
\getenv db_name SSC_DB_NAME
\getenv admin_user SSC_ADMIN_USER
\getenv app_user SSC_APP_USER
\getenv app_password SSC_APP_PASSWORD
\getenv monitor_user SSC_MONITOR_USER
\getenv monitor_password SSC_MONITOR_PASSWORD

BEGIN;

SELECT format(
  'CREATE ROLE %I',
  :'app_user'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = :'app_user'
)
\gexec

SELECT format(
  'ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB '
  'NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS '
  'CONNECTION LIMIT 20 PASSWORD %L',
  :'app_user',
  :'app_password'
)
\gexec

SELECT format(
  'CREATE ROLE %I',
  :'monitor_user'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = :'monitor_user'
)
\gexec

SELECT format(
  'ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB '
  'NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS '
  'CONNECTION LIMIT 5 PASSWORD %L',
  :'monitor_user',
  :'monitor_password'
)
\gexec

SELECT format(
  'REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC',
  :'db_name'
)
\gexec

SELECT format(
  'GRANT CONNECT ON DATABASE %I TO %I',
  :'db_name',
  :'app_user'
)
\gexec

SELECT format(
  'GRANT CONNECT ON DATABASE %I TO %I',
  :'db_name',
  :'monitor_user'
)
\gexec

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

SELECT format(
  'GRANT USAGE ON SCHEMA public TO %I',
  :'app_user'
)
\gexec

SELECT format(
  'GRANT SELECT, INSERT, UPDATE, DELETE '
  'ON ALL TABLES IN SCHEMA public TO %I',
  :'app_user'
)
\gexec

SELECT format(
  'GRANT USAGE, SELECT '
  'ON ALL SEQUENCES IN SCHEMA public TO %I',
  :'app_user'
)
\gexec

SELECT format(
  'REVOKE CREATE ON SCHEMA public FROM %I',
  :'app_user'
)
\gexec

SELECT format(
  'REVOKE TEMPORARY ON DATABASE %I FROM %I',
  :'db_name',
  :'app_user'
)
\gexec

SELECT format(
  'REVOKE TRUNCATE, REFERENCES, TRIGGER '
  'ON ALL TABLES IN SCHEMA public FROM %I',
  :'app_user'
)
\gexec

SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I '
  'IN SCHEMA public '
  'GRANT SELECT, INSERT, UPDATE, DELETE '
  'ON TABLES TO %I',
  :'admin_user',
  :'app_user'
)
\gexec

SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I '
  'IN SCHEMA public '
  'GRANT USAGE, SELECT '
  'ON SEQUENCES TO %I',
  :'admin_user',
  :'app_user'
)
\gexec

SELECT format(
  'GRANT pg_monitor TO %I',
  :'monitor_user'
)
\gexec

SELECT format(
  'REVOKE ALL ON SCHEMA public FROM %I',
  :'monitor_user'
)
\gexec

SELECT format(
  'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I',
  :'monitor_user'
)
\gexec

SELECT format(
  'REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I',
  :'monitor_user'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET search_path = pg_catalog, public',
  :'app_user',
  :'db_name'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET statement_timeout = %L',
  :'app_user',
  :'db_name',
  '30s'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET lock_timeout = %L',
  :'app_user',
  :'db_name',
  '5s'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET idle_in_transaction_session_timeout = %L',
  :'app_user',
  :'db_name',
  '60s'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET search_path = pg_catalog',
  :'monitor_user',
  :'db_name'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET default_transaction_read_only = on',
  :'monitor_user',
  :'db_name'
)
\gexec

SELECT format(
  'ALTER ROLE %I IN DATABASE %I '
  'SET statement_timeout = %L',
  :'monitor_user',
  :'db_name',
  '15s'
)
\gexec

COMMIT;

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
SQL
SSC_CONTAINER_SHELL

  ok "Papéis e privilégios configurados."
}

test_new_credentials_before_switch() {
  info "Testando as novas credenciais antes da troca."

  docker exec \
    -i \
    "${MISSION_CONTROL_CONTAINER_ID}" \
    sh -s <<'SSC_CONTAINER_SHELL'
set -Eeuo pipefail

set -a
. /tmp/ssc-postgresql-operational.env
set +a

python - <<'PY'
from __future__ import annotations

import os

import psycopg
from psycopg import errors


app_user = os.environ["SSC_APP_USER"]
monitor_user = os.environ["SSC_MONITOR_USER"]

with psycopg.connect(
    os.environ["SSC_APP_DSN"],
    autocommit=True,
) as connection:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
              current_user,
              current_database(),
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
            os.environ["SSC_DB_NAME"],
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

        cursor.execute(
            "SELECT count(*) FROM public.users"
        )
        cursor.fetchone()

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
                "companyos_app conseguiu criar tabela."
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
              current_setting(
                'transaction_read_only'
              ),
              rolinherit,
              rolconnlimit
            FROM pg_roles
            WHERE rolname = current_user
            """
        )

        assert cursor.fetchone() == (
            monitor_user,
            True,
            True,
            "on",
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

print("[OK] Credenciais novas validadas antes da troca.")
PY
SSC_CONTAINER_SHELL

  ok "Novas credenciais funcionam com privilégios mínimos."
}

update_private_env() {
  info "Atualizando o .env privado."

  ENV_BACKUP="$(mktemp)"
  cp "${ENV_FILE}" "${ENV_BACKUP}"
  chmod 0600 "${ENV_BACKUP}"

  python3 - \
    "${ENV_FILE}" \
    "${SECRET_HOST_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


env_path = Path(sys.argv[1])
secret_path = Path(sys.argv[2])


def load(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    for raw_line in path.read_text(
        encoding="utf-8"
    ).splitlines():
        line = raw_line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

    return values


secrets = load(secret_path)

updates = {
    "POSTGRES_APP_USER": secrets["SSC_APP_USER"],
    "POSTGRES_APP_PASSWORD": secrets["SSC_APP_PASSWORD"],
    "POSTGRES_MONITOR_USER": secrets["SSC_MONITOR_USER"],
    "POSTGRES_MONITOR_PASSWORD": secrets["SSC_MONITOR_PASSWORD"],
    "DATABASE_URL": secrets["SSC_APP_DATABASE_URL"],
}

lines = env_path.read_text(
    encoding="utf-8"
).splitlines()
seen: set[str] = set()
result: list[str] = []

for raw_line in lines:
    stripped = raw_line.strip()

    if (
        stripped
        and not stripped.startswith("#")
        and "=" in raw_line
    ):
        key = raw_line.split("=", 1)[0].strip()

        if key in updates:
            result.append(f"{key}={updates[key]}")
            seen.add(key)
            continue

    result.append(raw_line)

missing = [
    key
    for key in updates
    if key not in seen
]

if missing:
    result.extend(
        [
            "",
            "# PostgreSQL — acessos operacionais",
        ]
    )

    for key in missing:
        result.append(f"{key}={updates[key]}")

temporary_path = env_path.with_name(
    env_path.name + ".postgresql.tmp"
)

try:
    temporary_path.write_text(
        "\n".join(result).rstrip() + "\n",
        encoding="utf-8",
        newline="\n",
    )
    temporary_path.chmod(0o600)
    temporary_path.replace(env_path)
except Exception:
    temporary_path.unlink(missing_ok=True)
    raise
PY

  chmod 0600 "${ENV_FILE}"
  ENV_UPDATED=true

  ok ".env atualizado sem exibir credenciais."
}

restart_mission_control() {
  info "Recriando somente o Mission Control."

  compose up \
    -d \
    --no-deps \
    --force-recreate \
    --wait \
    --wait-timeout 240 \
    mission-control

  MISSION_CONTROL_CONTAINER_ID="$(compose ps -q mission-control)"

  ok "Mission Control recriado."
}

run_final_tests() {
  "${SCRIPT_DIR}/test-postgresql-access.sh"
}

main() {
  check_requirements
  prepare_values
  prepare_secret_file
  configure_roles
  test_new_credentials_before_switch
  update_private_env
  restart_mission_control
  run_final_tests

  CONFIGURATION_SUCCEEDED=true
  ENV_UPDATED=false

  printf '\n'
  ok "PostgreSQL com acesso operacional configurado."
  printf 'Mission Control agora utiliza: %s\n' "${APP_USER}"
  printf 'Nenhuma senha foi exibida.\n'
}

main "$@"
