#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose stop redis
sleep 3
curl -sS --max-time 2 -w '\nHTTP %{http_code}\n' http://127.0.0.1:8088/ready || true
