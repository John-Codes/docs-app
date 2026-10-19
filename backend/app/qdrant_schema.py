from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PayloadSchemaType, VectorParams

from app.config import Settings

DUMMY_VECTOR = "dummy"


def _create_if_missing(client: QdrantClient, name: str, vectors) -> None:
    if not client.collection_exists(name):
        client.create_collection(collection_name=name, vectors_config=vectors)


def _index(client: QdrantClient, collection: str, field: str) -> None:
    try:
        client.create_payload_index(collection, field, PayloadSchemaType.KEYWORD)
    except Exception:
        pass


def ensure_schema(settings: Settings, client: QdrantClient) -> None:
    _create_if_missing(
        client,
        settings.chunks_collection,
        VectorParams(size=settings.embedding_dimensions, distance=Distance.COSINE),
    )
    dummy = {DUMMY_VECTOR: VectorParams(size=1, distance=Distance.COSINE)}
    _create_if_missing(client, settings.files_collection, dummy)
    _create_if_missing(client, settings.meta_collection, dummy)
    for collection in (settings.chunks_collection, settings.files_collection):
        _index(client, collection, "doc_id")
