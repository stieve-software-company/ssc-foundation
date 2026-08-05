#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"

compose() {
  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f compose.yaml \
      -f compose.access.yaml \
      -f compose.observability.yaml \
      --profile observability \
      "$@"
  )
}

services=(
  grafana
  prometheus
  alloy
  blackbox-exporter
  redis-exporter
  postgres-exporter
  cadvisor
  node-exporter
  loki
  docker-socket-proxy
)

printf '[INFO] Parando somente os componentes de observabilidade.\n'

compose stop \
  --timeout 60 \
  "${services[@]}"

printf '[OK] Observabilidade parada sem remover volumes.\n'
