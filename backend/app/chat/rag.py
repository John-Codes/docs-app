import re

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


def _citation(source: dict) -> dict:
    return {
        "doc_id": source["doc_id"],
        "doc_title": source["doc_title"],
        "page": source["page"],
        "score": source["score"],
        "snippet": source["text"][:260].strip(),
    }


_NUMBERED = re.compile(r"\[(\d+)\]")


def _normalize_citations(answer: str, sources: list[dict]) -> str:
    """Turn excerpt numbers the model may emit into [Title, p. N]."""

    def replace(match: re.Match[str]) -> str:
        index = int(match.group(1))
        if 1 <= index <= len(sources):
            source = sources[index - 1]
            return f"[{source['doc_title']}, p. {source['page']}]"
        return match.group(0)

    return _NUMBERED.sub(replace, answer)


def _unique_citations(sources: list[dict]) -> list[dict]:
    seen: set[tuple[str, int]] = set()
    citations = []
    for source in sources:
        key = (source["doc_id"], source["page"])
        if key in seen:
            continue
        seen.add(key)
        citations.append(_citation(source))
    return citations


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
    return _normalize_citations(answer, sources), _unique_citations(sources)
