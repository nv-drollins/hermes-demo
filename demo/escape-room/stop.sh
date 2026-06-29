#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
docker compose -f "$DIR/compose.yaml" down
echo "Escape room stopped. Mission state was preserved under .demo-state."
