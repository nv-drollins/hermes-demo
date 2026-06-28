#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
JOBS_FILE="$HOME/.hermes/cron/jobs.json"

docker compose -f "$DIR/compose.yaml" stop

removed=0
if [[ -f "$JOBS_FILE" ]]; then
  mapfile -t job_ids < <(jq -r '.jobs[] | select(.name == "checkout-health") | .id' "$JOBS_FILE")
  for job_id in "${job_ids[@]}"; do
    [[ -n "$job_id" ]] || continue
    hermes cron remove "$job_id"
    removed=$((removed + 1))
  done
fi

rm -f "$ROOT/.demo-state/cron-job-id"
echo "Container monitor services stopped; removed $removed checkout-health cron job(s)."
echo "Containers and checkout data were preserved."
