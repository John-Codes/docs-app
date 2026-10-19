import base64
from uuid import uuid4

from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct

from app.config import Settings
from app.documents.repo import doc_filter
from app.qdrant_schema import DUMMY_VECTOR

PART_BYTES = 2_000_000


def save_file(client: QdrantClient, settings: Settings, doc_id: str, data: bytes) -> None:
    points = []
    for part, start in enumerate(range(0, len(data), PART_BYTES)):
        chunk = data[start : start + PART_BYTES]
        points.append(
            PointStruct(
                id=str(uuid4()),
                vector={DUMMY_VECTOR: [0.0]},
                payload={
                    "doc_id": doc_id,
                    "part": part,
                    "data": base64.b64encode(chunk).decode("ascii"),
                },
            )
        )
    if points:
        client.upsert(
            collection_name=settings.files_collection, points=points, wait=True
        )


def load_file(client: QdrantClient, settings: Settings, doc_id: str) -> bytes:
    records, _ = client.scroll(
        collection_name=settings.files_collection,
        scroll_filter=doc_filter(doc_id),
        limit=1000,
        with_payload=True,
        with_vectors=False,
    )
    ordered = sorted(records, key=lambda item: (item.payload or {}).get("part", 0))
    return b"".join(
        base64.b64decode((record.payload or {})["data"]) for record in ordered
    )
