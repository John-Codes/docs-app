# Docs App

A calm, minimal document reader with a grounded AI chat over your whole
collection. Upload a document, read it, then ask questions — every answer
cites the page it came from and never invents content.

## Stack

- **UI:** Flutter (web first)
- **Backend:** FastAPI (Python)
- **Vectors + file storage:** Qdrant Cloud (free tier)
- **Embeddings + chat:** OpenRouter (`nvidia/llama-nemotron-embed-vl-1b-v2:free`, `anthropic/claude-haiku-5.5` by default)
- **Deploy:** one Render free web service (Docker) serving the API and the Flutter build

## How it works

1. `POST /documents` stores the PDF bytes and metadata in Qdrant, then starts a
   background ingestion job.
2. The job extracts text per page, chunks it with overlap, embeds each chunk
   with OpenRouter, and upserts vectors to the `docs_chunks` collection with
   `doc_id`, `doc_title`, `page`, and `text` payloads.
3. `POST /chat` embeds the question, retrieves the best chunks, and asks the
   chat model to answer **only** from those excerpts with `[Title, p. N]`
   citations. The response includes the source list shown under each answer.

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

## Tests

End-to-end only, against the real API and a **local** Qdrant container — never
the cloud instance (see `BRANCH_UPDATE_RULES.md`).

```bash
scripts/local_stack.sh
cd backend && .venv/bin/pytest -q
```

## Deploy

```bash
scripts/build_web.sh   # builds frontend and copies it to backend/static
```

Push to `main`; Render builds `backend/Dockerfile` and serves the app at the
service URL. Secrets are set in the Render dashboard / `render.yaml`
(`sync: false`) and are never committed.

## Branch rules

All new work follows [`BRANCH_UPDATE_RULES.md`](BRANCH_UPDATE_RULES.md):
small files (<100 lines), one feature per folder, SRP, simple names, e2e tests
against real services, local test DB only.
