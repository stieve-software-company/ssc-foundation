#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly MAIN_FILE="${PROJECT_ROOT}/apps/mission-control/app/main.py"
readonly BOOTSTRAP_FILE="${PROJECT_ROOT}/apps/mission-control/app/bootstrap.py"
readonly BASE_FILE="${PROJECT_ROOT}/apps/mission-control/app/templates/base.html"
readonly ASSISTANT_DIR="${PROJECT_ROOT}/apps/mission-control/app/assistant"
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
  for file in \
    "${MAIN_FILE}" \
    "${BOOTSTRAP_FILE}" \
    "${BASE_FILE}" \
    "${ASSISTANT_DIR}/routes.py" \
    "${ASSISTANT_DIR}/orchestrator.py" \
    "${ASSISTANT_DIR}/provider.py" \
    "${ASSISTANT_DIR}/rate_limit.py" \
    "${ASSISTANT_DIR}/schemas.py" \
    "${ASSISTANT_DIR}/tools.py" \
    "${PROJECT_ROOT}/apps/mission-control/app/templates/assistant.html" \
    "${PROJECT_ROOT}/apps/mission-control/app/static/assistant.css" \
    "${PROJECT_ROOT}/apps/mission-control/app/static/assistant.js"; do
    [[ -s "${file}" ]] \
      || fail "Arquivo ausente ou vazio: ${file}"
  done

  grep -Fq "branding_router" "${MAIN_FILE}" \
    || fail "A versão com Aparência não está instalada."

  grep -Fq 'href="/branding"' "${BASE_FILE}" \
    || fail "A navegação da Aparência não foi encontrada."

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

backup_files() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_ROOT}/mission-control-assistant-${timestamp}"

  install -d -m 0700 "${destination}"
  install -m 0600 "${MAIN_FILE}" "${destination}/main.py"
  install -m 0600 "${BOOTSTRAP_FILE}" "${destination}/bootstrap.py"
  install -m 0600 "${BASE_FILE}" "${destination}/base.html"

  ok "Arquivos originais preservados em ${destination}"
}

patch_sources() {
  info "Integrando Assistant, RBAC e navegação."

  python3 - \
    "${MAIN_FILE}" \
    "${BOOTSTRAP_FILE}" \
    "${BASE_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


main_path = Path(sys.argv[1])
bootstrap_path = Path(sys.argv[2])
base_path = Path(sys.argv[3])


main = main_path.read_text(encoding="utf-8")

if "assistant_router" not in main:
    marker = (
        "from app.branding.routes import "
        "router as branding_router\n"
    )
    addition = (
        "from app.assistant.routes import "
        "router as assistant_router\n"
    )

    if marker not in main:
        raise SystemExit(
            "[ERRO] Import do branding não encontrado."
        )

    main = main.replace(
        marker,
        marker + addition,
        1,
    )

if "app.include_router(assistant_router)" not in main:
    marker = "app.include_router(branding_router)\n"

    if marker not in main:
        raise SystemExit(
            "[ERRO] Router do branding não encontrado."
        )

    main = main.replace(
        marker,
        marker + "app.include_router(assistant_router)\n",
        1,
    )

main = main.replace(
    'version="0.2.1"',
    'version="0.3.0"',
)
main = main.replace(
    '"version": "0.2.1"',
    '"version": "0.3.0"',
)

if 'version="0.3.0"' not in main:
    raise SystemExit(
        "[ERRO] Não foi possível atualizar a versão."
    )

main_path.write_text(main, encoding="utf-8")


bootstrap = bootstrap_path.read_text(encoding="utf-8")

permission_block = '''    (
        "assistant.use",
        "Usar o CompanyOS Assistant",
        "Consultar ferramentas operacionais em linguagem natural.",
    ),
'''

if '"assistant.use"' not in bootstrap:
    marker = '''    (
        "branding.manage",
'''

    if marker not in bootstrap:
        raise SystemExit(
            "[ERRO] Permissão de branding não encontrada."
        )

    bootstrap = bootstrap.replace(
        marker,
        permission_block + marker,
        1,
    )

for role_slug in (
    "manager",
    "operator",
    "viewer",
):
    start_marker = f'    "{role_slug}": {{'
    start = bootstrap.find(start_marker)

    if start < 0:
        raise SystemExit(
            f"[ERRO] Perfil não encontrado: {role_slug}"
        )

    next_role = bootstrap.find(
        '\n    "',
        start + len(start_marker),
    )
    section_end = (
        next_role
        if next_role >= 0
        else bootstrap.find("\n}\n", start)
    )

    if section_end < 0:
        raise SystemExit(
            f"[ERRO] Final do perfil não encontrado: {role_slug}"
        )

    section = bootstrap[start:section_end]

    if '"assistant.use"' in section:
        continue

    marker = '            "dashboard.view",\n'

    if marker not in section:
        raise SystemExit(
            f"[ERRO] dashboard.view ausente em {role_slug}."
        )

    updated = section.replace(
        marker,
        marker + '            "assistant.use",\n',
        1,
    )

    bootstrap = (
        bootstrap[:start]
        + updated
        + bootstrap[section_end:]
    )

bootstrap_path.write_text(
    bootstrap,
    encoding="utf-8",
)


base = base_path.read_text(encoding="utf-8")

assistant_nav = '''      {% if "assistant.use" in permission_codes %}
      <a class="{{ 'active' if active_nav == 'assistant' else '' }}" href="/assistant">
        <span>Assistant</span>
      </a>
      {% endif %}

'''

if 'href="/assistant"' not in base:
    marker = (
        '      {% if "users.view" in permission_codes %}\n'
    )

    if marker not in base:
        raise SystemExit(
            "[ERRO] Navegação de usuários não encontrada."
        )

    base = base.replace(
        marker,
        assistant_nav + marker,
        1,
    )

base = base.replace(
    "CompanyOS v0.2.1",
    "CompanyOS v0.3.0",
)

if "CompanyOS v0.3.0" not in base:
    raise SystemExit(
        "[ERRO] Não foi possível atualizar o menu."
    )

base_path.write_text(base, encoding="utf-8")
PY

  ok "Integração concluída."
}

validate_sources() {
  info "Validando Python, JavaScript e Docker Compose."

  python3 -m compileall \
    -q \
    "${PROJECT_ROOT}/apps/mission-control/app"

  if grep -R -n "innerHTML" \
    "${PROJECT_ROOT}/apps/mission-control/app/static/assistant.js"; then
    fail "assistant.js contém innerHTML."
  fi

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file .env \
      -f compose.yaml \
      -f compose.access.yaml \
      config --quiet
  )

  ok "Fontes e Docker Compose válidos."
}

main() {
  check_requirements
  backup_files
  patch_sources
  validate_sources

  printf '\n'
  ok "Assistant instalado nos arquivos-fonte."
  printf 'Próximo comando:\n'
  printf '  ./scripts/bootstrap-mission-control-assistant.sh\n'
}

main "$@"
