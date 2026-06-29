#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

docker compose -f "$DIR/compose.yaml" up -d --build
"$ROOT/scripts/ensure-container-monitor-cron.sh"
"$DIR/reset.sh"
"$DIR/monitor-notify.sh" >/dev/null
echo "Container monitor demo started with a healthy notification baseline."
