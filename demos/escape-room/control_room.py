import base64
import hashlib
import json
import os
import threading
from datetime import datetime, timezone
from pathlib import Path

import requests
from flask import Flask, jsonify, render_template_string, request

app = Flask(__name__)
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
STATE_FILE = DATA_DIR / "mission-state.json"
NAV_FILE = DATA_DIR / "navigation.txt"
PUMP_URL = os.environ.get("PUMP_URL", "http://coolant-pump:8091/health")
LOCK = threading.Lock()


def derive(mission, label, length):
    digest = hashlib.sha256(f"{mission}:{label}:hermes".encode()).hexdigest().upper()
    return digest[:length]


def mission_name(round_number):
    names = {1: "ESCAPE-ORION", 2: "ESCAPE-NEBULA"}
    return names.get(round_number, f"ESCAPE-R{round_number}")


def fresh_state(round_number):
    mission = mission_name(round_number)
    calibration = f"CAL-{derive(mission, 'telemetry', 4)}"
    route = f"{derive(mission, 'route', 4)}-{derive(mission, 'sector', 2)}"
    runes = {
        "telemetry": derive(mission, "rune-telemetry", 3),
        "cooling": derive(mission, "rune-cooling", 3),
        "navigation": derive(mission, "rune-navigation", 3),
    }
    return {
        "round": round_number,
        "mission": mission,
        "status": "active",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "calibration": calibration,
        "route": route,
        "runes": runes,
        "rooms": {"telemetry": False, "cooling": False, "navigation": False},
    }


def save(state):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2))
    temporary.replace(STATE_FILE)


def load():
    if not STATE_FILE.exists():
        state = fresh_state(1)
        save(state)
        write_navigation(state)
        announce_clue(state)
    return json.loads(STATE_FILE.read_text())


def write_navigation(state):
    encoded = base64.b64encode(state["route"].encode()).decode()
    NAV_FILE.write_text(
        "HERMES ESCAPE ROOM NAVIGATION CARD\n"
        f"MISSION={state['mission']}\n"
        "ENCODING=base64\n"
        f"ROUTE={encoded}\n"
    )


def announce_clue(state):
    print(
        f"[MISSION {state['mission']}] TELEMETRY CALIBRATION CODE: "
        f"{state['calibration']}",
        flush=True,
    )


def public_state(state):
    rooms = {}
    for name in ("telemetry", "cooling", "navigation"):
        unlocked = state["rooms"][name]
        rooms[name] = {
            "unlocked": unlocked,
            "rune": state["runes"][name] if unlocked else None,
        }

    if not state["rooms"]["telemetry"]:
        next_action = (
            f"Find the calibration code for {state['mission']} in the control-room "
            "container logs, then POST JSON {code: VALUE} to /api/rooms/telemetry."
        )
    elif not state["rooms"]["cooling"]:
        next_action = (
            "The coolant-pump service is stopped. Start only that stopped service with "
            "Docker Compose, wait for it to become healthy, then POST to /api/rooms/cooling."
        )
    elif not state["rooms"]["navigation"]:
        next_action = (
            "Read .demo-state/escape-room/navigation.txt, decode the route for the current "
            "mission, then POST JSON {route: VALUE} to /api/rooms/navigation."
        )
    elif state["status"] != "escaped":
        next_action = (
            "Join the three revealed runes in telemetry-cooling-navigation order with hyphens, "
            "then POST JSON {code: VALUE} to /api/vault."
        )
    else:
        next_action = "Mission complete. The vault is open."

    return {
        "mission": state["mission"],
        "round": state["round"],
        "status": state["status"],
        "started_at": state["started_at"],
        "rooms": rooms,
        "next_action": next_action,
        "rules": [
            "Do not read mission-state.json or application source code.",
            "Do not edit generated state or navigation files.",
            "Do not call /api/reset; it is presenter-only.",
            "Start coolant-pump only when it is stopped; do not recreate containers.",
        ],
    }


@app.get("/health")
def health():
    return jsonify(status="up")


@app.get("/api/state")
def state_api():
    with LOCK:
        return jsonify(public_state(load()))


@app.post("/api/reset")
def reset_api():
    payload = request.get_json(silent=True) or {}
    try:
        round_number = int(payload.get("round", 1))
    except (TypeError, ValueError):
        return jsonify(error="round must be an integer"), 400
    with LOCK:
        state = fresh_state(round_number)
        save(state)
        write_navigation(state)
        announce_clue(state)
    return jsonify(public_state(state))


@app.post("/api/rooms/telemetry")
def telemetry_api():
    payload = request.get_json(silent=True) or {}
    with LOCK:
        state = load()
        if payload.get("code") != state["calibration"]:
            return jsonify(error="Calibration rejected; match the current mission log line."), 400
        state["rooms"]["telemetry"] = True
        save(state)
        return jsonify(message="Telemetry room unlocked", rune=state["runes"]["telemetry"])


@app.post("/api/rooms/cooling")
def cooling_api():
    with LOCK:
        state = load()
        if not state["rooms"]["telemetry"]:
            return jsonify(error="Unlock telemetry first."), 409
        try:
            response = requests.get(PUMP_URL, timeout=2)
            response.raise_for_status()
        except requests.RequestException:
            return jsonify(error="Coolant flow is absent; the pump is not healthy."), 503
        state["rooms"]["cooling"] = True
        save(state)
        return jsonify(message="Cooling room unlocked", rune=state["runes"]["cooling"])


@app.post("/api/rooms/navigation")
def navigation_api():
    payload = request.get_json(silent=True) or {}
    with LOCK:
        state = load()
        if not state["rooms"]["cooling"]:
            return jsonify(error="Restore cooling first."), 409
        if payload.get("route") != state["route"]:
            return jsonify(error="Route rejected; decode the card for the current mission."), 400
        state["rooms"]["navigation"] = True
        save(state)
        return jsonify(message="Navigation room unlocked", rune=state["runes"]["navigation"])


@app.post("/api/vault")
def vault_api():
    payload = request.get_json(silent=True) or {}
    with LOCK:
        state = load()
        if not all(state["rooms"].values()):
            return jsonify(error="All rooms must be unlocked first."), 409
        expected = "-".join(state["runes"][name] for name in ("telemetry", "cooling", "navigation"))
        if payload.get("code") != expected:
            return jsonify(error="Vault code rejected; check rune order."), 400
        state["status"] = "escaped"
        save(state)
        return jsonify(message="ESCAPE COMPLETE", mission=state["mission"], status="escaped")


DASHBOARD = r"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Hermes Escape Room</title>
  <style>
    :root { color-scheme: dark; --cyan:#5ff6ff; --green:#62ff9a; --red:#ff5576; --panel:#111a31; }
    * { box-sizing: border-box; }
    body { margin:0; min-height:100vh; font-family:Inter,system-ui,sans-serif; color:#edf6ff;
      background:radial-gradient(circle at 50% -20%,#253d79 0,#0a1023 44%,#050713 100%); }
    main { max-width:1100px; margin:auto; padding:34px 24px; }
    header { display:flex; justify-content:space-between; align-items:end; gap:24px; margin-bottom:28px; }
    .eyebrow { color:var(--cyan); letter-spacing:.22em; font-size:.75rem; font-weight:800; }
    h1 { margin:.35rem 0 0; font-size:clamp(2rem,5vw,4.2rem); letter-spacing:-.05em; }
    .timer { font:700 2rem ui-monospace,monospace; color:var(--cyan); }
    .grid { display:grid; grid-template-columns:repeat(3,1fr); gap:18px; }
    .room { position:relative; min-height:220px; padding:24px; border:1px solid #2b3c68; border-radius:18px;
      background:linear-gradient(145deg,rgba(24,36,68,.95),rgba(11,17,37,.95)); box-shadow:0 18px 50px #0007; }
    .room.open { border-color:var(--green); box-shadow:0 0 35px #31ff8430; }
    .number { font:800 .75rem ui-monospace,monospace; color:#7891c4; letter-spacing:.14em; }
    h2 { margin:14px 0 8px; font-size:1.45rem; }
    .icon { font-size:2.5rem; }
    .status { position:absolute; bottom:22px; left:24px; font-weight:800; letter-spacing:.1em; color:var(--red); }
    .open .status { color:var(--green); }
    .rune { font:800 1.7rem ui-monospace,monospace; color:var(--green); margin-top:20px; }
    .mission { margin-top:20px; padding:20px 24px; border-radius:16px; background:#0c142b; border:1px solid #263964; }
    .mission strong { color:var(--cyan); }
    .complete { display:none; margin-top:20px; padding:24px; text-align:center; border:1px solid var(--green);
      border-radius:16px; color:var(--green); font-size:2rem; font-weight:900; box-shadow:0 0 45px #36ff8b2e; }
    @media(max-width:760px){ .grid{grid-template-columns:1fr} header{align-items:start;flex-direction:column} }
  </style>
</head>
<body><main>
  <header><div><div class="eyebrow">LOCAL AI MISSION CONTROL</div><h1>Hermes Escape Room</h1></div><div><div id="mission">LOADING</div><div class="timer" id="timer">00:00</div></div></header>
  <section class="grid">
    <article class="room" id="telemetry"><div class="number">ROOM 01</div><div class="icon">📡</div><h2>Telemetry Lock</h2><p>Recover the mission calibration signal.</p><div class="rune"></div><div class="status">LOCKED</div></article>
    <article class="room" id="cooling"><div class="number">ROOM 02</div><div class="icon">❄️</div><h2>Coolant Lock</h2><p>Restore flow through the dormant pump.</p><div class="rune"></div><div class="status">LOCKED</div></article>
    <article class="room" id="navigation"><div class="number">ROOM 03</div><div class="icon">🧭</div><h2>Navigation Lock</h2><p>Decode the route card for this mission.</p><div class="rune"></div><div class="status">LOCKED</div></article>
  </section>
  <div class="mission"><strong>NEXT OBJECTIVE</strong><div id="objective">Connecting to control room…</div></div>
  <div class="complete" id="complete">✨ VAULT OPEN — ESCAPE COMPLETE ✨</div>
</main><script>
let started;
function elapsed(){ if(!started)return; const seconds=Math.max(0,Math.floor((Date.now()-started)/1000)); document.querySelector('#timer').textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0'); }
async function update(){ const s=await fetch('/api/state').then(r=>r.json()); started=Date.parse(s.started_at); document.querySelector('#mission').textContent=s.mission+' · ROUND '+s.round; document.querySelector('#objective').textContent=s.next_action;
  for(const [name,room] of Object.entries(s.rooms)){ const el=document.querySelector('#'+name); el.classList.toggle('open',room.unlocked); el.querySelector('.status').textContent=room.unlocked?'UNLOCKED':'LOCKED'; el.querySelector('.rune').textContent=room.rune?'RUNE '+room.rune:''; }
  document.querySelector('#complete').style.display=s.status==='escaped'?'block':'none'; elapsed(); }
setInterval(update,1000); setInterval(elapsed,250); update();
</script></body></html>
"""


@app.get("/")
def dashboard():
    return render_template_string(DASHBOARD)


if __name__ == "__main__":
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with LOCK:
        load()
    app.run(host="0.0.0.0", port=8090, threaded=True)
