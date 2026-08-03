#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly REDIS_CONFIG="${PROJECT_ROOT}/infrastructure/config/redis/redis.conf"

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
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      "$@"
  )
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"
  [[ -s "${BASE_COMPOSE}" ]] || fail "Arquivo ausente: ${BASE_COMPOSE}"
  [[ -s "${ACCESS_COMPOSE}" ]] \
    || fail "Arquivo ausente: ${ACCESS_COMPOSE}"
  [[ -s "${REDIS_CONFIG}" ]] \
    || fail "Arquivo ausente: ${REDIS_CONFIG}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  [[ "$(get_env_value REDIS_MAXMEMORY_POLICY)" == "noeviction" ]] \
    || fail "REDIS_MAXMEMORY_POLICY precisa ser noeviction."

  grep -Fq \
    './infrastructure/config/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro' \
    "${BASE_COMPOSE}" \
    || fail "compose.yaml ainda não monta redis.conf."
}

validate_compose() {
  info "Validando o Docker Compose."

  compose config --quiet

  ok "Docker Compose válido."
}

create_persistence_marker() {
  local marker=$1

  info "Criando marcador temporário de persistência."

  compose exec \
    -T \
    -e SSC_REDIS_MARKER="${marker}" \
    redis \
    sh -ec '
      export REDISCLI_AUTH="$REDIS_PASSWORD"

      redis-cli \
        --no-auth-warning \
        SET "$SSC_REDIS_MARKER" "before-recreate" EX 300 \
        >/dev/null

      local_fsync="$(
        redis-cli \
          --no-auth-warning \
          --raw \
          WAITAOF 1 0 5000 |
          head -n 1
      )"

      [ "$local_fsync" = "1" ]
    '

  ok "Marcador confirmado no AOF local."
}

recreate_redis() {
  info "Recriando somente o container Redis."

  compose up \
    -d \
    --force-recreate \
    --wait \
    --wait-timeout 180 \
    redis

  ok "Redis recriado e saudável."
}

verify_persistence_marker() {
  local marker=$1

  info "Confirmando persistência após a recriação."

  compose exec \
    -T \
    -e SSC_REDIS_MARKER="${marker}" \
    redis \
    sh -ec '
      export REDISCLI_AUTH="$REDIS_PASSWORD"

      value="$(
        redis-cli \
          --no-auth-warning \
          --raw \
          GET "$SSC_REDIS_MARKER"
      )"

      [ "$value" = "before-recreate" ]

      redis-cli \
        --no-auth-warning \
        DEL "$SSC_REDIS_MARKER" \
        >/dev/null
    '

  ok "Persistência validada e marcador removido."
}

run_tests() {
  "${SCRIPT_DIR}/test-redis-integration.sh"
}

main() {
  local marker

  marker="ssc:test:bootstrap:persistence:$(date +%s)-$$"

  check_requirements
  validate_compose
  create_persistence_marker "${marker}"
  recreate_redis
  verify_persistence_marker "${marker}"
  run_tests

  printf '\n'
  ok "Bootstrap do Redis concluído."
}

main "$@"
