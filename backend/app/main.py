from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.chat.router import router as chat_router
from app.clients import get_qdrant, get_settings
from app.documents.router import router as documents_router
from app.qdrant_schema import ensure_schema


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        ensure_schema(get_settings(), get_qdrant())
    except Exception as error:  # noqa: BLE001 - the app should still boot
        print(f"Qdrant schema check failed: {error}")
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="Docs App", version="1.0.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(documents_router)
    app.include_router(chat_router)

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    static_dir = Path(__file__).resolve().parent.parent / "static"
    if static_dir.is_dir():
        app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static")
    return app


app = create_app()
