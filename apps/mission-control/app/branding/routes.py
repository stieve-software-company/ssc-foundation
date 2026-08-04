from __future__ import annotations

from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    Form,
    Request,
    UploadFile,
    status,
)
from fastapi.responses import (
    HTMLResponse,
    RedirectResponse,
    Response,
)
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.audit import record_event
from app.auth import csrf_is_valid, resolve_auth
from app.authorization import has_permission, permission_codes
from app.branding.service import (
    DEFAULT_LOGO_SVG,
    THEMES,
    css_for,
    current_view,
    get_record,
    remove_logo,
    reset_branding,
    update_logo,
    update_theme,
)
from app.config import settings
from app.database import SessionLocal, get_db


router = APIRouter()
APP_DIR = Path(__file__).resolve().parents[1]
templates = Jinja2Templates(directory=APP_DIR / "templates")


def redirect(path: str) -> RedirectResponse:
    return RedirectResponse(
        path,
        status_code=status.HTTP_303_SEE_OTHER,
    )


def page_context(
    request: Request,
    auth,
    *,
    error: str | None = None,
) -> dict:
    with SessionLocal() as branding_db:
        branding = current_view(branding_db)

    return {
        "request": request,
        "current_user": auth.user,
        "permission_codes": permission_codes(auth.user),
        "csrf_token": auth.csrf_token,
        "active_nav": "branding",
        "message": request.query_params.get("message"),
        "environment": settings.environment,
        "branding": branding,
        "themes": THEMES,
        "error": error,
    }


def forbidden_page(request: Request, auth) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="error.html",
        context={
            **page_context(request, auth),
            "title": "Acesso não autorizado",
            "error_code": "403",
            "description": (
                "Seu perfil não possui permissão para alterar a aparência."
            ),
        },
        status_code=status.HTTP_403_FORBIDDEN,
    )


@router.get("/branding/theme.css")
def branding_theme_css():
    with SessionLocal() as db:
        view = current_view(db)

    return Response(
        css_for(view),
        media_type="text/css",
        headers={
            "Cache-Control": "no-store, max-age=0",
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.get("/branding/logo")
def branding_logo():
    with SessionLocal() as db:
        record = get_record(db)

        if (
            record is not None
            and record.logo_data
            and record.logo_content_type
        ):
            content = bytes(record.logo_data)
            media_type = record.logo_content_type
        else:
            content = DEFAULT_LOGO_SVG
            media_type = "image/svg+xml"

    return Response(
        content,
        media_type=media_type,
        headers={
            "Cache-Control": "no-store, max-age=0",
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.get("/branding", response_class=HTMLResponse)
def branding_page(
    request: Request,
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "branding.manage"):
        return forbidden_page(request, auth)

    return templates.TemplateResponse(
        request=request,
        name="branding.html",
        context=page_context(request, auth),
    )


@router.post("/branding/theme", response_class=HTMLResponse)
def save_theme(
    request: Request,
    theme_name: str = Form(...),
    background: str = Form(""),
    surface: str = Form(""),
    surface_soft: str = Form(""),
    accent: str = Form(""),
    accent_strong: str = Form(""),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return templates.TemplateResponse(
            request=request,
            name="error.html",
            context={
                **page_context(request, auth),
                "title": "Formulário expirado",
                "error_code": "419",
                "description": "Atualize a página e tente novamente.",
            },
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if not has_permission(auth.user, "branding.manage"):
        return forbidden_page(request, auth)

    try:
        record = update_theme(
            db,
            theme_name=theme_name,
            custom_values={
                "background": background,
                "surface": surface,
                "surface_soft": surface_soft,
                "accent": accent,
                "accent_strong": accent_strong,
            },
            updated_by_user_id=auth.user.id,
        )
    except ValueError as exc:
        db.rollback()
        return templates.TemplateResponse(
            request=request,
            name="branding.html",
            context=page_context(
                request,
                auth,
                error=str(exc),
            ),
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    record_event(
        db,
        request,
        action="branding.theme.updated",
        description="Tema visual do Mission Control atualizado.",
        user=auth.user,
        resource_type="branding",
        resource_id=str(record.id),
        details={"theme": record.theme_name},
    )
    db.commit()

    return redirect(
        "/branding?message=Tema+atualizado+com+sucesso."
    )


@router.post("/branding/logo", response_class=HTMLResponse)
async def save_logo(
    request: Request,
    logo: UploadFile,
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return templates.TemplateResponse(
            request=request,
            name="error.html",
            context={
                **page_context(request, auth),
                "title": "Formulário expirado",
                "error_code": "419",
                "description": "Atualize a página e tente novamente.",
            },
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if not has_permission(auth.user, "branding.manage"):
        return forbidden_page(request, auth)

    data = await logo.read(2 * 1024 * 1024 + 1)

    try:
        record = update_logo(
            db,
            data=data,
            filename=logo.filename or "logo",
            updated_by_user_id=auth.user.id,
        )
    except ValueError as exc:
        db.rollback()
        return templates.TemplateResponse(
            request=request,
            name="branding.html",
            context=page_context(
                request,
                auth,
                error=str(exc),
            ),
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    finally:
        await logo.close()

    record_event(
        db,
        request,
        action="branding.logo.updated",
        description="Logo do Mission Control atualizada.",
        user=auth.user,
        resource_type="branding",
        resource_id=str(record.id),
        details={
            "content_type": record.logo_content_type,
            "filename": record.logo_filename,
            "size": len(data),
        },
    )
    db.commit()

    return redirect(
        "/branding?message=Logo+atualizada+com+sucesso."
    )


@router.post("/branding/logo/remove")
def delete_logo(
    request: Request,
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return redirect("/branding")

    if not has_permission(auth.user, "branding.manage"):
        return forbidden_page(request, auth)

    record = remove_logo(
        db,
        updated_by_user_id=auth.user.id,
    )

    record_event(
        db,
        request,
        action="branding.logo.removed",
        description="Logo personalizada removida.",
        user=auth.user,
        resource_type="branding",
        resource_id=str(record.id),
    )
    db.commit()

    return redirect(
        "/branding?message=Logo+padrão+restaurada."
    )


@router.post("/branding/reset")
def reset_all(
    request: Request,
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return redirect("/branding")

    if not has_permission(auth.user, "branding.manage"):
        return forbidden_page(request, auth)

    record = reset_branding(
        db,
        updated_by_user_id=auth.user.id,
    )

    record_event(
        db,
        request,
        action="branding.reset",
        description="Aparência padrão do Mission Control restaurada.",
        user=auth.user,
        resource_type="branding",
        resource_id=str(record.id),
    )
    db.commit()

    return redirect(
        "/branding?message=Aparência+padrão+restaurada."
    )
