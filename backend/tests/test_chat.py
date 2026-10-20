import os

import pytest

pytestmark = pytest.mark.skipif(
    not os.getenv("NVIDIA_API_KEY"),
    reason="Chat tests call the real provider and need its key.",
)

SAMPLE_TITLE = "sample"


def _excerpt(text: str, page: int = 0) -> dict:
    return {
        "doc_id": "doc-1",
        "doc_title": SAMPLE_TITLE,
        "page": page,
        "score": 0.9,
        "text": text,
    }


def _ask(client, message: str, excerpts: list[dict]) -> dict:
    response = client.post(
        "/chat",
        json={"message": message, "history": [], "excerpts": excerpts},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_chat_answers_only_from_the_given_excerpts(client, extracted):
    """The whole document knowledge arrives in the request: the backend has
    no database, so an answer grounded in the fixture proves the contract."""
    chunk = extracted["pages"][0]["text"].strip()
    assert chunk, "fixture PDF has no extractable text"
    excerpt = _excerpt(chunk[:1500])

    reply = _ask(client, "In one short sentence, what is this document about?", [excerpt])

    assert reply["answer"]
    assert reply["answer"] != "The documents don't cover that."
    assert reply["sources"], "an answer from excerpts must carry citations"
    assert reply["sources"][0]["doc_title"] == SAMPLE_TITLE


def test_chat_with_no_excerpts_says_documents_do_not_cover_it(client):
    reply = _ask(client, "What is the airspeed velocity of an unladen swallow?", [])
    assert reply["answer"] == "The documents don't cover that."
    assert reply["sources"] == []


def test_chat_rejects_an_empty_message(client):
    response = client.post("/chat", json={"message": "   ", "excerpts": []})
    assert response.status_code == 400
