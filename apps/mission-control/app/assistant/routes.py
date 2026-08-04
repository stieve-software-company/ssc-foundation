from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    Form,
    Request,
    status,
)
from fastapi.responses import (
    HTMLResponse,
    JSONResponse,
    RedirectResponse,
)
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.assistant.orchestrator import process_message
from app.assistant.rate_limit import consume
from app.audit import record_event
from app.auth import csrf_is_valid, resolve_auth
from app.authorization import (
    has_permission,
    permission_codes,
)
from app.config import settings
from app.database import get_db


router = APIRouter()
APP_DIR = Path(__file__).resolve().parents[1]
templates = Jinja2Templates(
    directory=APP_DIR / "templates"
)


def redirect(path: str) -> RedirectResponse:
    return RedirectResponse(
        path,
        status_code=status.HTTP_303_SEE_OTHER,
    )


def page_context(
    request: Request,
    auth,
) -> dict:
    return {
        "request": request,
        "current_user": auth.user,
        "permission_codes": permission_codes(
            auth.user
        ),
        "csrf_token": auth.csrf_token,
        "active_nav": "assistant",
        "message": request.query_params.get(
            "message"
        ),
        "environment": settings.environment,
        "assistant_model": settings.ollama_model,
    }


def json_error(
    message: str,
    *,
    status_code: int,
    error_code: str,
) -> JSONResponse:
    return JSONResponse(
        {
            "ok": False,
            "message": message,
            "tool": None,
            "component": None,
            "provider": "application",
            "error_code": error_code,
        },
        status_code=status_code,
    )


@router.get(
    "/assistant",
    response_class=HTMLResponse,
)
def assistant_page(
    request: Request,
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(
        auth.user,
        "assistant.use",
    ):
        return templates.TemplateResponse(
            request=request,
            name="error.html",
            context={
                **page_context(request, auth),
                "title": "Acesso não autorizado",
                "error_code": "403",
                "description": (
                    "Seu perfil não possui permissão "
                    "para usar o Assistant."
                ),
            },
            status_code=status.HTTP_403_FORBIDDEN,
        )

    return templates.TemplateResponse(
        request=request,
        name="assistant.html",
        context=page_context(request, auth),
    )


@router.post(
    "/assistant/message",
    response_class=JSONResponse,
)
def assistant_message(
    request: Request,
    message: str = Form(...),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return json_error(
            "Sua sessão expirou. Entre novamente.",
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            error_code="authentication_required",
        )

    if not csrf_is_valid(auth, csrf_token):
        return json_error(
            "O formulário expirou. Atualize a página.",
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            error_code="invalid_csrf",
        )

    if not has_permission(
        auth.user,
        "assistant.use",
    ):
        record_event(
            db,
            request,
            action="assistant.tool.denied",
            description=(
                "Acesso ao Assistant negado."
            ),
            user=auth.user,
            resource_type="assistant",
            details={
                "reason": "assistant.use"
            },
        )
        db.commit()

        return json_error(
            "Seu perfil não possui permissão "
            "para usar o Assistant.",
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            error_code="permission_denied",
        )

    rate = consume(str(auth.user.id))

    if not rate.allowed:
        record_event(
            db,
            request,
            action="assistant.rate_limited",
            description=(
                "Limite de mensagens do "
                "Assistant atingido."
            ),
            user=auth.user,
            resource_type="assistant",
            details={
                "backend": rate.backend,
            },
        )
        db.commit()

        return json_error(
            "Muitas mensagens em pouco tempo. "
            "Aguarde um minuto.",
            status_code=(
                status.HTTP_429_TOO_MANY_REQUESTS
            ),
            error_code="rate_limited",
        )

    request_id = str(uuid.uuid4())

    record_event(
        db,
        request,
        action="assistant.message.received",
        description=(
            "Mensagem recebida pelo Assistant."
        ),
        user=auth.user,
        resource_type="assistant",
        resource_id=request_id,
        details={
            "length": len(message),
            "rate_limit_backend": rate.backend,
        },
    )

    result = process_message(
        db,
        auth.user,
        message,
    )

    record_event(
        db,
        request,
        action=result.audit_action,
        description=(
            "Ferramenta do Assistant processada."
            if result.tool
            else "Resposta do Assistant processada."
        ),
        user=auth.user,
        resource_type="assistant",
        resource_id=request_id,
        details={
            "tool": result.tool,
            "provider": result.provider,
            "ok": result.ok,
            "error_code": result.error_code,
        },
    )
    db.commit()

    response = result.as_dict()
    response["request_id"] = request_id
    response["rate_limit_remaining"] = (
        rate.remaining
    )

    return JSONResponse(
        response,
        status_code=result.status_code,
    )
