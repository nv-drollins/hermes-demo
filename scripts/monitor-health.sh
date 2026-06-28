#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$ROOT/.demo-state"
STATE_FILE="$STATE_DIR/last-health.sha256"
mkdir -p "$STATE_DIR"
cd "$ROOT"

body="$(curl -sS --max-time 3 http://127.0.0.1:8088/ready 2>&1 || true)"
http_code="$(curl -sS -o /dev/null --max-time 3 -w '%{http_code}' http://127.0.0.1:8088/ready 2>/dev/null || true)"
compose_state="$(docker compose ps --format json 2>&1 || true)"
summary="HTTP=$http_code READY=$body"
current_hash="$(printf '%s' "$summary" | sha256sum | cut -d' ' -f1)"
previous_hash="$(cat "$STATE_FILE" 2>/dev/null || true)"
printf '%s\n' "$current_hash" > "$STATE_FILE"

if [[ "$http_code" == "200" && -n "$previous_hash" && "$current_hash" == "$previous_hash" ]]; then
  echo "NO_CHANGE: checkout stack is healthy"
  exit 0
fi

if [[ "$http_code" == "200" ]]; then
  echo "STATE_CHANGED: checkout stack is healthy"
else
  echo "INCIDENT: checkout readiness check returned HTTP $http_code"
fi
echo "$body"
docker compose ps
echo "RECENT_LOGS"
docker compose logs --no-color --tail=20 checkout-api checkout-worker redis 2>&1
