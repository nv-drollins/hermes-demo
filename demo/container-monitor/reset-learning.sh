#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_NAME="checkout-service-triage"
SKILLS_DIR="$HOME/.hermes/skills"
PENDING_DIR="$HOME/.hermes/pending/skills"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$ROOT/.demo-state/container-monitor-skill-backups/$stamp"
archived=false

if [[ -d "$SKILLS_DIR" ]]; then
  while IFS= read -r -d '' skill_dir; do
    relative="${skill_dir#"$SKILLS_DIR"/}"
    destination="$backup/skills/$(dirname "$relative")"
    mkdir -p "$destination"
    mv "$skill_dir" "$destination/"
    archived=true
  done < <(find "$SKILLS_DIR" -type d -name "$SKILL_NAME" -print0)
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
