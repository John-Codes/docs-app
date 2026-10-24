"""Receive and review client error reports from the browser.

Kept deliberately small: only the exception summary and the device facts a
developer needs to reproduce a problem. No PDF text, no chat content, no
tokens, no signed model URLs — the browser is told to strip those before it
posts anything.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.config import load_settings
from app.error_store import ClientErrorStore

router = APIRouter(prefix="/errors", tags=["errors"])

_MAX_TEXT = 400
_MAX_STACK = 800
_MAX_BODY_BYTES = 8192

_store: ClientErrorStore | None = None


def error_store() -> ClientErrorStore:
    """Lazily create the store so tests can point it at anything."""
    global _store
    if _store is None:
        _store = ClientErrorStore(load_settings())
    return _store


def set_error_store(store: ClientErrorStore | None) -> None:
    """Replace the store (tests use this instead of a real MongoDB)."""
    global _store
    _store = store


class _ErrorDetail(BaseModel):
    name: str = ""
    message: str = ""
    stack: str = ""


class ClientErrorReport(BaseModel):
    """The one small object the browser sends when something breaks."""

    event: str = ""
    stage: str = ""
    error: _ErrorDetail = Field(default_factory=_ErrorDetail)
    device: dict = Field(default_factory=dict)
    caps: dict = Field(default_factory=dict)
    app: dict = Field(default_factory=dict)
    install_id: str = ""
    report_id: str = ""


def _clip(value: object, limit: int) -> str:
    """Shorten a client-supplied string; anything long is suspect."""
    text = str(value or "")
    return text[:limit]


def _clip_map(raw: dict, limit: int = _MAX_TEXT) -> dict:
    """Keep only flat string/number/boolean keys, each shortened."""
    out: dict = {}
    for key, value in list(raw.items())[:40]:
        name = _clip(key, 60)
        if isinstance(value, bool) or isinstance(value, (int, float)):
            out[name] = value
        else:
            out[name] = _clip(value, limit)
    return out


@router.post("")
async def report_error(report: ClientErrorReport, request: Request) -> dict:
    """Store one client error report and hand back its id."""
    body = await request.body()
    if len(body) > _MAX_BODY_BYTES:
        raise HTTPException(413, "Report too large.")

    record = {
        "event": _clip(report.event, 80),
        "stage": _clip(report.stage, 80),
        "error": {
            "name": _clip(report.error.name, 80),
            "message": _clip(report.error.message, _MAX_TEXT),
            "stack": _clip(report.error.stack, _MAX_STACK),
        },
        "device": _clip_map(report.device),
        "caps": _clip_map(report.caps),
        "app": _clip_map(report.app),
        "install_id": _clip(report.install_id, 64),
        "report_id": _clip(report.report_id, 64) or uuid.uuid4().hex[:12],
        "client_ip": request.client.host if request.client else "",
        "user_agent": _clip(request.headers.get("user-agent", ""), _MAX_TEXT),
    }
    stored = await error_store().add(record)
    return {"ok": True, "report_id": stored["report_id"]}


@router.get("/recent")
async def recent_errors(limit: int = 200) -> dict:
    """The newest reports, newest first. For a human reading the list."""
    limit = max(1, min(limit, 500))
    reports = await error_store().recent(limit)
    return {"count": len(reports), "persistent": error_store().persistent, "reports": reports}
