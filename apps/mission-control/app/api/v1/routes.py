from __future__ import annotations

import asyncio
import json
import time

from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.orm import Session

from app.auth import resolve_auth
from app.authorization import has_permission, permission_codes
from app.config import settings
from app.database import SessionLocal, get_db
from app.foundation.collector import get_status_summary


router = APIRouter(prefix="/api/v1")


def error_response(
    message: str,
    *,
    status_code: int,
    error_code: str,
) -> JSONResponse:
    return JSONResponse(
        {
            "ok": False,
            "error": {
                "code": error_code,
                "message": message,
            },
        },
        status_code=status_code,
    )


@router.get("/me")
def current_user(
    request: Request,
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return error_response(
            "Autenticação necessária.",
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="authentication_required",
        )

    return {
        "ok": True,
        "data": {
            "id": str(auth.user.id),
            "username": auth.user.username,
            "full_name": auth.user.full_name,
            "email": auth.user.email,
            "role": {
                "slug": auth.user.role.slug,
                "name": auth.user.role.name,
            },
            "permissions": sorted(
                permission_codes(auth.user)
            ),
            "locale": auth.user.locale,
            "timezone": auth.user.timezone,
        },
    }


@router.get("/system/summary")
def system_summary(
    request: Request,
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return error_response(
            "Autenticação necessária.",
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="authentication_required",
        )

    if not has_permission(auth.user, "system.view"):
        return error_response(
            "Permissão system.view necessária.",
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="permission_denied",
        )

    return {
        "ok": True,
        "data": get_status_summary(),
    }


def authorize_sse(request: Request) -> JSONResponse | None:
    with SessionLocal() as db:
        auth = resolve_auth(request, db)

        if not auth:
            return error_response(
                "Autenticação necessária.",
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="authentication_required",
            )

        if not has_permission(auth.user, "system.view"):
            return error_response(
                "Permissão system.view necessária.",
                status_code=status.HTTP_403_FORBIDDEN,
                error_code="permission_denied",
            )

    return None


@router.get("/system/events")
async def system_events(request: Request):
    denied = authorize_sse(request)

    if denied is not None:
        return denied

    async def event_stream():
        last_payload = ""
        last_heartbeat = 0.0

        yield "retry: 3000\n\n"

        while True:
            if await request.is_disconnected():
                break

            summary = await asyncio.to_thread(
                get_status_summary
            )
            payload = json.dumps(
                summary,
                ensure_ascii=False,
                separators=(",", ":"),
            )

            if payload != last_payload:
                event_id = str(
                    summary.get("generated_at")
                    or int(time.time())
                )
                yield (
                    f"id: {event_id}\n"
                    "event: system.summary\n"
                    f"data: {payload}\n\n"
                )
                last_payload = payload
                last_heartbeat = time.monotonic()
            elif time.monotonic() - last_heartbeat >= 15:
                yield ": heartbeat\n\n"
                last_heartbeat = time.monotonic()

            await asyncio.sleep(
                settings.status_sse_interval_seconds
            )

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
