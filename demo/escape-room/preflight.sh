#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
expected_model="nvidia/Qwen3.6-35B-A3B-NVFP4"
model="$(curl -fsS --max-time 5 http://127.0.0.1:8000/v1/models | jq -r '.data[0].id')"
[[ "$model" == "$expected_model" ]] || { echo "FAIL model endpoint: $model"; exit 1; }
echo "PASS local model: $model"

state="$(curl -fsS --max-time 5 http://127.0.0.1:8090/api/state)"
[[ "$(jq -r '.round' <<<"$state")" == "1" ]] || { echo "FAIL expected round 1"; exit 1; }
[[ "$(jq -r '.status' <<<"$state")" == "active" ]] || { echo "FAIL mission is not active"; exit 1; }
[[ "$(jq '[.rooms[].unlocked] | any' <<<"$state")" == "false" ]] || { echo "FAIL a room is already unlocked"; exit 1; }
echo "PASS round 1 active with all rooms locked"

if docker compose -f "$DIR/compose.yaml" ps --status running --services | grep -qx coolant-pump; then
  echo "FAIL coolant-pump should be stopped"
  exit 1
fi
echo "PASS coolant-pump stopped"

systemctl --user is-active --quiet hermes-gateway.service
echo "PASS Hermes gateway active"

python3 - "$HOME/.hermes/config.yaml" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as handle:
    config = yaml.safe_load(handle) or {}

assert config.get("skills", {}).get("write_approval") is True
toolsets = config.get("platform_toolsets", {}).get("telegram")
assert isinstance(toolsets, list)
assert {"terminal", "file", "skills"}.issubset(toolsets)
assert "hermes-telegram" not in toolsets
PY
echo "PASS skill approval on and Telegram demo tools restricted"

if find "$HOME/.hermes/skills" -type d -iname '*escape*room*operator*' -print -quit | grep -q .; then
  echo "FAIL escape-room-operator skill already exists"
  exit 1
fi
if [[ -d "$HOME/.hermes/pending/skills" ]] && grep -Rql 'escape-room-operator' "$HOME/.hermes/pending/skills"; then
  echo "FAIL pending escape-room-operator skill write already exists"
  exit 1
fi
echo "PASS no pre-existing escape-room skill or pending write"
echo "PREFLIGHT OK"
