#!/usr/bin/env bash
# Golden Gun test: real matches, headless. Checks that:
#  - when the match starts one player has the Golden Gun, and only one at a time
#  - whoever kills the holder takes it (and the holder gets their own weapon back);
#    a holder who dies with nobody to credit hands it to someone else
#  - every kill with it loads the next round at once
#  - the match ends at the kill target
#  - online, the host and a client (on a laggy network) see the same hand-overs and
#    agree on the results
#  - there are no script errors
# Usage: tests/run_golden_gun_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/golden_*.log
MAP="${MAP:-construction_site}"
PORT=$((25700 + RANDOM % 200))
TARGET=8

# Vs Bots, on a fixed game clock: you and 3 Hard bots, first to $TARGET kills.
timeout 300 "$GODOT" --fixed-fps 60 --headless --path . -- --game-clock --bot=2 --bots=3 --rules=golden --kill-target=$TARGET \
  --time-limit=150 --map="$MAP" --scripted-input --scripted-fire --sync-log --quit-after=165 > "$OUT/golden_bot.log" 2>&1 &
# Online (real time): a host and a client who both move and shoot on their own.
COMMON=(--scripted-input --scripted-fire --sync-log --map="$MAP" --quit-after=150)
"$GODOT" --headless --path . -- --host --port="$PORT" --name=Host --weapon=rifle --autostart=2 --rules=golden \
  --kill-target=$TARGET --time-limit=100 "${COMMON[@]}" > "$OUT/golden_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=Client --weapon=shotgun --net-sim=80,20,2 "${COMMON[@]}" \
  > "$OUT/golden_client.log" 2>&1 &
for _ in $(seq 1 150); do
  sleep 1
  if grep -q "^MATCH_OVER" "$OUT/golden_client.log" 2>/dev/null && grep -q "^MATCH_OVER" "$OUT/golden_host.log"; then sleep 2; break; fi
done
pkill -f -- "--port=$PORT" || true
pkill -f -- "--join=127.0.0.1:$PORT" || true
wait || true

python3 - "$OUT" "$TARGET" <<'PY'
import json, re, sys
out, target = sys.argv[1], int(sys.argv[2])
fail = False
passes_seen = 0

def read(name):
    return open(f"{out}/golden_{name}.log", errors="replace").read()

def bad(msg):
    global fail
    fail = True
    print("  FAIL:", msg)

def first_match(log):
    """The log up to the end of the first match."""
    m = re.search(r"^MATCH_OVER .*$", log, re.M)
    return log[:m.end()] if m else log

def check(name, log):
    global passes_seen
    if "SCRIPT ERROR" in log:
        bad(f"{name}: script errors")
    me = re.search(r"^GOLDEN (\d+) ", log, re.M)
    if not me:
        bad(f"{name}: nobody got the Golden Gun"); return None
    log = first_match(log)
    me = int(me.group(1))
    local = lambda pid: pid == me or (pid >= 9001 and name != "Online client")   # (bots run on the host)
    # Walk the match in order. The host hands the gun over (GOLDEN) just before the
    # death goes out (KILL_SCORE), and the reload comes with the hand-over too.
    events = re.findall(r"^(GOLDEN|GOLDEN_RELOAD|KILL_SCORE) (\d+) (\d+)(?: (\d+))?", log, re.M)
    holder, reloads, kills_with, passes, starts = 0, 0, 0, [], 0
    last_pass = None   # (from, to): waiting for the kill of `from` that caused it
    for kind, a, b, c in events:
        if kind == "GOLDEN":
            to, frm = int(b), int(c)
            if frm == 0:
                starts += 1
                if holder != 0:
                    bad(f"{name}: the Golden Gun was handed out afresh while {holder} still had it")
            elif frm != holder:
                bad(f"{name}: it went from {frm}, but {holder} had it")
            else:
                passes.append((frm, to))
                last_pass = (frm, to)
            holder = to
        elif kind == "GOLDEN_RELOAD":
            reloads += 1
        else:   # KILL_SCORE seq killer victim
            killer, victim = int(b), int(c)
            if last_pass and victim == last_pass[0]:
                if killer != last_pass[1]:
                    bad(f"{name}: {killer} killed the holder {victim}, but the Golden Gun went to {last_pass[1]}")
                last_pass = None
            elif victim == holder and killer != victim:
                bad(f"{name}: {killer} killed the holder {victim} and did not get the Golden Gun")
            elif killer == holder and local(killer):
                kills_with += 1
    if reloads != kills_with:
        bad(f"{name}: {kills_with} kills with the Golden Gun here, but {reloads} rounds came back")
    if starts != 1:
        bad(f"{name}: the Golden Gun should be handed out once at the start, not {starts} times")
    passes_seen += len(passes)
    over = re.findall(r"^MATCH_OVER (.*)$", log, re.M)
    rows = json.loads(over[0]) if over else []
    print(f"{name}: hand-overs {passes}, kills with it {kills_with}, rounds back {reloads}, "
          f"results {[(r['name'], r['kills']) for r in rows]}")
    if not rows:
        bad(f"{name}: the match never ended")
    elif rows[0]["kills"] != target:
        print(f"  ({name} ended on the clock: the winner had {rows[0]['kills']} kills)")
    return [(f, t) for f, t in passes], rows

bot = check("Vs Bots", read("bot"))
host = check("Online host", read("host"))
client = check("Online client", read("client"))
if host and client:
    if host[0] != client[0]:
        bad(f"the host and the client saw different hand-overs:\n    host   {host[0]}\n    client {client[0]}")
    if host[1] != client[1]:
        bad("the host and the client disagree on the results")
if passes_seen == 0:
    bad("nobody ever took the Golden Gun from its holder (in any of the matches)")

print("GOLDEN GUN TEST", "FAILED" if fail else "PASSED")
sys.exit(1 if fail else 0)
PY
