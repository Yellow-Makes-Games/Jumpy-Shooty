#!/usr/bin/env bash
# The map terminal and the low gravity event in real matches on Halcyon:
#  - online, a client stands at the terminal and presses interact: the host checks it
#    and starts the event, and both copies run it from the same moment;
#  - a client that holds from across the room starts nothing;
#  - a player who joins while the event is running is told how far along it is;
#  - bots told to be keen (--eager-terminal) walk up and fire it, and keep fighting
#    through the low gravity;
#  - no script errors anywhere.
# (The rules themselves are checked step by step in tests/terminal_test.gd and
# tests/gravity_test.gd.)
# Usage: tests/run_gravity_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/gravity_*.log
PORT=$((25600 + RANDOM % 100))
COMMON=(--sync-log --map=halcyon)

# 1. A client fires it. P2 spawns beside the console and presses interact (for 0.3 s).
"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --autostart=2 --spawn=-40,-5.8,0,0 \
  --quit-after=20 "${COMMON[@]}" > "$OUT/gravity_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --spawn=1.3,1.3,0,90 --hold=7:interact:0.3 \
  --quit-after=18 "${COMMON[@]}" > "$OUT/gravity_client.log" 2>&1 &
# 2. Out of range, and a late joiner. P2 holds from the edge of the room (nothing may
#    happen); the host starts the event itself at 9 s; P3 joins at about 13 s.
PORT2=$((PORT + 100))
"$GODOT" --headless --path . -- --host --port="$PORT2" --name=P1 --autostart=2 --spawn=-40,-5.8,0,0 --map-event=9 \
  --quit-after=22 "${COMMON[@]}" > "$OUT/gravity_far_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT2" --name=P2 --spawn=11,0.2,0,90 --hold=4:interact:3.5 \
  --quit-after=20 "${COMMON[@]}" > "$OUT/gravity_far_client.log" 2>&1 &
sleep 12
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT2" --name=P3 --spawn=40,-5.8,0,0 \
  --quit-after=7 "${COMMON[@]}" > "$OUT/gravity_late.log" 2>&1 &
# 3. Bots.
timeout 120 "$GODOT" --headless --path . -- --bot=2 --bots=4 --eager-terminal --kill-target=99 --quit-after=45 "${COMMON[@]}" \
  > "$OUT/gravity_bots.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/gravity_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import re, sys
out = sys.argv[1]
ok = True


def lines(name):
    return open(f"{out}/gravity_{name}.log", errors="replace").read().splitlines()


def events(name):
    """(log line number, running, seconds in) for every event message this copy applied."""
    found = []
    for i, line in enumerate(lines(name)):
        m = re.match(r"MAP_EVENT 0 (on|off) ([\d.]+)", line)
        if m:
            found.append((i, m.group(1) == "on", float(m.group(2))))
    return found


def check(cond, what):
    global ok
    print(("ok   " if cond else "FAIL ") + what)
    ok = ok and cond


host, client = events("host"), events("client")
started_by = [l for l in lines("host") if l.startswith("[map] LowGravity started by")]
check(len(started_by) == 1 and "P2" in started_by[0], f"a client pressing interact at the terminal starts the event on the host ({started_by})")
check(bool(host) and host[0][1] and host[0][2] == 0.0, "the host runs it from the start")
check(bool(client) and client[0][1] and client[0][2] < 0.5, "the client is told and runs it from the same moment")

far_started = [l for l in lines("far_host") if l.startswith("[map] LowGravity started")]
check(len(far_started) == 1 and "by" not in far_started[0], f"holding from across the room starts nothing (only the host's own start: {far_started})")
late = events("late")
check(bool(late) and late[0][1] and late[0][2] > 1.0, f"a player who joins mid-event is told how far along it is ({late[0][2] if late else 'never'} s)")

bots = [l for l in lines("bots") if l.startswith("[map] LowGravity started by")]
check(len(bots) >= 1, f"a bot walks up and fires the terminal ({bots[:1]})")
# Bots keep moving through the low gravity: none stands on one spot for 10 s after it starts.
seen_event = False
tracks = {}
for line in lines("bots"):
    if line.startswith("MAP_EVENT 0 on"):
        seen_event = True
    m = re.match(r"BOT (\d+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", line)
    if m and seen_event:
        tracks.setdefault(m.group(1), []).append(tuple(float(v) for v in m.groups()[1:]))
stuck = []
for bot, track in tracks.items():
    run, anchor, worst = 0, None, 0
    for p in track:
        if anchor and sum(abs(a - b) for a, b in zip(p, anchor)) < 1.0:
            run += 1
        else:
            anchor, run = p, 0
        worst = max(worst, run)
    if worst >= 10:
        stuck.append((bot, worst))
check(bool(tracks) and not stuck, f"no bot gets stuck in low gravity ({len(tracks)} bots tracked, stuck: {stuck})")
print("PASS: gravity test" if ok else "FAIL: gravity test")
sys.exit(0 if ok else 1)
PY
exit $fail
