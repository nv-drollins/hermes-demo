#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
cd "$ROOT"

expected_model="nvidia/Qwen3.6-35B-A3B-NVFP4"
model="$(curl -fsS --max-time 5 http://127.0.0.1:8000/v1/models | jq -r '.data[0].id')"
[[ "$model" == "$expected_model" ]] || { echo "FAIL model endpoint: $model"; exit 1; }
echo "PASS local model: $model"

ready="$(curl -fsS --max-time 5 http://127.0.0.1:8088/ready | jq -r '.ready')"
[[ "$ready" == "true" ]] || { echo "FAIL checkout readiness"; exit 1; }
echo "PASS checkout stack ready"

systemctl --user is-active --quiet hermes-gateway.service
echo "PASS Hermes gateway active"

hermes cron list | grep -q 'checkout-health'
echo "PASS checkout-health cron active"

if find "$HOME/.hermes/skills" -type d -iname "*checkout*triage*" -print -quit | grep -q .; then
  echo "FAIL checkout triage skill directory already exists"
  exit 1
fi

if [[ -d "$HOME/.hermes/pending/skills" ]] && grep -Rql "checkout-service-triage" "$HOME/.hermes/pending/skills"; then
  echo "FAIL pending checkout triage skill write already exists"
  exit 1
fi

echo "PASS no pre-existing checkout triage skill or pending write"

echo "PREFLIGHT OK"
