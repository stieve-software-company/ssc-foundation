#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly REPORT_FILE="${PROJECT_ROOT}/observability-audit.txt"

ok() { printf '[OK] %s\n' "$*"; }
fail() { printf '[ERRO] %s\n' "$*" >&2; exit 1; }
section() { printf '\n============================================================\n%s\n============================================================\n' "$1"; }

compose() {
  (
    cd "${PROJECT_ROOT}"
    local files=(-f "${BASE_COMPOSE}")
    [[ -s "${ACCESS_COMPOSE}" ]] && files+=(-f "${ACCESS_COMPOSE}")
    docker compose --env-file "${ENV_FILE}" "${files[@]}" "$@"
  )
}

safe_env_value() {
  python3 - "${ENV_FILE}" "$1" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1]); target = sys.argv[2]
for raw in path.read_text(encoding='utf-8').splitlines():
    line = raw.strip()
    if not line or line.startswith('#') or '=' not in line:
        continue
    key, value = line.split('=', 1)
    if key.strip() != target:
        continue
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    print(value)
    break
PY
}

http_status() {
  local url=$1
  if command -v curl >/dev/null 2>&1; then
    curl -sS -o /dev/null --connect-timeout 2 --max-time 4 -w '%{http_code}' "$url" 2>/dev/null || printf 'unreachable'
  else
    printf 'not-tested'
  fi
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente ou vazio: ${ENV_FILE}"
  [[ -s "${BASE_COMPOSE}" ]] || fail "Arquivo ausente ou vazio: ${BASE_COMPOSE}"
  command -v docker >/dev/null 2>&1 || fail "Docker não encontrado."
  command -v python3 >/dev/null 2>&1 || fail "Python 3 não encontrado."
  command -v git >/dev/null 2>&1 || fail "Git não encontrado."
  docker info >/dev/null 2>&1 || fail "Docker daemon não está acessível."
  compose config --quiet || fail "Docker Compose integrado inválido."
}

header() {
  printf 'SSC Observability Audit\n'
  printf 'generated_at=%s\n' "$(date --iso-8601=seconds)"
  printf 'project_root=%s\n' "${PROJECT_ROOT}"
  printf 'mode=read-only\n'
  printf 'audit_version=1\n'
  printf 'secrets_included=false\n'
}

audit_git() {
  section "GIT"
  cd "${PROJECT_ROOT}"
  printf 'branch='; git branch --show-current
  printf 'commit='; git rev-parse --short HEAD
  printf 'commit_message='; git log -1 --pretty=%s
  printf 'working_tree:\n'; git status --short || true
}

audit_host() {
  section "HOST E RECURSOS"
  printf 'hostname=%s\n' "$(hostname)"
  printf 'kernel=%s\n' "$(uname -srmo)"
  printf '\nMemória:\n'; free -h || true
  printf '\nSwap:\n'; swapon --show || true
  printf '\nDisco:\n'; df -h / || true
  printf '\nInodes:\n'; df -hi / || true
  printf '\nLoad:\n'; cat /proc/loadavg || true
}

audit_docker() {
  section "DOCKER"
  docker version --format 'client={{.Client.Version}} server={{.Server.Version}}' || true
  docker compose version || true
  docker info --format 'root_dir={{.DockerRootDir}}\nlogging_driver={{.LoggingDriver}}\ncgroup_driver={{.CgroupDriver}}\ncgroup_version={{.CgroupVersion}}\ncontainers={{.Containers}}\ncontainers_running={{.ContainersRunning}}\nimages={{.Images}}' || true
  printf '\nDocker socket:\n'
  if [[ -S /var/run/docker.sock ]]; then
    stat --format='exists=true mode=%a owner=%U group=%G' /var/run/docker.sock || true
  else
    printf 'exists=false\n'
  fi
  printf '\nPlugins:\n'; docker plugin ls --format '{{.Name}} enabled={{.Enabled}}' 2>/dev/null || true
  printf '\nDocker daemon metrics:\n'
  printf 'http://127.0.0.1:9323/metrics=%s\n' "$(http_status 'http://127.0.0.1:9323/metrics')"
}

audit_compose() {
  section "COMPOSE E PERFIS"
  printf 'profiles:\n'; compose config --profiles || true
  printf '\nservices:\n'; compose config --services || true
  printf '\nimages:\n'; compose config --images || true
  printf '\nvolumes:\n'; compose config --volumes || true
  printf '\nnetworks:\n'; compose config --networks || true

  printf '\nResumo dos serviços de observabilidade:\n'
  python3 - "${BASE_COMPOSE}" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
services = ['prometheus','loki','grafana','alloy','node-exporter','cadvisor','postgres-exporter','redis-exporter']
for service in services:
    pattern = re.compile(rf'^  {re.escape(service)}:\n(.*?)(?=^  [a-zA-Z0-9_.-]+:\n|^networks:\n|\Z)', re.M|re.S)
    match = pattern.search(text)
    if not match:
        print(f'{service}=absent'); continue
    block = match.group(1)
    print(f"{service}=present profile_observability={str('observability' in block).lower()} config_mount={str(any(x in block for x in ['/etc/prometheus','/etc/loki','/etc/grafana/provisioning','/etc/alloy'])).lower()} raw_docker_socket={str('/var/run/docker.sock' in block).lower()}")
PY
}

audit_environment() {
  section "VARIÁVEIS NÃO SENSÍVEIS"
  for key in PROMETHEUS_IMAGE PROMETHEUS_HOST_PORT PROMETHEUS_RETENTION_TIME PROMETHEUS_RETENTION_SIZE LOKI_IMAGE LOKI_HOST_PORT GRAFANA_IMAGE GRAFANA_HOST_PORT GRAFANA_ALLOW_SIGN_UP GRAFANA_LOG_LEVEL DOCKER_LOG_MAX_SIZE DOCKER_LOG_MAX_FILE SSC_BIND_ADDRESS SSC_ACCESS_BIND_ADDRESS; do
    value="$(safe_env_value "$key")"
    [[ -n "$value" ]] && printf '%s=%s\n' "$key" "$value" || printf '%s=not-set\n' "$key"
  done
  printf '\nVariáveis sensíveis — apenas presença:\n'
  for key in GRAFANA_ADMIN_USER GRAFANA_ADMIN_PASSWORD POSTGRES_MONITOR_USER POSTGRES_MONITOR_PASSWORD; do
    value="$(safe_env_value "$key")"
    [[ -n "$value" ]] && printf '%s=present\n' "$key" || printf '%s=absent\n' "$key"
  done
}

audit_files() {
  section "ARQUIVOS DE CONFIGURAÇÃO"
  for dir in infrastructure/config/prometheus infrastructure/config/loki infrastructure/config/grafana infrastructure/config/alloy infrastructure/config/observability; do
    if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
      printf '%s=present\n' "$dir"
      find "${PROJECT_ROOT}/${dir}" -maxdepth 4 -type f -printf '  %P\n' | sort
    else
      printf '%s=absent\n' "$dir"
    fi
  done
}

audit_containers() {
  section "CONTAINERS"
  compose ps -a || true
  printf '\nObservabilidade ativa:\n'
  for service in prometheus loki grafana alloy; do
    id="$(compose ps -a -q "$service" 2>/dev/null || true)"
    if [[ -z "$id" ]]; then printf '%s=not-created\n' "$service"; continue; fi
    state="$(docker inspect --format '{{.State.Status}}' "$id")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
    printf '%s=state:%s health:%s\n' "$service" "$state" "$health"
  done
}

audit_networks() {
  section "REDES"
  for network in ssc_public ssc_application ssc_data ssc_execution ssc_observability; do
    if docker network inspect "$network" >/dev/null 2>&1; then
      printf '\n%s:\n' "$network"
      docker network inspect --format 'internal={{.Internal}} driver={{.Driver}}\n{{range $id, $c := .Containers}}container={{$c.Name}} ipv4={{$c.IPv4Address}}\n{{end}}' "$network" || true
    else
      printf '\n%s=absent\n' "$network"
    fi
  done
}

audit_volumes() {
  section "VOLUMES"
  for volume in ssc_prometheus_data ssc_loki_data ssc_grafana_data ssc_alloy_data; do
    if docker volume inspect "$volume" >/dev/null 2>&1; then
      docker volume inspect --format 'name={{.Name}} driver={{.Driver}} mountpoint={{.Mountpoint}}' "$volume"
    else
      printf '%s=absent\n' "$volume"
    fi
  done
}

audit_logs() {
  section "INVENTÁRIO DE LOGS DOCKER"
  printf 'O conteúdo dos logs não é lido.\n\n'
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    name="$(docker inspect --format '{{.Name}}' "$id" | sed 's#^/##')"
    driver="$(docker inspect --format '{{.HostConfig.LogConfig.Type}}' "$id")"
    path="$(docker inspect --format '{{.LogPath}}' "$id")"
    if [[ -n "$path" && -e "$path" ]]; then size="$(stat --format='%s' "$path" 2>/dev/null || printf unknown)"; else size=not-accessible; fi
    printf 'container=%s driver=%s bytes=%s path=%s\n' "$name" "$driver" "$size" "${path:-none}"
  done < <(compose ps -a -q 2>/dev/null || true)
}

audit_endpoints() {
  section "ENDPOINTS"
  access_port="$(safe_env_value SSC_ACCESS_HOST_PORT)"; access_port="${access_port:-8080}"
  prometheus_port="$(safe_env_value PROMETHEUS_HOST_PORT)"; prometheus_port="${prometheus_port:-9090}"
  loki_port="$(safe_env_value LOKI_HOST_PORT)"; loki_port="${loki_port:-3100}"
  grafana_port="$(safe_env_value GRAFANA_HOST_PORT)"; grafana_port="${grafana_port:-3000}"
  printf 'mission_control_health=%s\n' "$(http_status "http://127.0.0.1:${access_port}/health")"
  printf 'mission_control_metrics=%s\n' "$(http_status "http://127.0.0.1:${access_port}/metrics")"
  printf 'prometheus_health=%s\n' "$(http_status "http://127.0.0.1:${prometheus_port}/-/healthy")"
  printf 'prometheus_targets=%s\n' "$(http_status "http://127.0.0.1:${prometheus_port}/api/v1/targets")"
  printf 'loki_ready=%s\n' "$(http_status "http://127.0.0.1:${loki_port}/ready")"
  printf 'grafana_health=%s\n' "$(http_status "http://127.0.0.1:${grafana_port}/api/health")"
}

audit_services() {
  section "MÉTRICAS DOS SERVIÇOS"
  rabbitmq_id="$(compose ps -q rabbitmq 2>/dev/null || true)"
  minio_id="$(compose ps -q minio 2>/dev/null || true)"
  postgres_id="$(compose ps -q postgres 2>/dev/null || true)"

  printf 'RabbitMQ plugins ativos:\n'
  if [[ -n "$rabbitmq_id" ]]; then
    docker exec "$rabbitmq_id" rabbitmq-plugins list -e -m 2>/dev/null || true
    printf 'rabbitmq_prometheus='
    docker exec "$rabbitmq_id" rabbitmq-plugins list -e -m 2>/dev/null | grep -Fxq rabbitmq_prometheus && printf 'enabled\n' || printf 'disabled\n'
  else
    printf 'rabbitmq=not-running\n'
  fi

  printf '\nMinIO metrics local:\n'
  if [[ -n "$minio_id" ]]; then
    docker exec "$minio_id" sh -ec 'code="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:9000/minio/v2/metrics/cluster 2>/dev/null || printf unreachable)"; printf "cluster_metrics=%s\n" "$code"' || true
  else
    printf 'minio=not-running\n'
  fi

  printf '\nPostgreSQL monitor role:\n'
  if [[ -n "$postgres_id" ]]; then
    admin_user="$(safe_env_value POSTGRES_USER)"; db="$(safe_env_value POSTGRES_DB)"
    docker exec "$postgres_id" psql -X -At -U "$admin_user" -d "$db" -c "SELECT rolname || ' login=' || rolcanlogin || ' inherit=' || rolinherit || ' pg_monitor=' || pg_has_role(rolname,'pg_monitor','MEMBER') FROM pg_roles WHERE rolname='companyos_monitor';" 2>/dev/null || true
  else
    printf 'postgres=not-running\n'
  fi

  printf '\nExporters adicionais:\n'
  compose config --services | grep -Fxq redis-exporter && printf 'redis_exporter=configured\n' || printf 'redis_exporter=absent\n'
  compose config --services | grep -Fxq postgres-exporter && printf 'postgres_exporter=configured\n' || printf 'postgres_exporter=absent\n'
  compose config --services | grep -Fxq cadvisor && printf 'cadvisor=configured\n' || printf 'cadvisor=absent\n'
  compose config --services | grep -Fxq alloy && printf 'alloy=configured\n' || printf 'alloy=absent\n'
}

audit_summary() {
  section "RESUMO"
  printf 'compose_valid=true\n'
  compose config --profiles | grep -Fxq observability && printf 'observability_profile_defined=true\n' || printf 'observability_profile_defined=false\n'
  for name in prometheus loki grafana alloy; do
    [[ -d "${PROJECT_ROOT}/infrastructure/config/${name}" ]] && printf '%s_config_directory=present\n' "$name" || printf '%s_config_directory=absent\n' "$name"
  done
  printf 'audit_completed_without_mutations=true\n'
}

main() {
  check_requirements
  : > "${REPORT_FILE}"
  chmod 0600 "${REPORT_FILE}"
  exec > >(tee "${REPORT_FILE}") 2>&1
  header
  audit_git
  audit_host
  audit_docker
  audit_compose
  audit_environment
  audit_files
  audit_containers
  audit_networks
  audit_volumes
  audit_logs
  audit_endpoints
  audit_services
  audit_summary
  printf '\n'
  ok "Auditoria de observabilidade concluída."
  printf 'Relatório: %s\n' "${REPORT_FILE}"
  printf 'Não adicione observability-audit.txt ao Git.\n'
}

main "$@"
