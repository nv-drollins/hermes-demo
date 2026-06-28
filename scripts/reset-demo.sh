#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d redis checkout-api checkout-worker
for _ in $(seq 1 20); do
  if curl -fsS --max-time 2 http://127.0.0.1:8088/ready >/dev/null; then
    echo "checkout demo is healthy"
    exit 0
  fi
  sleep 1
done
echo "checkout demo did not become ready" >&2
docker compose ps
exit 1
