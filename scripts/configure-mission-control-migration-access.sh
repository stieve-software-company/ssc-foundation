#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly SECRET_CONTAINER_PATH="/tmp/ssc-mission-control-migrator.env"

SECRET_HOST_FILE=""
POSTGRES_CONTAINER_ID=""

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
      -f compose.yaml \
      -f compose.access.yaml \
      -f compose.observability.yaml \
      --profile observability \
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

for raw_line in path.read_text(
    encoding="utf-8"
).splitlines():
    line = raw_line.strip()

    if (
        not line
        or line.startswith("#")
        or "=" not in line
    ):
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

env_set() {
  local key=$1
  local value=$2

  python3 - "${ENV_FILE}" "${key}" "${value}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines()
replacement = f"{key}={value}"
found = False
updated = []

for line in lines:
    if (
        not line.lstrip().startswith("#")
        and "=" in line
        and line.split("=", 1)[0].strip() == key
    ):
        if not found:
            updated.append(replacement)
            found = True
        continue

    updated.append(line)

if not found:
    updated.extend(["", replacement])

path.write_text(
    "\n".join(updated).rstrip() + "\n",
    encoding="utf-8",
    newline="\n",
)
PY
}

generate_secret() {
  python3 - <<'PY'
import secrets

print(secrets.token_urlsafe(48))
PY
}

validate_role_name() {
  local value=$1
  local label=$2

  if ! [[ "${value}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]]; then
    fail "${label} inválido: ${value}"
  fi
}

cleanup() {
  if [[ -n "${POSTGRES_CONTAINER_ID}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      rm -f "${SECRET_CONTAINER_PATH}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${SECRET_HOST_FILE}" ]]; then
    rm -f -- "${SECRET_HOST_FILE}" || true
  fi
}

trap cleanup EXIT

check_environment() {
  [[ -s "${ENV_FILE}" ]] ||
    fail ".env ausente."

  command -v docker >/dev/null 2>&1 ||
    fail "Docker ausente."

  command -v python3 >/dev/null 2>&1 ||
    fail "Python 3 ausente."

  docker info >/dev/null 2>&1 ||
    fail "Docker daemon indisponível."

  compose config --quiet ||
    fail "Compose inválido."

  POSTGRES_CONTAINER_ID="$(compose ps -q postgres)"

  [[ -n "${POSTGRES_CONTAINER_ID}" ]] ||
    fail "Container PostgreSQL ausente."

  local health
  health="$(
    docker inspect \
      --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${POSTGRES_CONTAINER_ID}"
  )"

  [[ "${health}" == "healthy" ]] ||
    fail "PostgreSQL não está healthy: ${health}"
}

prepare_values() {
  DB_NAME="$(env_get POSTGRES_DB)"
  ADMIN_USER="$(env_get POSTGRES_USER)"
  APP_USER="$(env_get POSTGRES_APP_USER)"
  OWNER_ROLE="$(env_get POSTGRES_OWNER_ROLE)"
  MIGRATOR_USER="$(env_get POSTGRES_MIGRATOR_USER)"
  MIGRATOR_PASSWORD="$(env_get POSTGRES_MIGRATOR_PASSWORD)"

  DB_NAME="${DB_NAME:-companyos}"
  ADMIN_USER="${ADMIN_USER:-companyos}"
  APP_USER="${APP_USER:-companyos_app}"
  OWNER_ROLE="${OWNER_ROLE:-companyos_owner}"
  MIGRATOR_USER="${MIGRATOR_USER:-companyos_migrator}"

  case "${MIGRATOR_PASSWORD}" in
    ""|CHANGE_ME_*)
      MIGRATOR_PASSWORD="$(generate_secret)"
      ;;
  esac

  validate_role_name "${DB_NAME}" "POSTGRES_DB"
  validate_role_name "${ADMIN_USER}" "POSTGRES_USER"
  validate_role_name "${APP_USER}" "POSTGRES_APP_USER"
  validate_role_name "${OWNER_ROLE}" "POSTGRES_OWNER_ROLE"
  validate_role_name "${MIGRATOR_USER}" "POSTGRES_MIGRATOR_USER"

  [[ "${OWNER_ROLE}" != "${ADMIN_USER}" ]] ||
    fail "Owner não pode ser o administrador."

  [[ "${MIGRATOR_USER}" != "${APP_USER}" ]] ||
    fail "Migrator não pode ser o runtime."

  [[ "${MIGRATOR_USER}" != "${OWNER_ROLE}" ]] ||
    fail "Migrator e owner precisam ser distintos."

  env_set POSTGRES_OWNER_ROLE "${OWNER_ROLE}"
  env_set POSTGRES_MIGRATOR_USER "${MIGRATOR_USER}"
  env_set POSTGRES_MIGRATOR_PASSWORD "${MIGRATOR_PASSWORD}"

  chmod 0600 "${ENV_FILE}"
}

prepare_secret_file() {
  SECRET_HOST_FILE="$(mktemp)"

  {
    printf 'SSC_DB_NAME=%s\n' "${DB_NAME}"
    printf 'SSC_ADMIN_USER=%s\n' "${ADMIN_USER}"
    printf 'SSC_APP_USER=%s\n' "${APP_USER}"
    printf 'SSC_OWNER_ROLE=%s\n' "${OWNER_ROLE}"
    printf 'SSC_MIGRATOR_USER=%s\n' "${MIGRATOR_USER}"
    printf 'SSC_MIGRATOR_PASSWORD=%s\n' "${MIGRATOR_PASSWORD}"
  } > "${SECRET_HOST_FILE}"

  chmod 0600 "${SECRET_HOST_FILE}"

  docker cp \
    "${SECRET_HOST_FILE}" \
    "${POSTGRES_CONTAINER_ID}:${SECRET_CONTAINER_PATH}" \
    >/dev/null
}

configure_roles_and_ownership() {
  info "Configurando owner e migrator."

  docker exec \
    -i \
    "${POSTGRES_CONTAINER_ID}" \
    sh -s <<'SSC_CONTAINER'
set -Eeuo pipefail

set -a
. /tmp/ssc-mission-control-migrator.env
set +a

psql \
  --no-psqlrc \
  --set ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set owner_role="$SSC_OWNER_ROLE" \
  --set migrator_user="$SSC_MIGRATOR_USER" \
  --set migrator_password="$SSC_MIGRATOR_PASSWORD" \
  --set app_user="$SSC_APP_USER" \
  --set db_name="$SSC_DB_NAME" <<'SQL'
BEGIN;

SELECT format(
    'CREATE ROLE %I',
    :'owner_role'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'owner_role'
)
\gexec

SELECT format(
    'ALTER ROLE %I WITH NOLOGIN NOSUPERUSER '
    'NOCREATEDB NOCREATEROLE INHERIT '
    'NOREPLICATION NOBYPASSRLS',
    :'owner_role'
)
\gexec

SELECT format(
    'CREATE ROLE %I',
    :'migrator_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'migrator_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I WITH LOGIN NOSUPERUSER '
    'NOCREATEDB NOCREATEROLE NOINHERIT '
    'NOREPLICATION NOBYPASSRLS '
    'CONNECTION LIMIT 2 PASSWORD %L',
    :'migrator_user',
    :'migrator_password'
)
\gexec

SELECT format(
    'REVOKE %I FROM %I',
    :'owner_role',
    :'migrator_user'
)
WHERE EXISTS (
    SELECT 1
    FROM pg_auth_members AS membership
    JOIN pg_roles AS granted
      ON granted.oid = membership.roleid
    JOIN pg_roles AS member
      ON member.oid = membership.member
    WHERE
      granted.rolname = :'owner_role'
      AND member.rolname = :'migrator_user'
)
\gexec

SELECT format(
    'GRANT %I TO %I',
    :'owner_role',
    :'migrator_user'
)
\gexec

SELECT format(
    'ALTER DATABASE %I OWNER TO %I',
    :'db_name',
    :'owner_role'
)
\gexec

SELECT format(
    'ALTER TABLE %I.%I OWNER TO %I',
    schemaname,
    tablename,
    :'owner_role'
)
FROM pg_tables
WHERE
    schemaname = 'public'
    AND tablename IN (
        'permissions',
        'roles',
        'role_permissions',
        'users',
        'audit_events',
        'branding_settings'
    )
\gexec

SELECT format(
    'ALTER SEQUENCE %I.%I OWNER TO %I',
    namespace.nspname,
    relation.relname,
    :'owner_role'
)
FROM pg_class AS relation
JOIN pg_namespace AS namespace
  ON namespace.oid = relation.relnamespace
WHERE
    relation.relkind = 'S'
    AND namespace.nspname = 'public'
    AND relation.relname IN (
        'permissions_id_seq',
        'roles_id_seq',
        'audit_events_id_seq',
        'branding_settings_id_seq'
    )
\gexec

SELECT format(
    'GRANT CONNECT ON DATABASE %I TO %I',
    :'db_name',
    :'migrator_user'
)
\gexec

SELECT format(
    'REVOKE CREATE, TEMPORARY '
    'ON DATABASE %I FROM %I',
    :'db_name',
    :'migrator_user'
)
\gexec

SELECT format(
    'REVOKE CREATE ON SCHEMA public FROM %I',
    :'migrator_user'
)
\gexec

SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I '
    'IN SCHEMA public '
    'GRANT SELECT, INSERT, UPDATE, DELETE '
    'ON TABLES TO %I',
    :'owner_role',
    :'app_user'
)
\gexec

SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I '
    'IN SCHEMA public '
    'GRANT USAGE, SELECT '
    'ON SEQUENCES TO %I',
    :'owner_role',
    :'app_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I SET statement_timeout = %L',
    :'migrator_user',
    '5min'
)
\gexec

SELECT format(
    'ALTER ROLE %I SET lock_timeout = %L',
    :'migrator_user',
    '10s'
)
\gexec

SELECT format(
    'ALTER ROLE %I SET '
    'idle_in_transaction_session_timeout = %L',
    :'migrator_user',
    '2min'
)
\gexec

COMMIT;
SQL
SSC_CONTAINER

  ok "Owner, migrator e propriedade configurados."
}

verify_configuration() {
  docker exec \
    -i \
    "${POSTGRES_CONTAINER_ID}" \
    sh -s <<'SSC_VERIFY'
set -Eeuo pipefail

set -a
. /tmp/ssc-mission-control-migrator.env
set +a

psql \
  --no-psqlrc \
  --set ON_ERROR_STOP=1 \
  --tuples-only \
  --no-align \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set owner_role="$SSC_OWNER_ROLE" \
  --set migrator_user="$SSC_MIGRATOR_USER" \
  --set app_user="$SSC_APP_USER" <<'SQL'
SELECT
    CASE
        WHEN (
            SELECT pg_get_userbyid(datdba)
            FROM pg_database
            WHERE datname = current_database()
        ) = :'owner_role'
        THEN 'database_owner=ok'
        ELSE 'database_owner=fail'
    END;

SELECT
    CASE
        WHEN has_schema_privilege(
            :'app_user',
            'public',
            'CREATE'
        )
        THEN 'app_create=fail'
        ELSE 'app_create=ok'
    END;

SELECT
    CASE
        WHEN (
            SELECT rolcanlogin
            FROM pg_roles
            WHERE rolname = :'owner_role'
        )
        THEN 'owner_login=fail'
        ELSE 'owner_login=ok'
    END;

SELECT
    CASE
        WHEN (
            SELECT
                rolcanlogin
                AND NOT rolsuper
                AND NOT rolcreatedb
                AND NOT rolcreaterole
            FROM pg_roles
            WHERE rolname = :'migrator_user'
        )
        THEN 'migrator_role=ok'
        ELSE 'migrator_role=fail'
    END;
SQL
SSC_VERIFY
}

main() {
  check_environment
  prepare_values
  prepare_secret_file
  configure_roles_and_ownership
  verify_configuration
}

main "$@"
