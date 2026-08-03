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

get_env_value() {
  local key=$1
  local fallback=${2:-}
  local value

  value="$(
    awk -F= -v wanted="${key}" '
      $0 !~ /^[[:space:]]*#/ &&
      $1 == wanted {
        sub(/^[^=]*=/, "", $0)
        value=$0
      }
      END {
        print value
      }
    ' "${ENV_FILE}"
  )"

  printf '%s' "${value:-${fallback}}"
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"
  [[ -s "${BASE_COMPOSE}" ]] || fail "Arquivo ausente: ${BASE_COMPOSE}"
  [[ -s "${ACCESS_COMPOSE}" ]] || fail "Arquivo ausente: ${ACCESS_COMPOSE}"

  local key
  for key in \
    DATABASE_URL \
    REDIS_URL \
    RABBITMQ_URL \
    SSC_ADMIN_USERNAME \
    SSC_ADMIN_PASSWORD_HASH \
    SSC_SESSION_SECRET; do
    if ! grep -q "^${key}=." "${ENV_FILE}"; then
      fail "Variável ausente no .env: ${key}"
    fi
  done

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

validate_compose() {
  info "Validando o Compose do Mission Control."

  (
    cd "${PROJECT_ROOT}"
    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      config --quiet
  )

  ok "Compose válido."
}

start_service() {
  info "Construindo e iniciando o Mission Control v0.2."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      up \
      -d \
      --build \
      --wait \
      --wait-timeout 300 \
      postgres \
      rabbitmq \
      redis \
      minio \
      mission-control
  )

  ok "Mission Control iniciado."
}

show_access_url() {
  local port
  local bind_address
  local vm_ip

  port="$(get_env_value SSC_ACCESS_HOST_PORT 8080)"
  bind_address="$(get_env_value SSC_ACCESS_BIND_ADDRESS 0.0.0.0)"
  vm_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"

  printf '\n'
  printf 'Mission Control v0.2 disponível em:\n\n'

  if [[ "${bind_address}" == "127.0.0.1" ]]; then
    printf '  http://127.0.0.1:%s\n' "${port}"
  elif [[ -n "${vm_ip}" ]]; then
    printf '  http://%s:%s\n' "${vm_ip}" "${port}"
  else
    printf '  http://IP-DA-VM:%s\n' "${port}"
  fi

  printf '\nHealth check:\n'
  printf '  http://%s:%s/health\n\n' "${vm_ip:-IP-DA-VM}" "${port}"
}

main() {
  info "Iniciando o painel administrativo do CompanyOS."

  check_requirements
  validate_compose
  start_service
  show_access_url
}

main "$@"
