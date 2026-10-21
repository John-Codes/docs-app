def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_extract_returns_pages_with_text(client, extracted):
    assert extracted["title"] == "sample"
    assert extracted["extractor"] == "server"
    assert len(extracted["pages"]) >= 1
    assert any(page["text"].strip() for page in extracted["pages"])


def test_extract_numbers_pages_from_one(client, extracted):
    assert [page["page"] for page in extracted["pages"]] == list(
        range(1, len(extracted["pages"]) + 1)
    )


def test_extract_rejects_a_non_pdf(client):
    response = client.post(
        "/extract",
        files={"file": ("broken.pdf", b"not a pdf at all", "application/pdf")},
    )
    assert response.status_code == 400


def test_extract_rejects_an_empty_file(client):
    response = client.post(
        "/extract",
        files={"file": ("empty.pdf", b"", "application/pdf")},
    )
    assert response.status_code == 400
