#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== mission ==="
curl -fsS http://127.0.0.1:8090/api/state | jq
echo "=== containers ==="
docker compose -f "$DIR/compose.yaml" ps --all
