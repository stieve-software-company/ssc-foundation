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

get_env_value() {
  local key=$1
  local fallback=${2:-}
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
    ' "${ENV_FILE}"
  )"

  printf '%s' "${value:-${fallback}}"
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"
  [[ -s "${BASE_COMPOSE}" ]] || fail "Arquivo ausente: ${BASE_COMPOSE}"
  [[ -s "${ACCESS_COMPOSE}" ]] || fail "Arquivo ausente: ${ACCESS_COMPOSE}"

  command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."
  command -v docker >/dev/null 2>&1 || fail "docker não encontrado."
  command -v curl >/dev/null 2>&1 || fail "curl não encontrado."

  docker info >/dev/null 2>&1 || fail "Docker daemon não está acessível."
}

test_remote_api() {
  local base_url
  local model
  local context_length
  local keep_alive
  local timeout

  base_url="$(get_env_value OLLAMA_BASE_URL)"
  model="$(get_env_value OLLAMA_MODEL qwen2.5-coder:3b)"
  context_length="$(get_env_value OLLAMA_CONTEXT_LENGTH 4096)"
  keep_alive="$(get_env_value OLLAMA_KEEP_ALIVE 10m)"
  timeout="$(get_env_value OLLAMA_REQUEST_TIMEOUT_SECONDS 120)"

  [[ -n "${base_url}" ]] || fail "OLLAMA_BASE_URL não configurada."

  info "Testando Ollama em ${base_url}."

  python3 - \
    "${base_url%/}" \
    "${model}" \
    "${context_length}" \
    "${keep_alive}" \
    "${timeout}" <<'PY'
from __future__ import annotations

import json
import sys
import urllib.request
from typing import Any

base_url = sys.argv[1]
model = sys.argv[2]
context_length = int(sys.argv[3])
keep_alive = sys.argv[4]
timeout = int(sys.argv[5])


def request_json(
    path: str,
    *,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    data = None
    headers = {"User-Agent": "SSC-Integration-Test/1.0"}

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        headers=headers,
        method="POST" if payload is not None else "GET",
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        parsed = json.load(response)

    if not isinstance(parsed, dict):
        raise RuntimeError(f"Resposta inválida em {path}")

    return parsed


version = request_json("/api/version").get("version", "desconhecida")
print(f"[OK] API do Ollama respondeu. Versão: {version}")

tags = request_json("/api/tags")
models = tags.get("models", [])
names = {
    str(item.get("name") or item.get("model") or "")
    for item in models
    if isinstance(item, dict)
}

if model not in names:
    raise RuntimeError(f"Modelo não instalado: {model}")

print(f"[OK] Modelo {model} disponível.")

generated = request_json(
    "/api/generate",
    payload={
        "model": model,
        "prompt": (
            "Responda somente com a frase: "
            "CompanyOS conectado com sucesso."
        ),
        "stream": False,
        "keep_alive": keep_alive,
        "options": {
            "num_ctx": context_length,
            "temperature": 0,
        },
    },
)

response_text = str(generated.get("response", "")).strip()

if not response_text:
    raise RuntimeError("A inferência retornou resposta vazia.")

print(f"[OK] Inferência concluída: {response_text}")

running = request_json("/api/ps").get("models", [])
loaded = next(
    (
        item
        for item in running
        if isinstance(item, dict)
        and str(item.get("name") or item.get("model") or "") == model
    ),
    None,
)

if loaded is None:
    raise RuntimeError("Modelo não permaneceu carregado após a inferência.")

size = int(loaded.get("size") or 0)
size_vram = int(loaded.get("size_vram") or 0)

if size > 0 and size_vram >= size:
    print("[OK] Modelo carregado integralmente na GPU.")
elif size_vram > 0:
    percentage = round((size_vram / size) * 100, 1) if size else 0
    print(
        "[AVISO] Modelo dividido entre GPU e CPU. "
        f"VRAM: {percentage}%"
    )
else:
    print("[AVISO] Modelo carregado somente na CPU.")
PY
}

test_from_mission_control() {
  info "Testando acesso a partir do container Mission Control."

  (
    cd "${PROJECT_ROOT}"

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      exec \
      -T \
      mission-control \
      python - <<'PY'
from __future__ import annotations

import json
import urllib.request

from app.config import settings

with urllib.request.urlopen(
    f"{settings.ollama_base_url}/api/tags",
    timeout=min(settings.ollama_request_timeout_seconds, 10),
) as response:
    payload = json.load(response)

models = payload.get("models", [])
names = {
    str(item.get("name") or item.get("model") or "")
    for item in models
    if isinstance(item, dict)
}

if settings.ollama_model not in names:
    raise SystemExit(
        f"Modelo ausente no container: {settings.ollama_model}"
    )

print(
    "[OK] Mission Control acessa o Ollama e encontrou "
    f"{settings.ollama_model}."
)
PY
  )
}

test_mission_control_health() {
  local port
  port="$(get_env_value SSC_ACCESS_HOST_PORT 8080)"

  info "Testando health check do Mission Control."

  local health
  health="$(
    curl \
      --fail \
      --silent \
      --show-error \
      "http://127.0.0.1:${port}/health"
  )"

  grep -q '"status":"healthy"' <<< "${health}" \
    || fail "Mission Control não retornou healthy."

  ok "Mission Control saudável."
}

main() {
  check_requirements
  test_remote_api
  test_from_mission_control
  test_mission_control_health

  printf '\n'
  ok "Integração Ollama concluída."
}

main "$@"
