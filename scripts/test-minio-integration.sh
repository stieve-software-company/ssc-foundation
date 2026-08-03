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
  [[ -s "${BUCKETS_FILE}" ]] \
    || fail "Arquivo ausente: ${BUCKETS_FILE}"

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  command -v sha256sum >/dev/null 2>&1 \
    || fail "sha256sum não encontrado."

  command -v cmp >/dev/null 2>&1 \
    || fail "cmp não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose ps --status running minio |
    grep -q minio \
    || fail "MinIO não está em execução."

  compose ps --status running mission-control |
    grep -q mission-control \
    || fail "Mission Control não está em execução."
}

check_health() {
  info "Validando health checks."

  compose exec -T minio sh -ec '
    for endpoint in live ready cluster cluster/read; do
      curl \
        --fail \
        --silent \
        --show-error \
        "http://127.0.0.1:9000/minio/health/$endpoint" \
        >/dev/null
    done
  '

  ok "Health checks validados."
}

check_structure() {
  local -a bucket_specs=()
  local spec
  local bucket
  local versioning
  local anonymous
  local version_info

  info "Validando buckets, privacidade e versionamento."

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

    mc_command stat "companyos/${bucket}" >/dev/null

    anonymous="$(
      mc_command anonymous get "companyos/${bucket}" 2>&1
    )"

    grep -Eqi 'private|none' <<< "${anonymous}" \
      || fail "Bucket não está privado: ${bucket}"

    version_info="$(
      mc_command version info "companyos/${bucket}" 2>&1
    )"

    if [[ "${versioning}" == "true" ]]; then
      grep -Eqi 'versioning.*enabled|enabled' <<< "${version_info}" \
        || fail "Versionamento não está habilitado: ${bucket}"

      if grep -Eqi 'not[[:space:]]+enabled|disabled|suspended' \
        <<< "${version_info}"; then
        fail "Versionamento não está ativo: ${bucket}"
      fi
    else
      if grep -Eqi 'not[[:space:]]+enabled|disabled|unversioned' \
        <<< "${version_info}"; then
        :
      elif grep -Eqi 'versioning.*enabled|enabled' <<< "${version_info}"; then
        fail "Versionamento inesperado no bucket: ${bucket}"
      fi
    fi

    ok "Bucket validado: ${bucket}"
  done
}

copy_to_container() {
  local local_file=$1
  local container_file=$2
  local container_id

  container_id="$(compose ps -q minio)"
  [[ -n "${container_id}" ]] \
    || fail "Container MinIO não encontrado."

  docker cp \
    "${local_file}" \
    "${container_id}:${container_file}" \
    >/dev/null
}

test_object_operations() {
  local temp_dir=$1
  local test_id=$2
  local prefix
  local object_name
  local target
  local container_file
  local original_hash
  local downloaded_hash
  local stat_output
  local http_status
  local share_json
  local share_url

  prefix="ssc-test/${test_id}"
  object_name="payload.json"
  target="companyos/companyos-exports/${prefix}/${object_name}"
  container_file="/tmp/ssc-minio-${test_id}.json"

  cat > "${temp_dir}/payload.json" <<EOF
{"service":"companyos","test_id":"${test_id}","operation":"object-roundtrip"}
EOF

  original_hash="$(
    sha256sum "${temp_dir}/payload.json" |
      awk '{print $1}'
  )"

  copy_to_container "${temp_dir}/payload.json" "${container_file}"

  mc_command cp \
    --checksum SHA256 \
    --attr "Content-Type=application/json;X-Amz-Meta-Ssc-Test=true;X-Amz-Meta-Sha256=${original_hash}" \
    "${container_file}" \
    "${target}" \
    >/dev/null

  compose exec -T minio rm -f "${container_file}"

  ok "Upload com checksum concluído."

  stat_output="$(
    mc_command stat --json "${target}"
  )"

  grep -Fqi "${original_hash}" <<< "${stat_output}" \
    || fail "SHA-256 não encontrado nos metadados."

  grep -Fqi 'ssc-test' <<< "${stat_output}" \
    || fail "Metadado de teste não encontrado."

  ok "Metadados e stat validados."

  mc_command ls \
    "companyos/companyos-exports/${prefix}/" |
    grep -Fq "${object_name}" \
    || fail "Objeto não encontrado por prefixo."

  ok "Listagem por prefixo validada."

  mc_command cat "${target}" > "${temp_dir}/downloaded.json"

  downloaded_hash="$(
    sha256sum "${temp_dir}/downloaded.json" |
      awk '{print $1}'
  )"

  [[ "${downloaded_hash}" == "${original_hash}" ]] \
    || fail "SHA-256 do download não corresponde."

  ok "Download autenticado e SHA-256 validados."

  http_status="$(
    compose exec -T minio sh -ec '
      curl \
        --silent \
        --output /dev/null \
        --write-out "%{http_code}" \
        "http://127.0.0.1:9000/$1"
    ' sh "companyos-exports/${prefix}/${object_name}"
  )"

  [[ "${http_status}" == "403" ]] \
    || fail "Acesso anônimo retornou HTTP ${http_status}, esperado 403."

  ok "Acesso anônimo rejeitado."

  share_json="$(
    mc_command \
      --json \
      share download \
      --expire 5m \
      "${target}"
  )"

  share_url="$(
    python3 -c '
import json
import sys

payload = json.load(sys.stdin)
share = payload.get("share", "")

if not share:
    raise SystemExit(1)

print(share)
' <<< "${share_json}"
  )"

  compose exec -T \
    -e SSC_PRESIGNED_URL="${share_url}" \
    minio sh -ec '
      curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "$SSC_PRESIGNED_URL"
    ' > "${temp_dir}/presigned.json"

  downloaded_hash="$(
    sha256sum "${temp_dir}/presigned.json" |
      awk '{print $1}'
  )"

  [[ "${downloaded_hash}" == "${original_hash}" ]] \
    || fail "Download por URL assinada não corresponde."

  ok "URL assinada e download temporário validados."

  mc_command rm "${target}" >/dev/null

  if mc_command stat "${target}" >/dev/null 2>&1; then
    fail "Objeto de teste ainda existe após remoção."
  fi

  ok "Objeto não versionado removido."
}

test_versioning() {
  local temp_dir=$1
  local test_id=$2
  local target
  local container_v1
  local container_v2
  local versions_output
  local version_count

  target="companyos/companyos-references/ssc-test/${test_id}/versioned.txt"
  container_v1="/tmp/ssc-minio-${test_id}-v1.txt"
  container_v2="/tmp/ssc-minio-${test_id}-v2.txt"

  printf 'version-one-%s\n' "${test_id}" > "${temp_dir}/v1.txt"
  printf 'version-two-%s\n' "${test_id}" > "${temp_dir}/v2.txt"

  copy_to_container "${temp_dir}/v1.txt" "${container_v1}"
  copy_to_container "${temp_dir}/v2.txt" "${container_v2}"

  mc_command cp "${container_v1}" "${target}" >/dev/null
  mc_command cp "${container_v2}" "${target}" >/dev/null

  compose exec -T minio rm -f "${container_v1}" "${container_v2}"

  versions_output="$(
    mc_command ls --versions "${target}"
  )"

  version_count="$(
    grep -Fc 'versioned.txt' <<< "${versions_output}" || true
  )"

  (( version_count >= 2 )) \
    || fail "Foram encontradas menos de duas versões."

  mc_command cat "${target}" > "${temp_dir}/latest-version.txt"

  cmp -s "${temp_dir}/v2.txt" "${temp_dir}/latest-version.txt" \
    || fail "A versão mais recente não corresponde."

  ok "Duas versões e leitura da versão atual validadas."

  mc_command rm \
    --versions \
    --force \
    "${target}" \
    >/dev/null

  if mc_command ls --versions "${target}" 2>/dev/null |
    grep -Fq 'versioned.txt'; then
    fail "Versões de teste ainda existem."
  fi

  ok "Versões temporárias removidas."
}

test_mission_control() {
  info "Validando acesso pelo Mission Control."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
import urllib.request

from app.config import settings

for endpoint in ("live", "ready"):
    with urllib.request.urlopen(
        f"{settings.minio_base_url}/minio/health/{endpoint}",
        timeout=5,
    ) as response:
        if response.status != 200:
            raise RuntimeError(
                f"MinIO {endpoint} retornou HTTP {response.status}"
            )

print("[OK] Mission Control acessa os health checks do MinIO.")
PY
}

check_cleanup() {
  local test_id=$1
  local output

  output="$(
    {
      mc_command ls \
        --recursive \
        "companyos/companyos-exports/ssc-test/${test_id}/" \
        2>/dev/null || true

      mc_command ls \
        --recursive \
        --versions \
        "companyos/companyos-references/ssc-test/${test_id}/" \
        2>/dev/null || true
    }
  )"

  [[ -z "${output}" ]] \
    || fail "Objetos temporários restantes: ${output}"

  ok "Nenhum objeto temporário permaneceu."
}

main() {
  local test_id

  TEMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  test_id="$(date +%s)-$$"

  check_requirements
  check_health
  check_structure
  test_object_operations "${TEMP_DIR}" "${test_id}"
  test_versioning "${TEMP_DIR}" "${test_id}"
  test_mission_control
  check_cleanup "${test_id}"

  printf '\n'
  ok "Integração MinIO validada."
}

main "$@"
