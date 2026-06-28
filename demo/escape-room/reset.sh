#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROUND="${1:-1}"
COMPOSE=(docker compose -f "$DIR/compose.yaml")

[[ "$ROUND" =~ ^[0-9]+$ ]] || { echo "Round must be an integer." >&2; exit 1; }
curl -fsS --max-time 5 -X POST http://127.0.0.1:8090/api/reset \
  -H 'Content-Type: application/json' \
  -d "{\"round\":$ROUND}" >/dev/null
"${COMPOSE[@]}" stop coolant-pump >/dev/null

for _ in $(seq 1 20); do
  if ! "${COMPOSE[@]}" ps --status running --services | grep -qx coolant-pump; then
    curl -fsS http://127.0.0.1:8090/api/state | jq '{mission, round, status, rooms, next_action}'
    echo "Round $ROUND reset; coolant-pump is stopped."
    exit 0
  fi
  sleep 1
done
echo "Coolant pump did not stop." >&2
exit 1
