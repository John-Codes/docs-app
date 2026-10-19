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


def test_chat_refuses_questions_outside_the_documents(client) -> None:
    response = client.post(
        "/chat",
        json={"message": "What is the capital of France?", "history": []},
    )
    assert response.status_code == 200
    answer = response.json()["answer"].lower()
    assert "cover" in answer, answer


def test_chat_rejects_empty_message(client) -> None:
    response = client.post("/chat", json={"message": "   ", "history": []})
    assert response.status_code == 400
