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

if command -v loginctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
  sudo -n loginctl enable-linger "$USER" 2>/dev/null || echo "WARN could not enable user lingering; gateway may stop after logout."
fi
hermes gateway install
hermes gateway restart

"$ROOT/scripts/ensure-container-monitor-cron.sh"

echo "Hermes, Telegram gateway, and container monitor cron configured."
