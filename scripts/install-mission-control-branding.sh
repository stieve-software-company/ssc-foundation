#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly MAIN_FILE="${PROJECT_ROOT}/apps/mission-control/app/main.py"
readonly MODELS_FILE="${PROJECT_ROOT}/apps/mission-control/app/models.py"
readonly BOOTSTRAP_FILE="${PROJECT_ROOT}/apps/mission-control/app/bootstrap.py"
readonly BASE_FILE="${PROJECT_ROOT}/apps/mission-control/app/templates/base.html"
readonly LOGIN_FILE="${PROJECT_ROOT}/apps/mission-control/app/templates/login.html"
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
    "${MODELS_FILE}" \
    "${BOOTSTRAP_FILE}" \
    "${BASE_FILE}" \
    "${LOGIN_FILE}" \
    "${PROJECT_ROOT}/apps/mission-control/app/branding/routes.py" \
    "${PROJECT_ROOT}/apps/mission-control/app/branding/service.py" \
    "${PROJECT_ROOT}/apps/mission-control/app/templates/branding.html"; do
    [[ -s "${file}" ]] || fail "Arquivo ausente ou vazio: ${file}"
  done

  command -v python3 >/dev/null 2>&1 \
    || fail "Python 3 não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."
}

backup_files() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_ROOT}/mission-control-branding-${timestamp}"

  install -d -m 0700 "${destination}"
  install -m 0600 "${MAIN_FILE}" "${destination}/main.py"
  install -m 0600 "${MODELS_FILE}" "${destination}/models.py"
  install -m 0600 "${BOOTSTRAP_FILE}" "${destination}/bootstrap.py"
  install -m 0600 "${BASE_FILE}" "${destination}/base.html"
  install -m 0600 "${LOGIN_FILE}" "${destination}/login.html"

  ok "Arquivos originais preservados em ${destination}"
}

patch_sources() {
  info "Integrando banco, rotas, permissão e interface."

  python3 - \
    "${MAIN_FILE}" \
    "${MODELS_FILE}" \
    "${BOOTSTRAP_FILE}" \
    "${BASE_FILE}" \
    "${LOGIN_FILE}" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys


main_path = Path(sys.argv[1])
models_path = Path(sys.argv[2])
bootstrap_path = Path(sys.argv[3])
base_path = Path(sys.argv[4])
login_path = Path(sys.argv[5])


main = main_path.read_text(encoding="utf-8")

if "branding_router" not in main:
    marker = "from app.audit import record_event\n"
    addition = (
        "from app.branding.routes import "
        "router as branding_router\n"
    )

    if marker not in main:
        raise SystemExit("[ERRO] Import de auditoria não encontrado.")

    main = main.replace(marker, marker + addition, 1)

if "app.include_router(branding_router)" not in main:
    marker = (
        'templates = Jinja2Templates('
        'directory=BASE_DIR / "templates")\n'
    )

    if marker not in main:
        raise SystemExit("[ERRO] Instância de templates não encontrada.")

    main = main.replace(
        marker,
        marker + "\napp.include_router(branding_router)\n",
        1,
    )

main = main.replace('version="0.2.0"', 'version="0.2.1"')
main = main.replace('"version": "0.2.0"', '"version": "0.2.1"')
main_path.write_text(main, encoding="utf-8")


models = models_path.read_text(encoding="utf-8")

if "LargeBinary" not in models:
    models = models.replace(
        "    JSON,\n",
        "    JSON,\n    LargeBinary,\n",
        1,
    )

branding_model = '''

class BrandingSettings(Base):
    __tablename__ = "branding_settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    theme_name: Mapped[str] = mapped_column(
        String(40),
        default="midnight",
    )
    background: Mapped[str] = mapped_column(
        String(7),
        default="#070a12",
    )
    surface: Mapped[str] = mapped_column(
        String(7),
        default="#111726",
    )
    surface_soft: Mapped[str] = mapped_column(
        String(7),
        default="#171f33",
    )
    accent: Mapped[str] = mapped_column(
        String(7),
        default="#7c8cff",
    )
    accent_strong: Mapped[str] = mapped_column(
        String(7),
        default="#9f7aea",
    )
    text: Mapped[str] = mapped_column(
        String(7),
        default="#f5f7ff",
    )
    muted: Mapped[str] = mapped_column(
        String(7),
        default="#9aa5bd",
    )
    logo_data: Mapped[bytes | None] = mapped_column(LargeBinary)
    logo_content_type: Mapped[str | None] = mapped_column(String(50))
    logo_filename: Mapped[str | None] = mapped_column(String(255))
    logo_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True)
    )
    updated_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )
'''

if "class BrandingSettings" not in models:
    models = models.rstrip() + branding_model + "\n"

models_path.write_text(models, encoding="utf-8")


bootstrap = bootstrap_path.read_text(encoding="utf-8")

permission_block = '''    (
        "branding.manage",
        "Gerenciar aparência",
        "Alterar a logo e o esquema de cores do Mission Control.",
    ),
'''

if '"branding.manage"' not in bootstrap:
    marker = '''    (
        "profile.edit",
'''

    if marker not in bootstrap:
        raise SystemExit(
            "[ERRO] Não foi possível inserir branding.manage."
        )

    bootstrap = bootstrap.replace(
        marker,
        permission_block + marker,
        1,
    )

bootstrap_path.write_text(bootstrap, encoding="utf-8")


base = base_path.read_text(encoding="utf-8")
styles_marker = (
    "  <link rel=\"stylesheet\" "
    "href=\"{{ url_for('static', path='/styles.css') }}\">\n"
)
global_styles = (
    "  <link rel=\"stylesheet\" href=\"/branding/theme.css\">\n"
    "  <link rel=\"stylesheet\" "
    "href=\"{{ url_for('static', path='/branding-global.css') }}\">\n"
)

if "/branding/theme.css" not in base:
    if styles_marker not in base:
        raise SystemExit("[ERRO] CSS principal não encontrado em base.html.")

    base = base.replace(
        styles_marker,
        styles_marker + global_styles,
        1,
    )

if "{% block head_assets %}" not in base:
    script_marker = (
        "  <script src=\"{{ url_for('static', path='/app.js') }}\" "
        "defer></script>\n"
    )

    if script_marker not in base:
        raise SystemExit("[ERRO] app.js não encontrado em base.html.")

    base = base.replace(
        script_marker,
        script_marker + "  {% block head_assets %}{% endblock %}\n",
        1,
    )

base = base.replace(
    '<span class="brand-mark">SSC</span>',
    '''<span class="brand-mark branding-logo-frame">
        <img src="/branding/logo" alt="Logo do Mission Control">
      </span>''',
)

branding_nav = '''      {% if "branding.manage" in permission_codes %}
      <a class="{{ 'active' if active_nav == 'branding' else '' }}" href="/branding">
        <span>Aparência</span>
      </a>
      {% endif %}

'''

if 'href="/branding"' not in base:
    marker = '      {% if "system.view" in permission_codes %}\n'

    if marker not in base:
        raise SystemExit("[ERRO] Navegação de Sistema não encontrada.")

    base = base.replace(marker, branding_nav + marker, 1)

base = base.replace("CompanyOS v0.2", "CompanyOS v0.2.1")
base_path.write_text(base, encoding="utf-8")


login = login_path.read_text(encoding="utf-8")

if "/branding/theme.css" not in login:
    if styles_marker not in login:
        raise SystemExit("[ERRO] CSS principal não encontrado em login.html.")

    login = login.replace(
        styles_marker,
        styles_marker + global_styles,
        1,
    )

login = login.replace(
    '<div class="brand-mark large">SSC</div>',
    '''<div class="brand-mark large branding-logo-frame">
        <img src="/branding/logo" alt="Logo do Mission Control">
      </div>''',
)

login = login.replace("CompanyOS v0.2", "CompanyOS v0.2.1")
login = login.replace("SSC v0.2", "SSC v0.2.1")
login_path.write_text(login, encoding="utf-8")
PY

  ok "Integração concluída."
}

validate_sources() {
  info "Validando Python e Docker Compose."

  python3 -m compileall \
    -q \
    "${PROJECT_ROOT}/apps/mission-control/app"

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file .env \
      -f compose.yaml \
      -f compose.access.yaml \
      config --quiet
  )

  ok "Fontes e Compose válidos."
}

main() {
  check_requirements
  backup_files
  patch_sources
  validate_sources

  printf '\n'
  ok "A aba Aparência foi instalada nos arquivos-fonte."
  printf 'Próximo comando:\n'
  printf '  ./scripts/bootstrap-mission-control-branding.sh\n'
}

main "$@"
