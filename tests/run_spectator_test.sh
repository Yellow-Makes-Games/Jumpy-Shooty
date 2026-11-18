#!/usr/bin/env bash
# Spectating online: a host plays, one client joins to play and one joins mid-match to
# spectate (--spectate). The spectator sees the players move, but nobody sees a robot for
# the spectator (no movement from it reaches anyone) and it is never on the player list.
# Usage: tests/run_spectator_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/spectator_*.log
MAP="${MAP:-construction_site}"
PORT=$((26100 + RANDOM % 100))
COMMON=(--scripted-input --sync-log --map="$MAP")

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --autostart=2 --time-limit=60 --quit-after=22 "${COMMON[@]}" \
  > "$OUT/spectator_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --quit-after=20 "${COMMON[@]}" > "$OUT/spectator_player.log" 2>&1 &
sleep 7
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=Watcher --spectate --quit-after=12 "${COMMON[@]}" \
  > "$OUT/spectator_watcher.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR\|^ERROR" "$OUT"/spectator_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import re, sys
out = sys.argv[1]
ok = True


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def text(name):
    return open(f"{out}/spectator_{name}.log", errors="replace").read()


host, player, watcher = text("host"), text("player"), text("watcher")
m = re.search(r"\[net\] (\d+) joined to spectate as Watcher", host)
check(m is not None, "the host has the watcher as a spectator")
wid = m.group(1) if m else "?"
check(f"[net] {wid} joined as" not in host, "the watcher never joined as a player")
seen = lambda log, by: set(re.findall(rf"SYNC SEEN {by} (\d+) ", log)) if by else set(re.findall(r"SYNC SEEN \d+ (\d+) ", log))
watched = set(re.findall(r"SYNC SEEN \d+ (\d+) ", watcher))
check(len(watched) >= 2, f"the spectator sees both players move ({sorted(watched)})")
check(wid not in seen(host, None) and wid not in seen(player, None), "nobody sees the spectator (no robot, no movement from it)")
loadouts = [l for l in host.splitlines() if l.startswith("LOADOUTS")]
check(all(f" {wid}:" not in l and f"{wid}=" not in l for l in loadouts), "the spectator is never on the player list")
sys.exit(0 if ok else 1)
PY
if [ "$fail" = 0 ]; then echo "PASS: spectator test"; else echo "FAIL: spectator test (logs in $OUT/spectator_*.log)"; exit 1; fi
