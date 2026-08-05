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
        print(value.strip().strip("\"'"))
        raise SystemExit(0)

print("")
PY
}

main() {
  local postgres_id
  local app_user
  local owner_role

  postgres_id="$(compose ps -q postgres)"
  app_user="$(env_get POSTGRES_APP_USER)"
  owner_role="$(env_get POSTGRES_OWNER_ROLE)"

  [[ -n "${postgres_id}" ]] ||
    fail "PostgreSQL ausente."

  [[ -n "${app_user}" ]] ||
    fail "POSTGRES_APP_USER ausente."

  [[ -n "${owner_role}" ]] ||
    fail "POSTGRES_OWNER_ROLE ausente."

  docker exec \
    -i \
    "${postgres_id}" \
    sh -s <<SSC_CONTAINER
set -Eeuo pipefail

psql \
  --no-psqlrc \
  --set ON_ERROR_STOP=1 \
  --username "\$POSTGRES_USER" \
  --dbname "\$POSTGRES_DB" \
  --set app_user="${app_user}" \
  --set owner_role="${owner_role}" <<'SQL'
BEGIN;

SELECT format(
    'ALTER TABLE public.alembic_version OWNER TO %I',
    :'owner_role'
)
\gexec

SELECT format(
    'ALTER TABLE public.service_definitions OWNER TO %I',
    :'owner_role'
)
\gexec

SELECT format(
    'ALTER SEQUENCE public.service_definitions_id_seq '
    'OWNER TO %I',
    :'owner_role'
)
WHERE to_regclass(
    'public.service_definitions_id_seq'
) IS NOT NULL
\gexec

SELECT format(
    'REVOKE ALL ON public.alembic_version FROM %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT SELECT ON public.alembic_version TO %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, UPDATE, DELETE '
    'ON public.service_definitions TO %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT USAGE, SELECT '
    'ON SEQUENCE public.service_definitions_id_seq '
    'TO %I',
    :'app_user'
)
WHERE to_regclass(
    'public.service_definitions_id_seq'
) IS NOT NULL
\gexec

COMMIT;
SQL
SSC_CONTAINER

  printf '[OK] Privilégios pós-migração endurecidos.\n'
}

main "$@"
