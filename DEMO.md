# Three-Minute Live Demo

## Before going on stage

1. Run `./scripts/prepare-demo.sh`.
2. Send one harmless warm-up tool task to Hermes in Telegram.
3. Confirm no `checkout-service-triage` skill exists.

## Live sequence

1. Show that Qwen is local and the checkout stack is healthy.
2. Run `./scripts/incident-redis.sh`.
3. Run `./scripts/run-monitor.sh` and show its Telegram alert.
4. Send: "Checkout is unhealthy. Diagnose it, restore service safely, and verify the repair using the `/ready` endpoint as the authoritative health signal. You may start a dependency only if it is currently stopped. Do not stop, kill, restart, remove, recreate, or replace any running container. Do not delete data. Historical log errors alone are not evidence of a current failure."
5. Send: "Turn the successful procedure into a reusable checkout-service-triage skill. Include health checks, log inspection, dependency recovery, safety boundaries, and post-repair verification. Use `skill_manage` with action `create`, placing the complete SKILL.md frontmatter and body in the `content` parameter—not `file_content`. Recovery may use `docker compose start` for a stopped service, never `docker compose up`, and must not stop, kill, restart, remove, recreate, or replace a running container."
6. Review and approve the staged skill with `/skills pending`,
   `/skills diff <id>`, and `/skills approve <id>`.
7. Send `/reload_skills` in Telegram so the newly approved skill is available as a slash command.
8. After Redis is repaired, run `./scripts/run-monitor.sh`. Show the Telegram recovery notice; this also records the healthy baseline for the next incident.
9. Start a fresh conversation with `/new`.
10. Run `./scripts/incident-worker.sh`.
11. Run `./scripts/run-monitor.sh` again. Show the new Telegram alert; it should report `worker` as unhealthy while Redis remains up.
12. Send: "/checkout_service_triage A new checkout incident is active. Diagnose it, restore service safely, and verify the repair using the `/ready` endpoint as the authoritative health signal. You may start a dependency only if it is currently stopped. Do not stop, kill, restart, remove, recreate, or replace any running container. Do not delete data. Historical log errors alone are not evidence of a current failure."
13. Show that Hermes directly loads the learned skill, starts only the stopped worker, and verifies `/ready` returns HTTP 200 with both dependencies up.

## Recovery

At any point, run `./scripts/reset-demo.sh` to restore the stack.
