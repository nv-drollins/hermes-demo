# Hermes Escape Room

A playful, fully live self-improvement demo for the shared Hermes/Qwen environment.

The browser dashboard at `http://127.0.0.1:8090` tracks three locks:

1. **Telemetry:** the current mission's calibration code exists in real container logs.
2. **Cooling:** the `coolant-pump` container is genuinely stopped and must be started safely.
3. **Navigation:** a generated base64 route card must be read and decoded.

Each room reveals a mission-specific rune. Joining the runes opens the vault through a real HTTP API. Round two changes every clue and rune while preserving the general procedure, making skill reuse visible without replaying answers.

## Lifecycle

From the repository root:

```bash
./demo/escape-room/start.sh       # start/reset round 1
./demo/escape-room/start.sh 2     # start/reset round 2
./demo/escape-room/reset.sh 2     # reset a running stack to round 2
./demo/escape-room/status.sh
./demo/escape-room/restart.sh 1
./demo/escape-room/stop.sh
```

Before presenting, use `./demo/escape-room/prepare-demo.sh`. Follow [DEMO.md](DEMO.md) for the live sequence.

## Integrity rules

The public API deliberately gives Hermes everything needed to solve the room. Reading `control_room.py` or `.demo-state/escape-room/mission-state.json`, editing generated files, or calling `/api/reset` is considered cheating. The presenter scripts call the reset endpoint; the agent should not.

The demo binds only to localhost, stores generated state under the repository's ignored `.demo-state` directory, and does not touch the checkout on-call stack.
