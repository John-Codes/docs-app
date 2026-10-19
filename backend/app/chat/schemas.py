from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = Field(default_factory=list)


class Citation(BaseModel):
    doc_id: str
    doc_title: str
    page: int
    score: float
    snippet: str


class ChatResponse(BaseModel):
    answer: str
    sources: list[Citation]
