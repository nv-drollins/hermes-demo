#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
ROOT="$(repo_root)"
load_demo_env
require_env HF_TOKEN TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_HOME_CHANNEL

[[ "$TELEGRAM_ALLOWED_USERS" =~ ^[0-9]+(,[0-9]+)*$ ]] || {
  echo "TELEGRAM_ALLOWED_USERS must contain numeric Telegram user IDs, comma-separated." >&2
  exit 1
}
[[ "$TELEGRAM_HOME_CHANNEL" =~ ^-?[0-9]+$ ]] || {
  echo "TELEGRAM_HOME_CHANNEL must be a numeric chat ID." >&2
  exit 1
}

export PATH="$HOME/.local/bin:$PATH"
command -v hermes >/dev/null || {
  echo "Hermes is not installed. Run ./scripts/install-hermes.sh first." >&2
  exit 1
}

mkdir -p "$HOME/.hermes"
chmod 700 "$HOME/.hermes"
env_file="$HOME/.hermes/.env"
touch "$env_file"
chmod 600 "$env_file"

# Preserve unrelated Hermes secrets while replacing only this demo's four values.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
grep -Ev '^(HF_TOKEN|TELEGRAM_BOT_TOKEN|TELEGRAM_ALLOWED_USERS|TELEGRAM_HOME_CHANNEL)=' "$env_file" > "$tmp" || true
{
  sed -n '1,$p' "$tmp"
  printf 'HF_TOKEN=%s\n' "$HF_TOKEN"
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN"
  printf 'TELEGRAM_ALLOWED_USERS=%s\n' "$TELEGRAM_ALLOWED_USERS"
  printf 'TELEGRAM_HOME_CHANNEL=%s\n' "$TELEGRAM_HOME_CHANNEL"
} > "$env_file"
chmod 600 "$env_file"

hermes config set model.default nvidia/Qwen3.6-35B-A3B-NVFP4
hermes config set model.provider custom
hermes config set model.base_url http://127.0.0.1:8000/v1
hermes config set model.context_length 262144
hermes config set terminal.cwd "$ROOT"
hermes config set terminal.timeout 180
hermes config set skills.write_approval true
hermes config set memory.write_approval true
hermes config set cron.mirror_delivery true

mkdir -p "$HOME/.hermes/scripts"
wrapper="$HOME/.hermes/scripts/checkout-notify.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\nexec %q\n' "$ROOT/scripts/monitor-notify.sh" > "$wrapper"
chmod 700 "$wrapper"

if command -v loginctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
  sudo -n loginctl enable-linger "$USER" 2>/dev/null || echo "WARN could not enable user lingering; gateway may stop after logout."
fi
hermes gateway install
hermes gateway restart

jobs_file="$HOME/.hermes/cron/jobs.json"
job_id=""
if [[ -f "$jobs_file" ]]; then
  job_id="$(jq -r '.jobs[] | select(.name == "checkout-health") | .id' "$jobs_file" | head -1)"
fi
if [[ -z "$job_id" ]]; then
  hermes cron create 60m --name checkout-health --deliver telegram \
    --script checkout-notify.sh --no-agent --workdir "$ROOT"
  job_id="$(jq -r '.jobs[] | select(.name == "checkout-health") | .id' "$jobs_file" | head -1)"
fi
[[ -n "$job_id" ]] || { echo "Unable to locate checkout-health cron job." >&2; exit 1; }
mkdir -p "$ROOT/.demo-state"
printf '%s\n' "$job_id" > "$ROOT/.demo-state/cron-job-id"

echo "Hermes and Telegram gateway configured. checkout-health job: $job_id"
