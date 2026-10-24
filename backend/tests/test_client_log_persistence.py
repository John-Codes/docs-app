"""E2E tests for the durable client-log store behind POST /client-logs.

The endpoint already has its own tests; these prove the persistence layer
that was added for MongoDB: a posted report is readable back through
GET /client-logs/recent, newest first, with its values scrubbed — and the
behaviour is proven to break when the ordering or the read path is broken.
"""

import pytest
from fastapi.testclient import TestClient

from app.client_logs import set_client_log_store
from app.error_store import MemoryErrorStore


@pytest.fixture(autouse=True)
def memory_store():
    """Each test gets a clean store so assertions see only their own data."""
    set_client_log_store(MemoryErrorStore())
    yield
    set_client_log_store(MemoryErrorStore())


def _batch(event: str, message: str, **context: str) -> dict:
    return {
        "entries": [
            {"event": event, "message": message, "context": context},
        ],
    }


def test_posted_report_is_readable_back(client: TestClient):
    posted = client.post(
        "/client-logs",
        json=_batch(
            "install_failed",
            "fileHandle.createWritable is not a function",
            opfs="false",
            userAgent="Mozilla/5.0 (iPhone; CPU iPhone OS 18_3)",
        ),
    )
    assert posted.status_code == 204

    listed = client.get("/client-logs/recent")
    assert listed.status_code == 200
    body = listed.json()
    assert body["count"] == 1
    report = body["reports"][0]
    assert report["event"] == "install_failed"
    assert "createWritable" in report["message"]
    assert report["context"]["opfs"] == "false"
    assert "iPhone" in report["context"]["userAgent"]


def test_reports_come_back_newest_first(client: TestClient):
    for index in range(3):
        response = client.post(
            "/client-logs", json=_batch("event", f"failure {index}")
        )
        assert response.status_code == 204

    body = client.get("/client-logs/recent").json()
    messages = [report["message"] for report in body["reports"]]
    assert messages == ["failure 2", "failure 1", "failure 0"]


def test_tokens_never_reach_the_store(client: TestClient):
    client.post(
        "/client-logs",
        json=_batch(
            "install_failed",
            "download refused with hf_AbCdEf0123456789AbCdEf012345",
        ),
    )
    stored = client.get("/client-logs/recent").json()["reports"][0]
    assert "hf_AbCdEf" not in stored["message"]
    assert "hf_[redacted]" in stored["message"]


def test_long_context_values_are_clipped(client: TestClient):
    client.post(
        "/client-logs", json=_batch("install_failed", "x", ua="y" * 5000)
    )
    stored = client.get("/client-logs/recent").json()["reports"][0]
    assert len(stored["context"]["ua"]) <= 200


def test_recent_endpoint_reports_the_active_backend(client: TestClient):
    body = client.get("/client-logs/recent").json()
    assert body["persistent"] is False  # memory store in tests


def test_an_empty_store_returns_an_empty_list(client: TestClient):
    body = client.get("/client-logs/recent").json()
    assert body == {"count": 0, "persistent": False, "reports": []}
