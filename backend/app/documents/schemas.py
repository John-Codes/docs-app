from pydantic import BaseModel


class DocumentOut(BaseModel):
    id: str
    title: str
    filename: str = "document.pdf"
    pages: int = 0
    size_bytes: int = 0
    uploaded_at: str
    status: str = "processing"
    chunks: int = 0
    error: str | None = None
