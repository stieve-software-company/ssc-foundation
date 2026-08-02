#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"

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

require_command() {
  local command_name=$1

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "Comando obrigatório não encontrado: ${command_name}"
  fi
}

check_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    fail "Execute este script com seu usuário normal, sem sudo."
  fi
}

check_required_files() {
  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  [[ -s "${ENV_EXAMPLE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_EXAMPLE_FILE}"
}

check_docker() {
  require_command docker

  if ! docker info >/dev/null 2>&1; then
    fail "O Docker não está acessível. Verifique se o serviço está ativo e se seu usuário pertence ao grupo docker."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    fail "O plugin Docker Compose não está disponível."
  fi

  ok "Docker disponível: $(docker --version)"
  ok "Docker Compose disponível: $(docker compose version)"
}

create_directories() {
  local directories=(
    "${PROJECT_ROOT}/infrastructure/docker/postgres"
    "${PROJECT_ROOT}/infrastructure/docker/rabbitmq"
    "${PROJECT_ROOT}/infrastructure/docker/redis"
    "${PROJECT_ROOT}/infrastructure/docker/minio"
    "${PROJECT_ROOT}/infrastructure/docker/ollama"
    "${PROJECT_ROOT}/infrastructure/docker/prometheus"
    "${PROJECT_ROOT}/infrastructure/docker/grafana"
    "${PROJECT_ROOT}/infrastructure/docker/loki"
    "${PROJECT_ROOT}/infrastructure/config"
    "${PROJECT_ROOT}/infrastructure/backups"
    "${PROJECT_ROOT}/data/workspaces"
    "${PROJECT_ROOT}/data/artifacts"
    "${PROJECT_ROOT}/data/temporary"
  )

  info "Criando a estrutura local de diretórios."

  for directory in "${directories[@]}"; do
    install -d -m 0750 "${directory}"
  done

  chmod 0700 "${PROJECT_ROOT}/infrastructure/backups"
  chmod 0700 "${PROJECT_ROOT}/data/workspaces"
  chmod 0700 "${PROJECT_ROOT}/data/temporary"

  ok "Diretórios preparados."
}

prepare_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    chmod 0600 "${ENV_FILE}"

    warn "O arquivo .env foi criado a partir do modelo."
    warn "Preencha as credenciais e execute novamente:"
    warn "  nano ${ENV_FILE}"

    exit 2
  fi

  chmod 0600 "${ENV_FILE}"

  if grep -q 'CHANGE_ME' "${ENV_FILE}"; then
    fail "O arquivo .env ainda possui valores CHANGE_ME."
  fi

  if git -C "${PROJECT_ROOT}" check-ignore -q .env; then
    ok "O arquivo .env está protegido pelo .gitignore."
  else
    fail "O arquivo .env não está protegido pelo .gitignore."
  fi

  ok "Arquivo .env encontrado e protegido."
}

validate_compose() {
  info "Validando o compose.yaml."

  (
    cd "${PROJECT_ROOT}"
    docker compose --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" config --quiet
  )

  ok "compose.yaml válido."
}

show_summary() {
  printf '\n'
  printf 'Bootstrap concluído.\n'
  printf '\n'
  printf 'Projeto:       %s\n' "${PROJECT_ROOT}"
  printf 'Compose:       %s\n' "${COMPOSE_FILE}"
  printf 'Ambiente:      %s\n' "${ENV_FILE}"
  printf 'Backups:       %s\n' "${PROJECT_ROOT}/infrastructure/backups"
  printf 'Workspaces:    %s\n' "${PROJECT_ROOT}/data/workspaces"
  printf '\n'
  printf 'Próximo passo:\n'
  printf '  ./scripts/validate.sh\n'
  printf '\n'
  printf 'Os containers ainda não foram iniciados.\n'
}

main() {
  info "Iniciando o bootstrap do CompanyOS."

  check_not_root
  require_command git
  check_required_files
  check_docker
  create_directories
  prepare_env_file
  validate_compose
  show_summary
}

main "$@"
