#!/usr/bin/env bash
set -euo pipefail

# Local throwaway Qdrant for development and e2e tests.
# Never point tests at the Qdrant Cloud cluster (see BRANCH_UPDATE_RULES.md).
NAME="docs-app-qdrant"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker run -d --name "$NAME" -p 6333:6333 -p 6334:6334 qdrant/qdrant:latest >/dev/null
elif ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
fi

echo "Qdrant is ready at http://localhost:6333"
