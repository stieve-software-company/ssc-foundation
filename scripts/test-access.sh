#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"

port="$(
  awk -F= '
    $1 == "SSC_ACCESS_HOST_PORT" {
      sub(/^[^=]*=/, "", $0)
      value=$0
    }
    END {
      print value
    }
  ' "${ENV_FILE}"
)"

port="${port:-8080}"
base_url="http://127.0.0.1:${port}"

printf '[INFO] Testando %s\n' "${base_url}"

health="$(
  curl \
    --fail \
    --silent \
    --show-error \
    "${base_url}/health"
)"

printf '%s\n' "${health}"

grep -q '"status":"healthy"' <<< "${health}" \
  || {
    printf '[ERRO] Health check não retornou healthy.\n' >&2
    exit 1
  }

login_status="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    "${base_url}/login"
)"

[[ "${login_status}" == "200" ]] \
  || {
    printf '[ERRO] Tela de login retornou HTTP %s.\n' \
      "${login_status}" >&2
    exit 1
  }

printf '[OK] Health check e tela de login responderam corretamente.\n'
