#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
readonly GITIGNORE="${PROJECT_ROOT}/.gitignore"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly OBSERVABILITY_COMPOSE="${PROJECT_ROOT}/compose.observability.yaml"
readonly BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
readonly RESTORE_SCRIPT="${SCRIPT_DIR}/restore.sh"
readonly CONFIG_BACKUP_ROOT="${PROJECT_ROOT}/infrastructure/backups/config"

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
  local file

  for file in \
    "${ENV_FILE}" \
    "${ENV_EXAMPLE}" \
    "${GITIGNORE}" \
    "${BASE_COMPOSE}" \
    "${ACCESS_COMPOSE}" \
    "${OBSERVABILITY_COMPOSE}" \
    "${BACKUP_SCRIPT}" \
    "${RESTORE_SCRIPT}"; do
    [[ -s "${file}" ]] \
      || fail "Arquivo ausente ou vazio: ${file}"
  done

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  local required_paths=(
    infrastructure/config/prometheus/prometheus.yml
    infrastructure/config/prometheus/rules/companyos-alerts.yml
    infrastructure/config/loki/loki-config.yaml
    infrastructure/config/alloy/config.alloy
    infrastructure/config/blackbox/blackbox.yml
    infrastructure/config/grafana/provisioning/datasources/companyos.yml
    infrastructure/config/grafana/provisioning/dashboards/companyos.yml
    infrastructure/config/grafana/dashboards/companyos-infrastructure.json
    infrastructure/config/grafana/dashboards/companyos-logs.json
    infrastructure/config/rabbitmq/enabled_plugins
  )

  local relative

  for relative in "${required_paths[@]}"; do
    [[ -s "${PROJECT_ROOT}/${relative}" ]] \
      || fail "Configuração ausente: ${relative}"
  done
}

backup_current_files() {
  local timestamp
  local destination
  local file

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${CONFIG_BACKUP_ROOT}/observability-${timestamp}"

  install -d -m 0700 "${destination}"

  for file in \
    "${ENV_EXAMPLE}" \
    "${GITIGNORE}" \
    "${BASE_COMPOSE}" \
    "${ACCESS_COMPOSE}" \
    "${BACKUP_SCRIPT}" \
    "${RESTORE_SCRIPT}"; do
    install -m 0600 \
      "${file}" \
      "${destination}/$(basename "${file}")"
  done

  ok "Arquivos preservados em ${destination}"
}

patch_environment_files() {
  info "Atualizando variáveis públicas e privadas."

  python3 - \
    "${ENV_EXAMPLE}" \
    "${ENV_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


public_path = Path(sys.argv[1])
private_path = Path(sys.argv[2])

values = {
    "ALLOY_IMAGE": "grafana/alloy:v1.18.0",
    "NODE_EXPORTER_IMAGE": "prom/node-exporter:v1.11.1",
    "CADVISOR_IMAGE": "ghcr.io/google/cadvisor:v0.57.0",
    "POSTGRES_EXPORTER_IMAGE": (
        "quay.io/prometheuscommunity/postgres-exporter:v0.19.1"
    ),
    "REDIS_EXPORTER_IMAGE": (
        "quay.io/oliver006/redis_exporter:v1.84.0"
    ),
    "BLACKBOX_EXPORTER_IMAGE": (
        "quay.io/prometheus/blackbox-exporter:v0.28.0"
    ),
    "DOCKER_SOCKET_PROXY_IMAGE": (
        "ghcr.io/tecnativa/docker-socket-proxy:v0.4.2"
    ),
}


def update(path: Path, public: bool) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    existing: set[str] = set()

    for line in lines:
        stripped = line.strip()

        if (
            stripped
            and not stripped.startswith("#")
            and "=" in stripped
        ):
            existing.add(stripped.split("=", 1)[0].strip())

    missing = [
        key
        for key in values
        if key not in existing
    ]

    if not missing:
        return

    lines.extend(
        [
            "",
            "# ------------------------------------------------------------",
            "# Observabilidade",
            "# ------------------------------------------------------------",
            "",
        ]
    )

    for key in missing:
        lines.append(f"{key}={values[key]}")

    path.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
        newline="\n",
    )


update(public_path, True)
update(private_path, False)
private_path.chmod(0o600)
PY

  ok "Variáveis de observabilidade configuradas."
}

patch_gitignore() {
  info "Protegendo relatórios locais."

  python3 - "${GITIGNORE}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
entries = [
    "observability-audit.txt",
    "observability-test.txt",
]

lines = text.splitlines()
known = set(lines)

missing = [
    entry
    for entry in entries
    if entry not in known
]

if missing:
    lines.extend(
        [
            "",
            "# Auditorias locais de observabilidade",
            *missing,
        ]
    )

path.write_text(
    "\n".join(lines).rstrip() + "\n",
    encoding="utf-8",
    newline="\n",
)
PY

  ok "Relatórios locais protegidos."
}

patch_grafana_bind() {
  info "Configurando o acesso LAN do Grafana."

  python3 - "${BASE_COMPOSE}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old = (
    '"${SSC_BIND_ADDRESS:-127.0.0.1}:'
    '${GRAFANA_HOST_PORT:-3000}:'
    '${GRAFANA_CONTAINER_PORT:-3000}"'
)
new = (
    '"${SSC_ACCESS_BIND_ADDRESS:-0.0.0.0}:'
    '${GRAFANA_HOST_PORT:-3000}:'
    '${GRAFANA_CONTAINER_PORT:-3000}"'
)

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit(
        "[ERRO] Porta do Grafana não encontrada em compose.yaml."
    )

path.write_text(text, encoding="utf-8", newline="\n")
PY

  ok "Grafana configurado para o endereço de acesso."
}

patch_backup_script() {
  info "Integrando observabilidade ao backup físico."

  python3 - "${BACKUP_SCRIPT}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

constant = (
    'readonly OBSERVABILITY_COMPOSE_FILE='
    '"${PROJECT_ROOT}/compose.observability.yaml"'
)

if constant not in text:
    marker = (
        'readonly ACCESS_COMPOSE_FILE='
        '"${PROJECT_ROOT}/compose.access.yaml"\n'
    )

    if marker not in text:
        raise SystemExit(
            "[ERRO] Constante ACCESS_COMPOSE_FILE não encontrada."
        )

    text = text.replace(
        marker,
        marker + constant + "\n",
        1,
    )

compose_block = """    if [[ -s "${OBSERVABILITY_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${OBSERVABILITY_COMPOSE_FILE}"
      )
    fi

"""

if compose_block not in text:
    marker = """    if [[ -s "${LOCAL_DOMAIN_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${LOCAL_DOMAIN_COMPOSE_FILE}"
      )
    fi

"""

    if marker not in text:
        raise SystemExit(
            "[ERRO] Bloco local-domain não encontrado no backup."
        )

    text = text.replace(
        marker,
        marker + compose_block,
        1,
    )

metadata_block = """  if [[ -s "${OBSERVABILITY_COMPOSE_FILE}" ]]; then
    cp "${OBSERVABILITY_COMPOSE_FILE}" \
      "${BACKUP_DIR}/metadata/compose.observability.yaml"
  fi

"""

if metadata_block not in text:
    marker = """  if [[ -s "${LOCAL_DOMAIN_COMPOSE_FILE}" ]]; then
    cp "${LOCAL_DOMAIN_COMPOSE_FILE}" \
      "${BACKUP_DIR}/metadata/compose.local-domain.yaml"
  fi

"""

    if marker not in text:
        raise SystemExit(
            "[ERRO] Bloco de metadata local-domain não encontrado."
        )

    text = text.replace(
        marker,
        marker + metadata_block,
        1,
    )

path.write_text(text, encoding="utf-8", newline="\n")
PY

  chmod +x "${BACKUP_SCRIPT}"
  ok "Backup integrado atualizado."
}

patch_restore_script() {
  info "Integrando observabilidade à restauração."

  python3 - "${RESTORE_SCRIPT}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

constants = """readonly ACCESS_COMPOSE_FILE="${PROJECT_ROOT}/compose.access.yaml"
readonly OBSERVABILITY_COMPOSE_FILE="${PROJECT_ROOT}/compose.observability.yaml"
"""

if "readonly OBSERVABILITY_COMPOSE_FILE=" not in text:
    marker = (
        'readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"\n'
    )

    if marker not in text:
        raise SystemExit(
            "[ERRO] Constante COMPOSE_FILE não encontrada."
        )

    text = text.replace(
        marker,
        marker + constants,
        1,
    )

old = """    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_FILE}" \
      --profile "*" \
      "$@"
"""

new = """    local compose_files=(
      -f "${COMPOSE_FILE}"
    )

    if [[ -s "${ACCESS_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${ACCESS_COMPOSE_FILE}"
      )
    fi

    if [[ -s "${OBSERVABILITY_COMPOSE_FILE}" ]]; then
      compose_files+=(
        -f "${OBSERVABILITY_COMPOSE_FILE}"
      )
    fi

    docker compose \
      --env-file "${ENV_FILE}" \
      "${compose_files[@]}" \
      --profile "*" \
      "$@"
"""

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit(
        "[ERRO] Função compose do restore não reconhecida."
    )

path.write_text(text, encoding="utf-8", newline="\n")
PY

  chmod +x "${RESTORE_SCRIPT}"
  ok "Restauração integrada atualizada."
}

validate_installation() {
  info "Validando os arquivos instalados."

  bash -n "${BACKUP_SCRIPT}"
  bash -n "${RESTORE_SCRIPT}"

  docker compose \
    --env-file "${ENV_FILE}" \
    -f "${BASE_COMPOSE}" \
    -f "${ACCESS_COMPOSE}" \
    -f "${OBSERVABILITY_COMPOSE}" \
    --profile observability \
    config --quiet

  grep -Fq "ALLOY_IMAGE=grafana/alloy:v1.18.0" \
    "${ENV_EXAMPLE}" \
    || fail "ALLOY_IMAGE não foi adicionada."

  grep -Fq "OBSERVABILITY_COMPOSE_FILE" \
    "${BACKUP_SCRIPT}" \
    || fail "Backup não foi atualizado."

  grep -Fq "OBSERVABILITY_COMPOSE_FILE" \
    "${RESTORE_SCRIPT}" \
    || fail "Restore não foi atualizado."

  grep -Fq "SSC_ACCESS_BIND_ADDRESS" \
    "${BASE_COMPOSE}" \
    || fail "Bind do Grafana não foi atualizado."

  ok "Instalação validada."
}

main() {
  check_requirements
  backup_current_files
  patch_environment_files
  patch_gitignore
  patch_grafana_bind
  patch_backup_script
  patch_restore_script
  validate_installation

  printf '\n'
  ok "Observabilidade instalada no repositório."
  printf 'Próximo passo:\n'
  printf '  ./scripts/bootstrap-observability.sh\n'
}

main "$@"
