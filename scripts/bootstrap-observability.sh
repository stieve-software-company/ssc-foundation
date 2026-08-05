#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

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

check_requirements() {
  local script

  for script in \
    "${SCRIPT_DIR}/backup.sh" \
    "${SCRIPT_DIR}/start-observability.sh" \
    "${SCRIPT_DIR}/test-observability.sh"; do
    [[ -x "${script}" ]] \
      || fail "Script ausente ou sem execução: ${script}"
  done

  [[ -s "${PROJECT_ROOT}/compose.observability.yaml" ]] \
    || fail "Execute install-observability.sh primeiro."

  grep -Fq "OBSERVABILITY_COMPOSE_FILE" \
    "${SCRIPT_DIR}/backup.sh" \
    || fail "Backup ainda não integra a observabilidade."
}

main() {
  check_requirements

  info "Etapa 1/4 — backup físico anterior."
  "${SCRIPT_DIR}/backup.sh" --yes

  info "Etapa 2/4 — inicialização da observabilidade."
  "${SCRIPT_DIR}/start-observability.sh"

  info "Etapa 3/4 — testes integrados."
  "${SCRIPT_DIR}/test-observability.sh"

  info "Etapa 4/4 — backup físico com os novos volumes."
  "${SCRIPT_DIR}/backup.sh" --yes

  printf '\n'
  ok "Observabilidade implantada, testada e protegida por backup."
}

main "$@"
