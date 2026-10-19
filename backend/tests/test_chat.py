import re


def test_chat_answers_from_document_with_citation(client, uploaded_doc: dict) -> None:
    response = client.post(
        "/chat",
        json={"message": "How often must the hydrocyclone be inspected?", "history": []},
    )
    assert response.status_code == 200
    body = response.json()
    assert "250" in body["answer"]
    assert body["sources"], "expected retrieval sources"
    source = body["sources"][0]
    assert source["doc_title"] == "sample"
    assert source["page"] == 1
    assert source["score"] > 0


def test_chat_citations_use_short_markers(client, uploaded_doc: dict) -> None:
    response = client.post(
        "/chat",
        json={"message": "How often must the hydrocyclone be inspected?", "history": []},
    )
    assert response.status_code == 200
    body = response.json()
    answer = body["answer"]
    sources = body["sources"]

    indexes = [source["index"] for source in sources]
    assert indexes[0] == 1, indexes
    assert indexes == sorted(indexes), indexes
    assert len(set(indexes)) == len(indexes), indexes

    markers = [int(number) for number in re.findall(r"\[(\d+)\]", answer)]
    assert markers, answer
    assert all(1 <= number <= len(sources) for number in markers), markers

    bracketed = re.findall(r"\[([^\]]+)\]", answer)
    assert all(", p. " not in content for content in bracketed), answer
    assert not re.search(r"[【】［］〔〕]", answer), answer


def test_chat_refuses_questions_outside_the_documents(client, uploaded_doc: dict) -> None:
    response = client.post(
        "/chat",
        json={"message": "What is the capital of France?", "history": []},
    )
    assert response.status_code == 200
    body = response.json()
    assert "cover" in body["answer"].lower(), body["answer"]
    assert body["sources"] == []


def test_chat_rejects_empty_message(client) -> None:
    response = client.post("/chat", json={"message": "   ", "history": []})
    assert response.status_code == 400