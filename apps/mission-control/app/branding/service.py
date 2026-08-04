from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import BrandingSettings, utc_now


HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")

DEFAULT_THEME = {
    "theme_name": "midnight",
    "background": "#070a12",
    "surface": "#111726",
    "surface_soft": "#171f33",
    "accent": "#7c8cff",
    "accent_strong": "#9f7aea",
    "text": "#f5f7ff",
    "muted": "#9aa5bd",
}

THEMES: dict[str, dict[str, str]] = {
    "midnight": {
        **DEFAULT_THEME,
        "label": "Midnight",
    },
    "ocean": {
        "theme_name": "ocean",
        "label": "Ocean",
        "background": "#04151f",
        "surface": "#0b2634",
        "surface_soft": "#113747",
        "accent": "#2dd4bf",
        "accent_strong": "#38bdf8",
        "text": "#ecfeff",
        "muted": "#9fb6bf",
    },
    "forest": {
        "theme_name": "forest",
        "label": "Forest",
        "background": "#06130d",
        "surface": "#10261b",
        "surface_soft": "#173727",
        "accent": "#4ade80",
        "accent_strong": "#a3e635",
        "text": "#f0fdf4",
        "muted": "#a5b7aa",
    },
    "ember": {
        "theme_name": "ember",
        "label": "Ember",
        "background": "#180b08",
        "surface": "#2a1510",
        "surface_soft": "#3a2118",
        "accent": "#fb923c",
        "accent_strong": "#f43f5e",
        "text": "#fff7ed",
        "muted": "#c4aaa0",
    },
    "slate": {
        "theme_name": "slate",
        "label": "Slate",
        "background": "#0b0f14",
        "surface": "#151b23",
        "surface_soft": "#202936",
        "accent": "#60a5fa",
        "accent_strong": "#a78bfa",
        "text": "#f8fafc",
        "muted": "#a4adbb",
    },
}


@dataclass(frozen=True)
class BrandingView:
    theme_name: str
    background: str
    surface: str
    surface_soft: str
    accent: str
    accent_strong: str
    text: str
    muted: str
    has_logo: bool
    logo_filename: str | None
    logo_content_type: str | None


def default_view() -> BrandingView:
    return BrandingView(
        **DEFAULT_THEME,
        has_logo=False,
        logo_filename=None,
        logo_content_type=None,
    )


def get_record(db: Session) -> BrandingSettings | None:
    return db.scalar(
        select(BrandingSettings).where(BrandingSettings.id == 1)
    )


def ensure_record(db: Session) -> BrandingSettings:
    record = get_record(db)

    if record is not None:
        return record

    record = BrandingSettings(
        id=1,
        **DEFAULT_THEME,
    )
    db.add(record)
    db.flush()
    return record


def to_view(record: BrandingSettings | None) -> BrandingView:
    if record is None:
        return default_view()

    return BrandingView(
        theme_name=record.theme_name,
        background=record.background,
        surface=record.surface,
        surface_soft=record.surface_soft,
        accent=record.accent,
        accent_strong=record.accent_strong,
        text=record.text,
        muted=record.muted,
        has_logo=bool(record.logo_data),
        logo_filename=record.logo_filename,
        logo_content_type=record.logo_content_type,
    )


def current_view(db: Session) -> BrandingView:
    return to_view(get_record(db))


def validate_color(value: str, field_name: str) -> str:
    cleaned = value.strip().lower()

    if not HEX_COLOR.fullmatch(cleaned):
        raise ValueError(
            f"A cor de {field_name} precisa usar o formato #RRGGBB."
        )

    return cleaned


def relative_luminance(value: str) -> float:
    color = value.lstrip("#")
    channels = [
        int(color[index:index + 2], 16) / 255
        for index in (0, 2, 4)
    ]

    converted = [
        channel / 12.92
        if channel <= 0.04045
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in channels
    ]

    return (
        0.2126 * converted[0]
        + 0.7152 * converted[1]
        + 0.0722 * converted[2]
    )


def update_theme(
    db: Session,
    *,
    theme_name: str,
    custom_values: dict[str, Any],
    updated_by_user_id,
) -> BrandingSettings:
    selected = theme_name.strip().lower()

    if selected == "custom":
        background = validate_color(
            str(custom_values.get("background", "")),
            "fundo",
        )
        surface = validate_color(
            str(custom_values.get("surface", "")),
            "superfície",
        )
        surface_soft = validate_color(
            str(custom_values.get("surface_soft", "")),
            "superfície secundária",
        )
        accent = validate_color(
            str(custom_values.get("accent", "")),
            "destaque",
        )
        accent_strong = validate_color(
            str(custom_values.get("accent_strong", "")),
            "destaque secundário",
        )

        if relative_luminance(background) > 0.25:
            raise ValueError(
                "A cor de fundo precisa ser escura para manter a leitura."
            )

        if relative_luminance(surface) > 0.35:
            raise ValueError(
                "A cor da superfície precisa ser escura."
            )

        selected_values = {
            "theme_name": "custom",
            "background": background,
            "surface": surface,
            "surface_soft": surface_soft,
            "accent": accent,
            "accent_strong": accent_strong,
            "text": "#f8fafc",
            "muted": "#a7b0bf",
        }
    else:
        selected_values = THEMES.get(selected)

        if selected_values is None:
            raise ValueError("Tema selecionado é inválido.")

    record = ensure_record(db)

    for key in (
        "theme_name",
        "background",
        "surface",
        "surface_soft",
        "accent",
        "accent_strong",
        "text",
        "muted",
    ):
        setattr(record, key, selected_values[key])

    record.updated_by_user_id = updated_by_user_id
    record.updated_at = utc_now()
    db.flush()
    return record


def detect_image_type(data: bytes) -> str | None:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"

    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"

    if (
        len(data) >= 12
        and data[:4] == b"RIFF"
        and data[8:12] == b"WEBP"
    ):
        return "image/webp"

    return None


def update_logo(
    db: Session,
    *,
    data: bytes,
    filename: str,
    updated_by_user_id,
) -> BrandingSettings:
    if not data:
        raise ValueError("Selecione uma imagem.")

    if len(data) > 2 * 1024 * 1024:
        raise ValueError("A logo deve ter no máximo 2 MB.")

    detected = detect_image_type(data)

    if detected is None:
        raise ValueError(
            "Formato inválido. Use PNG, JPEG ou WebP."
        )

    safe_filename = filename.strip()[:255] or "logo"

    record = ensure_record(db)
    record.logo_data = data
    record.logo_content_type = detected
    record.logo_filename = safe_filename
    record.logo_updated_at = utc_now()
    record.updated_at = utc_now()
    record.updated_by_user_id = updated_by_user_id
    db.flush()
    return record


def remove_logo(
    db: Session,
    *,
    updated_by_user_id,
) -> BrandingSettings:
    record = ensure_record(db)
    record.logo_data = None
    record.logo_content_type = None
    record.logo_filename = None
    record.logo_updated_at = utc_now()
    record.updated_at = utc_now()
    record.updated_by_user_id = updated_by_user_id
    db.flush()
    return record


def reset_branding(
    db: Session,
    *,
    updated_by_user_id,
) -> BrandingSettings:
    record = ensure_record(db)

    for key, value in DEFAULT_THEME.items():
        setattr(record, key, value)

    record.logo_data = None
    record.logo_content_type = None
    record.logo_filename = None
    record.logo_updated_at = utc_now()
    record.updated_at = utc_now()
    record.updated_by_user_id = updated_by_user_id
    db.flush()
    return record


def css_for(view: BrandingView) -> str:
    lines = [
        ":root {",
        f"  --background: {view.background};",
        f"  --surface: color-mix(in srgb, {view.surface} 88%, transparent);",
        f"  --surface-strong: {view.surface};",
        f"  --surface-soft: {view.surface_soft};",
        f"  --text: {view.text};",
        f"  --muted: {view.muted};",
        f"  --accent: {view.accent};",
        f"  --accent-strong: {view.accent_strong};",
        "}",
        "",
    ]
    return "\n".join(lines)


DEFAULT_LOGO_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">'
    '<rect width="256" height="256" rx="64" fill="#111726"/>'
    '<path d="M32 128c0-53 43-96 96-96s96 43 96 96-43 96-96 96-96-43-96-96z" '
    'fill="#7c8cff" opacity=".18"/>'
    '<text x="128" y="147" text-anchor="middle" '
    'font-family="Arial,sans-serif" font-size="64" font-weight="800" '
    'fill="#f5f7ff">SSC</text></svg>'
).encode("utf-8")
