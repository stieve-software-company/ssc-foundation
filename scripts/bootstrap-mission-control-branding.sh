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

main() {
  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  grep -Fq "branding_router" \
    "${PROJECT_ROOT}/apps/mission-control/app/main.py" \
    || fail "Execute primeiro install-mission-control-branding.sh."

  info "Construindo Mission Control v0.2.1."
  compose build mission-control
  ok "Imagem construída."

  info "Recriando somente o Mission Control."
  compose up \
    -d \
    --no-deps \
    --force-recreate \
    --wait \
    --wait-timeout 240 \
    mission-control
  ok "Mission Control saudável."

  "${SCRIPT_DIR}/test-mission-control-branding.sh"

  printf '\n'
  ok "Aba Aparência implantada."
}

main "$@"
