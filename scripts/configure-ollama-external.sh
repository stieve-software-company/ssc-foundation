#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BACKUP_DIR="${PROJECT_ROOT}/infrastructure/backups/config"

OLLAMA_URL=""
OLLAMA_MODEL_VALUE="qwen2.5-coder:3b"
OLLAMA_CONTEXT_VALUE="4096"
OLLAMA_KEEP_ALIVE_VALUE="10m"
OLLAMA_TIMEOUT_VALUE="120"

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

usage() {
  cat <<'EOF'
Uso:
  ./scripts/configure-ollama-external.sh \
    --url http://192.168.3.18:11434 \
    [--model qwen2.5-coder:3b] \
    [--context 4096] \
    [--keep-alive 10m] \
    [--timeout 120]
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --url)
        shift
        (($# > 0)) || fail "Informe um valor para --url."
        OLLAMA_URL=$1
        ;;
      --model)
        shift
        (($# > 0)) || fail "Informe um valor para --model."
        OLLAMA_MODEL_VALUE=$1
        ;;
      --context)
        shift
        (($# > 0)) || fail "Informe um valor para --context."
        OLLAMA_CONTEXT_VALUE=$1
        ;;
      --keep-alive)
        shift
        (($# > 0)) || fail "Informe um valor para --keep-alive."
        OLLAMA_KEEP_ALIVE_VALUE=$1
        ;;
      --timeout)
        shift
        (($# > 0)) || fail "Informe um valor para --timeout."
        OLLAMA_TIMEOUT_VALUE=$1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Opção desconhecida: $1"
        ;;
    esac
    shift
  done
}

validate_inputs() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"
  command -v curl >/dev/null 2>&1 || fail "curl não encontrado."
  command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

  [[ -n "${OLLAMA_URL}" ]] || fail "--url é obrigatório."
  OLLAMA_URL="${OLLAMA_URL%/}"

  [[ "${OLLAMA_URL}" =~ ^https?://[^[:space:]]+:[0-9]+$ ]] \
    || fail "URL inválida: ${OLLAMA_URL}"

  [[ "${OLLAMA_MODEL_VALUE}" =~ ^[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$ ]] \
    || fail "Nome de modelo inválido."

  [[ "${OLLAMA_CONTEXT_VALUE}" =~ ^[0-9]+$ ]] \
    || fail "--context precisa ser inteiro."

  (( OLLAMA_CONTEXT_VALUE >= 512 && OLLAMA_CONTEXT_VALUE <= 131072 )) \
    || fail "--context fora do intervalo permitido."

  [[ "${OLLAMA_TIMEOUT_VALUE}" =~ ^[0-9]+$ ]] \
    || fail "--timeout precisa ser inteiro."

  (( OLLAMA_TIMEOUT_VALUE >= 5 && OLLAMA_TIMEOUT_VALUE <= 3600 )) \
    || fail "--timeout fora do intervalo permitido."

  [[ "${OLLAMA_KEEP_ALIVE_VALUE}" =~ ^[0-9]+(ms|s|m|h)$ ]] \
    || fail "--keep-alive deve usar ms, s, m ou h. Exemplo: 10m."
}

validate_remote() {
  local tags_file
  tags_file="$(mktemp)"
  trap 'rm -f "${tags_file}"' RETURN

  info "Testando a API do Ollama."

  curl \
    --fail \
    --silent \
    --show-error \
    --max-time 10 \
    "${OLLAMA_URL}/api/tags" \
    > "${tags_file}"

  python3 - \
    "${tags_file}" \
    "${OLLAMA_MODEL_VALUE}" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
wanted = sys.argv[2]
models = payload.get("models", [])

names = {
    str(item.get("name") or item.get("model") or "")
    for item in models
    if isinstance(item, dict)
}

if wanted not in names:
    print(
        f"[ERRO] Modelo não encontrado no Ollama: {wanted}",
        file=sys.stderr,
    )
    print(
        "[INFO] Modelos encontrados: "
        + (", ".join(sorted(names)) if names else "nenhum"),
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"[OK] Modelo disponível: {wanted}")
PY

  ok "API do Ollama validada."
}

backup_env() {
  local timestamp
  local destination

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  destination="${BACKUP_DIR}/env-before-ollama-${timestamp}"

  install -d -m 0700 "${BACKUP_DIR}"
  install -m 0600 "${ENV_FILE}" "${destination}"

  ok "Cópia privada criada: ${destination}"
}

update_env() {
  python3 - \
    "${ENV_FILE}" \
    "${OLLAMA_URL}" \
    "${OLLAMA_MODEL_VALUE}" \
    "${OLLAMA_CONTEXT_VALUE}" \
    "${OLLAMA_KEEP_ALIVE_VALUE}" \
    "${OLLAMA_TIMEOUT_VALUE}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])

updates = {
    "AI_PROVIDER": "ollama",
    "OLLAMA_DEPLOYMENT_MODE": "external",
    "OLLAMA_BASE_URL": sys.argv[2],
    "OLLAMA_MODEL": sys.argv[3],
    "OLLAMA_DEFAULT_MODEL": sys.argv[3],
    "OLLAMA_CONTEXT_LENGTH": sys.argv[4],
    "OLLAMA_KEEP_ALIVE": sys.argv[5],
    "OLLAMA_REQUEST_TIMEOUT_SECONDS": sys.argv[6],
    "OLLAMA_VERIFY_MODEL": "true",
}

lines = path.read_text(encoding="utf-8").splitlines()
output: list[str] = []
written: set[str] = set()

for line in lines:
    stripped = line.strip()

    if stripped and not stripped.startswith("#") and "=" in line:
        key = line.split("=", 1)[0].strip()

        if key in updates:
            if key not in written:
                output.append(f"{key}={updates[key]}")
                written.add(key)
            continue

    output.append(line)

missing = [key for key in updates if key not in written]

if missing:
    output.extend(
        [
            "",
            "# ------------------------------------------------------------",
            "# Integração Ollama externo",
            "# ------------------------------------------------------------",
            "",
        ]
    )
    output.extend(f"{key}={updates[key]}" for key in missing)

path.write_text("\n".join(output) + "\n", encoding="utf-8")
PY

  chmod 0600 "${ENV_FILE}"
  ok "Variáveis do Ollama atualizadas sem exibir segredos."
}

show_summary() {
  printf '\n'
  printf 'Configuração aplicada:\n'
  printf '  Provedor:  ollama\n'
  printf '  URL:       %s\n' "${OLLAMA_URL}"
  printf '  Modelo:    %s\n' "${OLLAMA_MODEL_VALUE}"
  printf '  Contexto:  %s\n' "${OLLAMA_CONTEXT_VALUE}"
  printf '  KeepAlive: %s\n' "${OLLAMA_KEEP_ALIVE_VALUE}"
  printf '  Timeout:   %ss\n' "${OLLAMA_TIMEOUT_VALUE}"
  printf '\n'
  printf 'Próximo comando:\n'
  printf '  ./scripts/start-access.sh\n'
}

main() {
  parse_args "$@"
  validate_inputs
  validate_remote
  backup_env
  update_env
  show_summary
}

main "$@"
