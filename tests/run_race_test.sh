#!/usr/bin/env bash
# Race mode test. Headless, in game time (--fixed-fps 60 --game-clock), so it plays
# out the same however slowly the machine runs. Checks that:
#  - on every race map, a race against 4 bots (Normal) with your own racer on
#    autopilot (Expert) ends with all 5 having finished, in time order, and the
#    results are race results; "Race again" starts a second race
#  - Easy bots get round every course too
#  - fail conditions: touching a hazard, falling off the course and pressing R
#    each put you back at your checkpoint
#  - an online race (host and one client, both on autopilot) finishes for both,
#    and the client sees the same finishers as the host
#  - there are no script errors
# Usage: tests/run_race_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/race_*.log
RUN=(--headless --fixed-fps 60 --path . --)
MAPS=(rooftop_run foundry sky_ruins summit_plunge)

for map in "${MAPS[@]}"; do
  timeout 400 "$GODOT" "${RUN[@]}" --bot=1 --bots=4 --map="$map" --autopilot --bot-level=3 --sync-log --game-clock \
    --auto-return --quit-after=200 > "$OUT/race_$map.log" 2>&1 &
  timeout 400 "$GODOT" "${RUN[@]}" --bot=0 --bots=2 --map="$map" --autopilot --bot-level=0 --sync-log --game-clock \
    --quit-after=150 > "$OUT/race_easy_$map.log" 2>&1 &
done
# Fail conditions on Foundry: dropped onto the molten pool between the pistons
# (a hazard), dropped beside the Sky Ruins course (a fall), and R.
timeout 60 "$GODOT" "${RUN[@]}" --practice --map=foundry --spawn=62.75,6,3,90 --sync-log --game-clock \
  --quit-after=6 > "$OUT/race_hazard.log" 2>&1 &
timeout 60 "$GODOT" "${RUN[@]}" --practice --map=sky_ruins --spawn=40,4,40,0 --sync-log --game-clock \
  --quit-after=8 > "$OUT/race_fall.log" 2>&1 &
timeout 60 "$GODOT" "${RUN[@]}" --practice --map=foundry --hold=4:move_forward:1.5 --press=6:reload --sync-log --game-clock \
  --quit-after=8 > "$OUT/race_reset.log" 2>&1 &
wait

# Online: host and one client race Sky Ruins.
PORT=24790
timeout 300 "$GODOT" "${RUN[@]}" --host --port=$PORT --name=Host --autostart=2 --map=sky_ruins --autopilot --sync-log \
  --quit-after=130 > "$OUT/race_host.log" 2>&1 &
sleep 2
timeout 300 "$GODOT" "${RUN[@]}" --join=127.0.0.1:$PORT --name=Guest --autopilot --sync-log \
  --quit-after=128 > "$OUT/race_client.log" 2>&1 &
wait

python3 - "$OUT" "${MAPS[@]}" <<'EOF'
import json, re, sys
out, maps = sys.argv[1], sys.argv[2:]
fails = []

def read(name):
    return open(f"{out}/race_{name}.log", errors="replace").read()

def results(text):
    return [json.loads(m) for m in re.findall(r"^MATCH_OVER (\[.*\])$", text, re.M)]

for name in [f"{m}" for m in maps] + [f"easy_{m}" for m in maps] + ["hazard", "fall", "reset", "host", "client"]:
    if "SCRIPT ERROR" in read(name):
        fails.append(f"{name}: script errors")

for m in maps:
    text = read(m)
    games = results(text)
    if not games:
        fails.append(f"{m}: the race never ended")
        continue
    rows = games[0]
    done = [r for r in rows if r.get("finished")]
    times = [r["time"] for r in done]
    print(f"  {m}: {len(done)}/{len(rows)} finished, times {', '.join('%.1f' % t for t in times)}")
    if len(rows) != 5 or len(done) != 5:
        fails.append(f"{m}: {len(done)} of {len(rows)} racers finished")
    if times != sorted(times):
        fails.append(f"{m}: results are not in finishing order")
    if not all(r.get("race") for r in rows):
        fails.append(f"{m}: results are not race results")
    if len(games) < 2 and text.count("RACE_GATE 1 1 ") < 2:
        fails.append(f"{m}: 'Race again' did not start a second race")
    easy = results(read(f"easy_{m}"))
    if not easy or not all(r.get("finished") for r in easy[0]):
        fails.append(f"easy {m}: not every Easy bot finished")
    else:
        print(f"  {m} (Easy): all {len(easy[0])} finished")

checks = {"hazard": "RACE_BACK 1 hazard", "fall": "RACE_BACK 1 fell", "reset": "RACE_BACK 1 reset"}
for name, needle in checks.items():
    ok = needle in read(name)
    print(f"  {name}: {'sent back' if ok else 'NOT sent back'}")
    if not ok:
        fails.append(f"{name}: never sent back to the checkpoint")

host, client = results(read("host")), results(read("client"))
if not host or not client:
    fails.append("online: the race did not end for both players")
else:
    hf = sorted(r["id"] for r in host[0] if r.get("finished"))
    cf = sorted(r["id"] for r in client[0] if r.get("finished"))
    print(f"  online: host saw {len(hf)} finishers, client saw {len(cf)}")
    if len(hf) != 2 or hf != cf:
        fails.append(f"online: finishers differ or missing (host {hf}, client {cf})")

if fails:
    print("FAIL:\n  " + "\n  ".join(fails))
    sys.exit(1)
print("PASS")
EOF
