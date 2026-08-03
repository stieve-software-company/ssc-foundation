#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE_FILE="${PROJECT_ROOT}/compose.access.yaml"
readonly REDIS_CONFIG_FILE="${PROJECT_ROOT}/infrastructure/config/redis/redis.conf"
readonly BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/config"

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

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${ENV_EXAMPLE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_EXAMPLE_FILE}"

  [[ -s "${COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${COMPOSE_FILE}"

  [[ -s "${ACCESS_COMPOSE_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ACCESS_COMPOSE_FILE}"

  [[ -s "${REDIS_CONFIG_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${REDIS_CONFIG_FILE}"

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

backup_configuration() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_ROOT}/redis-configuration-${timestamp}"

  install -d -m 0700 "${destination}"
  install -m 0600 "${ENV_FILE}" "${destination}/.env"
  install -m 0600 "${ENV_EXAMPLE_FILE}" "${destination}/.env.example"
  install -m 0600 "${COMPOSE_FILE}" "${destination}/compose.yaml"
  install -m 0600 "${REDIS_CONFIG_FILE}" "${destination}/redis.conf"

  ok "Configuração preservada em ${destination}"
}

update_files() {
  info "Atualizando o Compose e as variáveis do Redis."

  python3 - \
    "${ENV_FILE}" \
    "${ENV_EXAMPLE_FILE}" \
    "${COMPOSE_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

env_path = Path(sys.argv[1])
example_path = Path(sys.argv[2])
compose_path = Path(sys.argv[3])

redis_block = """  redis:
    <<: *service-defaults
    image: ${REDIS_IMAGE:?Defina REDIS_IMAGE no arquivo .env}
    command:
      - sh
      - -ec
      - |
        exec redis-server /usr/local/etc/redis/redis.conf \\
          --requirepass "$$REDIS_PASSWORD" \\
          --maxmemory "${REDIS_MAXMEMORY:-256mb}" \\
          --maxmemory-policy "${REDIS_MAXMEMORY_POLICY:-noeviction}"
    environment:
      REDIS_PASSWORD: ${REDIS_PASSWORD:?Defina REDIS_PASSWORD no arquivo .env}
      TZ: ${SSC_TIMEZONE:-America/Sao_Paulo}
    ports:
      - "${SSC_BIND_ADDRESS:-127.0.0.1}:${REDIS_HOST_PORT:-6379}:${REDIS_CONTAINER_PORT:-6379}"
    volumes:
      - ./infrastructure/config/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
      - redis_data:/data
    networks:
      - data
    healthcheck:
      test:
        - CMD-SHELL
        - redis-cli --no-auth-warning -a "$$REDIS_PASSWORD" ping | grep -q PONG
      interval: ${HEALTHCHECK_INTERVAL:-10s}
      timeout: ${HEALTHCHECK_TIMEOUT:-5s}
      retries: ${HEALTHCHECK_RETRIES:-5}
      start_period: 15s
    stop_grace_period: 30s
    labels:
      <<: *common-labels
      com.stieve-software-company.service: "redis"
"""


def set_env_value(path: Path, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    output: list[str] = []
    written = False

    for line in lines:
        if line.startswith(f"{key}="):
            if not written:
                output.append(f"{key}={value}")
                written = True
            continue

        output.append(line)

    if not written:
        output.append(f"{key}={value}")

    path.write_text("\n".join(output) + "\n", encoding="utf-8")


for path in (env_path, example_path):
    set_env_value(path, "REDIS_MAXMEMORY", "256mb")
    set_env_value(path, "REDIS_MAXMEMORY_POLICY", "noeviction")

compose = compose_path.read_text(encoding="utf-8")

start_marker = "  redis:\n"
end_marker = "\n  minio:\n"

start = compose.find(start_marker)
end = compose.find(end_marker, start)

if start < 0 or end < 0:
    raise SystemExit(
        "[ERRO] Não foi possível localizar o bloco Redis em compose.yaml."
    )

current_block = compose[start:end]

if "com.stieve-software-company.service: \"redis\"" not in current_block:
    raise SystemExit(
        "[ERRO] O bloco encontrado não parece ser o serviço Redis esperado."
    )

compose = compose[:start] + redis_block.rstrip("\n") + compose[end:]
compose_path.write_text(compose, encoding="utf-8")
PY

  chmod 0600 "${ENV_FILE}"
  ok "Arquivos atualizados sem exibir segredos."
}

validate_configuration() {
  info "Validando o Docker Compose."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      -f "${ACCESS_COMPOSE_FILE}" \
      config --quiet
  )

  ok "Docker Compose válido."

  if git -C "${PROJECT_ROOT}" check-ignore -q .env; then
    ok "O arquivo .env continua ignorado pelo Git."
  else
    fail "O arquivo .env não está protegido pelo .gitignore."
  fi
}

show_summary() {
  printf '\n'
  ok "Configuração do Redis instalada."
  printf '\n'
  printf 'Política de memória: noeviction\n'
  printf 'Configuração: infrastructure/config/redis/redis.conf\n'
  printf '\n'
  printf 'Próximo comando:\n'
  printf '  ./scripts/bootstrap-redis.sh\n'
}

main() {
  check_requirements
  backup_configuration
  update_files
  validate_configuration
  show_summary
}

main "$@"
