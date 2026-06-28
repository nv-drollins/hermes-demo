#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="vllm/vllm-openai:nightly-aarch64"
docker pull "$IMAGE"
digest="$(docker image inspect "$IMAGE" --format '{{index .RepoDigests 0}}')"
if [[ -z "$digest" || "$digest" != *@sha256:* ]]; then
  echo "could not resolve repository digest for $IMAGE" >&2
  exit 1
fi
printf 'HF_TOKEN=%s\nVLLM_IMAGE=%s\n' "${HF_TOKEN:-hf_replace_me}" "$digest" > "$ROOT/inference/.env"
printf '%s\n' "$digest" > "$ROOT/inference/image-digest.txt"
chmod 600 "$ROOT/inference/.env"
echo "Pinned $digest"
