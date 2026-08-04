from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class AssistantDecision:
    type: str
    tool: str | None = None
    arguments: dict[str, Any] = field(default_factory=dict)
    content: str | None = None


@dataclass(frozen=True)
class ToolPayload:
    message: str
    component: dict[str, Any] | None = None


@dataclass(frozen=True)
class AssistantResult:
    ok: bool
    message: str
    tool: str | None = None
    component: dict[str, Any] | None = None
    provider: str = "application"
    status_code: int = 200
    error_code: str | None = None
    audit_action: str = "assistant.message.responded"

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "message": self.message,
            "tool": self.tool,
            "component": self.component,
            "provider": self.provider,
            "error_code": self.error_code,
        }
