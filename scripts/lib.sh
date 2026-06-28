#!/usr/bin/env bash

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

load_demo_env() {
  local root env_file
  root="$(repo_root)"
  env_file="$root/.env"
  if [[ ! -f "$env_file" ]]; then
    echo "Missing $env_file. Copy .env.example to .env and fill in the four credentials." >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

require_env() {
  local name value
  for name in "$@"; do
    value="${!name:-}"
    if [[ -z "$value" || "$value" == *replace_me* ]]; then
      echo "Set $name in .env before continuing." >&2
      exit 1
    fi
  done
}

wait_for_url() {
  local url="$1" label="$2" timeout="${3:-1800}" elapsed=0
  echo "Waiting for $label at $url ..."
  until curl -fsS --max-time 5 "$url" >/dev/null 2>&1; do
    if (( elapsed >= timeout )); then
      echo "Timed out waiting for $label after ${timeout}s." >&2
      return 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "$label is ready."
}
