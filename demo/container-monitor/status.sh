#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== checkout readiness ==="
curl -sS --max-time 2 -w '\nHTTP %{http_code}\n' http://127.0.0.1:8088/ready || true
echo "=== containers ==="
docker compose -f "$DIR/compose.yaml" ps
echo "=== recent service logs ==="
docker compose -f "$DIR/compose.yaml" logs --tail=12 checkout-api checkout-worker redis
