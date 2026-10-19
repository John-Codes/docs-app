from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = Field(default_factory=list)


class Citation(BaseModel):
    index: int = 0
    doc_id: str
    doc_title: str
    page: int
    score: float
    snippet: str


class ChatResponse(BaseModel):
    answer: str
    sources: list[Citation]
