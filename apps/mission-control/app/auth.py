from __future__ import annotations

import secrets
import uuid
from dataclasses import dataclass
from typing import Any

from fastapi import Request
from fastapi.responses import Response
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import User


COOKIE_NAME = "ssc_session"

serializer = URLSafeTimedSerializer(
    secret_key=settings.session_secret,
    salt="ssc-mission-control-session-v2",
)


@dataclass(frozen=True)
class AuthContext:
    user: User
    csrf_token: str


def create_session_token(user: User) -> str:
    return serializer.dumps(
        {
            "sub": str(user.id),
            "ver": user.session_version,
            "csrf": secrets.token_urlsafe(32),
        }
    )


def set_session_cookie(response: Response, user: User) -> None:
    response.set_cookie(
        key=COOKIE_NAME,
        value=create_session_token(user),
        max_age=settings.session_max_age_seconds,
        httponly=True,
        secure=settings.cookie_secure,
        samesite="strict",
        path="/",
    )


def clear_session_cookie(response: Response) -> None:
    response.delete_cookie(key=COOKIE_NAME, path="/")


def resolve_auth(request: Request, db: Session) -> AuthContext | None:
    token = request.cookies.get(COOKIE_NAME)

    if not token:
        return None

    try:
        payload: dict[str, Any] = serializer.loads(
            token,
            max_age=settings.session_max_age_seconds,
        )
        user_id = uuid.UUID(str(payload["sub"]))
        session_version = int(payload["ver"])
        csrf_token = str(payload["csrf"])
    except (
        BadSignature,
        SignatureExpired,
        KeyError,
        TypeError,
        ValueError,
    ):
        return None

    user = db.scalar(
        select(User).where(User.id == user_id)
    )

    if not user or not user.is_active:
        return None

    if user.session_version != session_version:
        return None

    return AuthContext(user=user, csrf_token=csrf_token)


def csrf_is_valid(auth: AuthContext, submitted: str) -> bool:
    return secrets.compare_digest(auth.csrf_token, submitted)
