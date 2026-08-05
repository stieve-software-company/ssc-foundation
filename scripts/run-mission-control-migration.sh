#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ok() {
  printf '[OK] %s\n' "$*"
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

    key, value = line.split("=", 1)

    if key.strip() != target:
        continue

    value = value.strip()

    if (
        len(value) >= 2
        and value[0] == value[-1]
        and value[0] in {'"', "'"}
    ):
        value = value[1:-1]

    print(value)
    raise SystemExit(0)

print("")
PY
}

urlencode() {
  python3 - "$1" <<'PY'
from urllib.parse import quote
import sys

print(quote(sys.argv[1], safe=""))
PY
}

main() {
  [[ -s "${ENV_FILE}" ]] ||
    fail ".env ausente."

  local db_name
  local migrator_user
  local migrator_password
  local owner_role

  db_name="$(env_get POSTGRES_DB)"
  migrator_user="$(env_get POSTGRES_MIGRATOR_USER)"
  migrator_password="$(env_get POSTGRES_MIGRATOR_PASSWORD)"
  owner_role="$(env_get POSTGRES_OWNER_ROLE)"

  [[ -n "${db_name}" ]] ||
    fail "POSTGRES_DB ausente."

  [[ -n "${migrator_user}" ]] ||
    fail "POSTGRES_MIGRATOR_USER ausente."

  [[ -n "${migrator_password}" ]] ||
    fail "POSTGRES_MIGRATOR_PASSWORD ausente."

  [[ -n "${owner_role}" ]] ||
    fail "POSTGRES_OWNER_ROLE ausente."

  case "${migrator_password}" in
    CHANGE_ME_*)
      fail "Senha do migrator ainda é placeholder."
      ;;
  esac

  local encoded_user
  local encoded_password
  local encoded_database

  encoded_user="$(urlencode "${migrator_user}")"
  encoded_password="$(urlencode "${migrator_password}")"
  encoded_database="$(urlencode "${db_name}")"

  export DATABASE_URL
  DATABASE_URL="$(
    printf \
      'postgresql+psycopg://%s:%s@postgres:5432/%s' \
      "${encoded_user}" \
      "${encoded_password}" \
      "${encoded_database}"
  )"

  export SSC_MIGRATION_ROLE="${owner_role}"

  compose run \
    --rm \
    --no-deps \
    -e DATABASE_URL \
    -e SSC_MIGRATION_ROLE \
    mission-control \
    python \
    -m \
    app.migration_manager \
    upgrade

  unset DATABASE_URL
  unset SSC_MIGRATION_ROLE

  ok "Migração one-shot concluída."
}

main "$@"
