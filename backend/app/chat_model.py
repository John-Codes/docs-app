import time

import httpx

from app.config import Settings

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MAX_TOKENS = 1200

# Only failures that can clear quickly are worth another try. A read timeout
# means the provider is slow, not briefly unavailable: retrying it just makes
# the user wait twice as long for the same failure.
_RETRYABLE_STATUS = frozenset({429, 500, 502, 503, 504})
_RETRYABLE_FAILURES = (
    httpx.ConnectError,
    httpx.ConnectTimeout,
    httpx.ReadError,
    httpx.WriteError,
    httpx.RemoteProtocolError,
    httpx.PoolTimeout,
)


def _openrouter(settings: Settings, messages: list[dict]) -> tuple[str, str, dict]:
    return (
        OPENROUTER_URL,
        settings.openrouter_api_key,
        {
            "model": settings.chat_model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": MAX_TOKENS,
        },
    )


def _nvidia(settings: Settings, messages: list[dict]) -> tuple[str, str, dict]:
    return (
        f"{settings.nvidia_base_url}/chat/completions",
        settings.nvidia_api_key,
        {
            "model": settings.chat_model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": MAX_TOKENS,
        },
    )


def _post(url: str, key: str, body: dict, timeout: float) -> httpx.Response:
    # Connecting must not eat the whole answer budget; only the reply may wait.
    limits = httpx.Timeout(connect=10, read=timeout, write=10, pool=10)
    with httpx.Client(timeout=limits) as client:
        return client.post(
            url,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json=body,
        )


def _is_retryable(failure: Exception) -> bool:
    if isinstance(failure, httpx.HTTPStatusError):
        return failure.response.status_code in _RETRYABLE_STATUS
    return isinstance(failure, _RETRYABLE_FAILURES)


def chat_completion(settings: Settings, messages: list[dict]) -> str:
    """Ask the configured provider and return the assistant text.

    Sends the same request again once when the connection fails or the
    provider returns 429/5xx. A slow answer is not retried: it would double
    the wait and still fail, so it surfaces to the caller instead.
    """
    url, key, body = (
        _nvidia(settings, messages)
        if settings.chat_provider == "nvidia"
        else _openrouter(settings, messages)
    )
    attempts = max(1, settings.chat_attempts)
    for attempt in range(1, attempts + 1):
        try:
            response = _post(url, key, body, settings.chat_timeout_seconds)
            response.raise_for_status()
            content = response.json()["choices"][0]["message"].get("content")
            return (content or "").strip()
        except (httpx.HTTPStatusError, httpx.TransportError) as failure:
            if attempt == attempts or not _is_retryable(failure):
                raise
            time.sleep(settings.chat_retry_delay_seconds)
    raise RuntimeError("chat_completion ran no attempts")
