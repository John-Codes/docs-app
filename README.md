# Docs App

A calm, minimal document reader with a grounded AI chat over your whole
collection. Upload a document, read it, then ask questions — every answer
cites the page it came from and never invents content.

**Live:** https://docs-app-e834.onrender.com

## Stack

- **UI:** Flutter (web first)
- **Backend:** FastAPI (Python)
- **Vectors + file storage:** Qdrant Cloud (free tier)
- **Embeddings:** OpenRouter, `nvidia/llama-nemotron-embed-vl-1b-v2:free`
  (2048-dim), with an automatic NVIDIA NIM fallback that serves the same model
- **Chat:** NVIDIA NIM, `nvidia/nemotron-3-ultra-550b-a55b` by default (OpenRouter also supported). Answers that do not cite a supplied excerpt are replaced with the refusal before they reach the client.
- **Deploy:** one Render free web service (Docker) serving the API and the
  Flutter build

## How it works

1. `POST /documents` stores the PDF bytes and metadata in Qdrant, then starts a
   background ingestion job.
2. The job extracts text per page, chunks it with overlap, embeds each chunk,
   and upserts vectors to `docs_chunks` with `doc_id`, `doc_title`, `page`, and
   `text` payloads.
3. `POST /chat` embeds the question, retrieves the best chunks, and asks the
   chat model to answer **only** from those excerpts with `[Title, p. N]`
   citations. Excerpt numbers the model may emit are rewritten to that form,
   and the response includes the source list shown under each answer.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/documents` | Upload a PDF and start indexing |
| `GET` | `/documents` | List documents |
| `GET` | `/documents/{id}/status` | Indexing progress and failure reason |
| `GET` | `/documents/{id}/file` | Stream the original PDF (supports `#page=N`) |
| `DELETE` | `/documents/{id}` | Remove a document, its vectors and its bytes |
| `POST` | `/chat` | Grounded answer plus cited sources |
| `GET` | `/health` | Liveness check |

## Local development

```bash
# 1. Local Qdrant (throwaway container for tests/dev)
scripts/local_stack.sh

# 2. Backend
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env   # then fill in the real keys
.venv/bin/uvicorn app.main:app --reload --port 8000

# 3. Flutter web (dev)
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

## Environment variables

Set in `backend/.env` locally and in the Render service in production. Secrets
are never committed.

| Key | Notes |
| --- | --- |
| `OPENROUTER_API_KEY` | Embeddings |
| `QDRANT_URL`, `QDRANT_API_KEY` | Qdrant Cloud cluster |
| `EMBEDDING_MODEL`, `EMBEDDING_DIMENSIONS` | Defaults: nemotron VL embed, `2048` |
| `CHAT_PROVIDER` | `nvidia` (default) or `openrouter` |
| `CHAT_MODEL` | Default: `nvidia/nemotron-3-ultra-550b-a55b` |
| `NVIDIA_API_KEY`, `NVIDIA_BASE_URL` | Required when `CHAT_PROVIDER=nvidia` |
| `CHAT_TOP_K` | Retrieved passages per question (default `8`) |
| `MAX_UPLOAD_MB` | Upload guard for the 512 MB instance (default `50`) |

## Tests

End-to-end only, against the real API and a **local** Qdrant container — never
the cloud cluster (see `BRANCH_UPDATE_RULES.md`).

```bash
scripts/local_stack.sh
cd backend && .venv/bin/pytest -q
```

CI runs the same suite on `main` and same-repo pull requests, with a throwaway
Qdrant service container. Fork PRs skip the steps that need repo secrets.

## Deploy

```bash
scripts/build_web.sh   # build the Flutter web app into backend/static
git push origin main
```

Render builds `backend/Dockerfile` and serves the API plus `backend/static` at
the service URL. `render.yaml` documents the service and the expected
environment variables.

## Branch rules

All new work follows [`BRANCH_UPDATE_RULES.md`](BRANCH_UPDATE_RULES.md):
small files (<100 lines), one feature per folder, SRP, simple names, e2e tests
against real services, local test DB only.
