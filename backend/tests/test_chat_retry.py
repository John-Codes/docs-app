import json
import threading
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import httpx
import pytest

from app.chat_model import chat_completion
from app.config import Settings


class _Provider:
    """A real HTTP server that answers like a chat provider."""

    def __init__(self, replies: list[tuple[int, float]]):
        self.replies = replies
        self.requests = 0


def _handler(state: _Provider):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            state.requests += 1
            position = min(state.requests - 1, len(state.replies) - 1)
            status, delay = state.replies[position]
            if delay:
                time.sleep(delay)
            body = json.dumps(
                {"choices": [{"message": {"content": "grounded answer"}}]}
            ).encode()
            try:
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except BrokenPipeError:
                pass

        def log_message(self, *args):
            pass

    return Handler


@contextmanager
def _provider(replies: list[tuple[int, float]]):
    state = _Provider(replies)
    server = ThreadingHTTPServer(("127.0.0.1", 0), _handler(state))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/v1", state
    finally:
        server.shutdown()
        server.server_close()


def _settings(base_url: str, **overrides) -> Settings:
    values = dict(
        openrouter_api_key="",
        chat_provider="nvidia",
        chat_model="test-model",
        max_upload_mb=50,
        nvidia_api_key="test-key",
        nvidia_base_url=base_url,
        chat_timeout_seconds=2,
        chat_attempts=2,
        chat_retry_delay_seconds=0,
    )
    values.update(overrides)
    return Settings(**values)


MESSAGES = [{"role": "user", "content": "hi"}]


def test_a_dropped_answer_is_retried():
    with _provider([(503, 0), (200, 0)]) as (url, state):
        answer = chat_completion(_settings(url), MESSAGES)
    assert answer == "grounded answer"
    assert state.requests == 2


def test_a_timed_out_attempt_is_retried():
    # The exact CI failure: the provider accepts the request but answers late.
    with _provider([(200, 0.5), (200, 0)]) as (url, state):
        answer = chat_completion(_settings(url, chat_timeout_seconds=0.2), MESSAGES)
    assert answer == "grounded answer"
    assert state.requests == 2


def test_a_permanent_error_is_not_retried():
    with _provider([(401, 0), (200, 0)]) as (url, state):
        with pytest.raises(httpx.HTTPStatusError):
            chat_completion(_settings(url), MESSAGES)
    assert state.requests == 1


def test_it_gives_up_after_the_allowed_attempts():
    with _provider([(503, 0)]) as (url, state):
        with pytest.raises(httpx.HTTPStatusError):
            chat_completion(_settings(url), MESSAGES)
    assert state.requests == 2
