"""Turn the model's excerpt numbers into short, deduplicated citation markers."""

import re

_MARKER = re.compile(r"[\[［【〔](\d{1,2})[\]］】〕]")
_REPEATED_SPACES = re.compile(r"  +")


def _citation(source: dict, index: int) -> dict:
    return {
        "index": index,
        "doc_id": source["doc_id"],
        "doc_title": source["doc_title"],
        "page": source["page"],
        "score": source["score"],
        "snippet": source["text"][:260].strip(),
    }


def build_citations(sources: list[dict]) -> tuple[list[dict], dict[int, int]]:
    """Deduplicate sources by document and page, and map excerpt numbers to them.

    Returns the citation list (each with a stable 1-based ``index``) plus a
    mapping from each excerpt number to the citation index it belongs to.
    """
    citations: list[dict] = []
    mapping: dict[int, int] = {}
    seen: dict[tuple[str, int], int] = {}

    for excerpt_number, source in enumerate(sources, start=1):
        key = (source["doc_id"], source["page"])
        if key not in seen:
            seen[key] = len(citations) + 1
            citations.append(_citation(source, len(citations) + 1))
        mapping[excerpt_number] = seen[key]

    return citations, mapping


def apply_markers(answer: str, mapping: dict[int, int]) -> str:
    """Rewrite [excerpt] markers to the deduplicated numbering, dropping unknown ones."""

    def replace(match: re.Match[str]) -> str:
        number = int(match.group(1))
        return f"[{mapping[number]}]" if number in mapping else ""

    return _REPEATED_SPACES.sub(" ", _MARKER.sub(replace, answer)).strip()
