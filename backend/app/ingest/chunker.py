import re


def clean_text(text: str) -> str:
    return re.sub(r"[ \t]+", " ", text).strip()


def chunk_page(text: str, max_chars: int = 1100, overlap: int = 150) -> list[str]:
    """Split one page into overlapping chunks that end on word boundaries."""
    text = clean_text(text)
    if not text:
        return []

    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        if end < len(text):
            cut = text.rfind(" ", start + max_chars // 2, end)
            if cut > start:
                end = cut
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= len(text):
            break
        start = max(end - overlap, start + 1)
    return chunks
