from __future__ import annotations

import re
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

from email_validator import EmailNotValidError, validate_email
from fastapi import Depends, FastAPI, Form, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.audit import record_event
from app.api.v1.routes import router as api_v1_router
from app.branding.routes import router as branding_router
from app.assistant.routes import router as assistant_router
from app.auth import (
    AuthContext,
    clear_session_cookie,
    csrf_is_valid,
    resolve_auth,
    set_session_cookie,
)
from app.authorization import has_permission, permission_codes
from app.bootstrap import initialize_database
from app.config import settings
from app.database import get_db
from app.models import AuditEvent, Permission, Role, User, utc_now
from app.security import (
    hash_password,
    validate_password_strength,
    verify_password,
)
from app.foundation.collector import (
    get_status_summary,
    start_health_collector,
    stop_health_collector,
)


BASE_DIR = Path(__file__).resolve().parent


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    await start_health_collector()

    try:
        yield
    finally:
        await stop_health_collector()


app = FastAPI(
    title="SSC Mission Control",
    version="0.4.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=lifespan,
)

app.mount(
    "/static",
    StaticFiles(directory=BASE_DIR / "static"),
    name="static",
)

templates = Jinja2Templates(directory=BASE_DIR / "templates")

app.include_router(branding_router)
app.include_router(assistant_router)
app.include_router(api_v1_router)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = (
        "camera=(), microphone=(), geolocation=(), payment=()"
    )
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "style-src 'self'; "
        "img-src 'self' data:; "
        "script-src 'self'; "
        "font-src 'self'; "
        "connect-src 'self'; "
        "form-action 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'"
    )
    return response


def redirect(path: str) -> RedirectResponse:
    return RedirectResponse(path, status_code=status.HTTP_303_SEE_OTHER)


def message_redirect(path: str, message: str) -> RedirectResponse:
    separator = "&" if "?" in path else "?"
    return redirect(f"{path}{separator}message={quote(message)}")


def auth_required(request: Request, db: Session) -> AuthContext | None:
    return resolve_auth(request, db)


def render(
    request: Request,
    template_name: str,
    *,
    auth: AuthContext | None = None,
    active_nav: str = "",
    status_code: int = status.HTTP_200_OK,
    **context,
) -> HTMLResponse:
    base_context = {
        "request": request,
        "current_user": auth.user if auth else None,
        "permission_codes": (
            permission_codes(auth.user) if auth else set()
        ),
        "csrf_token": auth.csrf_token if auth else "",
        "active_nav": active_nav,
        "message": request.query_params.get("message"),
        "environment": settings.environment,
    }
    base_context.update(context)

    return templates.TemplateResponse(
        request=request,
        name=template_name,
        context=base_context,
        status_code=status_code,
    )


def forbidden(request: Request, auth: AuthContext) -> HTMLResponse:
    return render(
        request,
        "error.html",
        auth=auth,
        title="Acesso não autorizado",
        error_code="403",
        description="Seu perfil não possui permissão para esta área.",
        status_code=status.HTTP_403_FORBIDDEN,
    )


def invalid_csrf(request: Request, auth: AuthContext) -> HTMLResponse:
    return render(
        request,
        "error.html",
        auth=auth,
        title="Formulário expirado",
        error_code="419",
        description="Atualize a página e tente novamente.",
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def normalized_email(value: str) -> str:
    validated = validate_email(
        value.strip(),
        check_deliverability=False,
    )
    return validated.normalized.lower()


def clean_optional(value: str) -> str | None:
    cleaned = value.strip()
    return cleaned or None


def valid_username(value: str) -> bool:
    return bool(re.fullmatch(r"[a-zA-Z0-9_.-]{3,64}", value))


def valid_slug(value: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9][a-z0-9-]{2,79}", value))


def active_admin_count(db: Session) -> int:
    return int(
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


def get_role(db: Session, role_id: int) -> Role | None:
    return db.scalar(select(Role).where(Role.id == role_id))


def user_form_context(
    db: Session,
    *,
    user: User | None = None,
    values: dict | None = None,
) -> dict:
    return {
        "edited_user": user,
        "roles": db.scalars(select(Role).order_by(Role.name)).all(),
        "values": values or {},
    }


def role_form_context(
    db: Session,
    *,
    role: Role | None = None,
    values: dict | None = None,
) -> dict:
    permissions = db.scalars(
        select(Permission).order_by(Permission.name)
    ).all()
    selected = (
        {permission.code for permission in role.permissions}
        if role
        else set()
    )

    if values and "permissions" in values:
        selected = set(values["permissions"])

    return {
        "edited_role": role,
        "permissions": permissions,
        "selected_permissions": selected,
        "values": values or {},
    }


@app.get("/health", response_class=JSONResponse)
def health(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1")).scalar_one()
    except Exception:
        return JSONResponse(
            {
                "status": "unhealthy",
                "service": "ssc-mission-control",
                "version": "0.4.0",
                "database": "unavailable",
            },
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    return {
        "status": "healthy",
        "service": "ssc-mission-control",
        "version": "0.4.0",
        "database": "connected",
    }


@app.get("/", include_in_schema=False)
def root(request: Request, db: Session = Depends(get_db)):
    auth = resolve_auth(request, db)
    return redirect("/app" if auth else "/login")


@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request, db: Session = Depends(get_db)):
    if resolve_auth(request, db):
        return redirect("/app")

    return render(request, "login.html")


@app.post("/login", response_class=HTMLResponse)
def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db),
):
    normalized_username = username.strip().lower()

    user = db.scalar(
        select(User).where(
            func.lower(User.username) == normalized_username
        )
    )

    if (
        user is None
        or not user.is_active
        or not verify_password(password, user.password_hash)
    ):
        record_event(
            db,
            request,
            action="auth.login_failed",
            description="Tentativa de login inválida.",
            user=user,
            resource_type="authentication",
            details={"username": normalized_username},
        )
        db.commit()

        return render(
            request,
            "login.html",
            error="Usuário ou senha inválidos.",
            username=normalized_username,
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    user.last_login_at = utc_now()

    record_event(
        db,
        request,
        action="auth.login_success",
        description="Login realizado com sucesso.",
        user=user,
        resource_type="authentication",
        resource_id=str(user.id),
    )
    db.commit()

    destination = "/app"
    if not user.profile_completed:
        destination = "/profile?welcome=1"

    response = redirect(destination)
    set_session_cookie(response, user)
    return response


@app.post("/logout")
def logout(
    request: Request,
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = resolve_auth(request, db)

    if auth and csrf_is_valid(auth, csrf_token):
        record_event(
            db,
            request,
            action="auth.logout",
            description="Sessão encerrada.",
            user=auth.user,
            resource_type="authentication",
            resource_id=str(auth.user.id),
        )
        db.commit()

    response = redirect("/login")
    clear_session_cookie(response)
    return response


@app.get("/app", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "dashboard.view"):
        return forbidden(request, auth)

    stats = {
        "users": db.scalar(select(func.count(User.id))) or 0,
        "active_users": db.scalar(
            select(func.count(User.id)).where(User.is_active.is_(True))
        )
        or 0,
        "roles": db.scalar(select(func.count(Role.id))) or 0,
        "audit_events": db.scalar(select(func.count(AuditEvent.id))) or 0,
    }

    recent_events = db.scalars(
        select(AuditEvent)
        .order_by(AuditEvent.created_at.desc())
        .limit(8)
    ).all()

    service_summary = get_status_summary()
    service_statuses = service_summary["services"]

    return render(
        request,
        "dashboard.html",
        auth=auth,
        active_nav="dashboard",
        stats=stats,
        recent_events=recent_events,
        service_statuses=service_statuses,
    )


@app.get("/profile", response_class=HTMLResponse)
def profile_page(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "profile.edit"):
        return forbidden(request, auth)

    return render(
        request,
        "profile.html",
        auth=auth,
        active_nav="profile",
        welcome=request.query_params.get("welcome") == "1",
    )


@app.post("/profile", response_class=HTMLResponse)
def update_profile(
    request: Request,
    full_name: str = Form(...),
    email: str = Form(...),
    phone: str = Form(""),
    job_title: str = Form(""),
    department: str = Form(""),
    timezone_name: str = Form("America/Sao_Paulo"),
    locale: str = Form("pt-BR"),
    bio: str = Form(""),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "profile.edit"):
        return forbidden(request, auth)

    try:
        email_value = normalized_email(email)
    except EmailNotValidError as exc:
        return render(
            request,
            "profile.html",
            auth=auth,
            active_nav="profile",
            error=str(exc),
        )

    duplicate = db.scalar(
        select(User).where(
            func.lower(User.email) == email_value,
            User.id != auth.user.id,
        )
    )

    if duplicate:
        return render(
            request,
            "profile.html",
            auth=auth,
            active_nav="profile",
            error="Este e-mail já está sendo usado.",
        )

    auth.user.full_name = full_name.strip()
    auth.user.email = email_value
    auth.user.phone = clean_optional(phone)
    auth.user.job_title = clean_optional(job_title)
    auth.user.department = clean_optional(department)
    auth.user.timezone = timezone_name.strip() or "America/Sao_Paulo"
    auth.user.locale = locale.strip() or "pt-BR"
    auth.user.bio = clean_optional(bio)
    auth.user.profile_completed = bool(
        auth.user.full_name and auth.user.email
    )

    record_event(
        db,
        request,
        action="profile.updated",
        description="Perfil pessoal atualizado.",
        user=auth.user,
        resource_type="user",
        resource_id=str(auth.user.id),
    )
    db.commit()

    return message_redirect(
        "/profile",
        "Perfil atualizado com sucesso.",
    )


@app.post("/profile/password")
def update_own_password(
    request: Request,
    current_password: str = Form(...),
    new_password: str = Form(...),
    confirm_password: str = Form(...),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not verify_password(
        current_password,
        auth.user.password_hash,
    ):
        return render(
            request,
            "profile.html",
            auth=auth,
            active_nav="profile",
            password_error="A senha atual está incorreta.",
        )

    if new_password != confirm_password:
        return render(
            request,
            "profile.html",
            auth=auth,
            active_nav="profile",
            password_error="A confirmação da nova senha não confere.",
        )

    strength_error = validate_password_strength(new_password)

    if strength_error:
        return render(
            request,
            "profile.html",
            auth=auth,
            active_nav="profile",
            password_error=strength_error,
        )

    auth.user.password_hash = hash_password(new_password)
    auth.user.password_changed_at = utc_now()
    auth.user.session_version += 1

    record_event(
        db,
        request,
        action="profile.password_changed",
        description="Senha pessoal alterada.",
        user=auth.user,
        resource_type="user",
        resource_id=str(auth.user.id),
    )
    db.commit()

    response = message_redirect(
        "/profile",
        "Senha alterada com sucesso.",
    )
    set_session_cookie(response, auth.user)
    return response


@app.get("/users", response_class=HTMLResponse)
def users_list(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "users.view"):
        return forbidden(request, auth)

    users = db.scalars(
        select(User).order_by(User.created_at.desc())
    ).all()

    return render(
        request,
        "users/list.html",
        auth=auth,
        active_nav="users",
        users=users,
    )


@app.get("/users/new", response_class=HTMLResponse)
def new_user_page(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "users.create"):
        return forbidden(request, auth)

    return render(
        request,
        "users/form.html",
        auth=auth,
        active_nav="users",
        **user_form_context(db),
    )


@app.post("/users/new", response_class=HTMLResponse)
def create_user(
    request: Request,
    username: str = Form(...),
    full_name: str = Form(...),
    email: str = Form(...),
    role_id: int = Form(...),
    password: str = Form(...),
    phone: str = Form(""),
    job_title: str = Form(""),
    department: str = Form(""),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "users.create"):
        return forbidden(request, auth)

    username_value = username.strip().lower()
    values = {
        "username": username_value,
        "full_name": full_name,
        "email": email,
        "role_id": role_id,
        "phone": phone,
        "job_title": job_title,
        "department": department,
    }

    if not valid_username(username_value):
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Usuário inválido. Use letras, números, ponto, hífen ou sublinhado.",
            **user_form_context(db, values=values),
        )

    try:
        email_value = normalized_email(email)
    except EmailNotValidError as exc:
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error=str(exc),
            **user_form_context(db, values=values),
        )

    strength_error = validate_password_strength(password)

    if strength_error:
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error=strength_error,
            **user_form_context(db, values=values),
        )

    role = get_role(db, role_id)

    if not role:
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Perfil de acesso inválido.",
            **user_form_context(db, values=values),
        )

    user = User(
        username=username_value,
        full_name=full_name.strip(),
        email=email_value,
        password_hash=hash_password(password),
        phone=clean_optional(phone),
        job_title=clean_optional(job_title),
        department=clean_optional(department),
        role=role,
        is_active=True,
        profile_completed=True,
    )
    db.add(user)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Usuário ou e-mail já cadastrado.",
            **user_form_context(db, values=values),
        )

    record_event(
        db,
        request,
        action="user.created",
        description=f"Usuário {user.username} criado.",
        user=auth.user,
        resource_type="user",
        resource_id=str(user.id),
        details={"role": role.slug},
    )
    db.commit()

    return message_redirect(
        "/users",
        "Usuário criado com sucesso.",
    )


@app.get("/users/{user_id}/edit", response_class=HTMLResponse)
def edit_user_page(
    user_id: uuid.UUID,
    request: Request,
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "users.edit"):
        return forbidden(request, auth)

    edited_user = db.get(User, user_id)

    if not edited_user:
        return render(
            request,
            "error.html",
            auth=auth,
            title="Usuário não encontrado",
            error_code="404",
            description="O usuário informado não existe.",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    return render(
        request,
        "users/form.html",
        auth=auth,
        active_nav="users",
        **user_form_context(db, user=edited_user),
    )


@app.post("/users/{user_id}/edit", response_class=HTMLResponse)
def edit_user(
    user_id: uuid.UUID,
    request: Request,
    username: str = Form(...),
    full_name: str = Form(...),
    email: str = Form(...),
    role_id: int = Form(...),
    new_password: str = Form(""),
    phone: str = Form(""),
    job_title: str = Form(""),
    department: str = Form(""),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "users.edit"):
        return forbidden(request, auth)

    edited_user = db.get(User, user_id)

    if not edited_user:
        return redirect("/users")

    role = get_role(db, role_id)

    if not role:
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Perfil de acesso inválido.",
            **user_form_context(db, user=edited_user),
        )

    if (
        edited_user.role.slug == "admin"
        and role.slug != "admin"
        and edited_user.is_active
        and active_admin_count(db) <= 1
    ):
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="O último administrador ativo não pode perder esse perfil.",
            **user_form_context(db, user=edited_user),
        )

    username_value = username.strip().lower()

    if not valid_username(username_value):
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Nome de usuário inválido.",
            **user_form_context(db, user=edited_user),
        )

    try:
        email_value = normalized_email(email)
    except EmailNotValidError as exc:
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error=str(exc),
            **user_form_context(db, user=edited_user),
        )

    if new_password:
        strength_error = validate_password_strength(new_password)

        if strength_error:
            return render(
                request,
                "users/form.html",
                auth=auth,
                active_nav="users",
                error=strength_error,
                **user_form_context(db, user=edited_user),
            )

        edited_user.password_hash = hash_password(new_password)
        edited_user.password_changed_at = utc_now()
        edited_user.session_version += 1

    edited_user.username = username_value
    edited_user.full_name = full_name.strip()
    edited_user.email = email_value
    edited_user.phone = clean_optional(phone)
    edited_user.job_title = clean_optional(job_title)
    edited_user.department = clean_optional(department)
    edited_user.role = role
    edited_user.profile_completed = bool(
        edited_user.full_name and edited_user.email
    )

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        return render(
            request,
            "users/form.html",
            auth=auth,
            active_nav="users",
            error="Usuário ou e-mail já cadastrado.",
            **user_form_context(db, user=edited_user),
        )

    record_event(
        db,
        request,
        action="user.updated",
        description=f"Usuário {edited_user.username} atualizado.",
        user=auth.user,
        resource_type="user",
        resource_id=str(edited_user.id),
        details={"role": role.slug},
    )
    db.commit()

    return message_redirect(
        "/users",
        "Usuário atualizado com sucesso.",
    )


@app.post("/users/{user_id}/toggle")
def toggle_user(
    user_id: uuid.UUID,
    request: Request,
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "users.activate"):
        return forbidden(request, auth)

    user = db.get(User, user_id)

    if not user:
        return redirect("/users")

    if user.id == auth.user.id:
        return message_redirect(
            "/users",
            "Você não pode desativar o próprio usuário.",
        )

    if (
        user.is_active
        and user.role.slug == "admin"
        and active_admin_count(db) <= 1
    ):
        return message_redirect(
            "/users",
            "O último administrador ativo não pode ser desativado.",
        )

    user.is_active = not user.is_active
    user.session_version += 1

    action = "user.activated" if user.is_active else "user.deactivated"
    description = (
        f"Usuário {user.username} ativado."
        if user.is_active
        else f"Usuário {user.username} desativado."
    )

    record_event(
        db,
        request,
        action=action,
        description=description,
        user=auth.user,
        resource_type="user",
        resource_id=str(user.id),
    )
    db.commit()

    return message_redirect("/users", description)


@app.get("/roles", response_class=HTMLResponse)
def roles_list(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "roles.view"):
        return forbidden(request, auth)

    roles = db.scalars(
        select(Role).order_by(Role.is_system.desc(), Role.name)
    ).all()

    return render(
        request,
        "roles/list.html",
        auth=auth,
        active_nav="roles",
        roles=roles,
    )


@app.get("/roles/new", response_class=HTMLResponse)
def new_role_page(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "roles.manage"):
        return forbidden(request, auth)

    return render(
        request,
        "roles/form.html",
        auth=auth,
        active_nav="roles",
        **role_form_context(db),
    )


@app.post("/roles/new", response_class=HTMLResponse)
def create_role(
    request: Request,
    name: str = Form(...),
    slug: str = Form(...),
    description: str = Form(""),
    permissions: list[str] = Form(default=[]),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "roles.manage"):
        return forbidden(request, auth)

    slug_value = slug.strip().lower()
    values = {
        "name": name,
        "slug": slug_value,
        "description": description,
        "permissions": permissions,
    }

    if not valid_slug(slug_value):
        return render(
            request,
            "roles/form.html",
            auth=auth,
            active_nav="roles",
            error="Identificador inválido. Use letras minúsculas, números e hífens.",
            **role_form_context(db, values=values),
        )

    selected_permissions = db.scalars(
        select(Permission).where(Permission.code.in_(permissions))
    ).all()

    role = Role(
        name=name.strip(),
        slug=slug_value,
        description=description.strip(),
        is_system=False,
        permissions=list(selected_permissions),
    )
    db.add(role)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        return render(
            request,
            "roles/form.html",
            auth=auth,
            active_nav="roles",
            error="Já existe um perfil com esse identificador.",
            **role_form_context(db, values=values),
        )

    record_event(
        db,
        request,
        action="role.created",
        description=f"Perfil {role.name} criado.",
        user=auth.user,
        resource_type="role",
        resource_id=str(role.id),
        details={"permissions": permissions},
    )
    db.commit()

    return message_redirect(
        "/roles",
        "Perfil criado com sucesso.",
    )


@app.get("/roles/{role_id}/edit", response_class=HTMLResponse)
def edit_role_page(
    role_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "roles.manage"):
        return forbidden(request, auth)

    role = get_role(db, role_id)

    if not role:
        return redirect("/roles")

    return render(
        request,
        "roles/form.html",
        auth=auth,
        active_nav="roles",
        **role_form_context(db, role=role),
    )


@app.post("/roles/{role_id}/edit", response_class=HTMLResponse)
def edit_role(
    role_id: int,
    request: Request,
    name: str = Form(...),
    slug: str = Form(...),
    description: str = Form(""),
    permissions: list[str] = Form(default=[]),
    csrf_token: str = Form(...),
    db: Session = Depends(get_db),
):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not csrf_is_valid(auth, csrf_token):
        return invalid_csrf(request, auth)

    if not has_permission(auth.user, "roles.manage"):
        return forbidden(request, auth)

    role = get_role(db, role_id)

    if not role:
        return redirect("/roles")

    if role.slug == "admin":
        return message_redirect(
            "/roles",
            "O perfil Administrador é protegido.",
        )

    slug_value = role.slug if role.is_system else slug.strip().lower()

    if not valid_slug(slug_value):
        return render(
            request,
            "roles/form.html",
            auth=auth,
            active_nav="roles",
            error="Identificador inválido.",
            **role_form_context(db, role=role),
        )

    selected_permissions = db.scalars(
        select(Permission).where(Permission.code.in_(permissions))
    ).all()

    role.name = name.strip()
    role.slug = slug_value
    role.description = description.strip()
    role.permissions = list(selected_permissions)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        return render(
            request,
            "roles/form.html",
            auth=auth,
            active_nav="roles",
            error="Já existe um perfil com esse identificador.",
            **role_form_context(db, role=role),
        )

    record_event(
        db,
        request,
        action="role.updated",
        description=f"Perfil {role.name} atualizado.",
        user=auth.user,
        resource_type="role",
        resource_id=str(role.id),
        details={"permissions": permissions},
    )
    db.commit()

    return message_redirect(
        "/roles",
        "Perfil atualizado com sucesso.",
    )


@app.get("/audit", response_class=HTMLResponse)
def audit_page(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "audit.view"):
        return forbidden(request, auth)

    events = db.scalars(
        select(AuditEvent)
        .order_by(AuditEvent.created_at.desc())
        .limit(200)
    ).all()

    return render(
        request,
        "audit.html",
        auth=auth,
        active_nav="audit",
        events=events,
    )


@app.get("/system", response_class=HTMLResponse)
def system_page(request: Request, db: Session = Depends(get_db)):
    auth = auth_required(request, db)

    if not auth:
        return redirect("/login")

    if not has_permission(auth.user, "system.view"):
        return forbidden(request, auth)

    service_summary = get_status_summary()
    statuses = service_summary["services"]

    return render(
        request,
        "system.html",
        auth=auth,
        active_nav="system",
        service_statuses=statuses,
    )
