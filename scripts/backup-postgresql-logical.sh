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
CONTAINER_DUMP=""
CONTAINER_GLOBALS=""
CONTAINER_TOC=""

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
  if [[ -n "${POSTGRES_CONTAINER_ID}" ]]; then
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      rm -f \
      "${CONTAINER_DUMP:-/tmp/nonexistent}" \
      "${CONTAINER_GLOBALS:-/tmp/nonexistent}" \
      "${CONTAINER_TOC:-/tmp/nonexistent}" \
      >/dev/null 2>&1 || true
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

  DB_NAME="$(env_get POSTGRES_DB)"
  ADMIN_USER="$(env_get POSTGRES_USER)"

  [[ -n "${DB_NAME}" ]] \
    || fail "POSTGRES_DB não configurado."

  [[ -n "${ADMIN_USER}" ]] \
    || fail "POSTGRES_USER não configurado."

  mkdir -p "${BACKUP_ROOT}"
  chmod 0700 "${BACKUP_ROOT}"

  local free_kb
  local free_mb

  free_kb="$(
    df -Pk "${BACKUP_ROOT}" |
      awk 'NR == 2 {print $4}'
  )"
  free_mb=$((free_kb / 1024))

  (( free_mb >= 512 )) \
    || fail "Espaço livre inferior a 512 MB."
}

prepare_directory() {
  local timestamp

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  BACKUP_DIR="${BACKUP_ROOT}/${timestamp}"

  install -d -m 0700 "${BACKUP_DIR}"

  CONTAINER_DUMP="/tmp/ssc-${DB_NAME}-${timestamp}.dump"
  CONTAINER_GLOBALS="/tmp/ssc-globals-${timestamp}.sql"
  CONTAINER_TOC="/tmp/ssc-restore-list-${timestamp}.txt"

  ok "Diretório criado: ${BACKUP_DIR}"
}

create_dump() {
  info "Criando backup lógico consistente."

  docker exec \
    "${POSTGRES_CONTAINER_ID}" \
    sh -ec '
      pg_dump \
        --format=custom \
        --no-owner \
        --no-privileges \
        --file "$1" \
        --username "$2" \
        --dbname "$3"

      pg_restore \
        --list \
        "$1" \
        > "$4"

      pg_dumpall \
        --globals-only \
        --no-role-passwords \
        --no-tablespaces \
        --username "$2" \
        --file "$5"
    ' sh \
    "${CONTAINER_DUMP}" \
    "${ADMIN_USER}" \
    "${DB_NAME}" \
    "${CONTAINER_TOC}" \
    "${CONTAINER_GLOBALS}"

  ok "Dump e catálogo criados dentro do container."
}

copy_files() {
  info "Copiando arquivos validados."

  docker cp \
    "${POSTGRES_CONTAINER_ID}:${CONTAINER_DUMP}" \
    "${BACKUP_DIR}/${DB_NAME}.dump" \
    >/dev/null

  docker cp \
    "${POSTGRES_CONTAINER_ID}:${CONTAINER_TOC}" \
    "${BACKUP_DIR}/restore-list.txt" \
    >/dev/null

  docker cp \
    "${POSTGRES_CONTAINER_ID}:${CONTAINER_GLOBALS}" \
    "${BACKUP_DIR}/globals-no-passwords.sql" \
    >/dev/null

  chmod 0600 "${BACKUP_DIR}/"*

  [[ -s "${BACKUP_DIR}/${DB_NAME}.dump" ]] \
    || fail "Arquivo de dump vazio."

  [[ -s "${BACKUP_DIR}/restore-list.txt" ]] \
    || fail "Catálogo do pg_restore vazio."

  [[ -s "${BACKUP_DIR}/globals-no-passwords.sql" ]] \
    || fail "Arquivo de globals vazio."

  if grep -Eiq \
    'SCRAM-SHA-256\$|md5[0-9a-f]{32}' \
    "${BACKUP_DIR}/globals-no-passwords.sql"; then
    fail "O arquivo de globals contém um hash de senha."
  fi

  ok "Arquivos copiados sem hashes de senha."
}

write_manifest() {
  local postgres_version
  local database_size

  postgres_version="$(
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      postgres --version
  )"

  database_size="$(
    docker exec \
      "${POSTGRES_CONTAINER_ID}" \
      psql \
        -X \
        -At \
        -U "${ADMIN_USER}" \
        -d "${DB_NAME}" \
        -c "select pg_database_size(current_database())"
  )"

  {
    printf 'format_version=1\n'
    printf 'created_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'database=%s\n' "${DB_NAME}"
    printf 'archive_format=custom\n'
    printf 'owner_in_archive=false\n'
    printf 'privileges_in_archive=false\n'
    printf 'globals_passwords=false\n'
    printf 'postgres_version=%s\n' "${postgres_version}"
    printf 'database_size_bytes=%s\n' "${database_size}"
    printf 'source_container=%s\n' "${POSTGRES_CONTAINER_ID:0:12}"
    printf 'status=validated\n'
  } > "${BACKUP_DIR}/manifest.env"

  chmod 0600 "${BACKUP_DIR}/manifest.env"
}

generate_checksums() {
  info "Gerando e verificando checksums SHA-256."

  (
    cd "${BACKUP_DIR}"

    sha256sum \
      "${DB_NAME}.dump" \
      globals-no-passwords.sql \
      restore-list.txt \
      manifest.env \
      > checksums.sha256

    sha256sum --check checksums.sha256
  )

  chmod 0600 "${BACKUP_DIR}/checksums.sha256"

  ln -sfn \
    "$(basename "${BACKUP_DIR}")" \
    "${BACKUP_ROOT}/latest"

  ok "Checksums validados."
}

main() {
  check_requirements
  prepare_directory
  create_dump
  copy_files
  write_manifest
  generate_checksums

  printf '\n'
  ok "Backup lógico PostgreSQL concluído."
  printf 'Diretório: %s\n' "${BACKUP_DIR}"
  printf 'Próximo teste:\n'
  printf '  ./scripts/test-postgresql-logical-restore.sh\n'
}

main "$@"
