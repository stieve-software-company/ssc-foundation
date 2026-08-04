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

check_container() {
  local container_id
  local health

  container_id="$(compose ps -q mission-control)"
  [[ -n "${container_id}" ]] \
    || fail "Container Mission Control não encontrado."

  health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${container_id}"
  )"

  [[ "${health}" == "healthy" ]] \
    || fail "Mission Control não está healthy: ${health}"

  ok "Container Mission Control saudável."
}

run_integrated_tests() {
  info "Executando testes integrados do Assistant."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

from sqlalchemy import select

from app.assistant.provider import decide
from app.assistant.tools import available_tools
from app.auth import (
    COOKIE_NAME,
    create_session_token,
    serializer,
)
from app.database import SessionLocal
from app.models import AuditEvent, Permission, Role, User


BASE_URL = "http://127.0.0.1:8080"


def http_request(
    path: str,
    token: str | None = None,
    *,
    form: dict[str, str] | None = None,
):
    data = None
    headers = {
        "Accept": "application/json,text/html,*/*",
    }

    if token:
        headers["Cookie"] = f"{COOKIE_NAME}={token}"

    if form is not None:
        data = urllib.parse.urlencode(form).encode("utf-8")
        headers["Content-Type"] = (
            "application/x-www-form-urlencoded"
        )

    request = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers=headers,
        method="POST" if data is not None else "GET",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=150,
        ) as response:
            return (
                response.status,
                response.headers,
                response.read(),
            )
    except urllib.error.HTTPError as exc:
        return (
            exc.code,
            exc.headers,
            exc.read(),
        )


with SessionLocal() as db:
    assistant_permission = db.scalar(
        select(Permission).where(
            Permission.code == "assistant.use"
        )
    )
    assert assistant_permission is not None
    print("[OK] Permissão assistant.use criada.")

    branding_permission = db.scalar(
        select(Permission).where(
            Permission.code == "branding.manage"
        )
    )
    assert branding_permission is not None
    print("[OK] Permissão branding.manage preservada.")

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

    admin_permissions = {
        item.code
        for item in admin.role.permissions
    }
    assert "assistant.use" in admin_permissions
    assert "branding.manage" in admin_permissions
    print("[OK] Administrador possui as duas permissões.")

    for slug in ("manager", "operator", "viewer"):
        role = db.scalar(
            select(Role).where(Role.slug == slug)
        )
        assert role is not None
        assert any(
            item.code == "assistant.use"
            for item in role.permissions
        )

    print("[OK] Perfis de sistema receberam assistant.use.")

    catalog = [
        tool.catalog_entry()
        for tool in available_tools(admin)
    ]

    decision = decide(
        "Qual ferramenta consulta o status geral dos serviços?",
        catalog,
    )
    assert decision.type in {
        "tool_call",
        "message",
    }

    if decision.type == "tool_call":
        assert decision.tool in {
            item["name"]
            for item in catalog
        }

    print("[OK] Ollama retornou decisão JSON estruturada.")

    token = create_session_token(admin)
    session_payload = serializer.loads(token)
    csrf = str(session_payload["csrf"])

    status_code, _, page = http_request(
        "/assistant",
        token,
    )
    assert status_code == 200
    assert b"CompanyOS Assistant" in page
    print("[OK] Tela autenticada do Assistant respondeu.")

    status_code, _, body = http_request(
        "/assistant/message",
        token,
        form={
            "csrf_token": csrf,
            "message": "Como estão os serviços?",
        },
    )
    response = json.loads(body)
    assert status_code == 200
    assert response["ok"] is True
    assert response["tool"] == "system.get_status"
    assert response["component"]["type"] == "service_status"
    names = {
        item["name"]
        for item in response["component"]["items"]
    }
    assert {
        "Mission Control",
        "PostgreSQL",
        "Redis",
        "RabbitMQ",
        "MinIO",
        "Ollama",
    }.issubset(names)
    print("[OK] Consulta de serviços validada.")

    status_code, _, body = http_request(
        "/assistant/message",
        token,
        form={
            "csrf_token": csrf,
            "message": "Liste os usuários ativos.",
        },
    )
    response = json.loads(body)
    assert status_code == 200
    assert response["ok"] is True
    assert response["tool"] == "users.list"
    assert response["component"]["type"] == "table"

    serialized = json.dumps(
        response,
        ensure_ascii=False,
    ).casefold()

    for forbidden in (
        "password_hash",
        "session_version",
        "admin_password",
        "database_url",
        "redis_url",
        "rabbitmq_url",
    ):
        assert forbidden not in serialized

    print("[OK] Listagem segura de usuários validada.")

    status_code, _, body = http_request(
        "/assistant/message",
        token,
        form={
            "csrf_token": csrf,
            "message": "senha=segredo123",
        },
    )
    response = json.loads(body)
    assert status_code == 400
    assert response["error_code"] == "sensitive_content"
    print("[OK] Conteúdo sensível foi rejeitado.")

    status_code, _, body = http_request(
        "/assistant/message",
        token,
        form={
            "csrf_token": csrf,
            "message": "Crie um usuário para Maria.",
        },
    )
    response = json.loads(body)
    assert status_code == 200
    assert response["ok"] is True
    assert response["tool"] is None
    assert "somente" in response["message"].casefold()
    print("[OK] Operação de escrita não foi executada.")

    status_code, _, _ = http_request(
        "/branding/theme.css"
    )
    assert status_code == 200

    status_code, logo_headers, logo = http_request(
        "/branding/logo"
    )
    assert status_code == 200
    assert logo
    assert logo_headers.get_content_type().startswith(
        "image/"
    )
    print("[OK] Aparência e logo foram preservadas.")

    status_code, _, health_body = http_request(
        "/health"
    )
    health = json.loads(health_body)
    assert status_code == 200
    assert health["version"] == "0.3.0"
    assert health["database"] == "connected"
    print("[OK] Health check reporta Mission Control v0.3.0.")

    received = db.scalar(
        select(AuditEvent)
        .where(
            AuditEvent.action
            == "assistant.message.received"
        )
        .order_by(AuditEvent.created_at.desc())
        .limit(1)
    )
    executed = db.scalar(
        select(AuditEvent)
        .where(
            AuditEvent.action
            == "assistant.tool.executed"
        )
        .order_by(AuditEvent.created_at.desc())
        .limit(1)
    )
    rejected = db.scalar(
        select(AuditEvent)
        .where(
            AuditEvent.action
            == "assistant.message.rejected"
        )
        .order_by(AuditEvent.created_at.desc())
        .limit(1)
    )

    assert received is not None
    assert executed is not None
    assert rejected is not None
    assert "message" not in received.details
    print("[OK] Auditoria segura do Assistant validada.")

print("[OK] Testes integrados do Assistant concluídos.")
PY
}

main() {
  check_container
  run_integrated_tests

  printf '\n'
  ok "Mission Control Assistant validado."
}

main "$@"
