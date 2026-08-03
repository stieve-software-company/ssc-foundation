#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly DEFINITIONS_FILE="${PROJECT_ROOT}/infrastructure/config/rabbitmq/definitions.json"
readonly CONTAINER_DEFINITIONS="/tmp/companyos-definitions.json"

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

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${BASE_COMPOSE}" ]] \
    || fail "Arquivo ausente ou vazio: ${BASE_COMPOSE}"

  [[ -s "${ACCESS_COMPOSE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ACCESS_COMPOSE}"

  [[ -s "${DEFINITIONS_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${DEFINITIONS_FILE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  [[ "$(get_env_value RABBITMQ_DEFAULT_VHOST)" == "development" ]] \
    || fail "RABBITMQ_DEFAULT_VHOST precisa ser development."

  local rabbitmq_url
  rabbitmq_url="$(get_env_value RABBITMQ_URL)"

  [[ "${rabbitmq_url}" == */development ]] \
    || fail "RABBITMQ_URL precisa apontar para o vhost development."
}

validate_definitions() {
  info "Validando definitions.json."

  python3 - "${DEFINITIONS_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))

for forbidden in ("users", "permissions", "topic_permissions"):
    if payload.get(forbidden):
        raise SystemExit(
            f"[ERRO] A seção {forbidden} precisa permanecer vazia."
        )

serialized = json.dumps(payload).lower()

for forbidden_word in (
    '"password"',
    '"password_hash"',
    '"hashing_algorithm"',
):
    if forbidden_word in serialized:
        raise SystemExit(
            f"[ERRO] Conteúdo sensível encontrado: {forbidden_word}"
        )

required_exchanges = {
    "companyos.commands",
    "companyos.events",
    "companyos.retry.5s",
    "companyos.retry.30s",
    "companyos.retry.5m",
    "companyos.dead-letter",
}

required_queues = {
    "companyos.workflow.commands",
    "companyos.agent.commands",
    "companyos.audit.events",
    "companyos.notifications.events",
    "companyos.retry.5s",
    "companyos.retry.30s",
    "companyos.retry.5m",
    "companyos.dead-letter",
}

exchanges = {
    item["name"]
    for item in payload.get("exchanges", [])
    if item.get("vhost") == "development"
}

queues = {
    item["name"]
    for item in payload.get("queues", [])
    if item.get("vhost") == "development"
}

missing_exchanges = required_exchanges - exchanges
missing_queues = required_queues - queues

if missing_exchanges:
    raise SystemExit(
        "[ERRO] Exchanges ausentes: "
        + ", ".join(sorted(missing_exchanges))
    )

if missing_queues:
    raise SystemExit(
        "[ERRO] Filas ausentes: "
        + ", ".join(sorted(missing_queues))
    )

for binding in payload.get("bindings", []):
    if binding.get("source") not in exchanges:
        raise SystemExit(
            f"[ERRO] Binding usa exchange ausente: {binding}"
        )

    if (
        binding.get("destination_type") == "queue"
        and binding.get("destination") not in queues
    ):
        raise SystemExit(
            f"[ERRO] Binding usa fila ausente: {binding}"
        )

print("[OK] JSON e referências internas válidos.")
PY
}

wait_for_rabbitmq() {
  info "Aguardando o RabbitMQ."

  compose up \
    -d \
    --wait \
    --wait-timeout 180 \
    rabbitmq

  compose exec \
    -T \
    rabbitmq \
    rabbitmqctl await_startup --timeout 120

  ok "RabbitMQ disponível."
}

import_definitions() {
  local container_id
  container_id="$(compose ps -q rabbitmq)"

  [[ -n "${container_id}" ]] \
    || fail "Container RabbitMQ não foi encontrado."

  info "Copiando definições para o container."

  docker cp \
    "${DEFINITIONS_FILE}" \
    "${container_id}:${CONTAINER_DEFINITIONS}" \
    >/dev/null

  compose exec \
    -T \
    --user root \
    rabbitmq \
    chown rabbitmq:rabbitmq "${CONTAINER_DEFINITIONS}"

  info "Importando a topologia."

  compose exec \
    -T \
    rabbitmq \
    rabbitmqctl import_definitions "${CONTAINER_DEFINITIONS}"

  compose exec \
    -T \
    --user root \
    rabbitmq \
    rm -f "${CONTAINER_DEFINITIONS}"

  ok "Definições importadas."
}

run_tests() {
  "${SCRIPT_DIR}/test-rabbitmq-topology.sh"
}

main() {
  check_requirements
  validate_definitions
  wait_for_rabbitmq
  import_definitions
  run_tests

  printf '\n'
  ok "Bootstrap da topologia RabbitMQ concluído."
}

main "$@"
