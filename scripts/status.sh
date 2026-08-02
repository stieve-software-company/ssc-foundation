#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
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

section() {
  printf '\n'
  printf '============================================================\n'
  printf '%s\n' "$*"
  printf '============================================================\n'
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

show_platform_summary() {
  section "1. Plataforma"

  local environment
  local version
  local project_name

  environment="$(
    awk -F= '
      $1 == "SSC_ENVIRONMENT" {
        sub(/^[^=]*=/, "", $0)
        print $0
      }
    ' "${ENV_FILE}" | tail -n 1
  )"

  version="$(
    awk -F= '
      $1 == "SSC_VERSION" {
        sub(/^[^=]*=/, "", $0)
        print $0
      }
    ' "${ENV_FILE}" | tail -n 1
  )"

  project_name="$(
    awk -F= '
      $1 == "COMPOSE_PROJECT_NAME" {
        sub(/^[^=]*=/, "", $0)
        print $0
      }
    ' "${ENV_FILE}" | tail -n 1
  )"

  printf 'Projeto Docker: %s\n' "${project_name:-ssc}"
  printf 'Ambiente:       %s\n' "${environment:-development}"
  printf 'Versão:         %s\n' "${version:-não definida}"
  printf 'Diretório:      %s\n' "${PROJECT_ROOT}"
}

show_containers() {
  section "2. Containers"

  local output

  output="$(compose --profile "*" ps -a 2>/dev/null || true)"

  if [[ -z "${output}" ]]; then
    warn "Nenhum container foi criado."
    return
  fi

  printf '%s\n' "${output}"
}

show_health() {
  section "3. Saúde dos serviços"

  local service
  local container_id
  local state
  local health
  local found=0

  while IFS= read -r service; do
    [[ -n "${service}" ]] || continue

    container_id="$(compose --profile "*" ps -a -q "${service}")"

    if [[ -z "${container_id}" ]]; then
      printf '%-16s %s\n' "${service}" "não criado"
      continue
    fi

    found=1

    state="$(
      docker inspect \
        --format '{{.State.Status}}' \
        "${container_id}"
    )"

    health="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem healthcheck{{end}}' \
        "${container_id}"
    )"

    printf '%-16s estado=%-10s saúde=%s\n' \
      "${service}" "${state}" "${health}"
  done < <(compose --profile "*" config --services)

  if (( found == 0 )); then
    warn "Nenhum serviço possui container criado."
  fi
}

show_resource_usage() {
  section "4. CPU e memória"

  local container_ids=()

  while IFS= read -r container_id; do
    [[ -n "${container_id}" ]] && container_ids+=("${container_id}")
  done < <(compose --profile "*" ps -q)

  if (( ${#container_ids[@]} == 0 )); then
    warn "Nenhum container em execução."
    return
  fi

  docker stats \
    --no-stream \
    --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' \
    "${container_ids[@]}"
}

show_volumes() {
  section "5. Volumes"

  local volume
  local volume_names

  volume_names="$(compose --profile "*" config --volumes 2>/dev/null || true)"

  if [[ -z "${volume_names}" ]]; then
    warn "Nenhum volume configurado."
    return
  fi

  while IFS= read -r volume; do
    [[ -n "${volume}" ]] || continue

    if docker volume inspect "${volume}" >/dev/null 2>&1; then
      printf '%-32s %s\n' "${volume}" "criado"
    else
      printf '%-32s %s\n' "${volume}" "não criado"
    fi
  done <<< "${volume_names}"
}

show_networks() {
  section "6. Redes"

  local network
  local network_names

  network_names="$(compose --profile "*" config --networks 2>/dev/null || true)"

  if [[ -z "${network_names}" ]]; then
    warn "Nenhuma rede configurada."
    return
  fi

  while IFS= read -r network; do
    [[ -n "${network}" ]] || continue

    if docker network inspect "${network}" >/dev/null 2>&1; then
      printf '%-32s %s\n' "${network}" "criada"
    else
      printf '%-32s %s\n' "${network}" "não criada"
    fi
  done <<< "${network_names}"
}

show_disk_usage() {
  section "7. Armazenamento"

  df -h "${PROJECT_ROOT}"

  printf '\n'
  docker system df
}

show_ports() {
  section "8. Portas publicadas"

  local output

  output="$(
    compose --profile "*" ps \
      --format 'table {{.Service}}\t{{.State}}\t{{.Ports}}' \
      2>/dev/null || true
  )"

  if [[ -z "${output}" ]]; then
    warn "Nenhuma porta publicada por containers ativos."
    return
  fi

  printf '%s\n' "${output}"
}

show_profiles() {
  section "9. Perfis configurados"

  compose config --profiles
}

show_summary() {
  section "Resultado"

  local running_count
  local unhealthy_count

  running_count="$(compose --profile "*" ps -q | wc -l | tr -d ' ')"

  unhealthy_count="$(
    local container_id
    local count=0

    while IFS= read -r container_id; do
      [[ -n "${container_id}" ]] || continue

      if [[ "$(
        docker inspect \
          --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
          "${container_id}"
      )" == "unhealthy" ]]; then
        count=$((count + 1))
      fi
    done < <(compose --profile "*" ps -q)

    printf '%s' "${count}"
  )"

  printf 'Containers em execução: %s\n' "${running_count}"
  printf 'Containers unhealthy:   %s\n' "${unhealthy_count}"

  if (( unhealthy_count > 0 )); then
    fail "Existem containers unhealthy."
  fi

  ok "Consulta de status concluída."
}

main() {
  info "Consultando o estado do CompanyOS."

  check_requirements
  show_platform_summary
  show_containers
  show_health
  show_resource_usage
  show_volumes
  show_networks
  show_disk_usage
  show_ports
  show_profiles
  show_summary
}

main "$@"
