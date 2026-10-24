"""E2E tests for the client error log endpoints.

Real HTTP against the real app, no mocks. These prove the observable
behaviour: a report posted by a browser is stored and readable back, an
oversized report is refused, and the reason a download failed arrives with
the device facts that explain it.
"""

import pytest
from fastapi.testclient import TestClient

from app.error_store import ClientErrorStore
from app.errors import set_error_store


@pytest.fixture(autouse=True)
def memory_store():
    """Each test gets a clean store so assertions see only their own data."""
    set_error_store(ClientErrorStore(_Settings(mongodb_uri="", mongodb_db="")))
    yield
    set_error_store(None)


class _Settings:
    def __init__(self, mongodb_uri: str, mongodb_db: str) -> None:
        self.mongodb_uri = mongodb_uri
        self.mongodb_db = mongodb_db


def _iphone_write_failure() -> dict:
    """The exact report this fix exists for: iOS cannot write OPFS files."""
    return {
        "event": "download_failed",
        "stage": "search_model",
        "error": {
            "name": "TypeError",
            "message": "fileHandle.createWritable is not a function",
        },
        "device": {"platform": "iPhone", "osVersion": "18.3"},
        "caps": {"createWritable": False, "syncAccessHandle": True},
        "app": {"code": "capability", "headline": "cannot store the model"},
        "install_id": "install-abc",
        "report_id": "report-001",
    }


def test_posted_report_is_readable_back(client: TestClient):
    posted = client.post("/errors", json=_iphone_write_failure())
    assert posted.status_code == 200
    assert posted.json()["report_id"] == "report-001"

    listed = client.get("/errors/recent")
    assert listed.status_code == 200
    body = listed.json()
    assert body["count"] == 1
    report = body["reports"][0]
    assert report["event"] == "download_failed"
    assert report["stage"] == "search_model"
    assert report["error"]["message"] == "fileHandle.createWritable is not a function"
    assert report["device"]["osVersion"] == "18.3"
    assert report["caps"]["createWritable"] is False
    assert report["install_id"] == "install-abc"


def test_reports_come_back_newest_first(client: TestClient):
    for index in range(3):
        payload = _iphone_write_failure()
        payload["report_id"] = f"report-{index:03d}"
        assert client.post("/errors", json=payload).status_code == 200

    body = client.get("/errors/recent").json()
    ids = [report["report_id"] for report in body["reports"]]
    assert ids == ["report-002", "report-001", "report-000"]


def test_oversized_report_is_refused(client: TestClient):
    payload = _iphone_write_failure()
    payload["error"] = {
        "name": "Huge",
        "message": "x" * 20000,  # well past the 8 KB body cap
    }
    response = client.post("/errors", json=payload)
    assert response.status_code == 413
    assert client.get("/errors/recent").json()["count"] == 0


def test_long_strings_are_clipped_not_stored_whole(client: TestClient):
    payload = _iphone_write_failure()
    payload["device"] = {"ua": "y" * 5000}
    assert client.post("/errors", json=payload).status_code == 200

    stored = client.get("/errors/recent").json()["reports"][0]
    assert len(stored["device"]["ua"]) <= 400


def test_server_fills_in_a_report_id_when_the_client_has_none(client: TestClient):
    payload = _iphone_write_failure()
    payload["report_id"] = ""
    response = client.post("/errors", json=payload)
    assert response.status_code == 200
    assert response.json()["report_id"] != ""


def test_a_report_that_breaks_storage_never_breaks_the_endpoint(
    client: TestClient,
):
    """A bad report body must be rejected as 4xx, never a 500."""
    response = client.post("/errors", json={"event": 12, "stage": None})
    assert 400 <= response.status_code < 500
