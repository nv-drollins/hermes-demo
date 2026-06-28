#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
ROUND="${1:-1}"
COMPOSE=(docker compose -f "$DIR/compose.yaml")

[[ "$ROUND" =~ ^[0-9]+$ ]] || { echo "Round must be an integer." >&2; exit 1; }
mkdir -p "$ROOT/.demo-state/escape-room"
chmod 0777 "$ROOT/.demo-state/escape-room"

"${COMPOSE[@]}" up -d --build control-room coolant-pump
for _ in $(seq 1 60); do
  if curl -fsS --max-time 2 http://127.0.0.1:8090/health >/dev/null; then
    "$DIR/reset.sh" "$ROUND"
    echo "Escape room ready: http://127.0.0.1:8090"
    exit 0
  fi
  sleep 1
done

echo "Control room did not become healthy." >&2
"${COMPOSE[@]}" ps
"${COMPOSE[@]}" logs --tail=80 control-room
exit 1
