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

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente: ${ENV_FILE}"

  grep -Fq "assistant_router" \
    "${PROJECT_ROOT}/apps/mission-control/app/main.py" \
    || fail "Execute primeiro install-mission-control-assistant.sh."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

build_application() {
  info "Construindo Mission Control v0.3.0."

  compose build mission-control

  ok "Imagem construída."
}

deploy_application() {
  info "Recriando somente o Mission Control."

  compose up \
    -d \
    --no-deps \
    --force-recreate \
    --wait \
    --wait-timeout 240 \
    mission-control

  ok "Mission Control v0.3.0 saudável."
}

main() {
  check_requirements
  build_application
  deploy_application
  "${SCRIPT_DIR}/test-mission-control-assistant.sh"

  printf '\n'
  ok "CompanyOS Assistant implantado."
}

main "$@"
