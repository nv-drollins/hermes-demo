#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
jobs_file="$HOME/.hermes/cron/jobs.json"
[[ -f "$jobs_file" ]] || { echo "Hermes cron configuration not found." >&2; exit 1; }

job_id="$(jq -r '.jobs[] | select(.name == "checkout-health" and .enabled == true) | .id' "$jobs_file" | head -1)"
[[ -n "$job_id" ]] || {
  echo "No enabled checkout-health job found. Run ./scripts/configure-hermes.sh." >&2
  exit 1
}
mkdir -p "$ROOT/.demo-state"
printf '%s\n' "$job_id" > "$ROOT/.demo-state/cron-job-id"
echo "Triggering checkout-health ($job_id)."
hermes cron run "$job_id"
