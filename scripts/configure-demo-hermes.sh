#!/usr/bin/env bash
set -euo pipefail

command -v hermes >/dev/null || {
  echo "Hermes is not installed." >&2
  exit 1
}

# The demos include a visible review-and-approval step for newly learned skills.
hermes config set skills.write_approval true >/dev/null

# Qwen is substantially more reliable at structured tool calling when Telegram
# exposes only the tools these demos use. Use Hermes's tool configurator so the
# value is persisted as a YAML list rather than a string.
disabled_toolsets=(
  web browser code_execution vision video image_gen video_gen x_search tts
  todo memory context_engine session_search clarify delegation cronjob
  homeassistant spotify yuanbao computer_use
)
hermes tools disable --platform telegram "${disabled_toolsets[@]}" >/dev/null
hermes tools enable --platform telegram terminal file skills >/dev/null

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

echo "Hermes demo policy ready: skill approval on; Telegram tools restricted."
