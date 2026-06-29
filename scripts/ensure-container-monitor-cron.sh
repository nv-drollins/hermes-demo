#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$ROOT/demo/container-monitor"
JOBS_FILE="$HOME/.hermes/cron/jobs.json"

command -v hermes >/dev/null || {
  echo "Hermes is not installed. Run ./scripts/install-hermes.sh first." >&2
  exit 1
}
[[ -x "$DEMO_DIR/monitor-notify.sh" ]] || {
  echo "Missing executable monitor: $DEMO_DIR/monitor-notify.sh" >&2
  exit 1
}

mkdir -p "$HOME/.hermes/scripts"
wrapper="$HOME/.hermes/scripts/checkout-notify.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\nexec %q\n' "$DEMO_DIR/monitor-notify.sh" > "$wrapper"
chmod 700 "$wrapper"

job_id=""
if [[ -f "$JOBS_FILE" ]]; then
  job_id="$(jq -r '.jobs[] | select(.name == "checkout-health" and .enabled == true and .schedule.kind == "interval" and .schedule.minutes == 60 and .script == "checkout-notify.sh" and .no_agent == true) | .id' "$JOBS_FILE" | head -1)"
fi

if [[ -z "$job_id" ]]; then
  if [[ -f "$JOBS_FILE" ]]; then
    while IFS= read -r stale_id; do
      [[ -n "$stale_id" ]] && hermes cron remove "$stale_id"
    done < <(jq -r ' .jobs[] | select(.name == "checkout-health") | .id' "$JOBS_FILE")
  fi
  hermes cron create "every 60m" --name checkout-health --deliver telegram \
    --script checkout-notify.sh --no-agent --workdir "$ROOT"
  job_id="$(jq -r '.jobs[] | select(.name == "checkout-health" and .enabled == true and .schedule.kind == "interval" and .schedule.minutes == 60 and .script == "checkout-notify.sh" and .no_agent == true) | .id' "$JOBS_FILE" | head -1)"
fi

[[ -n "$job_id" ]] || { echo "Unable to create checkout-health cron job." >&2; exit 1; }
mkdir -p "$ROOT/.demo-state"
printf '%s\n' "$job_id" > "$ROOT/.demo-state/cron-job-id"
echo "checkout-health cron ready: $job_id"
