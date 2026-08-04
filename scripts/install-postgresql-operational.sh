#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
readonly GITIGNORE="${PROJECT_ROOT}/.gitignore"
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
  [[ -s "${ENV_EXAMPLE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_EXAMPLE}"

  [[ -s "${GITIGNORE}" ]] \
    || fail "Arquivo ausente ou vazio: ${GITIGNORE}"

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  for script in \
    "${SCRIPT_DIR}/configure-postgresql-access.sh" \
    "${SCRIPT_DIR}/test-postgresql-access.sh" \
    "${SCRIPT_DIR}/backup-postgresql-logical.sh" \
    "${SCRIPT_DIR}/test-postgresql-logical-restore.sh" \
    "${SCRIPT_DIR}/bootstrap-postgresql-operational.sh"; do
    [[ -s "${script}" ]] \
      || fail "Script ausente ou vazio: ${script}"
  done
}

backup_files() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_ROOT}/postgresql-operational-${timestamp}"

  install -d -m 0700 "${destination}"
  install -m 0600 "${ENV_EXAMPLE}" "${destination}/.env.example"
  install -m 0600 "${GITIGNORE}" "${destination}/.gitignore"

  ok "Arquivos públicos preservados em ${destination}"
}

patch_files() {
  info "Atualizando .env.example e .gitignore."

  python3 - \
    "${ENV_EXAMPLE}" \
    "${GITIGNORE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


env_path = Path(sys.argv[1])
gitignore_path = Path(sys.argv[2])

env_text = env_path.read_text(encoding="utf-8")

app_block = """
# Credenciais de runtime com privilégio mínimo.
POSTGRES_APP_USER=companyos_app
POSTGRES_APP_PASSWORD=CHANGE_ME_POSTGRES_APP_PASSWORD

# Credenciais exclusivas de observabilidade.
POSTGRES_MONITOR_USER=companyos_monitor
POSTGRES_MONITOR_PASSWORD=CHANGE_ME_POSTGRES_MONITOR_PASSWORD
""".strip()

if "POSTGRES_APP_USER=" not in env_text:
    marker = "POSTGRES_PASSWORD=CHANGE_ME_POSTGRES_PASSWORD\n"

    if marker not in env_text:
        raise SystemExit(
            "[ERRO] POSTGRES_PASSWORD não encontrado em .env.example."
        )

    env_text = env_text.replace(
        marker,
        marker + "\n" + app_block + "\n",
        1,
    )

old_url = (
    "DATABASE_URL=postgresql+psycopg://companyos:"
    "CHANGE_ME_POSTGRES_PASSWORD@postgres:5432/companyos"
)
new_url = (
    "DATABASE_URL=postgresql+psycopg://companyos_app:"
    "CHANGE_ME_POSTGRES_APP_PASSWORD@postgres:5432/companyos"
)

if old_url in env_text:
    env_text = env_text.replace(old_url, new_url, 1)

env_path.write_text(env_text, encoding="utf-8", newline="\n")


gitignore_text = gitignore_path.read_text(encoding="utf-8")
entry = "postgresql-audit.txt"

if entry not in gitignore_text.splitlines():
    marker = "checksums.local.sha256\n"

    if marker in gitignore_text:
        gitignore_text = gitignore_text.replace(
            marker,
            marker + entry + "\n",
            1,
        )
    else:
        gitignore_text = (
            gitignore_text.rstrip()
            + "\n\n# Auditorias locais\n"
            + entry
            + "\n"
        )

gitignore_path.write_text(
    gitignore_text,
    encoding="utf-8",
    newline="\n",
)
PY

  ok "Arquivos públicos atualizados."
}

validate() {
  info "Validando scripts."

  local script

  for script in \
    "${SCRIPT_DIR}/configure-postgresql-access.sh" \
    "${SCRIPT_DIR}/test-postgresql-access.sh" \
    "${SCRIPT_DIR}/backup-postgresql-logical.sh" \
    "${SCRIPT_DIR}/test-postgresql-logical-restore.sh" \
    "${SCRIPT_DIR}/bootstrap-postgresql-operational.sh"; do
    chmod +x "${script}"
    bash -n "${script}" \
      || fail "Sintaxe inválida: ${script}"
  done

  grep -Fq "POSTGRES_APP_USER=companyos_app" "${ENV_EXAMPLE}" \
    || fail "POSTGRES_APP_USER não foi adicionado."

  grep -Fq "POSTGRES_MONITOR_USER=companyos_monitor" "${ENV_EXAMPLE}" \
    || fail "POSTGRES_MONITOR_USER não foi adicionado."

  grep -Fxq "postgresql-audit.txt" "${GITIGNORE}" \
    || fail "postgresql-audit.txt não foi ignorado."

  ok "Validação concluída."
}

main() {
  check_requirements
  backup_files
  patch_files
  validate

  printf '\n'
  ok "Arquivos operacionais do PostgreSQL instalados."
  printf 'Próximo passo obrigatório:\n'
  printf '  ./scripts/backup.sh --yes\n'
}

main "$@"
