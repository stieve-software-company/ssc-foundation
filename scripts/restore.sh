#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE_FILE="${PROJECT_ROOT}/compose.access.yaml"
readonly OBSERVABILITY_COMPOSE_FILE="${PROJECT_ROOT}/compose.observability.yaml"
readonly BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
readonly BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/archives"
readonly REPORT_ROOT="${PROJECT_ROOT}/infrastructure/backups/restore-reports"
readonly BACKUP_HELPER_IMAGE="alpine:3.22.1"

BACKUP_DIR=""
SAFETY_BACKUP_DIR=""
REPORT_DIR=""
ASSUME_YES=false
CREATE_SAFETY_BACKUP=true
RESTART_SERVICES=true
WAIT_TIMEOUT=300
RESTORE_STARTED=false
SERVICES_STOPPED=false

RUNNING_SERVICES=()
ARCHIVE_VOLUMES=()

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
  ./scripts/restore.sh --latest
  ./scripts/restore.sh --backup <diretório>
  ./scripts/restore.sh --list
  ./scripts/restore.sh --latest --yes

Opções:
  --latest               Restaura o backup concluído mais recente.
  --backup <diretório>   Restaura um backup específico.
  --list                 Lista os backups disponíveis.
  --yes, -y              Não solicita confirmação interativa.
  --no-safety-backup     Não cria backup do estado atual antes da restauração.
  --no-restart           Mantém os serviços parados após a restauração.
  --wait-timeout <seg>   Tempo máximo para health checks. Padrão: 300.
  --help, -h             Exibe esta ajuda.

Comportamento padrão:
  - Verifica checksums e arquivos compactados.
  - Confirma que o backup pertence ao mesmo projeto.
  - Cria um backup de segurança do estado atual.
  - Para somente os serviços que estavam ativos.
  - Limpa e restaura os volumes incluídos no backup.
  - Reinicia somente os serviços que estavam ativos.

A restauração substitui o conteúdo atual dos volumes selecionados.
EOF
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    local compose_files=(
      -f "${COMPOSE_FILE}"
    )

    if [[ -s "${ACCESS_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${ACCESS_COMPOSE_FILE}"
      )
    fi

    if [[ -s "${OBSERVABILITY_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${OBSERVABILITY_COMPOSE_FILE}"
      )
    fi

    docker compose \
      --env-file "${ENV_FILE}" \
      "${compose_files[@]}" \
      --profile "*" \
      "$@"
  )
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

  printf '%s' "${value:-${default_value}}"
}

get_manifest_value() {
  local key=$1
  local manifest="${BACKUP_DIR}/metadata/manifest.env"

  awk -F= -v wanted="${key}" '
    $1 == wanted {
      sub(/^[^=]*=/, "", $0)
      value=$0
    }
    END {
      print value
    }
  ' "${manifest}"
}

latest_backup() {
  find "${BACKUP_ROOT}" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    awk 'NR == 1 {
      sub(/^[^ ]+ /, "", $0)
      print
    }'
}

list_backups() {
  mkdir -p "${BACKUP_ROOT}"

  printf 'Backups disponíveis:\n\n'

  local found=0
  local directory
  local status
  local created_at
  local volume_count

  while IFS= read -r directory; do
    [[ -n "${directory}" ]] || continue
    found=1

    status="$(
      awk -F= '
        $1 == "status" {
          sub(/^[^=]*=/, "", $0)
          value=$0
        }
        END {
          print value
        }
      ' "${directory}/metadata/manifest.env" 2>/dev/null || true
    )"

    created_at="$(
      awk -F= '
        $1 == "created_at" {
          sub(/^[^=]*=/, "", $0)
          print $0
          exit
        }
      ' "${directory}/metadata/manifest.env" 2>/dev/null || true
    )"

    volume_count="$(
      find "${directory}/volumes" \
        -maxdepth 1 \
        -type f \
        -name '*.tar.gz' 2>/dev/null |
        wc -l |
        tr -d ' '
    )"

    printf '%s\n' "${directory}"
    printf '  criado:  %s\n' "${created_at:-desconhecido}"
    printf '  status:  %s\n' "${status:-desconhecido}"
    printf '  volumes: %s\n\n' "${volume_count}"
  done < <(
    find "${BACKUP_ROOT}" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d |
      sort -r
  )

  if (( found == 0 )); then
    warn "Nenhum backup encontrado."
  fi
}

parse_args() {
  local selection_count=0

  while (($# > 0)); do
    case "$1" in
      --latest)
        BACKUP_DIR="$(latest_backup)"
        selection_count=$((selection_count + 1))
        ;;
      --backup)
        shift
        (($# > 0)) || fail "Informe um diretório após --backup."
        BACKUP_DIR=$1
        selection_count=$((selection_count + 1))
        ;;
      --list)
        list_backups
        exit 0
        ;;
      --yes|-y)
        ASSUME_YES=true
        ;;
      --no-safety-backup)
        CREATE_SAFETY_BACKUP=false
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

  if (( selection_count == 0 )); then
    fail "Escolha --latest ou --backup <diretório>."
  fi

  if (( selection_count > 1 )); then
    fail "Escolha somente uma origem de backup."
  fi

  [[ -n "${BACKUP_DIR}" ]] \
    || fail "Nenhum backup foi encontrado."

  BACKUP_DIR="$(readlink -f "${BACKUP_DIR}")"
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  [[ -x "${BACKUP_SCRIPT}" ]] \
    || fail "Script ausente ou sem permissão de execução: ${BACKUP_SCRIPT}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v sha256sum >/dev/null 2>&1 \
    || fail "Comando sha256sum não encontrado."

  command -v gzip >/dev/null 2>&1 \
    || fail "Comando gzip não encontrado."

  command -v tar >/dev/null 2>&1 \
    || fail "Comando tar não encontrado."

  command -v readlink >/dev/null 2>&1 \
    || fail "Comando readlink não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  if ! [[ "${WAIT_TIMEOUT}" =~ ^[0-9]+$ ]] ||
     (( WAIT_TIMEOUT < 30 || WAIT_TIMEOUT > 3600 )); then
    fail "--wait-timeout deve estar entre 30 e 3600 segundos."
  fi
}

validate_backup_structure() {
  info "Validando a estrutura do backup."

  [[ -d "${BACKUP_DIR}" ]] \
    || fail "Diretório de backup não encontrado: ${BACKUP_DIR}"

  [[ -s "${BACKUP_DIR}/metadata/manifest.env" ]] \
    || fail "Manifesto ausente ou vazio."

  [[ -s "${BACKUP_DIR}/checksums.sha256" ]] \
    || fail "Arquivo de checksums ausente ou vazio."

  [[ -d "${BACKUP_DIR}/volumes" ]] \
    || fail "Diretório de volumes ausente."

  local status
  status="$(get_manifest_value status)"

  [[ "${status}" == "success" ]] \
    || fail "O backup não está marcado como concluído com sucesso."

  ok "Estrutura do backup válida."
}

validate_project_identity() {
  local current_project
  local backup_project

  current_project="$(get_env_value COMPOSE_PROJECT_NAME ssc)"
  backup_project="$(get_manifest_value project_name)"

  [[ -n "${backup_project}" ]] \
    || fail "O manifesto não informa o projeto de origem."

  if [[ "${current_project}" != "${backup_project}" ]]; then
    fail "Projeto incompatível. Atual: ${current_project}; backup: ${backup_project}."
  fi

  ok "Backup pertence ao projeto ${current_project}."
}

verify_checksums() {
  info "Verificando checksums SHA-256."

  (
    cd "${BACKUP_DIR}"
    sha256sum --check checksums.sha256
  )

  ok "Checksums válidos."
}

discover_archives() {
  info "Identificando os volumes presentes no backup."

  mapfile -t ARCHIVE_VOLUMES < <(
    find "${BACKUP_DIR}/volumes" \
      -maxdepth 1 \
      -type f \
      -name '*.tar.gz' \
      -printf '%f\n' |
      sed 's/\.tar\.gz$//' |
      sort
  )

  (( ${#ARCHIVE_VOLUMES[@]} > 0 )) \
    || fail "Nenhum arquivo de volume foi encontrado."

  local volume
  local archive

  for volume in "${ARCHIVE_VOLUMES[@]}"; do
    [[ "${volume}" =~ ^[a-zA-Z0-9_.-]+$ ]] \
      || fail "Nome de volume inválido no backup: ${volume}"

    archive="${BACKUP_DIR}/volumes/${volume}.tar.gz"

    gzip -t "${archive}" \
      || fail "Arquivo compactado inválido: ${archive}"

    if tar -tzf "${archive}" |
       grep -Eq '(^/|(^|/)\.\.(/|$))'; then
      fail "O arquivo ${archive} contém caminhos inseguros."
    fi

    printf '  - %s\n' "${volume}"
  done

  ok "${#ARCHIVE_VOLUMES[@]} volume(s) pronto(s) para restauração."
}

discover_running_services() {
  info "Registrando os serviços atualmente ativos."

  mapfile -t RUNNING_SERVICES < <(
    compose ps \
      --services \
      --status running
  )

  if (( ${#RUNNING_SERVICES[@]} == 0 )); then
    warn "Nenhum serviço está em execução."
  else
    printf 'Serviços ativos:\n'
    printf '  - %s\n' "${RUNNING_SERVICES[@]}"
  fi
}

show_plan() {
  printf '\n'
  printf 'Plano de restauração:\n'
  printf '  Backup:                %s\n' "${BACKUP_DIR}"
  printf '  Volumes:               %s\n' "${#ARCHIVE_VOLUMES[@]}"
  printf '  Serviços ativos:       %s\n' "${#RUNNING_SERVICES[@]}"
  printf '  Backup de segurança:   %s\n' "${CREATE_SAFETY_BACKUP}"
  printf '  Reiniciar serviços:    %s\n' "${RESTART_SERVICES}"
  printf '\n'
  printf 'ATENÇÃO: o conteúdo atual dos volumes listados será substituído.\n'
  printf '\n'
}

confirm_restore() {
  if [[ "${ASSUME_YES}" == "true" ]]; then
    return
  fi

  local answer

  read -r -p 'Digite RESTAURAR para continuar: ' answer

  [[ "${answer}" == "RESTAURAR" ]] \
    || fail "Restauração cancelada."
}

create_restore_report() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

  REPORT_DIR="${REPORT_ROOT}/${timestamp}"
  install -d -m 0700 "${REPORT_DIR}"

  {
    printf 'started_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'target_backup=%s\n' "${BACKUP_DIR}"
    printf 'safety_backup_enabled=%s\n' "${CREATE_SAFETY_BACKUP}"
    printf 'restart_requested=%s\n' "${RESTART_SERVICES}"
    printf 'running_services=%s\n' "${RUNNING_SERVICES[*]:-none}"
    printf 'volumes=%s\n' "${ARCHIVE_VOLUMES[*]}"
    printf 'status=in_progress\n'
  } > "${REPORT_DIR}/restore.env"

  chmod 0600 "${REPORT_DIR}/restore.env"
}

create_safety_backup() {
  if [[ "${CREATE_SAFETY_BACKUP}" != "true" ]]; then
    warn "Backup de segurança desativado."
    return
  fi

  info "Criando backup de segurança do estado atual."

  local previous_latest
  previous_latest="$(latest_backup)"

  "${BACKUP_SCRIPT}" \
    --yes \
    --no-restart \
    --wait-timeout "${WAIT_TIMEOUT}"

  SAFETY_BACKUP_DIR="$(latest_backup)"

  [[ -n "${SAFETY_BACKUP_DIR}" ]] \
    || fail "Não foi possível localizar o backup de segurança."

  if [[ "${SAFETY_BACKUP_DIR}" == "${previous_latest}" ]]; then
    fail "O backup de segurança não foi criado."
  fi

  SERVICES_STOPPED=true

  {
    printf 'safety_backup=%s\n' "${SAFETY_BACKUP_DIR}"
  } >> "${REPORT_DIR}/restore.env"

  ok "Backup de segurança criado: ${SAFETY_BACKUP_DIR}"
}

stop_running_services() {
  if [[ "${CREATE_SAFETY_BACKUP}" == "true" ]]; then
    return
  fi

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
      || fail "Container não encontrado: ${service}"

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

ensure_services_stopped() {
  local running_after_stop

  running_after_stop="$(
    compose ps \
      --services \
      --status running
  )"

  if [[ -n "${running_after_stop}" ]]; then
    printf '%s\n' "${running_after_stop}" >&2
    fail "Ainda existem serviços do projeto em execução."
  fi

  ok "Todos os serviços do projeto estão parados."
}

ensure_volume_exists() {
  local volume=$1
  local project_name
  local logical_name

  if docker volume inspect "${volume}" >/dev/null 2>&1; then
    return
  fi

  project_name="$(get_env_value COMPOSE_PROJECT_NAME ssc)"
  logical_name="${volume#${project_name}_}"

  info "Criando o volume ausente ${volume}."

  docker volume create \
    --label "com.docker.compose.project=${project_name}" \
    --label "com.docker.compose.volume=${logical_name}" \
    "${volume}" >/dev/null
}

restore_volume() {
  local volume=$1
  local archive_name="${volume}.tar.gz"

  ensure_volume_exists "${volume}"

  info "Restaurando o volume ${volume}."

  RESTORE_STARTED=true

  docker run \
    --rm \
    --volume "${volume}:/target" \
    --volume "${BACKUP_DIR}/volumes:/backup:ro" \
    "${BACKUP_HELPER_IMAGE}" \
    sh -ceu '
      find /target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      tar -xzf "/backup/$1" -C /target
    ' sh "${archive_name}"

  ok "Volume restaurado: ${volume}"
}

restore_all_volumes() {
  info "Iniciando a restauração dos volumes."

  docker pull "${BACKUP_HELPER_IMAGE}" >/dev/null

  local volume

  for volume in "${ARCHIVE_VOLUMES[@]}"; do
    restore_volume "${volume}"
  done
}

restart_previous_services() {
  if [[ "${RESTART_SERVICES}" != "true" ]] ||
     (( ${#RUNNING_SERVICES[@]} == 0 )); then
    return
  fi

  info "Reiniciando os serviços anteriormente ativos."

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
      || fail "Container não encontrado após reinício: ${service}"

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
      || fail "${service}: estado inesperado: ${state}"

    [[ "${health}" != "unhealthy" ]] \
      || fail "${service}: health check unhealthy."

    ok "${service}: running / ${health}"
  done
}

record_success() {
  {
    printf 'completed_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'status=success\n'
  } >> "${REPORT_DIR}/restore.env"

  compose ps -a \
    > "${REPORT_DIR}/containers-after.txt"

  chmod 0600 "${REPORT_DIR}/containers-after.txt"

  (
    cd "${REPORT_DIR}"
    sha256sum restore.env containers-after.txt > checksums.sha256
  )

  chmod 0600 "${REPORT_DIR}/checksums.sha256"
}

handle_error() {
  local exit_code=$?

  trap - ERR

  printf '\n[ERRO] A restauração não foi concluída.\n' >&2

  if [[ "${RESTORE_STARTED}" == "true" ]]; then
    printf '[AVISO] Houve alteração em pelo menos um volume.\n' >&2
    printf '[AVISO] Os serviços permanecerão parados para proteger os dados.\n' >&2

    if [[ -n "${SAFETY_BACKUP_DIR}" ]]; then
      printf '[INFO] Backup de segurança: %s\n' \
        "${SAFETY_BACKUP_DIR}" >&2
    fi
  elif [[ "${SERVICES_STOPPED}" == "true" ]] &&
       [[ "${RESTART_SERVICES}" == "true" ]] &&
       (( ${#RUNNING_SERVICES[@]} > 0 )); then
    printf '[INFO] Nenhum volume foi alterado; tentando recuperar os serviços.\n' >&2

    compose up \
      -d \
      --wait \
      --wait-timeout "${WAIT_TIMEOUT}" \
      "${RUNNING_SERVICES[@]}" || true
  fi

  if [[ -n "${REPORT_DIR}" ]]; then
    {
      printf 'failed_at=%s\n' "$(date --iso-8601=seconds)"
      printf 'status=failed\n'
    } >> "${REPORT_DIR}/restore.env"

    printf '[INFO] Relatório: %s\n' "${REPORT_DIR}" >&2
  fi

  exit "${exit_code}"
}

show_summary() {
  printf '\n'
  printf 'Restauração concluída com sucesso.\n'
  printf '\n'
  printf 'Backup restaurado:   %s\n' "${BACKUP_DIR}"

  if [[ -n "${SAFETY_BACKUP_DIR}" ]]; then
    printf 'Backup de segurança: %s\n' "${SAFETY_BACKUP_DIR}"
  fi

  printf 'Relatório:            %s\n' "${REPORT_DIR}"
  printf 'Volumes restaurados:  %s\n' "${#ARCHIVE_VOLUMES[@]}"
  printf '\n'

  if [[ "${RESTART_SERVICES}" == "true" ]]; then
    printf 'Os serviços anteriormente ativos foram reiniciados.\n'
  else
    printf 'Os serviços permaneceram parados por solicitação.\n'
  fi
}

main() {
  trap handle_error ERR

  info "Iniciando a restauração controlada do CompanyOS."

  parse_args "$@"
  check_requirements
  validate_backup_structure
  validate_project_identity
  verify_checksums
  discover_archives
  discover_running_services
  show_plan
  confirm_restore
  create_restore_report
  create_safety_backup
  stop_running_services
  ensure_services_stopped
  restore_all_volumes
  restart_previous_services
  record_success
  show_summary
}

main "$@"
