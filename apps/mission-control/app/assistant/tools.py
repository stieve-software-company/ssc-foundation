from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Callable

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.assistant.schemas import ToolPayload
from app.models import AuditEvent, Role, User
from app.system_status import collect_statuses


ToolHandler = Callable[
    [Session, User, dict[str, Any]],
    ToolPayload,
]


@dataclass(frozen=True)
class ToolDefinition:
    name: str
    description: str
    arguments: dict[str, str]
    required_permissions: frozenset[str]
    handler: ToolHandler

    def catalog_entry(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "arguments": self.arguments,
            "mode": "read",
        }


def permissions_for(user: User) -> set[str]:
    return {
        permission.code
        for permission in user.role.permissions
    }


def available_tools(user: User) -> list[ToolDefinition]:
    permissions = permissions_for(user)

    return [
        definition
        for definition in TOOL_REGISTRY.values()
        if definition.required_permissions.issubset(
            permissions
        )
    ]


def _format_datetime(value: datetime | None) -> str:
    if value is None:
        return "—"

    return value.strftime("%d/%m/%Y %H:%M")


def _bounded_integer(
    value: Any,
    *,
    default: int,
    minimum: int,
    maximum: int,
) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default

    return max(minimum, min(maximum, parsed))


def _audit_user_name(event: AuditEvent) -> str:
    if event.user is None:
        return "Sistema"

    return event.user.full_name or event.user.username


def assistant_help(
    _: Session,
    user: User,
    __: dict[str, Any],
) -> ToolPayload:
    permissions = permissions_for(user)
    examples = ["O que você consegue fazer?"]

    if "system.view" in permissions:
        examples.extend(
            [
                "Como estão os serviços?",
                "O Redis está saudável?",
            ]
        )

    if "users.view" in permissions:
        examples.extend(
            [
                "Liste os usuários ativos.",
                "Quantos usuários existem?",
                "Procure o usuário maria.",
            ]
        )

    if "roles.view" in permissions:
        examples.extend(
            [
                "Liste os perfis de acesso.",
                "Mostre o perfil Operador.",
            ]
        )

    if "audit.view" in permissions:
        examples.extend(
            [
                "Mostre os últimos eventos de auditoria.",
                "Quantos eventos existem na auditoria?",
            ]
        )

    return ToolPayload(
        message=(
            "Nesta versão eu consulto informações em modo somente "
            "leitura. A criação e alteração de usuários serão "
            "adicionadas depois com confirmação obrigatória."
        ),
        component={
            "type": "list",
            "title": "Perguntas disponíveis",
            "items": examples,
        },
    )


def system_get_status(
    _: Session,
    __: User,
    ___: dict[str, Any],
) -> ToolPayload:
    collected = collect_statuses()
    items = [
        {
            "name": "Mission Control",
            "status": "healthy",
            "detail": "Aplicação disponível",
            "latency_ms": 0,
        }
    ]

    items.extend(
        {
            "name": service.name,
            "status": service.status,
            "detail": service.detail,
            "latency_ms": service.latency_ms,
        }
        for service in collected
    )

    healthy = sum(
        item["status"] == "healthy"
        for item in items
    )

    message = (
        "Todos os serviços consultados estão disponíveis."
        if healthy == len(items)
        else f"{healthy} de {len(items)} serviços estão disponíveis."
    )

    return ToolPayload(
        message=message,
        component={
            "type": "service_status",
            "items": items,
        },
    )


def system_get_service(
    db: Session,
    user: User,
    arguments: dict[str, Any],
) -> ToolPayload:
    query = str(
        arguments.get("name")
        or arguments.get("service")
        or ""
    ).strip().casefold()

    if not query:
        return system_get_status(db, user, arguments)

    result = system_get_status(db, user, arguments)
    items = (
        result.component.get("items", [])
        if result.component
        else []
    )

    selected = next(
        (
            item
            for item in items
            if query in str(item["name"]).casefold()
            or str(item["name"]).casefold() in query
        ),
        None,
    )

    if selected is None:
        names = ", ".join(
            str(item["name"])
            for item in items
        )
        return ToolPayload(
            message=(
                "Serviço não encontrado. Serviços conhecidos: "
                f"{names}."
            )
        )

    available = selected["status"] == "healthy"

    return ToolPayload(
        message=(
            f"{selected['name']}: "
            f"{'disponível' if available else 'indisponível'}."
        ),
        component={
            "type": "service_status",
            "items": [selected],
        },
    )


def users_list(
    db: Session,
    _: User,
    arguments: dict[str, Any],
) -> ToolPayload:
    status_filter = str(
        arguments.get("status", "all")
    ).strip().casefold()

    if status_filter in {
        "ativo",
        "ativos",
        "active",
    }:
        status_filter = "active"
    elif status_filter in {
        "inativo",
        "inativos",
        "inactive",
        "disabled",
    }:
        status_filter = "inactive"
    else:
        status_filter = "all"

    limit = _bounded_integer(
        arguments.get("limit"),
        default=25,
        minimum=1,
        maximum=50,
    )

    statement = select(User).order_by(
        User.created_at.desc()
    )

    if status_filter == "active":
        statement = statement.where(
            User.is_active.is_(True)
        )
    elif status_filter == "inactive":
        statement = statement.where(
            User.is_active.is_(False)
        )

    users = db.scalars(
        statement.limit(limit)
    ).all()

    rows = [
        {
            "username": item.username,
            "name": item.full_name or "—",
            "email": item.email or "—",
            "role": item.role.name,
            "status": (
                "Ativo"
                if item.is_active
                else "Inativo"
            ),
            "last_login": _format_datetime(
                item.last_login_at
            ),
        }
        for item in users
    ]

    return ToolPayload(
        message=f"{len(rows)} usuário(s) encontrado(s).",
        component={
            "type": "table",
            "columns": [
                {
                    "key": "username",
                    "label": "Usuário",
                },
                {
                    "key": "name",
                    "label": "Nome",
                },
                {
                    "key": "email",
                    "label": "E-mail",
                },
                {
                    "key": "role",
                    "label": "Perfil",
                },
                {
                    "key": "status",
                    "label": "Status",
                },
                {
                    "key": "last_login",
                    "label": "Último login",
                },
            ],
            "rows": rows,
        },
    )


def users_get(
    db: Session,
    _: User,
    arguments: dict[str, Any],
) -> ToolPayload:
    query = str(
        arguments.get("query")
        or arguments.get("username")
        or arguments.get("name")
        or ""
    ).strip()

    if not query:
        return ToolPayload(
            message=(
                "Informe um nome, usuário ou e-mail para pesquisar."
            )
        )

    pattern = f"%{query}%"
    users = db.scalars(
        select(User)
        .where(
            or_(
                User.username.ilike(pattern),
                User.full_name.ilike(pattern),
                User.email.ilike(pattern),
            )
        )
        .order_by(
            User.full_name,
            User.username,
        )
        .limit(10)
    ).all()

    rows = [
        {
            "username": item.username,
            "name": item.full_name or "—",
            "email": item.email or "—",
            "role": item.role.name,
            "status": (
                "Ativo"
                if item.is_active
                else "Inativo"
            ),
            "created_at": _format_datetime(
                item.created_at
            ),
        }
        for item in users
    ]

    return ToolPayload(
        message=f"{len(rows)} resultado(s) para “{query}”.",
        component={
            "type": "table",
            "columns": [
                {
                    "key": "username",
                    "label": "Usuário",
                },
                {
                    "key": "name",
                    "label": "Nome",
                },
                {
                    "key": "email",
                    "label": "E-mail",
                },
                {
                    "key": "role",
                    "label": "Perfil",
                },
                {
                    "key": "status",
                    "label": "Status",
                },
                {
                    "key": "created_at",
                    "label": "Criado em",
                },
            ],
            "rows": rows,
        },
    )


def users_count(
    db: Session,
    _: User,
    __: dict[str, Any],
) -> ToolPayload:
    total = int(
        db.scalar(
            select(func.count(User.id))
        )
        or 0
    )
    active = int(
        db.scalar(
            select(func.count(User.id)).where(
                User.is_active.is_(True)
            )
        )
        or 0
    )
    inactive = total - active
    administrators = int(
        db.scalar(
            select(func.count(User.id))
            .join(Role)
            .where(
                Role.slug == "admin",
                User.is_active.is_(True),
            )
        )
        or 0
    )

    return ToolPayload(
        message=f"O Mission Control possui {total} usuário(s).",
        component={
            "type": "summary",
            "items": [
                {
                    "label": "Total",
                    "value": total,
                },
                {
                    "label": "Ativos",
                    "value": active,
                },
                {
                    "label": "Inativos",
                    "value": inactive,
                },
                {
                    "label": "Administradores ativos",
                    "value": administrators,
                },
            ],
        },
    )


def roles_list(
    db: Session,
    _: User,
    __: dict[str, Any],
) -> ToolPayload:
    roles = db.scalars(
        select(Role).order_by(
            Role.is_system.desc(),
            Role.name,
        )
    ).all()

    rows = [
        {
            "name": role.name,
            "slug": role.slug,
            "type": (
                "Sistema"
                if role.is_system
                else "Personalizado"
            ),
            "users": len(role.users),
            "permissions": len(role.permissions),
        }
        for role in roles
    ]

    return ToolPayload(
        message=f"{len(rows)} perfil(is) encontrado(s).",
        component={
            "type": "table",
            "columns": [
                {
                    "key": "name",
                    "label": "Perfil",
                },
                {
                    "key": "slug",
                    "label": "Identificador",
                },
                {
                    "key": "type",
                    "label": "Tipo",
                },
                {
                    "key": "users",
                    "label": "Usuários",
                },
                {
                    "key": "permissions",
                    "label": "Permissões",
                },
            ],
            "rows": rows,
        },
    )


def roles_get(
    db: Session,
    _: User,
    arguments: dict[str, Any],
) -> ToolPayload:
    query = str(
        arguments.get("query")
        or arguments.get("name")
        or arguments.get("slug")
        or ""
    ).strip()

    if not query:
        return ToolPayload(
            message="Informe o nome ou identificador do perfil."
        )

    pattern = f"%{query}%"
    roles = db.scalars(
        select(Role)
        .where(
            or_(
                Role.name.ilike(pattern),
                Role.slug.ilike(pattern),
            )
        )
        .order_by(Role.name)
        .limit(10)
    ).all()

    rows = [
        {
            "name": role.name,
            "slug": role.slug,
            "description": role.description or "—",
            "users": len(role.users),
            "permissions": ", ".join(
                sorted(
                    permission.code
                    for permission in role.permissions
                )
            ),
        }
        for role in roles
    ]

    return ToolPayload(
        message=f"{len(rows)} perfil(is) encontrado(s).",
        component={
            "type": "table",
            "columns": [
                {
                    "key": "name",
                    "label": "Perfil",
                },
                {
                    "key": "slug",
                    "label": "Identificador",
                },
                {
                    "key": "description",
                    "label": "Descrição",
                },
                {
                    "key": "users",
                    "label": "Usuários",
                },
                {
                    "key": "permissions",
                    "label": "Permissões",
                },
            ],
            "rows": rows,
        },
    )


def audit_list_recent(
    db: Session,
    _: User,
    arguments: dict[str, Any],
) -> ToolPayload:
    limit = _bounded_integer(
        arguments.get("limit"),
        default=10,
        minimum=1,
        maximum=30,
    )

    events = db.scalars(
        select(AuditEvent)
        .order_by(AuditEvent.created_at.desc())
        .limit(limit)
    ).all()

    rows = [
        {
            "date": _format_datetime(
                event.created_at
            ),
            "action": event.action,
            "description": event.description,
            "user": _audit_user_name(event),
            "resource": event.resource_type,
        }
        for event in events
    ]

    return ToolPayload(
        message=f"{len(rows)} evento(s) recente(s).",
        component={
            "type": "table",
            "columns": [
                {
                    "key": "date",
                    "label": "Data",
                },
                {
                    "key": "action",
                    "label": "Ação",
                },
                {
                    "key": "description",
                    "label": "Descrição",
                },
                {
                    "key": "user",
                    "label": "Usuário",
                },
                {
                    "key": "resource",
                    "label": "Recurso",
                },
            ],
            "rows": rows,
        },
    )


def audit_count(
    db: Session,
    _: User,
    __: dict[str, Any],
) -> ToolPayload:
    total = int(
        db.scalar(
            select(func.count(AuditEvent.id))
        )
        or 0
    )

    return ToolPayload(
        message=f"A auditoria possui {total} evento(s).",
        component={
            "type": "summary",
            "items": [
                {
                    "label": "Eventos registrados",
                    "value": total,
                }
            ],
        },
    )


TOOL_REGISTRY: dict[str, ToolDefinition] = {
    item.name: item
    for item in (
        ToolDefinition(
            name="assistant.help",
            description=(
                "Explica as capacidades do Assistant."
            ),
            arguments={},
            required_permissions=frozenset(
                {"assistant.use"}
            ),
            handler=assistant_help,
        ),
        ToolDefinition(
            name="system.get_status",
            description=(
                "Retorna o status atual de todos os serviços."
            ),
            arguments={},
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "system.view",
                }
            ),
            handler=system_get_status,
        ),
        ToolDefinition(
            name="system.get_service",
            description=(
                "Retorna o status de um serviço específico."
            ),
            arguments={
                "name": (
                    "Mission Control, PostgreSQL, Redis, "
                    "RabbitMQ, MinIO ou Ollama."
                )
            },
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "system.view",
                }
            ),
            handler=system_get_service,
        ),
        ToolDefinition(
            name="users.list",
            description=(
                "Lista usuários ativos, inativos ou todos."
            ),
            arguments={
                "status": "active, inactive ou all",
                "limit": "Número entre 1 e 50",
            },
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "users.view",
                }
            ),
            handler=users_list,
        ),
        ToolDefinition(
            name="users.get",
            description=(
                "Pesquisa usuários por nome, username ou e-mail."
            ),
            arguments={
                "query": "Texto usado na pesquisa",
            },
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "users.view",
                }
            ),
            handler=users_get,
        ),
        ToolDefinition(
            name="users.count",
            description=(
                "Conta usuários totais, ativos e inativos."
            ),
            arguments={},
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "users.view",
                }
            ),
            handler=users_count,
        ),
        ToolDefinition(
            name="roles.list",
            description=(
                "Lista os perfis de acesso."
            ),
            arguments={},
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "roles.view",
                }
            ),
            handler=roles_list,
        ),
        ToolDefinition(
            name="roles.get",
            description=(
                "Pesquisa um perfil e suas permissões."
            ),
            arguments={
                "query": "Nome ou identificador do perfil",
            },
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "roles.view",
                }
            ),
            handler=roles_get,
        ),
        ToolDefinition(
            name="audit.list_recent",
            description=(
                "Lista eventos recentes da auditoria."
            ),
            arguments={
                "limit": "Número entre 1 e 30",
            },
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "audit.view",
                }
            ),
            handler=audit_list_recent,
        ),
        ToolDefinition(
            name="audit.count",
            description=(
                "Conta os eventos registrados na auditoria."
            ),
            arguments={},
            required_permissions=frozenset(
                {
                    "assistant.use",
                    "audit.view",
                }
            ),
            handler=audit_count,
        ),
    )
}
