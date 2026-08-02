#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly STOP_SCRIPT="${SCRIPT_DIR}/stop.sh"
readonly START_SCRIPT="${SCRIPT_DIR}/start.sh"

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

on_error() {
  local exit_code=$?
  local line_number=${1:-desconhecida}

  printf '[ERRO] Falha na linha %s. Código de saída: %s\n' \
    "${line_number}" "${exit_code}" >&2

  exit "${exit_code}"
}

trap 'on_error "${LINENO}"' ERR

check_scripts() {
  [[ -x "${STOP_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${STOP_SCRIPT}"

  [[ -x "${START_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${START_SCRIPT}"
}

restart_services() {
  info "Interrompendo a infraestrutura básica."
  "${STOP_SCRIPT}"

  printf '\n'
  info "Aguardando a liberação dos recursos."
  sleep 3

  printf '\n'
  info "Iniciando novamente a infraestrutura básica."
  "${START_SCRIPT}"
}

show_summary() {
  printf '\n'
  ok "Reinicialização controlada concluída."
  printf '\n'
  printf 'Os volumes e dados persistentes foram preservados.\n'
  printf 'PostgreSQL, RabbitMQ, Redis e MinIO estão ativos novamente.\n'
}

main() {
  info "Iniciando a reinicialização controlada do CompanyOS."

  check_scripts
  restart_services
  show_summary
}

main "$@"
