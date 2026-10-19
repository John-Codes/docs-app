from pathlib import Path

FIXTURE_PDF = Path(__file__).parent / "fixtures" / "sample.pdf"


def test_upload_ingests_to_ready(uploaded_doc: dict) -> None:
    assert uploaded_doc["pages"] == 1
    assert uploaded_doc["chunks"] > 0
    assert uploaded_doc["status"] == "ready"


def test_list_documents(client, uploaded_doc: dict) -> None:
    documents = client.get("/documents").json()
    assert [item["id"] for item in documents] == [uploaded_doc["id"]]


def test_file_bytes_round_trip(client, uploaded_doc: dict) -> None:
    response = client.get(f"/documents/{uploaded_doc['id']}/file")
    assert response.status_code == 200
    assert response.content == FIXTURE_PDF.read_bytes()


def test_rejects_non_pdf(client) -> None:
    response = client.post(
        "/documents",
        files={"file": ("notes.txt", b"plain text", "text/plain")},
    )
    assert response.status_code == 400


def test_unknown_document_is_404(client) -> None:
    assert client.get("/documents/00000000-0000-0000-0000-000000000000/status").status_code == 404
    assert client.get("/documents/00000000-0000-0000-0000-000000000000/file").status_code == 404
