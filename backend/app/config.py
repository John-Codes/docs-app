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
            "openai/gpt-oss-20b"
            if chat_provider == "nvidia"
            else "anthropic/claude-haiku-5.5",
        ),
        max_upload_mb=int(os.getenv("MAX_UPLOAD_MB", "50")),
        nvidia_api_key=nvidia_api_key,
        nvidia_base_url=os.getenv(
            "NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1"
        ),
    )
