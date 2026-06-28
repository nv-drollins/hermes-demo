#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
docker compose -f "$DIR/compose.yaml" stop checkout-worker
sleep 10
curl -sS --max-time 2 -w '\nHTTP %{http_code}\n' http://127.0.0.1:8088/ready || true
