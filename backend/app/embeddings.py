import time

import httpx

from app.config import Settings

OPENROUTER_URL = "https://openrouter.ai/api/v1/embeddings"
BATCH_SIZE = 16
RETRIES = 3
INPUT_TYPES = {
    "search_document": {"openrouter": "search_document", "nvidia": "passage"},
    "search_query": {"openrouter": "search_query", "nvidia": "query"},
}


def _post(url: str, key: str, payload: dict, timeout: float) -> list[list[float]]:
    with httpx.Client(timeout=timeout) as client:
        response = client.post(
            url,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        response.raise_for_status()
        items = sorted(response.json()["data"], key=lambda item: item["index"])
        return [item["embedding"] for item in items]


def _embed_batch(
    settings: Settings, batch: list[str], input_type: str
) -> list[list[float]]:
    providers = [
        (
            "openrouter",
            OPENROUTER_URL,
            settings.openrouter_api_key,
            settings.embedding_model,
            45.0,
        )
    ]
    if settings.nvidia_api_key:
        providers.append(
            (
                "nvidia",
                f"{settings.nvidia_base_url}/embeddings",
                settings.nvidia_api_key,
                settings.nvidia_embedding_model,
                60.0,
            )
        )

    last_error: Exception | None = None
    for provider, url, key, model, timeout in providers:
        for attempt in range(RETRIES):
            try:
                return _post(
                    url,
                    key,
                    {
                        "model": model,
                        "input": batch,
                        "input_type": INPUT_TYPES[input_type][provider],
                    },
                    timeout,
                )
            except Exception as error:  # noqa: BLE001 - try the next provider
                last_error = error
                time.sleep(1.5 * (attempt + 1))
    raise last_error or RuntimeError("Embedding request failed.")


def embed_texts(
    settings: Settings, texts: list[str], input_type: str = "search_document"
) -> list[list[float]]:
    """Embed texts in batches, preferring OpenRouter with a NIM fallback."""
    vectors: list[list[float]] = []
    for start in range(0, len(texts), BATCH_SIZE):
        batch = texts[start : start + BATCH_SIZE]
        vectors.extend(_embed_batch(settings, batch, input_type))
    return vectors
