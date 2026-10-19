from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.clients import get_qdrant, get_settings
from app.embeddings import embed_texts

router = APIRouter(prefix="/retrieve", tags=["retrieve"])


class RetrieveRequest(BaseModel):
    message: str


class RetrievedChunk(BaseModel):
    doc_id: str
    doc_title: str
    page: int
    score: float
    text: str


class RetrieveResponse(BaseModel):
    chunks: list[RetrievedChunk]


@router.post("", response_model=RetrieveResponse)
def retrieve(request: RetrieveRequest) -> RetrieveResponse:
    """Return the document chunks that best match a question.

    The on-device model answers from these chunks, so local replies can cite
    [Title, p. N] exactly like the cloud chat. The /chat endpoint is
    unchanged: retrieval-only, no model call, no cost.
    """
    question = request.message.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Message is required.")

    settings = get_settings()
    query_vector = embed_texts(settings, [question], input_type="search_query")[0]
    hits = get_qdrant().query_points(
        collection_name=settings.chunks_collection,
        query=query_vector,
        limit=settings.chat_top_k,
        with_payload=True,
    ).points
    return RetrieveResponse(chunks=[RetrievedChunk(**_chunk(hit)) for hit in hits])


def _chunk(hit) -> dict:
    payload = hit.payload or {}
    return {
        "doc_id": payload.get("doc_id", ""),
        "doc_title": payload.get("doc_title", "Untitled"),
        "page": int(payload.get("page", 0)),
        "score": round(float(hit.score or 0), 4),
        "text": payload.get("text", "") or "",
    }
