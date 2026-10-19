from qdrant_client import QdrantClient
from qdrant_client.models import (
    FieldCondition,
    Filter,
    FilterSelector,
    MatchValue,
    PointStruct,
)

from app.config import Settings
from app.qdrant_schema import DUMMY_VECTOR


def doc_filter(doc_id: str) -> Filter:
    return Filter(must=[FieldCondition(key="doc_id", match=MatchValue(value=doc_id))])


def save_meta(
    client: QdrantClient, settings: Settings, doc_id: str, payload: dict
) -> None:
    client.upsert(
        collection_name=settings.meta_collection,
        points=[
            PointStruct(id=doc_id, vector={DUMMY_VECTOR: [0.0]}, payload=payload)
        ],
        wait=True,
    )


def get_meta(client: QdrantClient, settings: Settings, doc_id: str) -> dict | None:
    points = client.retrieve(
        collection_name=settings.meta_collection, ids=[doc_id], with_payload=True
    )
    return dict(points[0].payload or {}) if points else None


def update_meta(
    client: QdrantClient, settings: Settings, doc_id: str, **fields
) -> None:
    payload = get_meta(client, settings, doc_id) or {"id": doc_id}
    payload.update(fields)
    save_meta(client, settings, doc_id, payload)


def list_meta(client: QdrantClient, settings: Settings, limit: int = 100) -> list[dict]:
    records, _ = client.scroll(
        collection_name=settings.meta_collection,
        limit=limit,
        with_payload=True,
        with_vectors=False,
    )
    documents = [dict(record.payload or {}) for record in records]
    return sorted(
        documents, key=lambda item: item.get("uploaded_at", ""), reverse=True
    )


def delete_document(client: QdrantClient, settings: Settings, doc_id: str) -> None:
    for collection in (settings.chunks_collection, settings.files_collection):
        client.delete(
            collection_name=collection,
            points_selector=FilterSelector(filter=doc_filter(doc_id)),
            wait=True,
        )
    client.delete(
        collection_name=settings.meta_collection,
        points_selector=[doc_id],
        wait=True,
    )
