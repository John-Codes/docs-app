#!/usr/bin/env bash
set -euo pipefail

# Build the Flutter web app and place it where the backend serves it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT/frontend"
flutter pub get
flutter build web --release

rm -rf "$ROOT/backend/static"
mkdir -p "$ROOT/backend/static"
cp -R build/web/. "$ROOT/backend/static/"

echo "Flutter web copied to backend/static"
