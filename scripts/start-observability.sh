#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly OBSERVABILITY_COMPOSE="${PROJECT_ROOT}/compose.observability.yaml"
readonly PROBE_IMAGE="alpine:3.22.1"

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

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      -f "${OBSERVABILITY_COMPOSE}" \
      --profile observability \
      "$@"
  )
}

container_id() {
  compose ps -q "$1"
}

wait_container() {
  local service=$1
  local timeout=${2:-240}
  local started
  local now
  local id
  local state
  local health

  started="$(date +%s)"

  while true; do
    id="$(container_id "${service}")"

    if [[ -n "${id}" ]]; then
      state="$(
        docker inspect \
          --format '{{.State.Status}}' \
          "${id}"
      )"

      health="$(
        docker inspect \
          --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
          "${id}"
      )"

      if [[ "${state}" == "running" ]] &&
         [[ "${health}" != "unhealthy" ]] &&
         [[ "${health}" != "starting" ]]; then
        ok "${service}: running / ${health}"
        return
      fi
    fi

    now="$(date +%s)"

    if (( now - started >= timeout )); then
      compose ps -a "${service}" || true
      compose logs \
        --no-color \
        --tail=100 \
        "${service}" || true

      fail "${service} não ficou disponível em ${timeout} segundos."
    fi

    sleep 3
  done
}

get_project_name() {
  python3 - "${ENV_FILE}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
value = ""

for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()

    if (
        not line
        or line.startswith("#")
        or "=" not in line
    ):
        continue

    key, current = line.split("=", 1)

    if key.strip() != "COMPOSE_PROJECT_NAME":
        continue

    current = current.strip()

    if (
        len(current) >= 2
        and current[0] == current[-1]
        and current[0] in {'"', "'"}
    ):
        current = current[1:-1]

    value = current
    break

print(value or "ssc")
PY
}

probe_network() {
  printf '%s_observability' "$(get_project_name)"
}

probe_http() {
  local url=$1
  local network

  network="$(probe_network)"

  docker run \
    --rm \
    --pull=never \
    --network "${network}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --pids-limit 64 \
    --memory 64m \
    --cpus 0.25 \
    --tmpfs /tmp:rw,noexec,nosuid,size=8m \
    "${PROBE_IMAGE}" \
    wget \
      -q \
      --spider \
      "${url}"
}

wait_internal_http() {
  local name=$1
  local url=$2
  local timeout=${3:-240}
  local started
  local now

  started="$(date +%s)"

  while true; do
    if probe_http "${url}" >/dev/null 2>&1; then
      ok "${name}: disponível internamente"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= timeout )); then
      fail "${name} não ficou disponível internamente em ${timeout} segundos."
    fi

    sleep 3
  done
}

wait_host_http() {
  local name=$1
  local url=$2
  local timeout=${3:-240}
  local started
  local now

  started="$(date +%s)"

  while true; do
    if curl \
      --silent \
      --show-error \
      --fail \
      --connect-timeout 2 \
      --max-time 5 \
      "${url}" \
      >/dev/null 2>&1; then
      ok "${name}: disponível"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= timeout )); then
      fail "${name} não ficou disponível em ${timeout} segundos."
    fi

    sleep 3
  done
}

check_requirements() {
  local file

  for file in \
    "${ENV_FILE}" \
    "${BASE_COMPOSE}" \
    "${ACCESS_COMPOSE}" \
    "${OBSERVABILITY_COMPOSE}"; do
    [[ -s "${file}" ]] \
      || fail "Arquivo ausente ou vazio: ${file}"
  done

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v curl >/dev/null 2>&1 \
    || fail "curl não encontrado."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker image inspect "${PROBE_IMAGE}" >/dev/null 2>&1 \
    || fail "Imagem de sonda ausente: ${PROBE_IMAGE}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose config --quiet \
    || fail "Configuração Compose integrada inválida."
}

pull_images() {
  info "Baixando as imagens pinadas de observabilidade."

  compose pull \
    docker-socket-proxy \
    alloy \
    node-exporter \
    cadvisor \
    postgres-exporter \
    redis-exporter \
    blackbox-exporter \
    prometheus \
    loki \
    grafana

  ok "Imagens disponíveis."
}

prepare_service_metrics() {
  info "Aplicando métricas persistentes do RabbitMQ e MinIO."

  compose up \
    -d \
    --wait \
    --wait-timeout 300 \
    rabbitmq \
    minio

  ok "RabbitMQ e MinIO saudáveis."
}

start_collectors() {
  info "Iniciando Loki, proxy e coletores."

  compose up \
    -d \
    docker-socket-proxy \
    loki \
    node-exporter \
    cadvisor \
    postgres-exporter \
    redis-exporter \
    blackbox-exporter \
    alloy

  info "Iniciando Prometheus e Grafana."

  compose up \
    -d \
    prometheus \
    grafana

  ok "Containers de observabilidade solicitados."
}

wait_services() {
  info "Aguardando os serviços."

  wait_container prometheus 240
  wait_container loki 240
  wait_container grafana 240

  wait_internal_http \
    "Prometheus" \
    "http://prometheus:9090/-/healthy" \
    240

  wait_internal_http \
    "Loki" \
    "http://loki:3100/ready" \
    240

  wait_host_http \
    "Grafana" \
    "http://127.0.0.1:3000/api/health" \
    240
}

show_status() {
  compose ps

  printf '\n'
  ok "Observabilidade inicializada."
  printf 'Grafana: http://192.168.3.19:3000\n'
  printf 'Prometheus: acesso interno pela rede Docker\n'
  printf 'Loki: acesso interno pela rede Docker\n'
}

main() {
  check_requirements
  pull_images
  prepare_service_metrics
  start_collectors
  wait_services
  show_status
}

main "$@"
