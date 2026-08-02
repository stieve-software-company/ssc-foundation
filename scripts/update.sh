#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly VALIDATE_SCRIPT="${SCRIPT_DIR}/validate.sh"
readonly SNAPSHOT_ROOT="${PROJECT_ROOT}/infrastructure/backups/update-snapshots"

readonly BASE_SERVICES=(
  postgres
  rabbitmq
  redis
  minio
)

readonly AI_SERVICES=(
  ollama
)

readonly OBSERVABILITY_SERVICES=(
  prometheus
  loki
  grafana
)

SELECTED_SERVICES=()
ACTIVE_PROFILES=()
ASSUME_YES=false
WAIT_TIMEOUT=300
SNAPSHOT_DIR=""

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

  if [[ -n "${SNAPSHOT_DIR}" ]]; then
    printf '[INFO] Snapshot da atualização: %s\n' "${SNAPSHOT_DIR}" >&2
  fi

  exit "${exit_code}"
}

trap 'on_error "${LINENO}"' ERR

usage() {
  cat <<'EOF'
Uso:
  ./scripts/update.sh
  ./scripts/update.sh --base
  ./scripts/update.sh --ai
  ./scripts/update.sh --observability
  ./scripts/update.sh --all
  ./scripts/update.sh --base --ai
  ./scripts/update.sh --yes

Opções:
  --base                 Atualiza PostgreSQL, RabbitMQ, Redis e MinIO.
  --ai                   Atualiza o perfil de IA.
  --observability        Atualiza Prometheus, Loki e Grafana.
  --all                  Atualiza todos os serviços.
  --wait-timeout <seg>   Tempo máximo dos health checks. Padrão: 300.
  --yes, -y              Não solicita confirmação.
  --help, -h             Exibe esta ajuda.

Sem opções de grupo, o script atualiza somente os serviços básicos.

Importante:
  - Volumes não são removidos.
  - O script não altera o arquivo .env.
  - O script não altera versões de imagens.
  - Para usar uma nova versão, altere primeiro a tag correspondente no .env.
EOF
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      "${ACTIVE_PROFILES[@]}" \
      "$@"
  )
}

add_service_once() {
  local candidate=$1
  local existing

  for existing in "${SELECTED_SERVICES[@]:-}"; do
    [[ "${existing}" == "${candidate}" ]] && return
  done

  SELECTED_SERVICES+=("${candidate}")
}

add_profile_once() {
  local profile=$1
  local argument="--profile=${profile}"
  local existing

  for existing in "${ACTIVE_PROFILES[@]:-}"; do
    [[ "${existing}" == "${argument}" ]] && return
  done

  ACTIVE_PROFILES+=("${argument}")
}

select_base() {
  local service

  for service in "${BASE_SERVICES[@]}"; do
    add_service_once "${service}"
  done
}

select_ai() {
  local service

  add_profile_once "ai"

  for service in "${AI_SERVICES[@]}"; do
    add_service_once "${service}"
  done
}

select_observability() {
  local service

  add_profile_once "observability"

  for service in "${OBSERVABILITY_SERVICES[@]}"; do
    add_service_once "${service}"
  done
}

parse_args() {
  local group_selected=false

  while (($# > 0)); do
    case "$1" in
      --base)
        select_base
        group_selected=true
        ;;
      --ai)
        select_ai
        group_selected=true
        ;;
      --observability)
        select_observability
        group_selected=true
        ;;
      --all)
        select_base
        select_ai
        select_observability
        group_selected=true
        ;;
      --wait-timeout)
        shift
        (($# > 0)) || fail "Informe um valor após --wait-timeout."
        WAIT_TIMEOUT=$1
        ;;
      --yes|-y)
        ASSUME_YES=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Opção desconhecida: $1"
        ;;
    esac

    shift
  done

  if [[ "${group_selected}" == "false" ]]; then
    select_base
  fi
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  [[ -x "${VALIDATE_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${VALIDATE_SCRIPT}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  if ! [[ "${WAIT_TIMEOUT}" =~ ^[0-9]+$ ]] ||
     (( WAIT_TIMEOUT < 30 || WAIT_TIMEOUT > 3600 )); then
    fail "--wait-timeout deve estar entre 30 e 3600 segundos."
  fi
}

run_validation() {
  info "Executando a validação do ambiente."

  if ! "${VALIDATE_SCRIPT}"; then
    fail "A validação falhou. Corrija os erros antes da atualização."
  fi

  ok "Validação concluída."
}

show_plan() {
  printf '\n'
  printf 'Serviços selecionados:\n'
  printf '  - %s\n' "${SELECTED_SERVICES[@]}"

  printf '\n'
  printf 'Perfis ativos nesta atualização:\n'

  if (( ${#ACTIVE_PROFILES[@]} == 0 )); then
    printf '  nenhum perfil opcional\n'
  else
    printf '  - %s\n' "${ACTIVE_PROFILES[@]#--profile=}"
  fi

  printf '\n'
  printf 'Tempo máximo de espera: %s segundos\n' "${WAIT_TIMEOUT}"
  printf '\n'
}

confirm_update() {
  if [[ "${ASSUME_YES}" == "true" ]]; then
    return
  fi

  local answer

  read -r -p "Continuar com a atualização? [s/N] " answer

  case "${answer}" in
    s|S|sim|SIM|Sim)
      ;;
    *)
      warn "Atualização cancelada."
      exit 0
      ;;
  esac
}

create_snapshot() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

  SNAPSHOT_DIR="${SNAPSHOT_ROOT}/${timestamp}"
  install -d -m 0700 "${SNAPSHOT_DIR}"

  info "Registrando snapshot das imagens atuais."

  {
    printf 'created_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'project_root=%s\n' "${PROJECT_ROOT}"
    printf 'services=%s\n' "${SELECTED_SERVICES[*]}"
    printf 'profiles=%s\n' "${ACTIVE_PROFILES[*]:-none}"
    printf '\n'
  } > "${SNAPSHOT_DIR}/manifest.txt"

  local service
  local configured_image
  local container_id
  local current_image_id
  local repo_digests

  for service in "${SELECTED_SERVICES[@]}"; do
    container_id="$(compose ps -a -q "${service}")"

    if [[ -n "${container_id}" ]]; then
      configured_image="$(
        docker inspect \
          --format '{{.Config.Image}}' \
          "${container_id}"
      )"

      current_image_id="$(
        docker inspect \
          --format '{{.Image}}' \
          "${container_id}"
      )"
    else
      configured_image="container_not_created"
      current_image_id="container_not_created"
    fi

    if [[ "${configured_image}" != "container_not_created" ]] &&
       docker image inspect "${configured_image}" >/dev/null 2>&1; then
      repo_digests="$(
        docker image inspect \
          --format '{{join .RepoDigests ","}}' \
          "${configured_image}"
      )"
    else
      repo_digests="image_not_present"
    fi

    {
      printf 'service=%s\n' "${service}"
      printf 'configured_image=%s\n' "${configured_image:-unknown}"
      printf 'current_image_id=%s\n' "${current_image_id}"
      printf 'repo_digests=%s\n' "${repo_digests}"
      printf '%s\n' '---'
    } >> "${SNAPSHOT_DIR}/images-before.txt"
  done

  sha256sum \
    "${SNAPSHOT_DIR}/manifest.txt" \
    "${SNAPSHOT_DIR}/images-before.txt" \
    > "${SNAPSHOT_DIR}/checksums.sha256"

  chmod 0600 "${SNAPSHOT_DIR}"/*

  ok "Snapshot criado: ${SNAPSHOT_DIR}"
}

pull_images() {
  info "Baixando as imagens configuradas."

  compose pull "${SELECTED_SERVICES[@]}"

  ok "Download das imagens concluído."
}

recreate_services() {
  info "Recriando os serviços selecionados sem remover volumes."

  compose up \
    -d \
    --remove-orphans \
    --wait \
    --wait-timeout "${WAIT_TIMEOUT}" \
    "${SELECTED_SERVICES[@]}"

  ok "Serviços recriados."
}

verify_health() {
  info "Verificando o estado final."

  local service
  local container_id
  local state
  local health

  for service in "${SELECTED_SERVICES[@]}"; do
    container_id="$(compose ps -q "${service}")"

    if [[ -z "${container_id}" ]]; then
      fail "Container não encontrado para o serviço: ${service}"
    fi

    state="$(
      docker inspect \
        --format '{{.State.Status}}' \
        "${container_id}"
    )"

    health="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "${container_id}"
    )"

    if [[ "${state}" != "running" ]]; then
      fail "${service}: estado inesperado: ${state}"
    fi

    if [[ "${health}" == "unhealthy" ]]; then
      fail "${service}: health check unhealthy."
    fi

    if [[ "${health}" == "healthy" ]]; then
      ok "${service}: running / healthy"
    else
      ok "${service}: running / sem health check"
    fi
  done
}

record_result() {
  {
    printf '\n'
    printf 'completed_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'result=success\n'
  } >> "${SNAPSHOT_DIR}/manifest.txt"

  compose ps "${SELECTED_SERVICES[@]}" \
    > "${SNAPSHOT_DIR}/services-after.txt"

  sha256sum \
    "${SNAPSHOT_DIR}/manifest.txt" \
    "${SNAPSHOT_DIR}/images-before.txt" \
    "${SNAPSHOT_DIR}/services-after.txt" \
    > "${SNAPSHOT_DIR}/checksums.sha256"

  chmod 0600 "${SNAPSHOT_DIR}"/*
}

show_summary() {
  printf '\n'
  printf 'Atualização concluída com sucesso.\n'
  printf '\n'
  printf 'Volumes preservados.\n'
  printf 'Snapshot: %s\n' "${SNAPSHOT_DIR}"
  printf '\n'
  printf 'Estado atual:\n'

  compose ps "${SELECTED_SERVICES[@]}"
}

main() {
  info "Iniciando a atualização controlada do CompanyOS."

  parse_args "$@"
  check_requirements
  run_validation
  show_plan
  confirm_update
  create_snapshot
  pull_images
  recreate_services
  verify_health
  record_result
  show_summary
}

main "$@"
