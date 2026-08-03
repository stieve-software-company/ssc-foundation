from __future__ import annotations

from app.models import User


def permission_codes(user: User) -> set[str]:
    return {permission.code for permission in user.role.permissions}


def has_permission(user: User, code: str) -> bool:
    return code in permission_codes(user)
