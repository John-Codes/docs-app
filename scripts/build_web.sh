#!/usr/bin/env bash
set -euo pipefail

# Build the Flutter web app and place it where the backend serves it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# HuggingFace token for the gated on-device model download. Priority:
# the HUGGINGFACE_TOKEN environment variable, then backend/.env.
HF_TOKEN="${HUGGINGFACE_TOKEN:-}"
if [ -z "$HF_TOKEN" ] && [ -f "$ROOT/backend/.env" ]; then
  HF_TOKEN="$(grep -E '^HUGGINGFACE_TOKEN=' "$ROOT/backend/.env" | tail -1 | cut -d= -f2- | tr -d '"' || true)"
fi

cd "$ROOT/frontend"
flutter pub get
flutter build web --release --dart-define=HUGGINGFACE_TOKEN="$HF_TOKEN"

rm -rf "$ROOT/backend/static"
mkdir -p "$ROOT/backend/static"
cp -R build/web/. "$ROOT/backend/static/"

echo "Flutter web copied to backend/static"
