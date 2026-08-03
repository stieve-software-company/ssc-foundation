#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"

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
      "$@"
  )
}

mc_command() {
  compose exec -T minio sh -ec '
    set -eu

    mc_home="/tmp/companyos-mc-$$"
    rm -rf "$mc_home"
    mkdir -p "$mc_home"
    trap "rm -rf \"$mc_home\"" EXIT

    HOME="$mc_home" mc alias set \
      companyos \
      http://127.0.0.1:9000 \
      "$MINIO_ROOT_USER" \
      "$MINIO_ROOT_PASSWORD" \
      >/dev/null

    HOME="$mc_home" mc "$@"
  ' sh "$@"
}

main() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  printf '%s\n' "============================================================"
  printf '%s\n' "VERSÕES"
  printf '%s\n' "============================================================"

  compose exec -T minio minio --version
  compose exec -T minio mc --version

  printf '\n%s\n' "============================================================"
  printf '%s\n' "HEALTH"
  printf '%s\n' "============================================================"

  compose exec -T minio sh -ec '
    for endpoint in live ready cluster cluster/read; do
      printf "%s: " "$endpoint"

      curl \
        --fail \
        --silent \
        --show-error \
        "http://127.0.0.1:9000/minio/health/$endpoint" \
        >/dev/null

      printf "OK\n"
    done
  '

  printf '\n%s\n' "============================================================"
  printf '%s\n' "SERVIDOR"
  printf '%s\n' "============================================================"

  mc_command admin info companyos

  printf '\n%s\n' "============================================================"
  printf '%s\n' "BUCKETS"
  printf '%s\n' "============================================================"

  mc_command ls companyos

  printf '\n%s\n' "============================================================"
  printf '%s\n' "VOLUME"
  printf '%s\n' "============================================================"

  docker volume inspect ssc_minio_data \
    --format 'Volume={{.Name}} Driver={{.Driver}} Mountpoint={{.Mountpoint}}'

  compose exec -T minio sh -ec '
    df -h /data
    du -sh /data
  '
}

main "$@"
