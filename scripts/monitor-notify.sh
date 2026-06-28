#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$ROOT/.demo-state"
STATE_FILE="$STATE_DIR/last-health.sha256"
mkdir -p "$STATE_DIR"

body="$(curl -sS --max-time 3 http://127.0.0.1:8088/ready 2>/dev/null || true)"
http_code="$(curl -sS -o /dev/null --max-time 3 -w '%{http_code}' http://127.0.0.1:8088/ready 2>/dev/null || true)"
summary="HTTP=$http_code READY=$body"
current_hash="$(printf '%s' "$summary" | sha256sum | cut -d' ' -f1)"
previous_hash="$(cat "$STATE_FILE" 2>/dev/null || true)"
printf '%s\n' "$current_hash" > "$STATE_FILE"

# No stdout means no delivery in Hermes no-agent cron mode.
if [[ -n "$previous_hash" && "$current_hash" == "$previous_hash" ]]; then
  exit 0
fi

if [[ "$http_code" == "200" ]]; then
  printf '✅ GB10 RECOVERY\nCheckout service is healthy again. Redis and worker readiness checks are passing.\n'
  exit 0
fi

unhealthy="$(printf '%s' "$body" | jq -r '[.dependencies | to_entries[] | select(.value != "up") | .key] | join(", ")' 2>/dev/null || true)"
[[ -n "$unhealthy" ]] || unhealthy="unknown dependencies"
printf '🚨 GB10 PRIVATE ON-CALL\nCheckout readiness failed with HTTP %s. Unhealthy: %s.\nReply to this alert and ask Hermes to diagnose and restore service safely.\n' "$http_code" "$unhealthy"
