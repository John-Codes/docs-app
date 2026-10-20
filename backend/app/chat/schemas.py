from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: str
    content: str


class Excerpt(BaseModel):
    """One document chunk, retrieved on the device by the local index."""

    doc_id: str
    doc_title: str = "Untitled"
    page: int = 0
    score: float = 0
    text: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = Field(default_factory=list)
    excerpts: list[Excerpt] = Field(default_factory=list)


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
