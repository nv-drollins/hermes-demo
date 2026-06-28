#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

docker compose --env-file inference/.env -f inference/compose.yaml up -d
docker compose up -d
./scripts/reset-demo-learning.sh
hermes gateway restart >/dev/null
./scripts/reset-demo.sh
./scripts/monitor-notify.sh >/dev/null
./scripts/preflight.sh
echo "NEXT: Send /new to the Hermes Telegram bot before starting incident one."
