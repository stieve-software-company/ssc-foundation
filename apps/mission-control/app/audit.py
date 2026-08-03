from __future__ import annotations

from fastapi import Request
from sqlalchemy.orm import Session

from app.models import AuditEvent, User


def client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")

    if forwarded:
        return forwarded.split(",", 1)[0].strip()

    if request.client:
        return request.client.host

    return None


def record_event(
    db: Session,
    request: Request,
    *,
    action: str,
    description: str,
    user: User | None = None,
    resource_type: str = "system",
    resource_id: str | None = None,
    details: dict | None = None,
) -> None:
    db.add(
        AuditEvent(
            user_id=user.id if user else None,
            action=action,
            description=description,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=client_ip(request),
            details=details or {},
        )
    )
