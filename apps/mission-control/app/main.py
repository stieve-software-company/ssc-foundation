from __future__ import annotations

import hmac
import os
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Form, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from app.security import verify_password


BASE_DIR = Path(__file__).resolve().parent
COOKIE_NAME = "ssc_session"
SESSION_MAX_AGE_SECONDS = int(os.getenv("SSC_SESSION_MAX_AGE_SECONDS", "28800"))

ADMIN_USERNAME = os.environ["SSC_ADMIN_USERNAME"]
ADMIN_PASSWORD_HASH = os.environ["SSC_ADMIN_PASSWORD_HASH"]
SESSION_SECRET = os.environ["SSC_SESSION_SECRET"]
COOKIE_SECURE = os.getenv("SSC_COOKIE_SECURE", "false").strip().lower() == "true"

serializer = URLSafeTimedSerializer(
    secret_key=SESSION_SECRET,
    salt="ssc-mission-control-session-v1",
)

app = FastAPI(
    title="SSC Mission Control",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

app.mount(
    "/static",
    StaticFiles(directory=BASE_DIR / "static"),
    name="static",
)

templates = Jinja2Templates(directory=BASE_DIR / "templates")


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


def current_user(request: Request) -> str | None:
    token = request.cookies.get(COOKIE_NAME)

    if not token:
        return None

    try:
        payload: dict[str, Any] = serializer.loads(
            token,
            max_age=SESSION_MAX_AGE_SECONDS,
        )
    except (BadSignature, SignatureExpired):
        return None

    username = payload.get("sub")

    if not isinstance(username, str):
        return None

    if not hmac.compare_digest(username, ADMIN_USERNAME):
        return None

    return username


def login_response(
    request: Request,
    *,
    error: str | None = None,
    status_code: int = status.HTTP_200_OK,
) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="login.html",
        context={
            "error": error,
            "username": ADMIN_USERNAME,
        },
        status_code=status_code,
    )


@app.get("/health", response_class=JSONResponse)
async def health() -> dict[str, str]:
    return {
        "status": "healthy",
        "service": "ssc-mission-control",
        "version": "0.1.0",
    }


@app.get("/", include_in_schema=False)
async def root(request: Request):
    if current_user(request):
        return RedirectResponse("/app", status_code=status.HTTP_303_SEE_OTHER)

    return RedirectResponse("/login", status_code=status.HTTP_303_SEE_OTHER)


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if current_user(request):
        return RedirectResponse("/app", status_code=status.HTTP_303_SEE_OTHER)

    return login_response(request)


@app.post("/login", response_class=HTMLResponse)
async def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
):
    username_valid = hmac.compare_digest(username.strip(), ADMIN_USERNAME)
    password_valid = verify_password(password, ADMIN_PASSWORD_HASH)

    if not (username_valid and password_valid):
        return login_response(
            request,
            error="Usuário ou senha inválidos.",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    token = serializer.dumps({"sub": ADMIN_USERNAME})

    response = RedirectResponse(
        "/app",
        status_code=status.HTTP_303_SEE_OTHER,
    )

    response.set_cookie(
        key=COOKIE_NAME,
        value=token,
        max_age=SESSION_MAX_AGE_SECONDS,
        httponly=True,
        secure=COOKIE_SECURE,
        samesite="strict",
        path="/",
    )

    return response


@app.get("/app", response_class=HTMLResponse)
async def protected_home(request: Request):
    username = current_user(request)

    if not username:
        return RedirectResponse(
            "/login",
            status_code=status.HTTP_303_SEE_OTHER,
        )

    return templates.TemplateResponse(
        request=request,
        name="home.html",
        context={"username": username},
    )


@app.post("/logout")
async def logout():
    response = RedirectResponse(
        "/login",
        status_code=status.HTTP_303_SEE_OTHER,
    )
    response.delete_cookie(
        key=COOKIE_NAME,
        path="/",
    )
    return response
