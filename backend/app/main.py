from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.chat.proxy import router as chat_proxy_router
from app.extract import router as extract_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="Docs App", version="2.0.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def cross_origin_isolation(request: Request, call_next):
        """Cross-origin isolation: the on-device SQLite vector store needs
        OPFS persistence and SharedArrayBuffer, which browsers only enable
        when the document is cross-origin isolated."""
        response = await call_next(request)
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return response

    app.include_router(extract_router)
    app.include_router(chat_proxy_router)

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    static_dir = Path(__file__).resolve().parent.parent / "static"
    if static_dir.is_dir():
        app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static")
    return app


app = create_app()
