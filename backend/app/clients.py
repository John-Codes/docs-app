from functools import lru_cache

from qdrant_client import QdrantClient

from app.config import Settings, load_settings


@lru_cache
def get_settings() -> Settings:
    return load_settings()


@lru_cache
def get_qdrant() -> QdrantClient:
    settings = get_settings()
    return QdrantClient(
        url=settings.qdrant_url,
        api_key=settings.qdrant_api_key,
        timeout=90,
    )
