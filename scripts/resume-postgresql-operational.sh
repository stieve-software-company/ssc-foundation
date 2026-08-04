#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ARCHIVE_ROOT="${PROJECT_ROOT}/infrastructure/backups/archives"

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

find_latest_backup() {
  LATEST_BACKUP="$(
    find "${ARCHIVE_ROOT}" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -printf '%p\n' 2>/dev/null |
      sort |
      tail -n 1
  )"

  [[ -n "${LATEST_BACKUP}" ]] \
    || fail "Nenhum backup físico foi encontrado."

  [[ -s "${LATEST_BACKUP}/metadata/manifest.env" ]] \
    || fail "Manifesto do backup ausente."

  [[ -s "${LATEST_BACKUP}/checksums.sha256" ]] \
    || fail "Checksums do backup ausentes."

  if ! grep -Fxq "status=success" \
    "${LATEST_BACKUP}/metadata/manifest.env"; then
    fail "O backup físico mais recente não está concluído."
  fi
}

verify_latest_backup() {
  info "Verificando o backup físico existente."

  (
    cd "${LATEST_BACKUP}"
    sha256sum --check checksums.sha256 >/dev/null
  )

  ok "Backup físico validado: ${LATEST_BACKUP}"
}

check_scripts() {
  local script

  for script in \
    "${SCRIPT_DIR}/configure-postgresql-access.sh" \
    "${SCRIPT_DIR}/test-postgresql-access.sh" \
    "${SCRIPT_DIR}/backup-postgresql-logical.sh" \
    "${SCRIPT_DIR}/test-postgresql-logical-restore.sh"; do
    [[ -x "${script}" ]] \
      || fail "Script ausente ou sem execução: ${script}"

    bash -n "${script}" \
      || fail "Sintaxe inválida: ${script}"
  done
}

main() {
  check_scripts
  find_latest_backup
  verify_latest_backup

  info "Retomando na etapa 2/4 — separação de acessos."
  "${SCRIPT_DIR}/configure-postgresql-access.sh"

  info "Executando a etapa 3/4 — backup lógico."
  "${SCRIPT_DIR}/backup-postgresql-logical.sh"

  info "Executando a etapa 4/4 — restauração temporária."
  "${SCRIPT_DIR}/test-postgresql-logical-restore.sh"

  printf '\n'
  ok "Configuração operacional do PostgreSQL retomada e concluída."
}

main "$@"
