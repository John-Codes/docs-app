from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.ingest.pdf_text import extract_pages

router = APIRouter(prefix="/extract", tags=["extract"])


class ExtractedPage(BaseModel):
    page: int
    text: str


class ExtractResponse(BaseModel):
    title: str
    pages: list[ExtractedPage]
    extractor: str = "server"


@router.post("", response_model=ExtractResponse)
async def extract(file: UploadFile = File(...)) -> ExtractResponse:
    """Extract per-page text from a PDF. Stateless: nothing is stored.

    The browser keeps the PDF and its chunks locally and retrieves from
    them; this endpoint only turns bytes into text. Documents extracted
    on-device while offline are re-run through here when the network
    returns, because this parser is the better one.
    """
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="The file is empty.")
    try:
        pages = extract_pages(data)
    except Exception as error:  # noqa: BLE001 - any parse failure is a client error
        raise HTTPException(
            status_code=400, detail=f"Could not read the PDF: {error}"
        ) from error

    name = file.filename or "Untitled"
    title = name.rsplit(".", 1)[0].strip() or "Untitled"
    return ExtractResponse(
        title=title,
        pages=[
            ExtractedPage(page=index + 1, text=text)
            for index, text in enumerate(pages)
        ],
    )
