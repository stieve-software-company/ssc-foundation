#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly VALIDATE_SCRIPT="${SCRIPT_DIR}/validate.sh"
readonly BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/archives"
readonly BACKUP_HELPER_IMAGE="alpine:3.22.1"

ASSUME_YES=false
RESTART_SERVICES=true
WAIT_TIMEOUT=300
BACKUP_DIR=""
SERVICES_STOPPED=false

RUNNING_SERVICES=()
PROJECT_VOLUMES=()

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
  ./scripts/backup.sh
  ./scripts/backup.sh --yes
  ./scripts/backup.sh --no-restart
  ./scripts/backup.sh --wait-timeout 600

Opções:
  --yes, -y              Não solicita confirmação.
  --no-restart           Mantém os serviços parados após o backup.
  --wait-timeout <seg>   Tempo máximo para health checks. Padrão: 300.
  --help, -h             Exibe esta ajuda.

Comportamento:
  1. Valida o ambiente.
  2. Registra quais serviços estão ativos.
  3. Baixa previamente a imagem auxiliar do backup.
  4. Para apenas os serviços ativos.
  5. Compacta todos os volumes Docker do projeto.
  6. Verifica a integridade e gera checksums SHA-256.
  7. Reinicia somente os serviços que estavam ativos.

Segurança:
  - O arquivo .env não é copiado.
  - Nenhuma senha é exibida.
  - Nenhum volume é removido.
EOF
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      --profile "*" \
      "$@"
  )
}

get_project_name() {
  local project_name

  project_name="$(
    awk -F= '
      $0 !~ /^[[:space:]]*#/ &&
      $1 == "COMPOSE_PROJECT_NAME" {
        sub(/^[^=]*=/, "", $0)
        print $0
      }
    ' "${ENV_FILE}" | tail -n 1
  )"

  project_name="${project_name%$'\r'}"
  project_name="${project_name#\"}"
  project_name="${project_name%\"}"
  project_name="${project_name#\'}"
  project_name="${project_name%\'}"

  printf '%s' "${project_name:-ssc}"
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --yes|-y)
        ASSUME_YES=true
        ;;
      --no-restart)
        RESTART_SERVICES=false
        ;;
      --wait-timeout)
        shift
        (($# > 0)) || fail "Informe um valor após --wait-timeout."
        WAIT_TIMEOUT=$1
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
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${ENV_EXAMPLE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_EXAMPLE_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  [[ -x "${VALIDATE_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${VALIDATE_SCRIPT}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v sha256sum >/dev/null 2>&1 \
    || fail "Comando sha256sum não encontrado."

  command -v gzip >/dev/null 2>&1 \
    || fail "Comando gzip não encontrado."

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
    fail "A validação falhou. Corrija os erros antes do backup."
  fi

  ok "Validação concluída."
}

discover_running_services() {
  info "Identificando os serviços atualmente ativos."

  mapfile -t RUNNING_SERVICES < <(
    compose ps \
      --services \
      --status running
  )

  if (( ${#RUNNING_SERVICES[@]} == 0 )); then
    warn "Nenhum serviço do projeto está em execução."
  else
    printf 'Serviços ativos:\n'
    printf '  - %s\n' "${RUNNING_SERVICES[@]}"
  fi
}

discover_volumes() {
  local project_name
  project_name="$(get_project_name)"

  info "Identificando os volumes do projeto ${project_name}."

  mapfile -t PROJECT_VOLUMES < <(
    docker volume ls \
      --filter "label=com.docker.compose.project=${project_name}" \
      --format '{{.Name}}' |
      sort
  )

  if (( ${#PROJECT_VOLUMES[@]} == 0 )); then
    fail "Nenhum volume Docker do projeto foi encontrado."
  fi

  printf 'Volumes encontrados:\n'
  printf '  - %s\n' "${PROJECT_VOLUMES[@]}"
}

check_free_space() {
  local free_kb
  local free_gb

  mkdir -p "${BACKUP_ROOT}"

  free_kb="$(df -Pk "${BACKUP_ROOT}" | awk 'NR == 2 {print $4}')"
  free_gb=$((free_kb / 1024 / 1024))

  if (( free_gb < 2 )); then
    fail "Espaço livre insuficiente para o backup: ${free_gb} GB."
  fi

  if (( free_gb < 10 )); then
    warn "Espaço livre disponível: ${free_gb} GB."
  else
    ok "Espaço livre disponível: ${free_gb} GB."
  fi
}

show_plan() {
  printf '\n'
  printf 'Resumo do backup:\n'
  printf '  Serviços ativos: %s\n' "${#RUNNING_SERVICES[@]}"
  printf '  Volumes:         %s\n' "${#PROJECT_VOLUMES[@]}"
  printf '  Reiniciar:       %s\n' "${RESTART_SERVICES}"
  printf '  Destino:         %s\n' "${BACKUP_ROOT}"
  printf '\n'
  printf 'Os serviços ativos serão interrompidos durante a cópia.\n'
  printf 'O arquivo .env não será incluído.\n'
  printf '\n'
}

confirm_backup() {
  if [[ "${ASSUME_YES}" == "true" ]]; then
    return
  fi

  local answer
  read -r -p "Continuar com o backup? [s/N] " answer

  case "${answer}" in
    s|S|sim|SIM|Sim)
      ;;
    *)
      warn "Backup cancelado."
      exit 0
      ;;
  esac
}

prepare_helper_image() {
  info "Preparando a imagem auxiliar ${BACKUP_HELPER_IMAGE}."

  docker pull "${BACKUP_HELPER_IMAGE}" >/dev/null

  ok "Imagem auxiliar disponível."
}

create_backup_directory() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

  BACKUP_DIR="${BACKUP_ROOT}/${timestamp}"
  install -d -m 0700 "${BACKUP_DIR}"
  install -d -m 0700 "${BACKUP_DIR}/volumes"
  install -d -m 0700 "${BACKUP_DIR}/metadata"

  ok "Diretório criado: ${BACKUP_DIR}"
}

record_metadata_before() {
  local project_name
  project_name="$(get_project_name)"

  {
    printf 'format_version=1\n'
    printf 'created_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'project_name=%s\n' "${project_name}"
    printf 'project_root=%s\n' "${PROJECT_ROOT}"
    printf 'helper_image=%s\n' "${BACKUP_HELPER_IMAGE}"
    printf 'restart_requested=%s\n' "${RESTART_SERVICES}"
    printf 'running_services=%s\n' "${RUNNING_SERVICES[*]:-none}"
    printf 'volumes=%s\n' "${PROJECT_VOLUMES[*]}"
    printf 'status=in_progress\n'
  } > "${BACKUP_DIR}/metadata/manifest.env"

  cp "${COMPOSE_FILE}" \
    "${BACKUP_DIR}/metadata/compose.yaml"

  cp "${ENV_EXAMPLE_FILE}" \
    "${BACKUP_DIR}/metadata/.env.example"

  compose ps -a \
    > "${BACKUP_DIR}/metadata/containers-before.txt"

  docker version \
    > "${BACKUP_DIR}/metadata/docker-version.txt"

  chmod 0600 "${BACKUP_DIR}/metadata/"*
  chmod 0600 "${BACKUP_DIR}/metadata/.env.example"
}

stop_running_services() {
  if (( ${#RUNNING_SERVICES[@]} == 0 )); then
    return
  fi

  info "Interrompendo os serviços ativos."

  compose stop \
    --timeout 120 \
    "${RUNNING_SERVICES[@]}"

  SERVICES_STOPPED=true

  local service
  local container_id
  local state

  for service in "${RUNNING_SERVICES[@]}"; do
    container_id="$(compose ps -a -q "${service}")"

    [[ -n "${container_id}" ]] \
      || fail "Container não encontrado após a parada: ${service}"

    state="$(
      docker inspect \
        --format '{{.State.Status}}' \
        "${container_id}"
    )"

    case "${state}" in
      exited|created)
        ok "${service}: ${state}"
        ;;
      *)
        fail "${service}: não foi interrompido corretamente (${state})."
        ;;
    esac
  done
}

archive_volume() {
  local volume=$1
  local archive_path="${BACKUP_DIR}/volumes/${volume}.tar.gz"

  info "Compactando o volume ${volume}."

  docker run \
    --rm \
    --volume "${volume}:/source:ro" \
    "${BACKUP_HELPER_IMAGE}" \
    sh -c 'cd /source && tar -czf - .' \
    > "${archive_path}"

  [[ -s "${archive_path}" ]] \
    || fail "O arquivo do volume ${volume} ficou vazio."

  gzip -t "${archive_path}" \
    || fail "O arquivo do volume ${volume} está corrompido."

  chmod 0600 "${archive_path}"

  ok "Volume protegido: ${volume}"
}

archive_all_volumes() {
  local volume

  for volume in "${PROJECT_VOLUMES[@]}"; do
    archive_volume "${volume}"
  done
}

generate_checksums() {
  info "Gerando checksums SHA-256."

  (
    cd "${BACKUP_DIR}"

    find metadata volumes \
      -type f \
      ! -name 'checksums.sha256' \
      -print0 |
      sort -z |
      xargs -0 sha256sum \
      > checksums.sha256
  )

  chmod 0600 "${BACKUP_DIR}/checksums.sha256"

  (
    cd "${BACKUP_DIR}"
    sha256sum --check checksums.sha256 >/dev/null
  )

  ok "Checksums verificados."
}

restart_previous_services() {
  if [[ "${RESTART_SERVICES}" != "true" ]] ||
     (( ${#RUNNING_SERVICES[@]} == 0 )); then
    return
  fi

  info "Reiniciando os serviços que estavam ativos."

  compose up \
    -d \
    --wait \
    --wait-timeout "${WAIT_TIMEOUT}" \
    "${RUNNING_SERVICES[@]}"

  SERVICES_STOPPED=false

  local service
  local container_id
  local state
  local health

  for service in "${RUNNING_SERVICES[@]}"; do
    container_id="$(compose ps -q "${service}")"

    [[ -n "${container_id}" ]] \
      || fail "Container não encontrado após a reinicialização: ${service}"

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

    [[ "${state}" == "running" ]] \
      || fail "${service}: estado inesperado após reinício: ${state}"

    [[ "${health}" != "unhealthy" ]] \
      || fail "${service}: health check unhealthy."

    ok "${service}: running / ${health}"
  done
}

record_success() {
  {
    printf '\n'
    printf 'completed_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'status=success\n'
  } >> "${BACKUP_DIR}/metadata/manifest.env"

  compose ps -a \
    > "${BACKUP_DIR}/metadata/containers-after.txt"

  chmod 0600 "${BACKUP_DIR}/metadata/containers-after.txt"

  generate_checksums
}

attempt_recovery() {
  local original_exit_code=$?

  trap - ERR

  if [[ "${SERVICES_STOPPED}" == "true" ]] &&
     [[ "${RESTART_SERVICES}" == "true" ]] &&
     (( ${#RUNNING_SERVICES[@]} > 0 )); then
    printf '\n[AVISO] Tentando reiniciar os serviços após a falha.\n' >&2

    if compose up \
      -d \
      --wait \
      --wait-timeout "${WAIT_TIMEOUT}" \
      "${RUNNING_SERVICES[@]}"; then
      SERVICES_STOPPED=false
      printf '[OK] Serviços recuperados após a falha.\n' >&2
    else
      printf '[ERRO] Não foi possível recuperar todos os serviços.\n' >&2
    fi
  fi

  if [[ -n "${BACKUP_DIR}" ]]; then
    printf '[INFO] Diretório do backup parcial: %s\n' \
      "${BACKUP_DIR}" >&2
  fi

  exit "${original_exit_code}"
}

show_summary() {
  printf '\n'
  printf 'Backup concluído com sucesso.\n'
  printf '\n'
  printf 'Local:    %s\n' "${BACKUP_DIR}"
  printf 'Volumes:  %s\n' "${#PROJECT_VOLUMES[@]}"
  printf 'Serviços: %s\n' "${#RUNNING_SERVICES[@]}"
  printf '\n'
  printf 'O arquivo .env não foi incluído.\n'

  if [[ "${RESTART_SERVICES}" == "true" ]]; then
    printf 'Os serviços anteriormente ativos foram reiniciados.\n'
  else
    printf 'Os serviços permaneceram parados por solicitação.\n'
  fi
}

main() {
  trap attempt_recovery ERR

  info "Iniciando o backup controlado do CompanyOS."

  parse_args "$@"
  check_requirements
  run_validation
  discover_running_services
  discover_volumes
  check_free_space
  show_plan
  confirm_backup
  prepare_helper_image
  create_backup_directory
  record_metadata_before
  stop_running_services
  archive_all_volumes
  restart_previous_services
  record_success
  show_summary
}

main "$@"
