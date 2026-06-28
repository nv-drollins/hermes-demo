# Hermes Demo Environment

A local, live demonstration environment for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on NVIDIA GB10. The first demo is a private on-call agent that detects a real Docker Compose outage, repairs it through Telegram, learns the successful runbook, and reuses that skill during a second incident.

Nothing in the incident flow is simulated: Redis, the checkout API, the worker, readiness failures, Telegram alerts, Hermes tool calls, and skill creation are all live.

## What this repository runs

- Hermes Agent with a Telegram gateway
- nvidia/Qwen3.6-35B-A3B-NVFP4 through the vLLM OpenAI-compatible API
- A three-service checkout stack: API, Redis, and worker
- A deterministic Hermes cron watchdog that alerts only on health-state changes
- Fault injection, recovery, preflight, and clean-demo reset scripts
- The [three-minute presenter runbook](demo/container-monitor/DEMO.md)

The model and checkout APIs bind to localhost only. Telegram is the remote interface.

## Included demos

- **[Private On-Call Agent](demo/container-monitor/DEMO.md):** detect two real checkout outages, repair them safely, learn a service-triage runbook, and reuse it.
- **[Hermes Escape Room](demo/escape-room/DEMO.md):** solve live log, container, file-decoding, and HTTP puzzles, learn the generalized escape procedure, then solve a new mission with different clues.

## Tested pins

| Component | Pin |
| --- | --- |
| Hermes Agent | 0c2e6c0049ca04ccc6fea1f264d52b48ffda33cd (v0.17.0) |
| vLLM image | vllm/vllm-openai@sha256:80bc9aaea8f35dae1ade94649893a0369ab261fb418ed7428ab3bb8a14173954 |
| Qwen model/tokenizer | 491c2f1ea524c639598bf8fa787a93fed5a6fbce |
| Redis | redis:7.4.2-alpine pinned by digest |
| Context length | 262,144 tokens |

The Qwen NVFP4 format and its ARM vLLM image are still an experimental combination. These pins are known to work together; do not swap in a mutable nightly image immediately before a presentation.

## Prerequisites

The known-good host is an NVIDIA DGX Spark/GB10 running Ubuntu 24.04 on aarch64. You need:

- An NVIDIA GPU with enough unified/GPU memory for the 35B-A3B NVFP4 model
- Current NVIDIA drivers and a working nvidia-smi
- Docker Engine, Docker Compose v2, and NVIDIA Container Toolkit
- curl, git, jq, sha256sum, and user-level systemd
- At least 50 GiB free for images and the Hugging Face cache; more is safer
- Passwordless sudo is helpful for keeping the user gateway alive after logout

Install Docker and the NVIDIA runtime using NVIDIA's current [Container Toolkit guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html), then run:

~~~bash
./scripts/check-prereqs.sh
~~~

Other GPU architectures will likely require a different vLLM image and memory settings.

## Credentials

Create a private repository-local environment file:

~~~bash
cp .env.example .env
chmod 600 .env
~~~

### Hugging Face

1. Sign in to [Hugging Face](https://huggingface.co/).
2. Create a read token under [Access Tokens](https://huggingface.co/settings/tokens).
3. Set HF_TOKEN in .env.
4. Accept any model-specific terms while signed into the same account.

### Telegram

1. Message [@BotFather](https://t.me/BotFather), run /newbot, and follow the prompts.
2. Put its token in TELEGRAM_BOT_TOKEN.
3. Message [@userinfobot](https://t.me/userinfobot) to obtain your numeric user ID.
4. Put that ID in TELEGRAM_ALLOWED_USERS.
5. For a private direct-message demo, put the same ID in TELEGRAM_HOME_CHANNEL.

~~~dotenv
HF_TOKEN=hf_replace_me
TELEGRAM_BOT_TOKEN=123456789:replace_me
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_HOME_CHANNEL=123456789
~~~

TELEGRAM_ALLOWED_USERS controls who may instruct the bot. TELEGRAM_HOME_CHANNEL is where proactive alerts go. A group has a different, usually negative, chat ID.

Never commit .env, inference/.env, ~/.hermes/.env, or any real token. Revoke and replace a credential if it is exposed.

## One-command setup

After the host prerequisites and .env are ready:

~~~bash
./scripts/setup-all.sh
~~~

This checks the host, installs the pinned Hermes commit, starts the pinned Qwen/vLLM stack, configures the local model endpoint, copies only the four required credentials to the private Hermes environment, installs the Telegram gateway, creates the hourly no-agent watchdog, and builds the checkout services.

The first model download can take a while. To follow it:

~~~bash
docker compose --env-file inference/.env -f inference/compose.yaml logs -f qwen
~~~

Stages may also be run independently:

~~~bash
./scripts/check-prereqs.sh
./scripts/install-hermes.sh
./scripts/setup-inference.sh
./scripts/configure-hermes.sh
~~~

## Run the demo

Prepare a clean presentation state:

~~~bash
./demo/container-monitor/prepare-demo.sh
~~~

This archives any prior checkout-service-triage skill under .demo-state, restores services, resets the healthy monitor baseline, restarts the gateway, and runs preflight checks. It does not delete the archived skill.

Send /new to the Telegram bot and follow the [container monitor presenter guide](demo/container-monitor/DEMO.md). Trigger the watchdog without knowing its generated job ID:

~~~bash
./demo/container-monitor/run-monitor.sh
~~~

The scheduled watchdog also runs every 60 minutes. It uses no LLM tokens: empty output is silent, while a changed incident or recovery state is sent directly to Telegram.

## Everyday operations

~~~bash
./demo/container-monitor/start.sh
./demo/container-monitor/status.sh
./demo/container-monitor/reset.sh
./demo/container-monitor/prepare-demo.sh
./demo/container-monitor/restart.sh
./demo/container-monitor/stop.sh

docker compose --env-file inference/.env -f inference/compose.yaml stop
docker compose --env-file inference/.env -f inference/compose.yaml up -d

hermes status
hermes gateway status
hermes cron list
journalctl --user -u hermes-gateway.service -f
~~~

Stopping the container monitor demo also removes its `checkout-health` cron job. Starting or restarting it recreates the job and records a healthy notification baseline; checkout containers and Redis data are preserved.

The escape room has its own isolated lifecycle:

~~~bash
./demo/escape-room/start.sh
./demo/escape-room/status.sh
./demo/escape-room/restart.sh
./demo/escape-room/stop.sh
~~~

## Safety boundaries

- Ports 8000, 8088, and 8090 bind only to 127.0.0.1.
- The Telegram bot is restricted by numeric user ID.
- Hermes skill and memory writes require approval.
- Fault scripts stop a dependency; they do not delete volumes or data.
- The learned runbook is instructed to start only an already stopped dependency.
- The deterministic monitor grants no model background execution.
- Interactive Hermes repairs can execute local commands. Use a dedicated demo system and review tool calls.

## Troubleshooting

### The bot does not answer

~~~bash
hermes gateway status
journalctl --user -u hermes-gateway.service -n 100 --no-pager
~~~

Confirm your numeric ID is allowed. Never paste the bot token into logs, issues, or screenshots.

### The alert did not arrive

Run ./demo/container-monitor/run-monitor.sh. The monitor intentionally sends nothing when health has not changed. prepare-demo.sh records a healthy baseline so the first incident changes state. Confirm TELEGRAM_HOME_CHANNEL is the intended private user or group chat ID.

### A newly approved skill is not a command

After /skills approve ID, send /reload_skills. Telegram commands use underscores, so invoke /checkout_service_triage rather than the hyphenated skill name.

### Approval says content is required for create

Repeat the creation prompt in demo/container-monitor/DEMO.md. It explicitly requires complete SKILL.md text in the content field, not file_content.

### Qwen does not start

~~~bash
docker compose --env-file inference/.env -f inference/compose.yaml ps
docker compose --env-file inference/.env -f inference/compose.yaml logs --tail=200 qwen
nvidia-smi
~~~

Authentication errors usually mean a bad Hugging Face token or unaccepted terms. For memory errors, stop other GPU workloads before changing the tested vLLM settings.

## Adding more demos

Keep shared inference and Hermes infrastructure at the root. Add future scenarios under directories such as `demo/docs-drift` or `demo/coding-loop`, each with its own Compose project name, localhost ports, prepare/incident/reset/preflight scripts, cron job name, .demo-state namespace, and presenter guide.

The escape room follows this layout under `demo/escape-room`. Good next additions are docs-drift/PR review and an agentic coding loop. Both can reuse the same local Qwen endpoint and Telegram gateway without duplicating the large model container.
