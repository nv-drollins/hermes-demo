#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
ROOT="$(repo_root)"
load_demo_env
require_env HF_TOKEN

VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai@sha256:80bc9aaea8f35dae1ade94649893a0369ab261fb418ed7428ab3bb8a14173954}"
umask 077
printf 'HF_TOKEN=%s\nVLLM_IMAGE=%s\n' "$HF_TOKEN" "$VLLM_IMAGE" > "$ROOT/inference/.env"
printf '%s\n' "$VLLM_IMAGE" > "$ROOT/inference/image-digest.txt"

docker compose --env-file "$ROOT/inference/.env" -f "$ROOT/inference/compose.yaml" pull
docker compose --env-file "$ROOT/inference/.env" -f "$ROOT/inference/compose.yaml" up -d
wait_for_url http://127.0.0.1:8000/v1/models "local Qwen model" 3600

model="$(curl -fsS http://127.0.0.1:8000/v1/models | jq -r '.data[0].id')"
[[ "$model" == "nvidia/Qwen3.6-35B-A3B-NVFP4" ]] || {
  echo "Unexpected model served: $model" >&2
  exit 1
}
echo "Inference setup complete: $model"
