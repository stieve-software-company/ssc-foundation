#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

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
  for script in \
    "${SCRIPT_DIR}/backup.sh" \
    "${SCRIPT_DIR}/configure-postgresql-access.sh" \
    "${SCRIPT_DIR}/test-postgresql-access.sh" \
    "${SCRIPT_DIR}/backup-postgresql-logical.sh" \
    "${SCRIPT_DIR}/test-postgresql-logical-restore.sh"; do
    [[ -x "${script}" ]] \
      || fail "Script ausente ou sem execução: ${script}"
  done

  grep -Fq "POSTGRES_APP_USER=companyos_app" \
    "${PROJECT_ROOT}/.env.example" \
    || fail "Execute install-postgresql-operational.sh primeiro."
}

main() {
  check_requirements

  info "Etapa 1/4 — backup físico integrado."
  "${SCRIPT_DIR}/backup.sh" --yes

  info "Etapa 2/4 — separação de acessos."
  "${SCRIPT_DIR}/configure-postgresql-access.sh"

  info "Etapa 3/4 — backup lógico."
  "${SCRIPT_DIR}/backup-postgresql-logical.sh"

  info "Etapa 4/4 — restauração temporária."
  "${SCRIPT_DIR}/test-postgresql-logical-restore.sh"

  printf '\n'
  ok "Configuração operacional do PostgreSQL concluída."
}

main "$@"
