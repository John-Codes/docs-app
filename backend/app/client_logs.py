"""Failure reports sent by the browser, for problems only it can see.

Release builds strip the engine's own logs (`kDebugMode` is compiled out), so
a failed on-device model install in production leaves no trace anywhere. The
app posts the failures it catches here; they are scrubbed and written to the
server log stream, which is the one durable place we can read them from.

Deliberately write-only: no database, no GET endpoint. A public dump of
visitor error reports would expose their data; reading instead happens in the
server's own log console, where access is already controlled.
"""

import json
import logging
import re

from fastapi import APIRouter, Response
from pydantic import BaseModel, Field

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

_HUGGINGFACE_TOKEN = re.compile(r"hf_[A-Za-z0-9]{20,}")
_BEARER_HEADER = re.compile(
    r"(?i)bearer\s+[A-Za-z0-9._~+/=-]{10,}"
)


class ClientLogEntry(BaseModel):
    event: str = Field(min_length=1, max_length=80)
    message: str = Field(default="", max_length=4000)
    context: dict[str, str] = Field(default_factory=dict)


class ClientLogBatch(BaseModel):
    entries: list[ClientLogEntry] = Field(min_length=1, max_length=20)


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
def receive_client_logs(batch: ClientLogBatch) -> Response:
    for entry in batch.entries:
        context = {
            key[:40]: scrub(value, _MAX_CONTEXT_VALUE_CHARS)
            for key, value in list(entry.context.items())[:_MAX_CONTEXT_KEYS]
        }
        logger.info(
            "client-log %s",
            json.dumps(
                {
                    "event": entry.event,
                    "message": scrub(entry.message),
                    "context": context,
                },
                ensure_ascii=False,
            ),
        )
    return Response(status_code=204)
