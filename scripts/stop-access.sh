#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"

cd "${PROJECT_ROOT}"

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${BASE_COMPOSE}" \
  -f "${ACCESS_COMPOSE}" \
  stop \
  --timeout 30 \
  mission-control

printf '[OK] SSC Mission Control interrompido.\n'
