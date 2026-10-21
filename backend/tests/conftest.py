import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

from app.main import app

FIXTURE_PDF = Path(__file__).parent / "fixtures" / "sample.pdf"


@pytest.fixture(scope="session")
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def extracted(client: TestClient) -> dict:
    """The fixture PDF run through the real /extract endpoint."""
    with open(FIXTURE_PDF, "rb") as handle:
        response = client.post(
            "/extract",
            files={"file": ("sample.pdf", handle, "application/pdf")},
        )
    assert response.status_code == 200, response.text
    return response.json()
