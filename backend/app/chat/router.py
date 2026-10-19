from fastapi import APIRouter, HTTPException

from app.chat.rag import answer_question
from app.chat.schemas import ChatRequest, ChatResponse

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    question = request.message.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Message is required.")

    history = [
        {"role": turn.role, "content": turn.content}
        for turn in request.history
        if turn.role in ("user", "assistant")
    ][-6:]

    answer, sources = answer_question(question, history)
    return ChatResponse(answer=answer, sources=sources)
