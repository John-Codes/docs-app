import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def _required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


@dataclass(frozen=True)
class Settings:
    openrouter_api_key: str
    qdrant_url: str
    qdrant_api_key: str
    embedding_model: str
    embedding_dimensions: int
    nvidia_embedding_model: str
    chat_provider: str
    chat_model: str
    chat_top_k: int
    max_upload_mb: int
    nvidia_api_key: str = ""
    nvidia_base_url: str = "https://integrate.api.nvidia.com/v1"
    chunks_collection: str = "docs_chunks"
    files_collection: str = "docs_files"
    meta_collection: str = "docs_meta"


def load_settings() -> Settings:
    chat_provider = os.getenv("CHAT_PROVIDER", "nvidia").strip().lower()
    nvidia_api_key = os.getenv("NVIDIA_API_KEY", "")
    if chat_provider == "nvidia" and not nvidia_api_key:
        raise RuntimeError(
            "CHAT_PROVIDER=nvidia requires NVIDIA_API_KEY to be set."
        )

    return Settings(
        openrouter_api_key=_required("OPENROUTER_API_KEY"),
        qdrant_url=_required("QDRANT_URL"),
        qdrant_api_key=_required("QDRANT_API_KEY"),
        embedding_model=os.getenv(
            "EMBEDDING_MODEL", "nvidia/llama-nemotron-embed-vl-1b-v2:free"
        ),
        embedding_dimensions=int(os.getenv("EMBEDDING_DIMENSIONS", "2048")),
        nvidia_embedding_model=os.getenv(
            "NVIDIA_EMBEDDING_MODEL", "nvidia/llama-nemotron-embed-vl-1b-v2"
        ),
        chat_provider=chat_provider,
        chat_model=os.getenv(
            "CHAT_MODEL",
            "openai/gpt-oss-20b" if chat_provider == "nvidia" else "anthropic/claude-haiku-5.5",
        ),
        chat_top_k=int(os.getenv("CHAT_TOP_K", "8")),
        max_upload_mb=int(os.getenv("MAX_UPLOAD_MB", "50")),
        nvidia_api_key=nvidia_api_key,
        nvidia_base_url=os.getenv(
            "NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1"
        ),
    )
