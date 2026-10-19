import os
import sys
import time
from pathlib import Path

# Tests run against a LOCAL throwaway Qdrant container only.
# See BRANCH_UPDATE_RULES.md rule 8 - never the cloud cluster.
TEST_URL = os.getenv("QDRANT_TEST_URL", "http://localhost:6333")
if "localhost" not in TEST_URL and "127.0.0.1" not in TEST_URL:
    raise RuntimeError("Tests must use a local Qdrant instance, never the cloud cluster.")

os.environ["QDRANT_URL"] = TEST_URL
os.environ["QDRANT_API_KEY"] = os.getenv("QDRANT_TEST_API_KEY", "local-test-key")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

from app.clients import get_qdrant, get_settings
from app.main import app

FIXTURE_PDF = Path(__file__).parent / "fixtures" / "sample.pdf"


@pytest.fixture(scope="session")
def client() -> TestClient:
    settings = get_settings()
    qdrant = get_qdrant()
    for name in (
        settings.chunks_collection,
        settings.files_collection,
        settings.meta_collection,
    ):
        if qdrant.collection_exists(name):
            qdrant.delete_collection(name)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def uploaded_doc(client: TestClient) -> dict:
    with open(FIXTURE_PDF, "rb") as handle:
        response = client.post(
            "/documents",
            files={"file": ("sample.pdf", handle, "application/pdf")},
        )
    assert response.status_code == 200, response.text

    deadline = time.time() + 120
    status = response.json()
    while time.time() < deadline:
        status = client.get(f"/documents/{response.json()['id']}/status").json()
        if status["status"] in ("ready", "failed"):
            break
        time.sleep(2)
    assert status["status"] == "ready", status
    return status
