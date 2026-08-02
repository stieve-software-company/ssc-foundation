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

  for key in \
    SSC_ADMIN_USERNAME \
    SSC_ADMIN_PASSWORD_HASH \
    SSC_SESSION_SECRET; do
    if ! grep -q "^${key}=." "${ENV_FILE}"; then
      fail "Variável ausente no .env: ${key}. Execute scripts/configure-access.py."
    fi
  done

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

start_service() {
  info "Construindo e iniciando o SSC Mission Control."

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
      --wait-timeout 240 \
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
  printf 'Tela de acesso disponível em:\n'
  printf '\n'

  if [[ "${bind_address}" == "127.0.0.1" ]]; then
    printf '  http://127.0.0.1:%s\n' "${port}"
  elif [[ -n "${vm_ip}" ]]; then
    printf '  http://%s:%s\n' "${vm_ip}" "${port}"
  else
    printf '  http://IP-DA-VM:%s\n' "${port}"
  fi

  printf '\n'
  printf 'Health check:\n'
  printf '  http://%s:%s/health\n' "${vm_ip:-IP-DA-VM}" "${port}"
  printf '\n'
}

main() {
  info "Iniciando a primeira interface do CompanyOS."

  check_requirements
  start_service
  show_access_url
}

main "$@"
