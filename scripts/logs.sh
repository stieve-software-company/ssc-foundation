#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"

DEFAULT_TAIL=100
FOLLOW=false
TIMESTAMPS=true
SERVICE=""

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

usage() {
  cat <<'EOF'
Uso:
  ./scripts/logs.sh
  ./scripts/logs.sh <serviço>
  ./scripts/logs.sh <serviço> --tail 200
  ./scripts/logs.sh <serviço> --follow
  ./scripts/logs.sh --all --tail 50

Opções:
  --all               Exibe logs de todos os serviços criados.
  --tail <número>     Define a quantidade de linhas. Padrão: 100.
  --follow, -f        Acompanha os logs em tempo real.
  --no-timestamps     Oculta timestamps.
  --list              Lista os serviços configurados.
  --help, -h          Exibe esta ajuda.

Exemplos:
  ./scripts/logs.sh postgres
  ./scripts/logs.sh rabbitmq --tail 200
  ./scripts/logs.sh minio --follow
  ./scripts/logs.sh --all --tail 50
EOF
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  docker compose version >/dev/null 2>&1 \
    || fail "Docker Compose não está disponível."
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      "$@"
  )
}

list_services() {
  compose --profile "*" config --services
}

service_exists() {
  local service_name=$1

  list_services | grep -qx "${service_name}"
}

service_has_container() {
  local service_name=$1
  local container_id

  container_id="$(compose --profile "*" ps -a -q "${service_name}")"

  [[ -n "${container_id}" ]]
}

validate_tail() {
  if ! [[ "${DEFAULT_TAIL}" =~ ^[0-9]+$ ]]; then
    fail "O valor de --tail deve ser um número inteiro positivo."
  fi

  if (( DEFAULT_TAIL < 1 || DEFAULT_TAIL > 10000 )); then
    fail "O valor de --tail deve estar entre 1 e 10000."
  fi
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --all)
        SERVICE=""
        ;;
      --tail)
        shift
        (($# > 0)) || fail "Informe um valor após --tail."
        DEFAULT_TAIL=$1
        ;;
      --follow|-f)
        FOLLOW=true
        ;;
      --no-timestamps)
        TIMESTAMPS=false
        ;;
      --list)
        list_services
        exit 0
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      -*)
        fail "Opção desconhecida: $1"
        ;;
      *)
        if [[ -n "${SERVICE}" ]]; then
          fail "Informe apenas um serviço por execução."
        fi
        SERVICE=$1
        ;;
    esac

    shift
  done
}

validate_service() {
  if [[ -z "${SERVICE}" ]]; then
    return
  fi

  if ! service_exists "${SERVICE}"; then
    printf '[ERRO] Serviço desconhecido: %s\n' "${SERVICE}" >&2
    printf '\nServiços disponíveis:\n' >&2
    list_services >&2
    exit 1
  fi

  if ! service_has_container "${SERVICE}"; then
    fail "O serviço ${SERVICE} ainda não possui container criado."
  fi
}

build_log_args() {
  LOG_ARGS=(
    logs
    --tail "${DEFAULT_TAIL}"
  )

  if [[ "${TIMESTAMPS}" == "true" ]]; then
    LOG_ARGS+=(--timestamps)
  fi

  if [[ "${FOLLOW}" == "true" ]]; then
    LOG_ARGS+=(--follow)
  fi

  if [[ -n "${SERVICE}" ]]; then
    LOG_ARGS+=("${SERVICE}")
  fi
}

show_context() {
  info "Consultando logs do CompanyOS."

  if [[ -n "${SERVICE}" ]]; then
    printf 'Serviço:       %s\n' "${SERVICE}"
  else
    printf 'Serviço:       todos os containers criados\n'
  fi

  printf 'Linhas:        %s\n' "${DEFAULT_TAIL}"
  printf 'Acompanhar:    %s\n' "${FOLLOW}"
  printf 'Timestamps:    %s\n' "${TIMESTAMPS}"
  printf '\n'
}

show_logs() {
  if [[ -z "${SERVICE}" ]]; then
    local created_count
    created_count="$(compose --profile "*" ps -a -q | wc -l | tr -d ' ')"

    if (( created_count == 0 )); then
      warn "Nenhum container foi criado."
      return
    fi
  fi

  compose --profile "*" "${LOG_ARGS[@]}"
}

main() {
  check_requirements
  parse_args "$@"
  validate_tail
  validate_service
  build_log_args
  show_context
  show_logs

  if [[ "${FOLLOW}" == "false" ]]; then
    ok "Consulta de logs concluída."
  fi
}

main "$@"
