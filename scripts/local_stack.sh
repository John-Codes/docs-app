#!/usr/bin/env bash
set -euo pipefail

# Local backend stack for development and e2e tests.
# There is no server-side database anymore: the browser owns documents,
# embeddings and retrieval (see BRANCH_UPDATE_RULES.md rule 8). The "real
# stack" for e2e is this backend plus the real provider APIs.

cd "$(dirname "$0")/.."

PORT="${PORT:-8001}"
if ! command -v uvicorn >/dev/null; then
  echo "uvicorn not found. Install: pip install -r backend/requirements.txt" >&2
  exit 1
fi

echo "Backend ready at http://localhost:${PORT}"
exec uvicorn app.main:app --app-dir backend --port "${PORT}"
