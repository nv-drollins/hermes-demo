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
| Reliability mode | Thinking and speculative decoding disabled; temperature 0 |

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

This checks the host, installs the pinned Hermes commit, starts the pinned Qwen/vLLM stack, configures the local model endpoint, copies only the four required credentials to the private Hermes environment, limits Telegram to the terminal, file, and skills toolsets for reliable local-model tool calling, installs the Telegram gateway, creates the hourly no-agent watchdog, and builds the checkout services.

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

## Demos

Both demos use the shared local Qwen/vLLM endpoint and Hermes Telegram gateway configured during setup. The instructions below are complete; the individual presenter guides remain available as shorter standalone references.

### Container Monitor

This professional on-call demo detects real checkout outages, guides Hermes through safe recovery, creates a reusable triage skill, and reuses it for a second incident. The standalone guide is [demo/container-monitor/DEMO.md](demo/container-monitor/DEMO.md).

#### Watchdog and cron behavior

`prepare-demo.sh` calls `start.sh`, which creates or validates one recurring Hermes cron job named `checkout-health`. It runs every 60 minutes in no-agent mode and sends Telegram output only when the checkout health state changes.

The live sequence uses:

~~~bash
./demo/container-monitor/run-monitor.sh
~~~

This triggers the same cron job immediately, so you can show incident and recovery notifications without waiting for the hourly schedule. `stop.sh` removes the cron job; `start.sh` or `restart.sh` recreates it.

#### Before going on stage

1. Run:

   ~~~bash
   ./demo/container-monitor/prepare-demo.sh
   ~~~

2. Send one harmless warm-up tool task to Hermes in Telegram.
3. Confirm no `checkout-service-triage` skill exists.

The preparation script archives any prior checkout triage skill under `.demo-state`, restores the services, enables skill-write approval, restricts Telegram to the demo toolsets, creates the hourly watchdog, records a healthy notification baseline, restarts the gateway, and runs preflight checks.

#### Live sequence

1. Show that Qwen is local and the checkout stack is healthy.
2. Inject the Redis incident:

   ~~~bash
   ./demo/container-monitor/incident-redis.sh
   ~~~

   Expected result: `/ready` returns HTTP 503 and may report both Redis and the worker as down. The worker container is still running, but its heartbeat is stored in Redis, so Redis loss causes a downstream worker-readiness failure. Redis is the root cause; Hermes should start only the stopped Redis service, after which the running worker reconnects and resumes its heartbeat without a restart.

3. Trigger the watchdog immediately and show its Telegram alert:

   ~~~bash
   ./demo/container-monitor/run-monitor.sh
   ~~~

4. Send this prompt in Telegram:

   > Checkout is unhealthy. Diagnose it, restore service safely, and verify the repair using the `/ready` endpoint as the authoritative health signal. Make exactly one tool call per response and wait for its result before making the next tool call; do not batch or parallelize tool calls, and do not print tool names or tool-call markup as text. Begin with one terminal call that runs `docker compose -f demo/container-monitor/compose.yaml ps --all`. All Docker Compose commands must use `-f demo/container-monitor/compose.yaml`. You may start a dependency only if it is currently stopped. Do not stop, kill, restart, remove, recreate, or replace any running container. Do not delete data. Historical log errors alone are not evidence of a current failure.

5. After Hermes repairs Redis, send:

   > Turn the successful procedure into a reusable checkout-service-triage skill. Include health checks, log inspection, dependency recovery, safety boundaries, and post-repair verification. Use `skill_manage` with action `create`, placing the complete SKILL.md frontmatter and body in the `content` parameter—not `file_content`. Recovery may use `docker compose -f demo/container-monitor/compose.yaml start <stopped-service>` only for a stopped service, never `docker compose up`, and must not stop, kill, restart, remove, recreate, or replace a running container.

6. Review and approve the staged skill:

   ~~~text
   /skills pending
   /skills diff <id>
   /skills approve <id>
   ~~~

7. Send `/reload_skills` so Telegram registers the new slash command.
8. Trigger the watchdog again after Redis is repaired:

   ~~~bash
   ./demo/container-monitor/run-monitor.sh
   ~~~

   Show the Telegram recovery notice. This also records the healthy baseline for the next incident.

9. Start a fresh Telegram conversation with `/new`.
10. Inject the worker incident:

    ~~~bash
    ./demo/container-monitor/incident-worker.sh
    ~~~

11. Trigger the watchdog again. It should report that the worker is unhealthy while Redis remains up:

    ~~~bash
    ./demo/container-monitor/run-monitor.sh
    ~~~

12. Invoke the learned skill in Telegram:

    > /checkout_service_triage A new checkout incident is active. Diagnose it, restore service safely, and verify the repair using the `/ready` endpoint as the authoritative health signal. Make exactly one tool call per response and wait for its result before making the next tool call; do not batch or parallelize tool calls, and do not print tool names or tool-call markup as text. Begin with one terminal call that runs `docker compose -f demo/container-monitor/compose.yaml ps --all`. All Docker Compose commands must use `-f demo/container-monitor/compose.yaml`. You may start a dependency only if it is currently stopped. Do not stop, kill, restart, remove, recreate, or replace any running container. Do not delete data. Historical log errors alone are not evidence of a current failure.

13. Show that Hermes loads the learned skill, starts only the stopped worker, and verifies that `/ready` returns HTTP 200 with both dependencies up.

#### Recovery and lifecycle

Restore the checkout services at any point:

~~~bash
./demo/container-monitor/reset.sh
~~~

Other lifecycle commands:

~~~bash
./demo/container-monitor/start.sh
./demo/container-monitor/status.sh
./demo/container-monitor/restart.sh
./demo/container-monitor/stop.sh
~~~

`stop.sh` stops the checkout services and removes every `checkout-health` cron job while preserving containers and Redis data. `start.sh` and `restart.sh` recreate exactly one recurring watchdog and record a healthy baseline.

### Escape Room

This playful demo has Hermes solve three live challenges using container logs, a stopped coolant service, an encoded navigation file, and HTTP APIs. It then learns the generalized procedure and attempts a second round with different clues. The standalone guide is [demo/escape-room/DEMO.md](demo/escape-room/DEMO.md).

#### Before going on stage

1. From the repository root, run:

   ~~~bash
   ./demo/escape-room/prepare-demo.sh
   ~~~

2. Open `http://127.0.0.1:8090` in a browser and leave the dashboard visible. Confirm the action clock is waiting at `00:00`.
3. Send `/new` to Hermes in Telegram.
4. Keep a terminal visible beside the dashboard for Hermes tool activity.

#### Round one: cold escape

Send this prompt in Telegram:

> A live escape mission is active at http://127.0.0.1:8090. Escape it using real terminal, Docker, file, and HTTP operations. Start with GET /api/state and follow its current next_action until status is escaped. Work from the repository root. Use `docker compose -f demo/escape-room/compose.yaml logs control-room` for the log clue. When decoding the navigation card, preserve all base64 padding by taking everything after `ROUTE=`. Treat the API rules as hard constraints: do not read application source code or .demo-state/escape-room/mission-state.json, do not edit generated files, and do not call /api/reset. You may use `docker compose -f demo/escape-room/compose.yaml start coolant-pump` only when that service is stopped. Never use compose up, stop, kill, restart, rm, down, or container recreation. Verify the final result with GET /api/state.

Watch the clock begin with the first successful unlock. The dashboard unlocks Telemetry, Cooling, and Navigation before displaying **ESCAPE COMPLETE** and freezing the round-one time.

#### Teach Hermes the procedure

Send this prompt in the same Telegram conversation:

> Turn the successful escape procedure into a reusable skill named escape-room-operator. Generalize the process; do not save this mission's calibration code, route, or runes. The skill must begin with GET http://127.0.0.1:8090/api/state and follow next_action one lock at a time, matching clues to the current mission. It may inspect logs with `docker compose -f demo/escape-room/compose.yaml logs control-room`, start only a stopped coolant-pump with `docker compose -f demo/escape-room/compose.yaml start coolant-pump`, read and decode .demo-state/escape-room/navigation.txt while preserving base64 padding, call the documented room and vault APIs, and verify escaped status. It must never read application source or mission-state.json, edit generated files, call /api/reset, use compose up, or stop, kill, restart, remove, or recreate containers. Use `skill_manage` with action `create`, putting the complete SKILL.md frontmatter and body in the `content` parameter—not `file_content`.

Then:

1. Send `/skills pending`.
2. Send `/skills diff <id>` and confirm that the skill contains the generalized workflow rather than round-one answers.
3. Send `/skills approve <id>`.
4. Send `/reload_skills` so Telegram registers the new slash command.

If Hermes has already installed `escape-room-operator` while also leaving a duplicate pending write, reject the redundant pending entries, keep the installed skill, and run `/reload_skills`.

#### Round two: learned escape

Reset the dashboard to the second mission:

~~~bash
./demo/escape-room/reset.sh 2
~~~

The dashboard changes to `ESCAPE-NEBULA`, resets the timer to `00:00`, locks all rooms, stops the coolant pump again, and retains the round-one completion time.

Send `/new`, then invoke the learned skill:

> /escape_room_operator A new mission is active. Escape it, obey every integrity and container-safety rule, and verify the final status.

Point out that all calibration values, navigation data, and runes changed. Hermes is reusing the learned procedure rather than memorized answers. When the vault opens, show the labeled round-one and round-two times side-by-side and the faster-round margin.

#### Recovery and lifecycle

~~~bash
./demo/escape-room/reset.sh 1    # clean round one while retaining the skill
./demo/escape-room/restart.sh 1  # rebuild and restart
./demo/escape-room/status.sh     # inspect mission and containers
./demo/escape-room/stop.sh       # stop the demo
~~~

`prepare-demo.sh` archives an existing `escape-room-operator` skill for a completely cold demonstration. It also enables skill-write approval and restricts Telegram to the demo toolsets. Use `reset.sh 1` when you want to reset the puzzle while retaining the learned skill.

If an approved skill is not recognized, send `/reload_skills`. Telegram uses `/escape_room_operator`, with underscores, even though the canonical skill directory is hyphenated.

## Shared operations

~~~bash
docker compose --env-file inference/.env -f inference/compose.yaml stop
docker compose --env-file inference/.env -f inference/compose.yaml up -d

hermes status
hermes gateway status
hermes cron list
journalctl --user -u hermes-gateway.service -f
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
