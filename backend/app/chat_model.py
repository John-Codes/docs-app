import time

import httpx

from app.config import Settings

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MAX_TOKENS = 1200

# A provider that is briefly overloaded answers late instead of failing fast,
# and a single timed-out request used to leave the user with no answer at all.
# One more try rides out that window; permanent errors still fail at once.
_RETRYABLE_STATUS = frozenset({429, 500, 502, 503, 504})


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
    with httpx.Client(timeout=timeout) as client:
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
    return isinstance(failure, (httpx.TimeoutException, httpx.NetworkError))


def chat_completion(settings: Settings, messages: list[dict]) -> str:
    """Ask the configured provider and return the assistant text.

    Sends the same request again once when the provider times out, drops the
    connection or returns 429/5xx. The answer is non-streaming, so a retry is
    the only way to recover without asking the user to resend.
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
        except (httpx.HTTPStatusError, httpx.TimeoutException, httpx.NetworkError) as failure:
            if attempt == attempts or not _is_retryable(failure):
                raise
            time.sleep(settings.chat_retry_delay_seconds)
    raise RuntimeError("chat_completion ran no attempts")
