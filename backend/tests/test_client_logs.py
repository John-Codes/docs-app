import logging

import pytest

TOKEN = "hf_" + "a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6"


def post_entries(client, entries):
    return client.post("/client-logs", json={"entries": entries})


@pytest.fixture
def log_capture(caplog):
    caplog.set_level(logging.INFO, logger="client_logs")
    return caplog


def test_client_logs_write_the_batch_to_the_server_log(client, log_capture):
    response = post_entries(
        client,
        [
            {
                "event": "answer_model_download_failed",
                "message": "Failed to download to OPFS: Error: HTTP 403",
                "context": {"stage": "download", "progress": "0"},
            },
            {
                "event": "local_ai_start_failed",
                "message": "TimeoutException: engine did not start",
            },
        ],
    )

    assert (response.status_code, response.content) == (204, b"")
    logged = log_capture.text
    assert "answer_model_download_failed" in logged
    assert "Failed to download to OPFS: Error: HTTP 403" in logged
    assert "local_ai_start_failed" in logged
    assert '"stage": "download"' in logged
    assert '"progress": "0"' in logged


def test_client_logs_redact_a_huggingface_token(client, log_capture):
    response = post_entries(
        client,
        [{"event": "model_token_failed", "message": f"token={TOKEN} rejected"}],
    )

    assert response.status_code == 204
    assert TOKEN not in log_capture.text
    assert "hf_[redacted]" in log_capture.text


def test_client_logs_redact_an_authorization_header(client, log_capture):
    response = post_entries(
        client,
        [
            {
                "event": "answer_model_download_failed",
                "message": "GET failed with Authorization: Bearer abcdef1234567890xyz",
            }
        ],
    )

    assert response.status_code == 204
    assert "abcdef1234567890xyz" not in log_capture.text
    assert "Bearer [redacted]" in log_capture.text


def test_client_logs_keep_long_failures_short(client, log_capture):
    response = post_entries(
        client,
        [
            {
                "event": "answer_model_download_failed",
                "message": "x" * 4000,
                "context": {"stack": "y" * 1000},
            }
        ],
    )

    assert response.status_code == 204
    assert "x" * 500 in log_capture.text
    assert "x" * 501 not in log_capture.text
    assert "y" * 200 in log_capture.text
    assert "y" * 201 not in log_capture.text


def test_client_logs_reject_more_than_twenty_entries(client):
    entries = [{"event": f"event_{index}"} for index in range(21)]

    response = post_entries(client, entries)

    assert response.status_code == 422


def test_client_logs_require_an_event_name(client):
    response = post_entries(client, [{"message": "no event"}])

    assert response.status_code == 422
