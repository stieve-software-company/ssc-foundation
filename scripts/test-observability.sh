#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly OBSERVABILITY_COMPOSE="${PROJECT_ROOT}/compose.observability.yaml"
readonly REPORT_FILE="${PROJECT_ROOT}/observability-test.txt"
readonly PROBE_IMAGE="alpine:3.22.1"

TEMP_DIR=""

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

cleanup() {
  if [[ -n "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi
}

trap cleanup EXIT INT TERM

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

probe_run() {
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
    "$@"
}

internal_get() {
  local url=$1
  local destination=$2

  probe_run \
    wget \
      -qO- \
      "${url}" \
    > "${destination}"
}

wait_internal_http() {
  local name=$1
  local url=$2
  local timeout=${3:-240}
  local started
  local now

  started="$(date +%s)"

  while true; do
    if probe_run \
      wget \
        -q \
        --spider \
        "${url}" \
      >/dev/null 2>&1; then
      ok "${name}"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= timeout )); then
      fail "${name} não ficou disponível em ${timeout} segundos."
    fi

    sleep 4
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
      ok "${name}"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= timeout )); then
      fail "${name} não ficou disponível em ${timeout} segundos."
    fi

    sleep 4
  done
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  command -v curl >/dev/null 2>&1 \
    || fail "curl não encontrado."

  docker image inspect "${PROBE_IMAGE}" >/dev/null 2>&1 \
    || fail "Imagem de sonda ausente: ${PROBE_IMAGE}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose config --quiet \
    || fail "Configuração Compose inválida."

  TEMP_DIR="$(
    mktemp -d \
      "${PROJECT_ROOT}/.observability-test.XXXXXX"
  )"

  chmod 0700 "${TEMP_DIR}"
}

check_internal_only_model() {
  info "Validando que Prometheus e Loki não publicam portas."

  local model_json="${TEMP_DIR}/compose.json"

  compose config --format json \
    > "${model_json}"

  python3 - "${model_json}" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

path = Path(sys.argv[1])

with path.open("r", encoding="utf-8") as stream:
    model = json.load(stream)

services = model.get("services", {})

for service_name in ("prometheus", "loki"):
    service = services.get(service_name)

    if not isinstance(service, dict):
        raise RuntimeError(
            f"Serviço ausente: {service_name}"
        )

    ports = service.get("ports")

    if ports not in (None, []):
        raise RuntimeError(
            f"{service_name} ainda publica portas: {ports}"
        )

print("[OK] Modelo interno confirmado.")
PY

  local service
  local id
  local runtime_ports

  for service in prometheus loki; do
    id="$(container_id "${service}")"

    [[ -n "${id}" ]] \
      || fail "Container ausente: ${service}"

    runtime_ports="$(
      docker port "${id}" 2>/dev/null || true
    )"

    [[ -z "${runtime_ports}" ]] \
      || fail "${service} possui porta publicada: ${runtime_ports}"
  done

  ok "Prometheus e Loki permanecem internos."
}

check_containers() {
  info "Validando os containers."

  local services=(
    rabbitmq
    minio
    prometheus
    loki
    grafana
    docker-socket-proxy
    alloy
    node-exporter
    cadvisor
    postgres-exporter
    redis-exporter
    blackbox-exporter
  )

  local service
  local id
  local state
  local health

  for service in "${services[@]}"; do
    id="$(container_id "${service}")"

    [[ -n "${id}" ]] \
      || fail "Container ausente: ${service}"

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

    [[ "${state}" == "running" ]] \
      || fail "${service}: estado ${state}"

    [[ "${health}" != "unhealthy" ]] \
      || fail "${service}: health unhealthy"

    printf '[OK] %s: running / %s\n' \
      "${service}" \
      "${health}"
  done
}

check_socket_isolation() {
  info "Validando o isolamento do Docker Socket."

  local alloy_id
  local proxy_id
  local alloy_socket
  local proxy_socket
  local published_ports

  alloy_id="$(container_id alloy)"
  proxy_id="$(container_id docker-socket-proxy)"

  alloy_socket="$(
    docker inspect \
      --format '{{range .Mounts}}{{if eq .Destination "/var/run/docker.sock"}}yes{{end}}{{end}}' \
      "${alloy_id}"
  )"

  proxy_socket="$(
    docker inspect \
      --format '{{range .Mounts}}{{if eq .Destination "/var/run/docker.sock"}}yes{{end}}{{end}}' \
      "${proxy_id}"
  )"

  published_ports="$(
    docker port "${proxy_id}" 2>/dev/null || true
  )"

  [[ -z "${alloy_socket}" ]] \
    || fail "Alloy recebeu o Docker Socket bruto."

  [[ "${proxy_socket}" == "yes" ]] \
    || fail "Proxy não recebeu o Docker Socket."

  [[ -z "${published_ports}" ]] \
    || fail "Docker Socket Proxy possui porta publicada."

  docker inspect \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    "${proxy_id}" |
    grep -Fxq 'POST=0' \
    || fail "POST não está bloqueado no proxy."

  ok "Docker Socket isolado por proxy sem porta publicada."
}

check_volumes() {
  info "Validando volumes persistentes."

  local volumes=(
    ssc_prometheus_data
    ssc_loki_data
    ssc_grafana_data
    ssc_alloy_data
  )

  local volume

  for volume in "${volumes[@]}"; do
    docker volume inspect "${volume}" >/dev/null 2>&1 \
      || fail "Volume ausente: ${volume}"

    printf '[OK] Volume encontrado: %s\n' "${volume}"
  done
}

validate_prometheus_targets() {
  local target_file="${TEMP_DIR}/targets.json"
  local reason_file="${TEMP_DIR}/targets-reason.txt"
  local started
  local now

  started="$(date +%s)"

  while true; do
    if internal_get \
      "http://prometheus:9090/api/v1/targets" \
      "${target_file}" &&
      python3 - \
        "${target_file}" \
        "${reason_file}" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

target_path = Path(sys.argv[1])
reason_path = Path(sys.argv[2])

required_jobs = {
    "prometheus",
    "node",
    "containers",
    "postgres",
    "redis",
    "rabbitmq",
    "minio",
    "loki",
    "grafana",
    "alloy",
    "blackbox-exporter",
    "blackbox-http",
}

try:
    payload = json.loads(
        target_path.read_text(encoding="utf-8")
    )
except Exception as exc:
    reason_path.write_text(
        f"JSON inválido: {exc}\n",
        encoding="utf-8",
    )
    raise SystemExit(1)

targets = (
    payload.get("data", {})
    .get("activeTargets", [])
)

jobs: dict[str, list[str]] = {}

for target in targets:
    labels = target.get("labels", {})
    job = labels.get("job", "")
    health = target.get("health", "unknown")
    jobs.setdefault(job, []).append(health)

missing = sorted(required_jobs - set(jobs))
unhealthy = {
    job: states
    for job, states in jobs.items()
    if job in required_jobs
    and any(state != "up" for state in states)
}

if missing or unhealthy:
    reason_path.write_text(
        (
            f"missing={missing}\n"
            f"unhealthy={unhealthy}\n"
        ),
        encoding="utf-8",
    )
    raise SystemExit(1)

reason_path.write_text(
    "all_targets_up=true\n",
    encoding="utf-8",
)
PY
    then
      ok "Todos os targets obrigatórios estão UP"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= 300 )); then
      cat "${reason_file}" 2>/dev/null || true
      fail "Os targets do Prometheus não ficaram UP."
    fi

    sleep 5
  done
}

validate_loki_logs() {
  local logs_file="${TEMP_DIR}/loki-logs.json"
  local reason_file="${TEMP_DIR}/loki-reason.txt"
  local query_url
  local started
  local now

  query_url='http://loki:3100/loki/api/v1/query_range?query=%7Bplatform%3D%22companyos%22%7D&limit=50&direction=backward'
  started="$(date +%s)"

  while true; do
    if internal_get "${query_url}" "${logs_file}" &&
      python3 - \
        "${logs_file}" \
        "${reason_file}" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

logs_path = Path(sys.argv[1])
reason_path = Path(sys.argv[2])

try:
    payload = json.loads(
        logs_path.read_text(encoding="utf-8")
    )
except Exception as exc:
    reason_path.write_text(
        f"JSON inválido: {exc}\n",
        encoding="utf-8",
    )
    raise SystemExit(1)

result = (
    payload.get("data", {})
    .get("result", [])
)

if not result:
    reason_path.write_text(
        "result=empty\n",
        encoding="utf-8",
    )
    raise SystemExit(1)

services = {
    stream.get("stream", {}).get("service", "")
    for stream in result
}

services.discard("")

if not services:
    reason_path.write_text(
        "service_labels=absent\n",
        encoding="utf-8",
    )
    raise SystemExit(1)

reason_path.write_text(
    "services=" + ",".join(sorted(services)) + "\n",
    encoding="utf-8",
)
PY
    then
      ok "Loki recebeu logs com labels do CompanyOS"
      return
    fi

    now="$(date +%s)"

    if (( now - started >= 300 )); then
      cat "${reason_file}" 2>/dev/null || true
      fail "O Loki não recebeu logs válidos do CompanyOS."
    fi

    sleep 5
  done
}

validate_grafana() {
  info "Validando Grafana, datasources e dashboards."

  python3 - "${ENV_FILE}" <<'PY'
from __future__ import annotations

import base64
import json
from pathlib import Path
import sys
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

env_path = Path(sys.argv[1])


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        value = value.strip()

        if (
            len(value) >= 2
            and value[0] == value[-1]
            and value[0] in {'"', "'"}
        ):
            value = value[1:-1]

        values[key.strip()] = value

    return values


def get_json(
    url: str,
    *,
    username: str | None = None,
    password: str | None = None,
    timeout: float = 5,
) -> object:
    headers: dict[str, str] = {}

    if username is not None and password is not None:
        token = base64.b64encode(
            f"{username}:{password}".encode()
        ).decode()
        headers["Authorization"] = f"Basic {token}"

    request = Request(url, headers=headers)

    with urlopen(request, timeout=timeout) as response:
        if response.status != 200:
            raise RuntimeError(
                f"HTTP {response.status}: {url}"
            )

        return json.loads(response.read().decode())


def wait_until(
    name: str,
    function,
    timeout: int = 240,
    interval: int = 5,
) -> object:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None

    while time.monotonic() < deadline:
        try:
            value = function()
            print(f"[OK] {name}")
            return value
        except Exception as exc:
            last_error = exc
            time.sleep(interval)

    raise RuntimeError(
        f"{name} não ficou pronto: {last_error}"
    )


env = load_env(env_path)
username = env.get("GRAFANA_ADMIN_USER", "")
password = env.get("GRAFANA_ADMIN_PASSWORD", "")

if not username or not password:
    raise RuntimeError(
        "Credenciais privadas do Grafana não encontradas."
    )

wait_until(
    "Grafana healthy",
    lambda: get_json(
        "http://127.0.0.1:3000/api/health"
    ),
)


def grafana_get(path: str) -> object:
    return get_json(
        "http://127.0.0.1:3000" + path,
        username=username,
        password=password,
    )


wait_until(
    "Datasource Prometheus provisionado",
    lambda: grafana_get(
        "/api/datasources/uid/prometheus"
    ),
)

wait_until(
    "Datasource Loki provisionado",
    lambda: grafana_get(
        "/api/datasources/uid/loki"
    ),
)

dashboards = wait_until(
    "Dashboards CompanyOS provisionados",
    lambda: grafana_get(
        "/api/search?query="
        + quote("CompanyOS")
    ),
)

if not isinstance(dashboards, list):
    raise RuntimeError(
        "Resposta de dashboards inválida."
    )

titles = {
    item.get("title")
    for item in dashboards
    if isinstance(item, dict)
}

expected = {
    "CompanyOS Infrastructure",
    "CompanyOS Logs",
}

missing = expected - titles

if missing:
    raise RuntimeError(
        "Dashboards ausentes: "
        + ", ".join(sorted(missing))
    )

print("[OK] Datasources e dashboards validados.")
PY
}

validate_endpoints_and_targets() {
  info "Validando endpoints internos e Grafana."

  wait_internal_http \
    "Prometheus healthy" \
    "http://prometheus:9090/-/healthy" \
    240

  wait_internal_http \
    "Loki ready" \
    "http://loki:3100/ready" \
    240

  wait_host_http \
    "Grafana healthy" \
    "http://127.0.0.1:3000/api/health" \
    240

  validate_prometheus_targets
  validate_loki_logs
  validate_grafana

  ok "Endpoints, targets, logs e Grafana validados."
}

restart_persistence_test() {
  info "Executando teste de reinicialização e persistência."

  compose restart \
    prometheus \
    loki \
    grafana \
    alloy

  wait_internal_http \
    "Prometheus voltou após reinicialização" \
    "http://prometheus:9090/-/healthy" \
    180

  wait_internal_http \
    "Loki voltou após reinicialização" \
    "http://loki:3100/ready" \
    180

  wait_host_http \
    "Grafana voltou após reinicialização" \
    "http://127.0.0.1:3000/api/health" \
    180

  local query_file="${TEMP_DIR}/prometheus-query.json"

  internal_get \
    "http://prometheus:9090/api/v1/query?query=prometheus_tsdb_head_series" \
    "${query_file}" \
    || fail "Consulta ao Prometheus falhou após reinicialização."

  python3 - "${query_file}" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
payload = json.loads(
    path.read_text(encoding="utf-8")
)

if payload.get("status") != "success":
    raise RuntimeError(
        "Prometheus não respondeu com status success."
    )

print("[OK] Consulta Prometheus validada após reinicialização.")
PY

  ok "Persistência validada após reinicialização."
}

write_report() {
  {
    printf 'SSC Observability Test\n'
    printf 'tested_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'compose_valid=true\n'
    printf 'containers_running=true\n'
    printf 'prometheus_internal_only=true\n'
    printf 'loki_internal_only=true\n'
    printf 'raw_socket_in_alloy=false\n'
    printf 'socket_proxy_private=true\n'
    printf 'prometheus_targets_up=true\n'
    printf 'loki_logs_received=true\n'
    printf 'grafana_datasources=true\n'
    printf 'grafana_dashboards=true\n'
    printf 'restart_test=true\n'
    printf 'status=success\n'
  } > "${REPORT_FILE}"

  chmod 0600 "${REPORT_FILE}"

  ok "Relatório criado: ${REPORT_FILE}"
}

main() {
  check_requirements
  check_internal_only_model
  check_containers
  check_socket_isolation
  check_volumes
  validate_endpoints_and_targets
  restart_persistence_test
  validate_endpoints_and_targets
  write_report

  printf '\n'
  ok "Observabilidade validada com sucesso."
}

main "$@"
