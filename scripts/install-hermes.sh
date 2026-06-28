#!/usr/bin/env bash
set -euo pipefail

HERMES_COMMIT="0c2e6c0049ca04ccc6fea1f264d52b48ffda33cd"
INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"

if command -v hermes >/dev/null 2>&1; then
  installed="$(hermes --version 2>/dev/null || true)"
  if [[ "$installed" == *"upstream ${HERMES_COMMIT:0:8}"* ]]; then
    echo "Hermes is already installed at the tested commit."
    exit 0
  fi
  echo "Hermes is installed, but not at the tested commit; the installer will update it."
fi

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "$INSTALL_URL" -o "$installer"
bash "$installer" --commit "$HERMES_COMMIT" --skip-setup --skip-browser --non-interactive

export PATH="$HOME/.local/bin:$PATH"
hermes --version
