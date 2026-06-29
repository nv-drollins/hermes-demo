#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

docker compose --env-file "$ROOT/inference/.env" -f "$ROOT/inference/compose.yaml" up -d
"$DIR/reset-learning.sh"
"$ROOT/scripts/configure-demo-hermes.sh" >/dev/null
hermes gateway restart >/dev/null
"$DIR/start.sh" 1
"$DIR/preflight.sh"

echo "NEXT: Open http://127.0.0.1:8090 and send /new to Hermes in Telegram."
