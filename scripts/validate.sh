#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"

ERROR_COUNT=0
WARNING_COUNT=0

info() {
  printf '[INFO] %s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  WARNING_COUNT=$((WARNING_COUNT + 1))
  printf '[AVISO] %s\n' "$*" >&2
}

error() {
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf '[ERRO] %s\n' "$*" >&2
}

section() {
  printf '\n'
  printf '============================================================\n'
  printf '%s\n' "$*"
  printf '============================================================\n'
}

require_command() {
  local command_name=$1

  if command -v "${command_name}" >/dev/null 2>&1; then
    ok "Comando disponível: ${command_name}"
  else
    error "Comando obrigatório não encontrado: ${command_name}"
  fi
}

get_env_value() {
  local key=$1
  local default_value=${2:-}
  local value

  value="$(
    awk -F= -v wanted="${key}" '
      $0 !~ /^[[:space:]]*#/ &&
      $1 == wanted {
        sub(/^[^=]*=/, "", $0)
        print $0
      }
    ' "${ENV_FILE}" | tail -n 1
  )"

  value="${value%$'\r'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"

  if [[ -z "${value}" ]]; then
    printf '%s' "${default_value}"
  else
    printf '%s' "${value}"
  fi
}

check_files() {
  section "1. Arquivos obrigatórios"

  local files=(
    "${ENV_FILE}"
    "${ENV_EXAMPLE_FILE}"
    "${COMPOSE_FILE}"
    "${PROJECT_ROOT}/.gitignore"
    "${PROJECT_ROOT}/scripts/bootstrap.sh"
  )

  local file

  for file in "${files[@]}"; do
    if [[ -s "${file}" ]]; then
      ok "Arquivo encontrado: ${file#${PROJECT_ROOT}/}"
    else
      error "Arquivo ausente ou vazio: ${file}"
    fi
  done
}

check_permissions() {
  section "2. Permissões"

  if [[ -f "${ENV_FILE}" ]]; then
    local env_mode
    env_mode="$(stat -c '%a' "${ENV_FILE}")"

    if [[ "${env_mode}" == "600" ]]; then
      ok ".env possui permissão 600."
    else
      warn ".env possui permissão ${env_mode}; recomendado: 600."
    fi
  fi

  local scripts=(
    "${PROJECT_ROOT}/scripts/bootstrap.sh"
    "${PROJECT_ROOT}/scripts/validate.sh"
  )

  local script

  for script in "${scripts[@]}"; do
    if [[ -f "${script}" ]]; then
      if [[ -x "${script}" ]]; then
        ok "Script executável: ${script#${PROJECT_ROOT}/}"
      else
        error "Script sem permissão de execução: ${script#${PROJECT_ROOT}/}"
      fi
    fi
  done
}

check_git_protection() {
  section "3. Proteção do Git"

  if git -C "${PROJECT_ROOT}" check-ignore -q .env; then
    ok ".env está protegido pelo .gitignore."
  else
    error ".env não está protegido pelo .gitignore."
  fi

  if git -C "${PROJECT_ROOT}" ls-files --error-unmatch .env \
      >/dev/null 2>&1; then
    error ".env está sendo rastreado pelo Git."
  else
    ok ".env não está sendo rastreado pelo Git."
  fi

  if git -C "${PROJECT_ROOT}" check-ignore -q \
      infrastructure/backups/test-validation.backup; then
    ok "Backups estão protegidos pelo .gitignore."
  else
    error "A pasta de backups não está protegida pelo .gitignore."
  fi
}

check_secrets() {
  section "4. Credenciais e placeholders"

  if grep -q 'CHANGE_ME' "${ENV_FILE}"; then
    error "O arquivo .env ainda contém valores CHANGE_ME."
  else
    ok "Nenhum placeholder CHANGE_ME encontrado no .env."
  fi

  local secret_keys=(
    POSTGRES_PASSWORD
    RABBITMQ_DEFAULT_PASS
    REDIS_PASSWORD
    MINIO_ROOT_PASSWORD
    GRAFANA_ADMIN_PASSWORD
    JWT_SECRET_KEY
    APP_ENCRYPTION_KEY
  )

  local key
  local value

  for key in "${secret_keys[@]}"; do
    value="$(get_env_value "${key}")"

    if [[ -z "${value}" ]]; then
      error "Variável obrigatória vazia: ${key}"
    elif [[ "${#value}" -lt 24 ]]; then
      warn "A variável ${key} possui menos de 24 caracteres."
    else
      ok "Variável protegida configurada: ${key}"
    fi
  done
}

check_docker() {
  section "5. Docker"

  require_command docker

  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      ok "Docker daemon acessível."
    else
      error "Docker daemon não está acessível."
    fi

    if docker compose version >/dev/null 2>&1; then
      ok "Docker Compose disponível: $(docker compose version)"
    else
      error "Plugin Docker Compose não disponível."
    fi
  fi
}

check_compose() {
  section "6. Docker Compose"

  if ! docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      --profile "*" \
      config --quiet; then
    error "compose.yaml inválido ao validar todos os perfis."
    return
  fi

  ok "compose.yaml válido, incluindo todos os perfis."

  local expected_services=(
    postgres
    rabbitmq
    redis
    minio
    ollama
    prometheus
    loki
    grafana
  )

  local configured_services
  configured_services="$(
    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      --profile "*" \
      config --services
  )"

  local service

  for service in "${expected_services[@]}"; do
    if grep -qx "${service}" <<< "${configured_services}"; then
      ok "Serviço configurado: ${service}"
    else
      error "Serviço ausente no Compose: ${service}"
    fi
  done

  local configured_profiles
  configured_profiles="$(
    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      config --profiles
  )"

  local expected_profiles=(
    ai
    observability
  )

  local profile

  for profile in "${expected_profiles[@]}"; do
    if grep -qx "${profile}" <<< "${configured_profiles}"; then
      ok "Perfil configurado: ${profile}"
    else
      error "Perfil ausente no Compose: ${profile}"
    fi
  done

  local images
  images="$(
    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      --profile "*" \
      config --images
  )"

  if grep -Eq '(^|:)latest$' <<< "${images}"; then
    error "Existe imagem usando a tag latest."
  else
    ok "Nenhuma imagem usa a tag latest."
  fi
}

check_directories() {
  section "7. Diretórios"

  local directories=(
    "${PROJECT_ROOT}/infrastructure/backups"
    "${PROJECT_ROOT}/infrastructure/config"
    "${PROJECT_ROOT}/data/workspaces"
    "${PROJECT_ROOT}/data/artifacts"
    "${PROJECT_ROOT}/data/temporary"
  )

  local directory

  for directory in "${directories[@]}"; do
    if [[ -d "${directory}" ]]; then
      ok "Diretório encontrado: ${directory#${PROJECT_ROOT}/}"
    else
      error "Diretório ausente: ${directory}"
    fi
  done
}

check_disk_and_memory() {
  section "8. Recursos da máquina"

  local free_kb
  local free_gb

  free_kb="$(df -Pk "${PROJECT_ROOT}" | awk 'NR == 2 {print $4}')"
  free_gb=$((free_kb / 1024 / 1024))

  if (( free_gb >= 20 )); then
    ok "Espaço livre em disco: ${free_gb} GB."
  elif (( free_gb >= 10 )); then
    warn "Espaço livre em disco: ${free_gb} GB. Recomendado: 20 GB ou mais."
  else
    error "Espaço livre insuficiente: ${free_gb} GB."
  fi

  if command -v free >/dev/null 2>&1; then
    local total_memory_mb
    total_memory_mb="$(free -m | awk '/^Mem:/ {print $2}')"

    if (( total_memory_mb >= 8192 )); then
      ok "Memória total: ${total_memory_mb} MB."
    elif (( total_memory_mb >= 4096 )); then
      warn "Memória total: ${total_memory_mb} MB. Ollama e observabilidade podem exigir mais recursos."
    else
      warn "Memória total baixa: ${total_memory_mb} MB. Inicie somente os serviços básicos."
    fi
  fi
}

check_bind_address() {
  section "9. Exposição de rede"

  local bind_address
  bind_address="$(get_env_value SSC_BIND_ADDRESS 127.0.0.1)"

  case "${bind_address}" in
    127.0.0.1|localhost)
      ok "Portas vinculadas localmente: ${bind_address}"
      ;;
    0.0.0.0)
      warn "SSC_BIND_ADDRESS está em 0.0.0.0. Os serviços poderão ficar acessíveis pela rede."
      ;;
    *)
      warn "SSC_BIND_ADDRESS configurado como: ${bind_address}"
      ;;
  esac
}

check_ports() {
  section "10. Portas"

  if ! command -v ss >/dev/null 2>&1; then
    warn "Comando ss não encontrado; verificação de portas ignorada."
    return
  fi

  local port_keys=(
    POSTGRES_HOST_PORT
    RABBITMQ_AMQP_HOST_PORT
    RABBITMQ_MANAGEMENT_HOST_PORT
    REDIS_HOST_PORT
    MINIO_API_HOST_PORT
    MINIO_CONSOLE_HOST_PORT
    OLLAMA_HOST_PORT
    PROMETHEUS_HOST_PORT
    GRAFANA_HOST_PORT
    LOKI_HOST_PORT
  )

  local key
  local port

  for key in "${port_keys[@]}"; do
    port="$(get_env_value "${key}")"

    if [[ -z "${port}" ]]; then
      warn "Porta não definida: ${key}"
      continue
    fi

    if ! [[ "${port}" =~ ^[0-9]+$ ]] ||
       (( port < 1 || port > 65535 )); then
      error "Porta inválida em ${key}: ${port}"
      continue
    fi

    if ss -lntH | awk '{print $4}' |
       grep -Eq "(^|:|\])${port}$"; then
      warn "Porta ${port} já está em uso (${key})."
    else
      ok "Porta disponível: ${port} (${key})"
    fi
  done
}

show_summary() {
  section "Resultado"

  printf 'Erros:  %s\n' "${ERROR_COUNT}"
  printf 'Avisos: %s\n' "${WARNING_COUNT}"
  printf '\n'

  if (( ERROR_COUNT > 0 )); then
    printf '[FALHA] O ambiente ainda não está pronto para iniciar.\n'
    exit 1
  fi

  if (( WARNING_COUNT > 0 )); then
    printf '[OK COM AVISOS] O ambiente passou nas verificações obrigatórias.\n'
  else
    printf '[OK] O ambiente está pronto para a próxima etapa.\n'
  fi

  printf '\n'
  printf 'Os containers ainda não foram iniciados.\n'
}

main() {
  info "Iniciando a validação do ambiente CompanyOS."

  check_files
  check_permissions
  check_git_protection
  check_secrets
  check_docker
  check_compose
  check_directories
  check_disk_and_memory
  check_bind_address
  check_ports
  show_summary
}

main "$@"
