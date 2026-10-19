from io import BytesIO

from pypdf import PdfReader


def extract_pages(data: bytes) -> list[str]:
    """Return the extracted text of every page, in order."""
    reader = PdfReader(BytesIO(data))
    return [(page.extract_text() or "") for page in reader.pages]
