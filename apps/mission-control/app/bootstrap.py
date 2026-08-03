from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.models import Permission, Role, User


PERMISSIONS = [
    (
        "dashboard.view",
        "Visualizar dashboard",
        "Acessar a página inicial e seus indicadores.",
    ),
    (
        "users.view",
        "Visualizar usuários",
        "Consultar usuários cadastrados.",
    ),
    (
        "users.create",
        "Criar usuários",
        "Cadastrar novos usuários.",
    ),
    (
        "users.edit",
        "Editar usuários",
        "Alterar dados, perfil e senha de usuários.",
    ),
    (
        "users.activate",
        "Ativar ou desativar usuários",
        "Controlar o estado de acesso dos usuários.",
    ),
    (
        "roles.view",
        "Visualizar perfis",
        "Consultar perfis e suas permissões.",
    ),
    (
        "roles.manage",
        "Gerenciar perfis",
        "Criar e alterar perfis personalizados.",
    ),
    (
        "audit.view",
        "Visualizar auditoria",
        "Consultar o histórico de ações administrativas.",
    ),
    (
        "system.view",
        "Visualizar sistema",
        "Consultar a saúde dos serviços da plataforma.",
    ),
    (
        "profile.edit",
        "Editar o próprio perfil",
        "Atualizar dados pessoais e a própria senha.",
    ),
]


ROLE_DEFINITIONS = {
    "admin": {
        "name": "Administrador",
        "description": "Acesso completo ao CompanyOS.",
        "permissions": "*",
    },
    "manager": {
        "name": "Gestor",
        "description": "Gestão de usuários e visualização operacional.",
        "permissions": {
            "dashboard.view",
            "users.view",
            "users.create",
            "users.edit",
            "users.activate",
            "roles.view",
            "audit.view",
            "system.view",
            "profile.edit",
        },
    },
    "operator": {
        "name": "Operador",
        "description": "Operação e consulta dos recursos da plataforma.",
        "permissions": {
            "dashboard.view",
            "users.view",
            "roles.view",
            "system.view",
            "profile.edit",
        },
    },
    "viewer": {
        "name": "Visualizador",
        "description": "Acesso de leitura aos painéis autorizados.",
        "permissions": {
            "dashboard.view",
            "system.view",
            "profile.edit",
        },
    },
}


def seed_permissions(db: Session) -> dict[str, Permission]:
    existing = {
        permission.code: permission
        for permission in db.scalars(select(Permission)).all()
    }

    for code, name, description in PERMISSIONS:
        permission = existing.get(code)

        if permission is None:
            permission = Permission(
                code=code,
                name=name,
                description=description,
            )
            db.add(permission)
            db.flush()
            existing[code] = permission
        else:
            permission.name = name
            permission.description = description

    return existing


def seed_roles(
    db: Session,
    permissions: dict[str, Permission],
) -> dict[str, Role]:
    existing = {
        role.slug: role
        for role in db.scalars(select(Role)).all()
    }

    for slug, definition in ROLE_DEFINITIONS.items():
        role = existing.get(slug)

        if role is None:
            role = Role(
                slug=slug,
                name=str(definition["name"]),
                description=str(definition["description"]),
                is_system=True,
            )
            db.add(role)
            db.flush()
            existing[slug] = role
        else:
            role.name = str(definition["name"])
            role.description = str(definition["description"])
            role.is_system = True

        configured = definition["permissions"]

        if configured == "*":
            role.permissions = list(permissions.values())
        else:
            role.permissions = [
                permissions[code]
                for code in configured
            ]

    return existing


def seed_initial_admin(db: Session, roles: dict[str, Role]) -> None:
    first_user = db.scalar(select(User).limit(1))

    if first_user is not None:
        return

    username = settings.admin_username.strip().lower()

    db.add(
        User(
            username=username,
            full_name="Administrador do CompanyOS",
            email=None,
            password_hash=settings.admin_password_hash,
            role=roles["admin"],
            is_active=True,
            profile_completed=False,
        )
    )


def initialize_database() -> None:
    Base.metadata.create_all(bind=engine)

    with SessionLocal() as db:
        permissions = seed_permissions(db)
        roles = seed_roles(db, permissions)
        seed_initial_admin(db, roles)
        db.commit()
