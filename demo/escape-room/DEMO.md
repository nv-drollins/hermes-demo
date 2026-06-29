# Three-Minute Live Escape Room Demo

## Before going on stage

1. Run `./demo/escape-room/prepare-demo.sh` from the repository root.
   This also enables skill-write approval and restricts Telegram to the terminal, file, and skills toolsets.
2. Open `http://127.0.0.1:8090` in a browser and leave the dashboard visible.
   Confirm the action clock is waiting at `00:00.0`.
3. Send `/new` to Hermes in Telegram.
4. Keep a terminal visible beside the dashboard for Hermes tool activity.

## Round one: cold escape

Send this in Telegram:

> A live escape mission is active at http://127.0.0.1:8090. Escape it using real terminal, Docker, file, and HTTP operations. Start with GET /api/state?start=1 to start the round clock, then follow its current next_action until status is escaped. Work from the repository root. Use `docker compose -f demo/escape-room/compose.yaml logs control-room` for the log clue. When decoding the navigation card, preserve all base64 padding by taking everything after `ROUTE=`. Treat the API rules as hard constraints: do not read application source code or .demo-state/escape-room/mission-state.json, do not edit generated files, and do not call /api/reset. You may use `docker compose -f demo/escape-room/compose.yaml start coolant-pump` only when that service is stopped. Never use compose up, stop, kill, restart, rm, down, or container recreation. Verify the final result with GET /api/state.

Watch the clock begin when Hermes makes its initial `GET /api/state?start=1` request. All other state reads are passive, so both rounds start from the same explicit agent action. The display updates in tenths of a second, then freezes when the dashboard shows **ESCAPE COMPLETE**.

## Teach Hermes the procedure

Send:

> Turn the successful escape procedure into a reusable skill named escape-room-operator. Generalize the process; do not save this mission's calibration code, route, or runes. The skill must begin each mission with GET http://127.0.0.1:8090/api/state?start=1 to start that round's clock, then follow next_action one lock at a time, matching clues to the current mission. It may inspect logs with `docker compose -f demo/escape-room/compose.yaml logs control-room`, start only a stopped coolant-pump with `docker compose -f demo/escape-room/compose.yaml start coolant-pump`, read and decode .demo-state/escape-room/navigation.txt while preserving base64 padding, call the documented room and vault APIs, and verify escaped status. It must never read application source or mission-state.json, edit generated files, call /api/reset, use compose up, or stop, kill, restart, remove, or recreate containers. Use `skill_manage` with action `create`, putting the complete SKILL.md frontmatter and body in the `content` parameter—not `file_content`.

Then:

1. Send `/skills pending`.
2. Send `/skills diff <id>` and briefly show that the skill contains the generalized workflow rather than round-one answers.
3. Send `/skills approve <id>`.
4. Send `/reload_skills` so Telegram registers the new slash command.

## Round two: learned escape

In the terminal, run:

```bash
./demo/escape-room/reset.sh 2
```

The dashboard changes to `ESCAPE-NEBULA`, resets the timer, locks all rooms, and stops the pump again. Send `/new`, then invoke the learned skill:

> /escape_room_operator A new mission is active. Begin with GET http://127.0.0.1:8090/api/state?start=1 to start the round clock, escape it, obey every integrity and container-safety rule, and verify the final status.

Point out that all calibration values, navigation data, and runes changed. Hermes is reusing the learned procedure, not memorized answers. When the vault opens, show the labeled round-one and round-two times side-by-side and the faster-round margin.

## Recovery

At any point:

```bash
./demo/escape-room/reset.sh 1    # clean round one
./demo/escape-room/restart.sh 1  # rebuild/restart if needed
./demo/escape-room/stop.sh       # stop the demo
```

If an approved skill is not recognized, send `/reload_skills`. Telegram uses `/escape_room_operator`, with underscores, even though the skill directory is hyphenated.
