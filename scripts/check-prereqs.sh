#!/usr/bin/env bash
set -euo pipefail

failed=false
for command in curl docker git jq sha256sum systemctl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "FAIL missing command: $command"
    failed=true
  else
    echo "PASS command: $command"
  fi
done

if command -v docker >/dev/null 2>&1; then
  docker compose version >/dev/null 2>&1 && echo "PASS Docker Compose v2" || {
    echo "FAIL Docker Compose v2 is unavailable"
    failed=true
  }
  docker info >/dev/null 2>&1 && echo "PASS Docker daemon is accessible" || {
    echo "FAIL current user cannot access the Docker daemon"
    failed=true
  }
  docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -qi nvidia &&
    echo "PASS NVIDIA container runtime" || {
      echo "FAIL NVIDIA container runtime is not registered with Docker"
      failed=true
    }
fi

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "PASS NVIDIA GPU is visible"
else
  echo "FAIL nvidia-smi cannot see an NVIDIA GPU"
  failed=true
fi

arch="$(uname -m)"
if [[ "$arch" == "aarch64" ]]; then
  echo "PASS architecture: $arch"
else
  echo "WARN tested on aarch64/GB10; detected $arch"
fi

available_gib="$(df -Pk "${HOME}/.cache" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || true)"
if [[ -n "$available_gib" && "$available_gib" -lt 50 ]]; then
  echo "WARN only ${available_gib} GiB is free on the Hugging Face cache filesystem"
else
  echo "PASS at least 50 GiB free for model and container data"
fi

[[ "$failed" == false ]] || exit 1
echo "PREREQUISITES OK"
