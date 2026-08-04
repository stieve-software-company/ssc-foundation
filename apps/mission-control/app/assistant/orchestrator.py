from __future__ import annotations

import re
from typing import Any

from sqlalchemy.orm import Session

from app.assistant.provider import ProviderError, decide
from app.assistant.schemas import (
    AssistantDecision,
    AssistantResult,
)
from app.assistant.tools import (
    TOOL_REGISTRY,
    available_tools,
    permissions_for,
)
from app.models import User


SECRET_PATTERN = re.compile(
    r"(?i)\b(?:senha|password|token|cookie|secret|segredo)"
    r"\s*[:=]\s*\S+"
)

WRITE_PATTERN = re.compile(
    r"(?i)\b(?:crie|criar|cadastre|cadastrar|edite|editar|"
    r"altere|alterar|ative|ativar|desative|desativar|"
    r"remova|remover|exclua|excluir|delete|reset|"
    r"redefina|redefinir|troque|trocar)\b"
)


def _extract_after(
    message: str,
    patterns: tuple[str, ...],
) -> str:
    for pattern in patterns:
        match = re.search(pattern, message, flags=re.IGNORECASE)

        if match:
            return match.group(1).strip(" .?!")

    return ""


def _local_decision(
    message: str,
) -> AssistantDecision | None:
    normalized = message.casefold()

    service_names = {
        "mission control": "Mission Control",
        "postgresql": "PostgreSQL",
        "postgres": "PostgreSQL",
        "redis": "Redis",
        "rabbitmq": "RabbitMQ",
        "rabbit": "RabbitMQ",
        "minio": "MinIO",
        "ollama": "Ollama",
    }

    for key, name in service_names.items():
        if key in normalized:
            return AssistantDecision(
                type="tool_call",
                tool="system.get_service",
                arguments={"name": name},
            )

    if any(
        term in normalized
        for term in (
            "status dos serviços",
            "status dos servicos",
            "como estão os serviços",
            "como estao os servicos",
            "saúde dos serviços",
            "saude dos servicos",
            "infraestrutura",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="system.get_status",
        )

    if any(
        term in normalized
        for term in (
            "quantos usuários",
            "quantos usuarios",
            "quantidade de usuários",
            "quantidade de usuarios",
            "contar usuários",
            "contar usuarios",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="users.count",
        )

    if any(
        term in normalized
        for term in (
            "usuários inativos",
            "usuarios inativos",
            "usuário inativo",
            "usuario inativo",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="users.list",
            arguments={"status": "inactive"},
        )

    if any(
        term in normalized
        for term in (
            "usuários ativos",
            "usuarios ativos",
            "listar usuários",
            "listar usuarios",
            "liste os usuários",
            "liste os usuarios",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="users.list",
            arguments={"status": "active"},
        )

    user_query = _extract_after(
        message,
        (
            r"(?:procure|pesquise|busque)\s+"
            r"(?:o\s+)?(?:usuário|usuario)\s+(.+)",
            r"(?:usuário|usuario)\s+chamado\s+(.+)",
        ),
    )

    if user_query:
        return AssistantDecision(
            type="tool_call",
            tool="users.get",
            arguments={"query": user_query},
        )

    if any(
        term in normalized
        for term in (
            "liste os perfis",
            "listar perfis",
            "perfis de acesso",
            "quais perfis",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="roles.list",
        )

    role_query = _extract_after(
        message,
        (
            r"(?:mostre|procure|pesquise)\s+"
            r"(?:o\s+)?perfil\s+(.+)",
        ),
    )

    if role_query:
        return AssistantDecision(
            type="tool_call",
            tool="roles.get",
            arguments={"query": role_query},
        )

    if any(
        term in normalized
        for term in (
            "quantos eventos",
            "quantidade de eventos",
            "contar eventos",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="audit.count",
        )

    if any(
        term in normalized
        for term in (
            "eventos recentes",
            "auditoria recente",
            "últimos eventos",
            "ultimos eventos",
            "atividade recente",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="audit.list_recent",
        )

    if any(
        term in normalized
        for term in (
            "ajuda",
            "o que você consegue",
            "o que voce consegue",
            "o que pode fazer",
            "como funciona",
        )
    ):
        return AssistantDecision(
            type="tool_call",
            tool="assistant.help",
        )

    return None


def _choose_decision(
    message: str,
    catalog: list[dict[str, Any]],
) -> tuple[AssistantDecision, str]:
    local = _local_decision(message)

    if local is not None:
        return local, "rules"

    try:
        return decide(message, catalog), "ollama"
    except ProviderError:
        return (
            AssistantDecision(
                type="tool_call",
                tool="assistant.help",
            ),
            "fallback",
        )


def process_message(
    db: Session,
    user: User,
    message: str,
) -> AssistantResult:
    cleaned = message.strip()

    if not cleaned:
        return AssistantResult(
            ok=False,
            message="Digite uma pergunta.",
            status_code=400,
            error_code="empty_message",
        )

    if len(cleaned) > 1000:
        return AssistantResult(
            ok=False,
            message=(
                "A mensagem deve ter no máximo 1.000 caracteres."
            ),
            status_code=400,
            error_code="message_too_long",
        )

    if SECRET_PATTERN.search(cleaned):
        return AssistantResult(
            ok=False,
            message=(
                "Não envie senhas, tokens ou segredos ao Assistant. "
                "Use os formulários seguros do Mission Control."
            ),
            status_code=400,
            error_code="sensitive_content",
            audit_action="assistant.message.rejected",
        )

    if WRITE_PATTERN.search(cleaned):
        return AssistantResult(
            ok=True,
            message=(
                "Esta versão do Assistant funciona somente em modo "
                "de leitura. Ações administrativas serão adicionadas "
                "na próxima fase com confirmação obrigatória."
            ),
            provider="application",
        )

    tools = available_tools(user)
    catalog = [
        definition.catalog_entry()
        for definition in tools
    ]

    decision, provider = _choose_decision(
        cleaned,
        catalog,
    )

    if decision.type == "message":
        content = (decision.content or "").strip()

        if not content:
            content = (
                "Não consegui interpretar a solicitação "
                "com segurança."
            )

        return AssistantResult(
            ok=True,
            message=content[:1500],
            provider=provider,
        )

    if decision.type != "tool_call" or not decision.tool:
        return AssistantResult(
            ok=False,
            message=(
                "Não consegui interpretar a solicitação "
                "com segurança."
            ),
            provider=provider,
            status_code=400,
            error_code="invalid_decision",
        )

    definition = TOOL_REGISTRY.get(decision.tool)

    if definition is None:
        return AssistantResult(
            ok=False,
            message=(
                "A ferramenta solicitada não está disponível."
            ),
            tool=decision.tool,
            provider=provider,
            status_code=400,
            error_code="unknown_tool",
            audit_action="assistant.tool.denied",
        )

    user_permissions = permissions_for(user)

    if not definition.required_permissions.issubset(
        user_permissions
    ):
        return AssistantResult(
            ok=False,
            message=(
                "Seu perfil não possui permissão para essa consulta."
            ),
            tool=definition.name,
            provider=provider,
            status_code=403,
            error_code="permission_denied",
            audit_action="assistant.tool.denied",
        )

    try:
        payload = definition.handler(
            db,
            user,
            decision.arguments,
        )
    except Exception:
        return AssistantResult(
            ok=False,
            message=(
                "A consulta não pôde ser concluída neste momento."
            ),
            tool=definition.name,
            provider=provider,
            status_code=503,
            error_code="tool_failed",
            audit_action="assistant.tool.failed",
        )

    return AssistantResult(
        ok=True,
        message=payload.message,
        tool=definition.name,
        component=payload.component,
        provider=provider,
        audit_action="assistant.tool.executed",
    )
