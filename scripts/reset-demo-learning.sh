#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="checkout-service-triage"
SKILL_DIR="$HOME/.hermes/skills/$SKILL_NAME"
PENDING_DIR="$HOME/.hermes/pending/skills"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$ROOT/.demo-state/skill-backups/$stamp"
archived=false

if [[ -d "$SKILL_DIR" ]]; then
  mkdir -p "$backup/skills"
  mv "$SKILL_DIR" "$backup/skills/"
  archived=true
fi

if [[ -d "$PENDING_DIR" ]]; then
  while IFS= read -r -d '' pending; do
    if grep -q "$SKILL_NAME" "$pending"; then
      mkdir -p "$backup/pending"
      mv "$pending" "$backup/pending/"
      archived=true
    fi
  done < <(find "$PENDING_DIR" -maxdepth 1 -type f -name '*.json' -print0)
fi

if [[ "$archived" == true ]]; then
  echo "Archived prior demo learning to $backup"
else
  echo "No prior checkout triage learning found"
fi
