#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/logical/postgresql"

POSTGRES_CONTAINER_ID=""
BACKUP_DIR=""
DUMP_FILE=""
CONTAINER_DUMP=""
RESTORE_DB=""
REPORT_FILE=""
ADMIN_USER=""
SOURCE_DB=""

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
  if [[ -n "${POSTGRES_CONTAINER_ID}" ]] &&
     [[ -n "${RESTORE_DB}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      dropdb \
        --if-exists \
        --force \
        --username "${ADMIN_USER}" \
        "${RESTORE_DB}" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${POSTGRES_CONTAINER_ID}" ]] &&
     [[ -n "${CONTAINER_DUMP}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      rm -f "${CONTAINER_DUMP}" \
      >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

resolve_backup_directory() {
  if (($# > 1)); then
    fail "Uso: $0 [diretório-do-backup]"
  fi

  if (($# == 1)); then
    BACKUP_DIR="$1"

    if [[ "${BACKUP_DIR}" != /* ]]; then
      BACKUP_DIR="${PROJECT_ROOT}/${BACKUP_DIR}"
    fi
  elif [[ -L "${BACKUP_ROOT}/latest" ]]; then
    BACKUP_DIR="$(
      readlink -f "${BACKUP_ROOT}/latest"
    )"
  else
    BACKUP_DIR="$(
      find "${BACKUP_ROOT}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%p\n' 2>/dev/null |
        sort |
        tail -n 1
    )"
  fi

  [[ -n "${BACKUP_DIR}" ]] \
    || fail "Nenhum backup lógico encontrado."

  [[ -d "${BACKUP_DIR}" ]] \
    || fail "Diretório inexistente: ${BACKUP_DIR}"

  SOURCE_DB="$(env_get POSTGRES_DB)"
  ADMIN_USER="$(env_get POSTGRES_USER)"

  SOURCE_DB="${SOURCE_DB:-companyos}"
  ADMIN_USER="${ADMIN_USER:-companyos}"

  DUMP_FILE="${BACKUP_DIR}/${SOURCE_DB}.dump"

  [[ -s "${DUMP_FILE}" ]] \
    || fail "Dump ausente ou vazio: ${DUMP_FILE}"

  [[ -s "${BACKUP_DIR}/checksums.sha256" ]] \
    || fail "Arquivo de checksums ausente."

  [[ -s "${BACKUP_DIR}/manifest.env" ]] \
    || fail "Manifesto ausente."
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v sha256sum >/dev/null 2>&1 \
    || fail "sha256sum não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose config --quiet \
    || fail "Docker Compose integrado inválido."

  POSTGRES_CONTAINER_ID="$(compose ps -q postgres)"

  [[ -n "${POSTGRES_CONTAINER_ID}" ]] \
    || fail "Container PostgreSQL não encontrado."

  local health
  health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${POSTGRES_CONTAINER_ID}"
  )"

  [[ "${health}" == "healthy" ]] \
    || fail "PostgreSQL não está healthy: ${health}"
}

verify_backup() {
  info "Verificando checksums do backup."

  (
    cd "${BACKUP_DIR}"
    sha256sum --check checksums.sha256
  )

  ok "Checksums válidos."
}

prepare_restore() {
  local timestamp

  timestamp="$(date '+%Y%m%d_%H%M%S')"
  RESTORE_DB="ssc_restore_${timestamp}"
  CONTAINER_DUMP="/tmp/${RESTORE_DB}.dump"
  REPORT_FILE="${BACKUP_DIR}/restore-test-${timestamp}.txt"

  docker cp \
    "${DUMP_FILE}" \
    "${POSTGRES_CONTAINER_ID}:${CONTAINER_DUMP}" \
    >/dev/null

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    pg_restore \
      --list \
      "${CONTAINER_DUMP}" \
    >/dev/null

  ok "Arquivo transferido e catálogo validado."
}

restore_database() {
  info "Criando banco temporário ${RESTORE_DB}."

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    dropdb \
      --if-exists \
      --force \
      --username "${ADMIN_USER}" \
      "${RESTORE_DB}" \
    >/dev/null 2>&1 || true

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    createdb \
      --username "${ADMIN_USER}" \
      --template template0 \
      "${RESTORE_DB}"

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    pg_restore \
      --exit-on-error \
      --no-owner \
      --no-privileges \
      --username "${ADMIN_USER}" \
      --dbname "${RESTORE_DB}" \
      "${CONTAINER_DUMP}"

  ok "Backup restaurado no banco temporário."
}

query_scalar() {
  local database=$1
  local sql=$2

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    psql \
      -X \
      -At \
      -v ON_ERROR_STOP=1 \
      -U "${ADMIN_USER}" \
      -d "${database}" \
      -c "${sql}"
}

schema_hash() {
  local database=$1

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    sh -ec '
      pg_dump \
        --schema-only \
        --no-owner \
        --no-privileges \
        --username "$1" \
        --dbname "$2" |
      sed \
        -e "/^--/d" \
        -e "/^\\\\restrict /d" \
        -e "/^\\\\unrestrict /d" \
        -e "/^[[:space:]]*$/d" |
      sha256sum |
      awk "{print \$1}"
    ' sh \
    "${ADMIN_USER}" \
    "${database}"
}

table_data_hash() {
  local database=$1
  local table=$2

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    sh -ec '
      pg_dump \
        --data-only \
        --column-inserts \
        --no-owner \
        --no-privileges \
        --table "public.$3" \
        --username "$1" \
        --dbname "$2" |
      sed \
        -e "/^--/d" \
        -e "/^\\\\restrict /d" \
        -e "/^\\\\unrestrict /d" \
        -e "/^[[:space:]]*$/d" |
      sha256sum |
      awk "{print \$1}"
    ' sh \
    "${ADMIN_USER}" \
    "${database}" \
    "${table}"
}

validate_restore() {
  info "Comparando schema e dados."

  local source_schema_hash
  local restored_schema_hash
  local source_table_count
  local restored_table_count
  local source_sequence_count
  local restored_sequence_count
  local source_audit_count
  local restored_audit_count
  local table
  local source_hash
  local restored_hash

  source_schema_hash="$(schema_hash "${SOURCE_DB}")"
  restored_schema_hash="$(schema_hash "${RESTORE_DB}")"

  [[ "${source_schema_hash}" == "${restored_schema_hash}" ]] \
    || fail "O schema restaurado é diferente do schema atual."

  source_table_count="$(
    query_scalar \
      "${SOURCE_DB}" \
      "select count(*) from pg_tables where schemaname = 'public'"
  )"

  restored_table_count="$(
    query_scalar \
      "${RESTORE_DB}" \
      "select count(*) from pg_tables where schemaname = 'public'"
  )"

  [[ "${source_table_count}" == "${restored_table_count}" ]] \
    || fail "Quantidade de tabelas divergente."

  source_sequence_count="$(
    query_scalar \
      "${SOURCE_DB}" \
      "select count(*) from information_schema.sequences where sequence_schema = 'public'"
  )"

  restored_sequence_count="$(
    query_scalar \
      "${RESTORE_DB}" \
      "select count(*) from information_schema.sequences where sequence_schema = 'public'"
  )"

  [[ "${source_sequence_count}" == "${restored_sequence_count}" ]] \
    || fail "Quantidade de sequências divergente."

  for table in \
    branding_settings \
    permissions \
    role_permissions \
    roles \
    users; do
    source_hash="$(
      table_data_hash "${SOURCE_DB}" "${table}"
    )"
    restored_hash="$(
      table_data_hash "${RESTORE_DB}" "${table}"
    )"

    [[ "${source_hash}" == "${restored_hash}" ]] \
      || fail "Dados divergentes na tabela ${table}."
  done

  source_audit_count="$(
    query_scalar \
      "${SOURCE_DB}" \
      "select count(*) from public.audit_events"
  )"

  restored_audit_count="$(
    query_scalar \
      "${RESTORE_DB}" \
      "select count(*) from public.audit_events"
  )"

  if (( restored_audit_count > source_audit_count )); then
    fail "A restauração possui mais eventos que o banco de origem."
  fi

  {
    printf 'SSC PostgreSQL Logical Restore Test\n'
    printf 'tested_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'backup_directory=%s\n' "${BACKUP_DIR}"
    printf 'source_database=%s\n' "${SOURCE_DB}"
    printf 'temporary_database=%s\n' "${RESTORE_DB}"
    printf 'schema_hash=%s\n' "${source_schema_hash}"
    printf 'table_count=%s\n' "${restored_table_count}"
    printf 'sequence_count=%s\n' "${restored_sequence_count}"
    printf 'source_audit_events=%s\n' "${source_audit_count}"
    printf 'restored_audit_events=%s\n' "${restored_audit_count}"
    printf 'stable_table_data=matched\n'
    printf 'status=success\n'
  } > "${REPORT_FILE}"

  chmod 0600 "${REPORT_FILE}"

  ok "Schema, tabelas, sequências e dados estáveis conferem."
}

main() {
  resolve_backup_directory "$@"
  check_requirements
  verify_backup
  prepare_restore
  restore_database
  validate_restore

  printf '\n'
  ok "Restauração lógica validada."
  printf 'Relatório: %s\n' "${REPORT_FILE}"
  printf 'O banco temporário será removido automaticamente.\n'
}

main "$@"
