def test_retrieve_returns_chunks_for_a_document_question(
    client, uploaded_doc: dict
) -> None:
    response = client.post(
        "/retrieve",
        json={"message": "How often must the hydrocyclone be inspected?"},
    )
    assert response.status_code == 200
    chunks = response.json()["chunks"]
    assert chunks, "expected retrieved chunks"
    top = chunks[0]
    assert top["doc_title"] == "sample"
    assert top["page"] == 1
    assert top["score"] > 0
    assert top["text"], "expected chunk text to ground the local answer"


def test_retrieve_rejects_empty_message(client) -> None:
    response = client.post("/retrieve", json={"message": "   "})
    assert response.status_code == 400
