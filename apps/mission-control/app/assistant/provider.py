from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any

from app.assistant.schemas import AssistantDecision
from app.config import settings


class ProviderError(RuntimeError):
    pass


def _tool_catalog(tools: list[dict[str, Any]]) -> str:
    return json.dumps(
        tools,
        ensure_ascii=False,
        separators=(",", ":"),
    )


def _system_prompt(tools: list[dict[str, Any]]) -> str:
    return (
        "Você é o roteador seguro do CompanyOS Assistant.\n\n"
        "Sua única função é interpretar a mensagem do usuário e "
        "selecionar uma ferramenta permitida.\n\n"
        "REGRAS OBRIGATÓRIAS:\n"
        "1. Retorne somente um objeto JSON válido.\n"
        "2. Nunca invente usuários, serviços, perfis ou eventos.\n"
        "3. Para dados reais, selecione uma ferramenta.\n"
        "4. Nunca solicite nem repita senhas, tokens ou segredos.\n"
        "5. Nunca produza SQL, shell ou comandos Docker.\n"
        "6. Use somente ferramentas presentes no catálogo.\n"
        "7. Esta versão é somente leitura.\n"
        "8. Responda em português do Brasil.\n\n"
        "Formato de ferramenta:\n"
        '{"type":"tool_call","tool":"nome","arguments":{}}\n\n'
        "Formato de mensagem simples:\n"
        '{"type":"message","content":"texto curto"}\n\n'
        "CATÁLOGO:\n"
        f"{_tool_catalog(tools)}"
    )


def _parse_decision(payload: dict[str, Any]) -> AssistantDecision:
    message = payload.get("message")

    if not isinstance(message, dict):
        raise ProviderError(
            "Ollama não retornou uma mensagem válida."
        )

    content = message.get("content")

    if not isinstance(content, str) or not content.strip():
        raise ProviderError("Ollama retornou conteúdo vazio.")

    try:
        parsed = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ProviderError(
            "Ollama retornou JSON inválido."
        ) from exc

    if not isinstance(parsed, dict):
        raise ProviderError(
            "A decisão do Ollama não é um objeto."
        )

    decision_type = str(parsed.get("type", "")).strip()

    if decision_type == "tool_call":
        tool = parsed.get("tool")
        arguments = parsed.get("arguments", {})

        if not isinstance(tool, str) or not tool.strip():
            raise ProviderError(
                "Ollama não informou uma ferramenta."
            )

        if not isinstance(arguments, dict):
            raise ProviderError(
                "Argumentos da ferramenta são inválidos."
            )

        return AssistantDecision(
            type="tool_call",
            tool=tool.strip(),
            arguments=arguments,
        )

    if decision_type == "message":
        response_content = parsed.get("content")

        if not isinstance(response_content, str):
            raise ProviderError(
                "Mensagem do Ollama é inválida."
            )

        return AssistantDecision(
            type="message",
            content=response_content.strip()[:1500],
        )

    raise ProviderError(
        "Tipo de decisão do Ollama não reconhecido."
    )


def decide(
    message: str,
    tools: list[dict[str, Any]],
) -> AssistantDecision:
    if settings.ai_provider != "ollama":
        raise ProviderError(
            f"Provedor não suportado: {settings.ai_provider}"
        )

    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "format": "json",
        "keep_alive": settings.ollama_keep_alive,
        "messages": [
            {
                "role": "system",
                "content": _system_prompt(tools),
            },
            {
                "role": "user",
                "content": message,
            },
        ],
        "options": {
            "temperature": 0,
            "num_ctx": settings.ollama_context_length,
        },
    }

    request = urllib.request.Request(
        f"{settings.ollama_base_url}/api/chat",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "SSC-Mission-Control/0.3",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=settings.ollama_request_timeout_seconds,
        ) as response:
            if response.status >= 400:
                raise ProviderError(
                    f"Ollama retornou HTTP {response.status}."
                )

            response_payload = json.load(response)
    except ProviderError:
        raise
    except (
        urllib.error.URLError,
        TimeoutError,
        OSError,
        ValueError,
    ) as exc:
        raise ProviderError(
            "Não foi possível consultar o Ollama."
        ) from exc

    if not isinstance(response_payload, dict):
        raise ProviderError(
            "Resposta do Ollama possui formato inválido."
        )

    return _parse_decision(response_payload)
