#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

docker compose --env-file "$ROOT/inference/.env" -f "$ROOT/inference/compose.yaml" up -d
"$DIR/reset-learning.sh"
hermes gateway restart >/dev/null
"$DIR/start.sh"
"$DIR/preflight.sh"
echo "NEXT: Send /new to the Hermes Telegram bot before starting incident one."
