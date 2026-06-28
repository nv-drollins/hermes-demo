#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/check-prereqs.sh
./scripts/install-hermes.sh
./scripts/setup-inference.sh
./scripts/configure-hermes.sh
docker compose up -d --build
./scripts/reset-demo.sh
./scripts/monitor-notify.sh >/dev/null
curl -fsS http://127.0.0.1:8000/v1/models >/dev/null
systemctl --user is-active --quiet hermes-gateway.service
hermes cron list | grep -q checkout-health
echo "INSTALL CHECKS OK"

echo
echo "SETUP COMPLETE"
echo "Open Telegram, message your bot, and run /new."
echo "Then follow DEMO.md or run ./scripts/prepare-demo.sh before presenting."
