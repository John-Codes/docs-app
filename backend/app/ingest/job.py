from uuid import uuid4

from qdrant_client.models import PointStruct

from app.clients import get_qdrant
from app.config import Settings
from app.documents import repo
from app.ingest.chunker import chunk_page
from app.ingest.files_repo import save_file
from app.ingest.pdf_text import extract_pages
from app.embeddings import embed_texts

BATCH_SIZE = 32


def collect_chunks(pages: list[str]) -> list[tuple[int, str]]:
    items: list[tuple[int, str]] = []
    for page_number, text in enumerate(pages, start=1):
        items.extend((page_number, chunk) for chunk in chunk_page(text))
    return items


def ingest_document(doc_id: str, data: bytes, title: str, settings: Settings) -> None:
    client = get_qdrant()
    try:
        pages = extract_pages(data)
        items = collect_chunks(pages)
        if not items:
            raise ValueError(
                "No extractable text found. Scanned/image-only PDFs are not supported yet."
            )

        save_file(client, settings, doc_id, data)
        repo.update_meta(client, settings, doc_id, pages=len(pages), chunks=0)

        for start in range(0, len(items), BATCH_SIZE):
            batch = items[start : start + BATCH_SIZE]
            vectors = embed_texts(settings, [text for _, text in batch])
            points = [
                PointStruct(
                    id=str(uuid4()),
                    vector=vector,
                    payload={
                        "doc_id": doc_id,
                        "doc_title": title,
                        "page": page,
                        "text": text,
                        "chunk_index": start + offset,
                    },
                )
                for offset, ((page, text), vector) in enumerate(zip(batch, vectors))
            ]
            client.upsert(
                collection_name=settings.chunks_collection, points=points, wait=True
            )
            repo.update_meta(
                client,
                settings,
                doc_id,
                chunks=min(start + BATCH_SIZE, len(items)),
            )

        repo.update_meta(
            client,
            settings,
            doc_id,
            status="ready",
            chunks=len(items),
            pages=len(pages),
        )
    except Exception as error:  # noqa: BLE001 - surfaced to the UI as status text
        repo.update_meta(client, settings, doc_id, status="failed", error=str(error))
