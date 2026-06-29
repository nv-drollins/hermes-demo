# Container Monitor Demo

The original private on-call demonstration: a real checkout API, Redis dependency, worker heartbeat, deterministic Telegram watchdog, controlled incidents, and a Hermes-created service-triage skill.

## Lifecycle

Run these commands from the repository root:

```bash
./demo/container-monitor/start.sh
./demo/container-monitor/status.sh
./demo/container-monitor/restart.sh
./demo/container-monitor/stop.sh
```

`start.sh` builds and starts the checkout services, ensures the hourly `checkout-health` Hermes cron job exists, restores service health, and records a healthy notification baseline.

`stop.sh` stops the three checkout services and removes every Hermes cron job named `checkout-health`. It preserves the containers, Redis volume, generated state, and learned-skill backups. Running `start.sh` or `restart.sh` recreates the cron job.

For a clean presentation state, run `./demo/container-monitor/prepare-demo.sh`, then follow [DEMO.md](DEMO.md).

Shared host, Hermes, Telegram, and inference installation scripts remain in the repository-level `scripts` directory.
