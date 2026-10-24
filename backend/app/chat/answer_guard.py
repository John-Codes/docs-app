"""Enforce the citation contract on every model answer.

The prompt asks the model to cite excerpts, but a prompt is a request, not
an enforcement. A model can still answer a joke, a roleplay request or an
uncited opinion. This guard runs after the model and before the client: any
answer that is not the refusal must cite at least one excerpt that was
actually supplied, otherwise it is replaced with the refusal.
"""

import re

NO_ANSWER = "The documents don't cover that."

_MARKER = re.compile(r"[\[［【〔](\d{1,2})[\]］】〕]")
_REFUSAL = "documents don't cover that"


def _is_refusal(answer: str) -> bool:
    return _REFUSAL in answer.lower()


def _has_valid_citation(answer: str, source_count: int) -> bool:
    return any(1 <= int(number) <= source_count for number in _MARKER.findall(answer))


def guard_answer(answer: str, source_count: int) -> tuple[str, bool]:
    """Return ``(answer, show_sources)`` for an answer to show the user.

    A refusal is kept as written (the model may name what is missing) and
    never carries sources. Any other answer must cite a supplied excerpt;
    an uncited answer is replaced, never forwarded.
    """
    text = answer.strip()
    if not text:
        return NO_ANSWER, False
    if _is_refusal(text):
        return text, False
    if not _has_valid_citation(text, source_count):
        return NO_ANSWER, False
    return text, True
