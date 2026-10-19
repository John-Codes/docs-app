from app.chat.citations import apply_markers, build_citations
from app.chat.prompt import build_messages
from app.clients import get_qdrant, get_settings
from app.chat_model import chat_completion
from app.embeddings import embed_texts


def _source(hit) -> dict:
    payload = hit.payload or {}
    return {
        "doc_id": payload.get("doc_id", ""),
        "doc_title": payload.get("doc_title", "Untitled"),
        "page": int(payload.get("page", 0)),
        "score": round(float(hit.score or 0), 4),
        "text": payload.get("text", "") or "",
    }


def answer_question(question: str, history: list[dict]) -> tuple[str, list[dict]]:
    settings = get_settings()
    query_vector = embed_texts(settings, [question], input_type="search_query")[0]
    hits = get_qdrant().query_points(
        collection_name=settings.chunks_collection,
        query=query_vector,
        limit=settings.chat_top_k,
        with_payload=True,
    ).points

    if not hits:
        return "The documents don't cover that.", []

    sources = [_source(hit) for hit in hits]
    answer = chat_completion(settings, build_messages(question, history, sources))
    if not answer:
        answer = "The documents don't cover that."
    lowered = answer.lower()
    if "documents don't cover that" in lowered or "documents don’t cover that" in lowered:
        return answer, []

    citations, marker_map = build_citations(sources)
    return apply_markers(answer, marker_map), citations
