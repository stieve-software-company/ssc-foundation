#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"

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

main() {
  info "Executando testes integrados da aba Aparência."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
from __future__ import annotations

import base64
import json
import urllib.parse
import urllib.request

from sqlalchemy import select

from app.auth import COOKIE_NAME, create_session_token, serializer
from app.database import SessionLocal
from app.models import BrandingSettings, Permission, Role, User


BASE_URL = "http://127.0.0.1:8080"


def request(
    path: str,
    token: str | None = None,
    *,
    data: bytes | None = None,
    content_type: str | None = None,
):
    headers = {}

    if token:
        headers["Cookie"] = f"{COOKIE_NAME}={token}"

    if content_type:
        headers["Content-Type"] = content_type

    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers=headers,
        method="POST" if data is not None else "GET",
    )

    with urllib.request.urlopen(req, timeout=30) as response:
        return response.status, response.headers, response.read()


def multipart(fields: dict[str, str], filename: str, content: bytes):
    boundary = "----SSCBrandingBoundary"
    chunks: list[bytes] = []

    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                (
                    f'Content-Disposition: form-data; name="{name}"'
                    "\r\n\r\n"
                ).encode(),
                value.encode(),
                b"\r\n",
            ]
        )

    chunks.extend(
        [
            f"--{boundary}\r\n".encode(),
            (
                'Content-Disposition: form-data; name="logo"; '
                f'filename="{filename}"\r\n'
            ).encode(),
            b"Content-Type: image/png\r\n\r\n",
            content,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )

    return (
        b"".join(chunks),
        f"multipart/form-data; boundary={boundary}",
    )


with SessionLocal() as db:
    permission = db.scalar(
        select(Permission).where(
            Permission.code == "branding.manage"
        )
    )
    assert permission is not None
    print("[OK] Permissão branding.manage criada.")

    admin = db.scalar(
        select(User)
        .join(Role)
        .where(
            Role.slug == "admin",
            User.is_active.is_(True),
        )
        .limit(1)
    )
    assert admin is not None
    assert any(
        item.code == "branding.manage"
        for item in admin.role.permissions
    )
    print("[OK] Administrador recebeu branding.manage.")

    token = create_session_token(admin)
    csrf = str(serializer.loads(token)["csrf"])

    original = db.get(BrandingSettings, 1)
    snapshot = None

    if original is not None:
        snapshot = {
            column.name: getattr(original, column.name)
            for column in BrandingSettings.__table__.columns
        }

status_code, _, page = request("/branding", token)
assert status_code == 200
assert b"Apar" in page
print("[OK] Aba Aparência respondeu com autenticação.")

theme_data = urllib.parse.urlencode(
    {
        "csrf_token": csrf,
        "theme_name": "ocean",
        "background": "#04151f",
        "surface": "#0b2634",
        "surface_soft": "#113747",
        "accent": "#2dd4bf",
        "accent_strong": "#38bdf8",
    }
).encode()

status_code, _, _ = request(
    "/branding/theme",
    token,
    data=theme_data,
    content_type="application/x-www-form-urlencoded",
)
assert status_code == 200

_, _, css = request("/branding/theme.css")
assert b"#2dd4bf" in css
assert b"#04151f" in css
print("[OK] Tema persistido e CSS dinâmico validado.")

png = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
    "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
body, content_type = multipart(
    {"csrf_token": csrf},
    "test-logo.png",
    png,
)

status_code, _, _ = request(
    "/branding/logo",
    token,
    data=body,
    content_type=content_type,
)
assert status_code == 200

_, logo_headers, logo = request("/branding/logo")
assert logo.startswith(b"\x89PNG\r\n\x1a\n")
assert logo_headers.get_content_type() == "image/png"
print("[OK] Upload e entrega da logo validados.")

with SessionLocal() as db:
    current = db.get(BrandingSettings, 1)
    assert current is not None

    if snapshot is None:
        db.delete(current)
    else:
        for key, value in snapshot.items():
            setattr(current, key, value)

    db.commit()

print("[OK] Configuração original restaurada após o teste.")

status_code, _, health = request("/health")
payload = json.loads(health)
assert status_code == 200
assert payload["version"] == "0.2.1"
print("[OK] Health check reporta Mission Control v0.2.1.")
print("[OK] Testes integrados da aba Aparência concluídos.")
PY

  ok "Aba Aparência validada."
}

main "$@"
