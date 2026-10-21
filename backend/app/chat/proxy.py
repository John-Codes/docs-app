from fastapi import APIRouter, HTTPException

from app.chat.answer_guard import NO_ANSWER, guard_answer
from app.chat.citations import apply_markers, build_citations
from app.chat.prompt import build_messages
from app.chat.schemas import ChatRequest, ChatResponse, Excerpt
from app.chat_model import chat_completion
from app.clients import get_settings

router = APIRouter(prefix="/chat", tags=["chat"])


def _source(excerpt: Excerpt) -> dict:
    return {
        "doc_id": excerpt.doc_id,
        "doc_title": excerpt.doc_title,
        "page": excerpt.page,
        "score": excerpt.score,
        "text": excerpt.text,
    }


@router.post("", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    """Answer a question from excerpts the browser retrieved locally.

    No server-side retrieval, embeddings or database: the client owns the
    whole local index. This endpoint only runs the cloud model over the
    excerpts it is given and keeps the citation contract identical.
    """
    question = request.message.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Message is required.")

    sources = [_source(excerpt) for excerpt in request.excerpts if excerpt.text.strip()]
    if not sources:
        return ChatResponse(answer=NO_ANSWER, sources=[])

    history = [
        {"role": turn.role, "content": turn.content}
        for turn in request.history
        if turn.role in ("user", "assistant")
    ][-6:]

    reply = chat_completion(get_settings(), build_messages(question, history, sources))
    answer, show_sources = guard_answer(reply, len(sources))
    if not show_sources:
        return ChatResponse(answer=answer, sources=[])

    citations, marker_map = build_citations(sources)
    return ChatResponse(answer=apply_markers(answer, marker_map), sources=citations)
