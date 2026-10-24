import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


@dataclass(frozen=True)
class Settings:
    """Everything the backend needs. No server-side database: the browser
    owns document storage, embeddings and retrieval."""

    openrouter_api_key: str
    chat_provider: str
    chat_model: str
    max_upload_mb: int
    nvidia_api_key: str = ""
    nvidia_base_url: str = "https://integrate.api.nvidia.com/v1"

    # Provider calls are non-streaming, so a slow answer is a failed answer.
    # The read timeout stays well above a normal reply; connection failures
    # get one quick retry, a slow answer does not.
    chat_timeout_seconds: float = 90.0
    chat_attempts: int = 2
    chat_retry_delay_seconds: float = 2.0

    # HuggingFace token for the gated on-device model downloads.
    #
    # Served to the browser by GET /token at runtime. It must never be
    # compiled into the web bundle: that bundle is public, and a token in it
    # is a published token. Optional — the search model is ungated, so the
    # app works without it.
    huggingface_token: str = ""

    # MongoDB connection string for client error reports. Optional: when it
    # is unset the /errors endpoints keep working from an in-memory ring
    # buffer so a browser report is never lost to a missing database.
    mongodb_uri: str = ""
    mongodb_db: str = "docs_app"


def load_settings() -> Settings:
    chat_provider = os.getenv("CHAT_PROVIDER", "nvidia").strip().lower()
    nvidia_api_key = os.getenv("NVIDIA_API_KEY", "")
    if chat_provider == "nvidia" and not nvidia_api_key:
        raise RuntimeError(
            "CHAT_PROVIDER=nvidia requires NVIDIA_API_KEY to be set."
        )

    return Settings(
        openrouter_api_key=os.getenv("OPENROUTER_API_KEY", ""),
        chat_provider=chat_provider,
        chat_model=os.getenv(
            "CHAT_MODEL",
            "nvidia/nemotron-3-ultra-550b-a55b"
            if chat_provider == "nvidia"
            else "anthropic/claude-haiku-5.5",
        ),
        max_upload_mb=int(os.getenv("MAX_UPLOAD_MB", "50")),
        nvidia_api_key=nvidia_api_key,
        nvidia_base_url=os.getenv(
            "NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1"
        ),
        chat_timeout_seconds=float(os.getenv("CHAT_TIMEOUT_SECONDS", "90")),
        chat_attempts=int(os.getenv("CHAT_ATTEMPTS", "2")),
        chat_retry_delay_seconds=float(os.getenv("CHAT_RETRY_DELAY_SECONDS", "2")),
        huggingface_token=os.getenv("HUGGINGFACE_TOKEN", ""),
        mongodb_uri=os.getenv("MONGODB_URI", ""),
        mongodb_db=os.getenv("MONGODB_DB", "docs_app"),
    )
