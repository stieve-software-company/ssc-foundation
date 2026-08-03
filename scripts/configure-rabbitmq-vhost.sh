#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE_FILE="${PROJECT_ROOT}/compose.access.yaml"
readonly BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/config"

TARGET_VHOST="development"

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
  local file=${2:-${ENV_FILE}}
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
    ' "${file}"
  )"

  printf '%s' "${value}"
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

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  [[ -n "$(get_env_value RABBITMQ_DEFAULT_USER)" ]] \
    || fail "RABBITMQ_DEFAULT_USER ausente no .env."

  [[ -n "$(get_env_value RABBITMQ_URL)" ]] \
    || fail "RABBITMQ_URL ausente no .env."
}

backup_configuration() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_ROOT}/rabbitmq-vhost-${timestamp}"

  install -d -m 0700 "${destination}"
  install -m 0600 "${ENV_FILE}" "${destination}/.env"
  install -m 0600 "${ENV_EXAMPLE_FILE}" "${destination}/.env.example"
  install -m 0600 "${COMPOSE_FILE}" "${destination}/compose.yaml"

  ok "Configuração anterior preservada em ${destination}"
}

update_configuration() {
  info "Padronizando o virtual host como ${TARGET_VHOST}."

  python3 - \
    "${ENV_FILE}" \
    "${ENV_EXAMPLE_FILE}" \
    "${COMPOSE_FILE}" \
    "${TARGET_VHOST}" <<'PY'
from __future__ import annotations

from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
import sys

env_path = Path(sys.argv[1])
example_path = Path(sys.argv[2])
compose_path = Path(sys.argv[3])
target_vhost = sys.argv[4]


def update_env_file(path: Path) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    output: list[str] = []
    seen_vhost = False
    seen_url = False

    for line in lines:
        if line.startswith("RABBITMQ_DEFAULT_VHOST="):
            output.append(f"RABBITMQ_DEFAULT_VHOST={target_vhost}")
            seen_vhost = True
            continue

        if line.startswith("RABBITMQ_URL="):
            raw_url = line.split("=", 1)[1]
            parsed = urlsplit(raw_url)

            if parsed.scheme not in {"amqp", "amqps"}:
                raise SystemExit(
                    f"[ERRO] RABBITMQ_URL inválida em {path.name}."
                )

            normalized = urlunsplit(
                (
                    parsed.scheme,
                    parsed.netloc,
                    f"/{target_vhost}",
                    parsed.query,
                    parsed.fragment,
                )
            )
            output.append(f"RABBITMQ_URL={normalized}")
            seen_url = True
            continue

        output.append(line)

    if not seen_vhost:
        raise SystemExit(
            f"[ERRO] RABBITMQ_DEFAULT_VHOST ausente em {path.name}."
        )

    if not seen_url:
        raise SystemExit(
            f"[ERRO] RABBITMQ_URL ausente em {path.name}."
        )

    path.write_text("\n".join(output) + "\n", encoding="utf-8")


update_env_file(env_path)
update_env_file(example_path)

compose = compose_path.read_text(encoding="utf-8")
old = "${RABBITMQ_DEFAULT_VHOST:-/development}"
new = "${RABBITMQ_DEFAULT_VHOST:-development}"

if old in compose:
    compose = compose.replace(old, new, 1)
elif new not in compose:
    raise SystemExit(
        "[ERRO] Não foi possível localizar o padrão do vhost em compose.yaml."
    )

compose_path.write_text(compose, encoding="utf-8")
PY

  chmod 0600 "${ENV_FILE}"
  ok "Arquivos de configuração atualizados."
}

validate_compose() {
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
}

configure_rabbitmq() {
  local rabbit_user
  rabbit_user="$(get_env_value RABBITMQ_DEFAULT_USER)"

  info "Criando o virtual host e aplicando permissões."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      -f "${ACCESS_COMPOSE_FILE}" \
      exec \
      -T \
      -e TARGET_VHOST="${TARGET_VHOST}" \
      -e TARGET_USER="${rabbit_user}" \
      rabbitmq \
      sh -ec '
        if rabbitmqctl -q list_vhosts name |
          grep -Fx -- "$TARGET_VHOST" >/dev/null; then
          printf "[OK] Virtual host %s já existe.\n" "$TARGET_VHOST"
        else
          rabbitmqctl add_vhost "$TARGET_VHOST"
          printf "[OK] Virtual host %s criado.\n" "$TARGET_VHOST"
        fi

        rabbitmqctl set_permissions \
          -p "$TARGET_VHOST" \
          "$TARGET_USER" \
          ".*" \
          ".*" \
          ".*"

        printf "[OK] Permissões aplicadas ao usuário %s.\n" "$TARGET_USER"
      '
  )
}

run_test() {
  "${SCRIPT_DIR}/test-rabbitmq-integration.sh"
}

show_summary() {
  printf '\n'
  ok "Correção do RabbitMQ concluída."
  printf '\n'
  printf 'Virtual host ativo: %s\n' "${TARGET_VHOST}"
  printf 'Nenhum segredo foi exibido.\n'
  printf '\n'
  printf 'Atualize a página Sistema no Mission Control.\n'
}

main() {
  check_requirements
  backup_configuration
  update_configuration
  validate_compose
  configure_rabbitmq
  run_test
  show_summary
}

main "$@"
