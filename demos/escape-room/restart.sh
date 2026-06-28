#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROUND="${1:-1}"
"$DIR/stop.sh"
"$DIR/start.sh" "$ROUND"
