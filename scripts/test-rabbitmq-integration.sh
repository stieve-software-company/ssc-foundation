#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE_FILE="${PROJECT_ROOT}/compose.access.yaml"

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

  printf '%s' "${value}"
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      -f "${ACCESS_COMPOSE_FILE}" \
      "$@"
  )
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente: ${ENV_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente: ${COMPOSE_FILE}"

  [[ -s "${ACCESS_COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente: ${ACCESS_COMPOSE_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

test_vhost_and_permissions() {
  local rabbit_user
  local rabbit_vhost

  rabbit_user="$(get_env_value RABBITMQ_DEFAULT_USER)"
  rabbit_vhost="$(get_env_value RABBITMQ_DEFAULT_VHOST)"

  [[ -n "${rabbit_user}" ]] \
    || fail "Usuário RabbitMQ não configurado."

  [[ -n "${rabbit_vhost}" ]] \
    || fail "Virtual host não configurado."

  info "Validando o virtual host ${rabbit_vhost}."

  compose exec \
    -T \
    -e TARGET_VHOST="${rabbit_vhost}" \
    rabbitmq \
    sh -ec '
      rabbitmqctl --quiet list_vhosts name |
        grep -Fx -- "$TARGET_VHOST" >/dev/null
    '

  ok "Virtual host ${rabbit_vhost} existe."

  info "Validando as permissões do usuário ${rabbit_user}."

  compose exec \
    -T \
    -e TARGET_VHOST="${rabbit_vhost}" \
    -e TARGET_USER="${rabbit_user}" \
    rabbitmq \
    sh -ec '
      rabbitmqctl \
        --quiet \
        list_permissions \
        --vhost "$TARGET_VHOST" \
        --no-table-headers |
        awk -v wanted="$TARGET_USER" "
          \$1 == wanted &&
          \$2 == \".*\" &&
          \$3 == \".*\" &&
          \$4 == \".*\" {
            found=1
          }
          END {
            exit !found
          }
        "
    '

  ok "Permissões do usuário estão configuradas."
}

test_from_mission_control() {
  info "Testando conexão AMQP pelo Mission Control."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
import pika

from app.config import settings

parameters = pika.URLParameters(settings.rabbitmq_url)
parameters.socket_timeout = 5
parameters.blocked_connection_timeout = 5
parameters.connection_attempts = 1

connection = pika.BlockingConnection(parameters)
connection.close()

print("[OK] Mission Control conectou ao RabbitMQ.")
PY
}

main() {
  check_requirements
  test_vhost_and_permissions
  test_from_mission_control

  printf '\n'
  ok "Integração RabbitMQ concluída."
}

main "$@"
