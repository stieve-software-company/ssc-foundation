#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"

readonly BASE_SERVICES=(
  postgres
  rabbitmq
  redis
  minio
)

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

check_required_files() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

show_current_status() {
  info "Estado atual dos serviços básicos."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      ps \
      "${BASE_SERVICES[@]}"
  )
}

stop_services() {
  info "Interrompendo os serviços básicos do CompanyOS:"
  printf '  - %s\n' "${BASE_SERVICES[@]}"

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      stop \
      --timeout 60 \
      "${BASE_SERVICES[@]}"
  )

  ok "Serviços básicos interrompidos."
}

verify_stopped() {
  info "Confirmando que os containers foram interrompidos."

  local service
  local container_id
  local state

  for service in "${BASE_SERVICES[@]}"; do
    container_id="$(
      cd "${PROJECT_ROOT}" &&
      docker compose \
        --env-file "${ENV_FILE}" \
        -f "${COMPOSE_FILE}" \
        ps \
        -a \
        -q \
        "${service}"
    )"

    if [[ -z "${container_id}" ]]; then
      ok "${service}: container ainda não foi criado."
      continue
    fi

    state="$(
      docker inspect \
        --format '{{.State.Status}}' \
        "${container_id}"
    )"

    case "${state}" in
      exited|created|dead)
        ok "${service}: ${state}"
        ;;
      *)
        fail "${service}: estado inesperado após parada: ${state}"
        ;;
    esac
  done
}

show_summary() {
  printf '\n'
  printf 'CompanyOS básico interrompido com sucesso.\n'
  printf '\n'
  printf 'Os containers foram preservados.\n'
  printf 'Os volumes e dados persistentes não foram removidos.\n'
  printf '\n'
  printf 'Para iniciar novamente:\n'
  printf '  ./scripts/start.sh\n'
  printf '\n'
  printf 'Não execute "docker compose down -v", pois isso remove volumes.\n'
}

main() {
  info "Iniciando a parada controlada do CompanyOS."

  check_required_files
  show_current_status
  stop_services
  verify_stopped
  show_summary
}

main "$@"
