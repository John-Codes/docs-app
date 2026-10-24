"""Failure reports sent by the browser, for problems only it can see.

Release builds strip the engine's own logs (`kDebugMode` is compiled out), so
a failed on-device model install in production leaves no trace anywhere. The
app posts the failures it catches here; they are scrubbed and written to the
server log stream, and — when ``MONGODB_URI`` is configured — persisted to
MongoDB so reports survive a redeploy and can be analysed in bulk.

Reading back is limited to the newest scrubbed reports: values are clipped,
tokens redacted and no page content is ever stored, so the dump cannot leak
visitor data beyond what a failure already revealed.
"""

import json
import logging
import re

from fastapi import APIRouter, Response
from pydantic import BaseModel, Field

from app.config import load_settings
from app.error_store import ClientErrorStore, MemoryErrorStore

router = APIRouter(prefix="/client-logs", tags=["client-logs"])

# uvicorn only configures its own loggers, so a plain module logger at INFO
# would be dropped. Own the destination: one line per report on stdout, which
# is where Render collects the service log.
logger = logging.getLogger("client_logs")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _stdout_handler = logging.StreamHandler()
    _stdout_handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(_stdout_handler)

_MAX_MESSAGE_CHARS = 500
_MAX_CONTEXT_VALUE_CHARS = 200
_MAX_CONTEXT_KEYS = 24
_MAX_REPORTS_RETURNED = 200

_HUGGINGFACE_TOKEN = re.compile(r"hf_[A-Za-z0-9]{20,}")
_BEARER_HEADER = re.compile(
    r"(?i)bearer\s+[A-Za-z0-9._~+/=-]{10,}"
)

# Replaced by tests; production uses MongoDB when configured.
_store: ClientErrorStore | MemoryErrorStore = MemoryErrorStore()
try:
    if load_settings().mongodb_uri:
        _store = ClientErrorStore(load_settings())
except Exception:  # noqa: BLE001 - a bad URI must not stop the app booting
    pass


class ClientLogEntry(BaseModel):
    event: str = Field(min_length=1, max_length=80)
    message: str = Field(default="", max_length=4000)
    context: dict[str, str] = Field(default_factory=dict)


class ClientLogBatch(BaseModel):
    entries: list[ClientLogEntry] = Field(min_length=1, max_length=20)


def client_log_store() -> ClientErrorStore | MemoryErrorStore:
    """The store the router writes through."""
    return _store


def close_client_log_store() -> None:
    """Release the MongoDB connection pool, if there is one."""
    close = getattr(_store, "close", None)
    if close:
        close()


def set_client_log_store(
    store: ClientErrorStore | MemoryErrorStore,
) -> None:
    """Point the router at a specific store (tests use this)."""
    global _store
    _store = store


def scrub(text: str, limit: int = _MAX_MESSAGE_CHARS) -> str:
    """Removes credentials before anything reaches the server log.

    The app never sends the model token, but an engine exception can quote
    the request it failed on. Redact the token itself and any Authorization
    header that carries it, then shorten the line so one failure cannot
    flood the log.
    """
    without_bearer = _BEARER_HEADER.sub("Bearer [redacted]", text)
    without_token = _HUGGINGFACE_TOKEN.sub("hf_[redacted]", without_bearer)
    return without_token[:limit]


@router.post("", status_code=204)
async def receive_client_logs(batch: ClientLogBatch) -> Response:
    for entry in batch.entries:
        context = {
            key[:40]: scrub(value, _MAX_CONTEXT_VALUE_CHARS)
            for key, value in list(entry.context.items())[:_MAX_CONTEXT_KEYS]
        }
        record = {
            "event": entry.event,
            "message": scrub(entry.message),
            "context": context,
        }
        logger.info("client-log %s", json.dumps(record, ensure_ascii=False))
        await _store.add(record)
    return Response(status_code=204)


@router.get("/recent")
async def recent_client_logs(limit: int = 100) -> dict:
    """The newest scrubbed reports, newest first, for analysis."""
    limit = max(1, min(limit, _MAX_REPORTS_RETURNED))
    reports = await _store.recent(limit)
    return {"count": len(reports), "persistent": _store.persistent, "reports": reports}
