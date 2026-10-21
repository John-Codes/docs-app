from fastapi import APIRouter

from app.config import load_settings

router = APIRouter(prefix="/token", tags=["token"])


@router.get("")
def model_token() -> dict:
    """The HuggingFace token the browser needs for gated model downloads.

    Served at runtime instead of being compiled into the web bundle, which
    is public: a token baked into it would be a published token. An empty
    string means "not configured" — the search model is ungated, so the app
    stays usable, and the caller decides whether to say so.
    """
    return {"token": load_settings().huggingface_token}
