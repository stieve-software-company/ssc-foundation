#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly BUCKETS_FILE="${PROJECT_ROOT}/infrastructure/config/minio/buckets.json"

TEMP_DIR=""

cleanup() {
  if [[ -n "${TEMP_DIR}" ]]; then
    rm -rf -- "${TEMP_DIR}"
  fi
}

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

get_env_value() {
  local key=$1
  local value

  value="$(
    awk -F= -v wanted="${key}" '
      $0 !~ /^[[:space:]]*#/ &&
      $1 == wanted {
        sub(/^[^=]*=/, "", $0)
        value=$0
      }
      END {
        print value
      }
    ' "${ENV_FILE}"
  )"

  printf '%s' "${value}"
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
  ' sh "$@" </dev/null
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"
  [[ -s "${BASE_COMPOSE}" ]] || fail "Arquivo ausente: ${BASE_COMPOSE}"
  [[ -s "${ACCESS_COMPOSE}" ]] \
    || fail "Arquivo ausente: ${ACCESS_COMPOSE}"
  [[ -s "${BUCKETS_FILE}" ]] \
    || fail "Arquivo ausente: ${BUCKETS_FILE}"

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v sha256sum >/dev/null 2>&1 \
    || fail "sha256sum não encontrado."

  command -v cmp >/dev/null 2>&1 \
    || fail "cmp não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

validate_buckets() {
  local env_buckets

  env_buckets="$(get_env_value MINIO_DEFAULT_BUCKETS)"
  [[ -n "${env_buckets}" ]] \
    || fail "MINIO_DEFAULT_BUCKETS ausente no .env."

  info "Validando buckets.json."

  python3 - \
    "${BUCKETS_FILE}" \
    "${env_buckets}" <<'PY'
from __future__ import annotations

from pathlib import Path
import json
import re
import sys

path = Path(sys.argv[1])
env_buckets = {
    item.strip()
    for item in sys.argv[2].split(",")
    if item.strip()
}

payload = json.loads(path.read_text(encoding="utf-8"))

if payload.get("schema_version") != 1:
    raise SystemExit("[ERRO] schema_version precisa ser 1.")

items = payload.get("buckets")

if not isinstance(items, list) or not items:
    raise SystemExit("[ERRO] Lista de buckets inválida.")

names: list[str] = []

for item in items:
    if not isinstance(item, dict):
        raise SystemExit("[ERRO] Entrada de bucket inválida.")

    name = item.get("name")
    versioning = item.get("versioning")
    anonymous = item.get("anonymous")

    if not isinstance(name, str):
        raise SystemExit("[ERRO] Nome de bucket inválido.")

    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", name):
        raise SystemExit(f"[ERRO] Nome S3 inválido: {name}")

    if not isinstance(versioning, bool):
        raise SystemExit(
            f"[ERRO] versioning precisa ser booleano: {name}"
        )

    if anonymous != "none":
        raise SystemExit(
            f"[ERRO] Bucket precisa ser privado: {name}"
        )

    names.append(name)

if len(names) != len(set(names)):
    raise SystemExit("[ERRO] Existem buckets duplicados.")

file_buckets = set(names)

if file_buckets != env_buckets:
    raise SystemExit(
        "[ERRO] MINIO_DEFAULT_BUCKETS e buckets.json divergem. "
        f"JSON={sorted(file_buckets)} ENV={sorted(env_buckets)}"
    )

print("[OK] Buckets e política de privacidade válidos.")
PY
}

wait_for_minio() {
  info "Aguardando o MinIO."

  compose up \
    -d \
    --wait \
    --wait-timeout 180 \
    minio

  mc_command ready companyos >/dev/null

  ok "MinIO disponível."
}

provision_buckets() {
  local -a bucket_specs=()
  local spec
  local bucket
  local versioning

  info "Provisionando os buckets."

  mapfile -t bucket_specs < <(
    python3 - "${BUCKETS_FILE}" <<'PY'
from pathlib import Path
import json
import sys

payload = json.loads(
    Path(sys.argv[1]).read_text(encoding="utf-8")
)

for item in payload["buckets"]:
    enabled = "true" if item["versioning"] else "false"
    print(f'{item["name"]}|{enabled}')
PY
  )

  [[ "${#bucket_specs[@]}" -gt 0 ]] \
    || fail "Nenhum bucket foi carregado de buckets.json."

  for spec in "${bucket_specs[@]}"; do
    IFS='|' read -r bucket versioning <<< "${spec}"

    [[ -n "${bucket}" ]] \
      || fail "Especificação de bucket vazia."

    if mc_command stat "companyos/${bucket}" >/dev/null 2>&1; then
      ok "Bucket já existe: ${bucket}"
    else
      mc_command mb "companyos/${bucket}" >/dev/null
      ok "Bucket criado: ${bucket}"
    fi

    mc_command anonymous set none "companyos/${bucket}" >/dev/null
    ok "Acesso anônimo removido: ${bucket}"

    if [[ "${versioning}" == "true" ]]; then
      mc_command version enable "companyos/${bucket}" >/dev/null
      ok "Versionamento habilitado: ${bucket}"
    fi
  done

  verify_provisioned_buckets "${bucket_specs[@]}"
}

verify_provisioned_buckets() {
  local spec
  local bucket
  local versioning

  info "Confirmando todos os buckets antes da persistência."

  for spec in "$@"; do
    IFS='|' read -r bucket versioning <<< "${spec}"

    mc_command stat "companyos/${bucket}" >/dev/null \
      || fail "Bucket não foi provisionado: ${bucket}"

    ok "Bucket confirmado: ${bucket}"
  done
}

create_persistence_marker() {
  local marker_key=$1
  local local_file=$2
  local container_file=$3
  local container_id

  printf '%s\n' \
    '{"service":"companyos","test":"minio-persistence"}' \
    > "${local_file}"

  container_id="$(compose ps -q minio)"
  [[ -n "${container_id}" ]] \
    || fail "Container MinIO não encontrado."

  docker cp \
    "${local_file}" \
    "${container_id}:${container_file}" \
    >/dev/null

  mc_command cp \
    --checksum SHA256 \
    "${container_file}" \
    "companyos/companyos-exports/${marker_key}" \
    >/dev/null

  compose exec -T minio rm -f "${container_file}"

  ok "Marcador de persistência enviado."
}

recreate_minio() {
  info "Recriando somente o container MinIO."

  compose up \
    -d \
    --force-recreate \
    --wait \
    --wait-timeout 180 \
    minio

  mc_command ready companyos >/dev/null

  ok "MinIO recriado e saudável."
}

verify_persistence_marker() {
  local marker_key=$1
  local original_file=$2
  local downloaded_file=$3

  info "Validando persistência do objeto."

  mc_command cat \
    "companyos/companyos-exports/${marker_key}" \
    > "${downloaded_file}"

  cmp -s "${original_file}" "${downloaded_file}" \
    || fail "O objeto persistido foi alterado."

  mc_command rm \
    "companyos/companyos-exports/${marker_key}" \
    >/dev/null

  ok "Persistência validada e marcador removido."
}

run_tests() {
  "${SCRIPT_DIR}/test-minio-integration.sh"
}

main() {
  local marker_key
  local container_file

  TEMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  marker_key="ssc-test/bootstrap/persistence-$(date +%s)-$$.json"
  container_file="/tmp/ssc-minio-persistence-$$.json"

  check_requirements
  validate_buckets
  wait_for_minio
  provision_buckets

  create_persistence_marker \
    "${marker_key}" \
    "${TEMP_DIR}/original.json" \
    "${container_file}"

  recreate_minio

  verify_persistence_marker \
    "${marker_key}" \
    "${TEMP_DIR}/original.json" \
    "${TEMP_DIR}/downloaded.json"

  run_tests

  printf '\n'
  ok "Bootstrap do MinIO concluído."
}

main "$@"
