#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly VALIDATE_SCRIPT="${SCRIPT_DIR}/validate.sh"

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

warn() {
  printf '[AVISO] %s\n' "$*" >&2
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

  [[ -x "${VALIDATE_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${VALIDATE_SCRIPT}"
}

run_validation() {
  info "Executando a validação do ambiente."

  if ! "${VALIDATE_SCRIPT}"; then
    fail "A validação falhou. Corrija os erros antes de iniciar."
  fi

  ok "Validação concluída."
}

start_services() {
  info "Iniciando os serviços básicos do CompanyOS:"
  printf '  - %s\n' "${BASE_SERVICES[@]}"

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      up \
      -d \
      --remove-orphans \
      --wait \
      --wait-timeout 240 \
      "${BASE_SERVICES[@]}"
  )

  ok "Serviços básicos iniciados."
}

show_status() {
  info "Estado atual dos containers."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      ps \
      "${BASE_SERVICES[@]}"
  )
}

check_health() {
  info "Confirmando a saúde dos serviços."

  local service
  local container_id
  local health_status

  for service in "${BASE_SERVICES[@]}"; do
    container_id="$(
      cd "${PROJECT_ROOT}" &&
      docker compose \
        --env-file "${ENV_FILE}" \
        -f "${COMPOSE_FILE}" \
        ps \
        -q \
        "${service}"
    )"

    if [[ -z "${container_id}" ]]; then
      fail "Container não encontrado para o serviço: ${service}"
    fi

    health_status="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "${container_id}"
    )"

    if [[ "${health_status}" == "healthy" ]]; then
      ok "${service}: healthy"
    else
      fail "${service}: estado inesperado: ${health_status}"
    fi
  done
}

show_next_steps() {
  printf '\n'
  printf 'CompanyOS básico iniciado com sucesso.\n'
  printf '\n'
  printf 'Serviços ativos:\n'
  printf '  PostgreSQL\n'
  printf '  RabbitMQ\n'
  printf '  Redis\n'
  printf '  MinIO\n'
  printf '\n'
  printf 'O perfil de IA não foi iniciado.\n'
  printf 'O perfil de observabilidade não foi iniciado.\n'
  printf '\n'
  printf 'Próximos comandos:\n'
  printf '  docker compose ps\n'
  printf '  docker compose logs --tail=100\n'
  printf '\n'
}

main() {
  info "Iniciando a infraestrutura básica do CompanyOS."

  check_required_files
  run_validation
  start_services
  show_status
  check_health
  show_next_steps
}

main "$@"
