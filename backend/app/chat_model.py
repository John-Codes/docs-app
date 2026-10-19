import httpx

from app.config import Settings

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MAX_TOKENS = 1200


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


def chat_completion(settings: Settings, messages: list[dict]) -> str:
    """Ask the configured provider and return the assistant text."""
    url, key, body = (
        _nvidia(settings, messages)
        if settings.chat_provider == "nvidia"
        else _openrouter(settings, messages)
    )
    with httpx.Client(timeout=120) as client:
        response = client.post(
            url,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json=body,
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"].get("content")
    return (content or "").strip()
