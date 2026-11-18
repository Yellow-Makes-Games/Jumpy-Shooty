#!/usr/bin/env bash
# The online lobby: size, ready and kick, with real copies of the game.
#  - the host sets the lobby size to 3; P2 and P3 join, P4 is refused (the lobby is full)
#  - P2 readies up; P3 never does, so the host cannot start (--start-when-ready tries
#    every time the lobby changes)
#  - the host kicks P3, who is sent back to the menu and told why; with only ready
#    players left, the match starts (for the host and P2)
#  - no script errors anywhere
# (The rules and the lobby screen are checked step by step in tests/lobby_settings_test.gd.)
# Usage: tests/run_lobby_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/lobbyroom_*.log
PORT=$((26100 + RANDOM % 100))
COMMON=(--sync-log --scripted-input --map=construction_site)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --lobby-size=3 --start-when-ready --kick-at=8:P3 \
  --quit-after=16 "${COMMON[@]}" > "$OUT/lobbyroom_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --ready-at=3 --quit-after=14 "${COMMON[@]}" \
  > "$OUT/lobbyroom_p2.log" 2>&1 &
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P3 --quit-after=14 "${COMMON[@]}" \
  > "$OUT/lobbyroom_p3.log" 2>&1 &
sleep 4
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P4 --quit-after=8 "${COMMON[@]}" \
  > "$OUT/lobbyroom_p4.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/lobbyroom_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import sys
out = sys.argv[1]
ok = True


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def lines(name):
    return open(f"{out}/lobbyroom_{name}.log", errors="replace").read().splitlines()


def first(name, prefix):
    for i, line in enumerate(lines(name)):
        if line.startswith(prefix):
            return i, line
    return None, ""


_, p4 = first("p4", "SESSION_ENDED ")
check("full" in p4, f"P4 is refused: the lobby of 3 is full ({p4 or 'never told'})")
_, p3 = first("p3", "SESSION_ENDED ")
check("removed" in p3, f"P3 is kicked and told why ({p3 or 'never told'})")
check(first("p3", "MATCH_START")[0] is None, "P3 never starts the match")
ready_at, _ = first("host", "READY ")
kick_at, _ = first("host", "KICKED ")
start_at, start = first("host", "MATCH_START")
check(ready_at is not None, "the host hears P2 ready up")
check(kick_at is not None, "the host kicks P3")
check(start_at is not None and kick_at is not None and start_at > kick_at and start_at > ready_at,
      f"the match starts only once everyone left is ready, after the kick ({start})")
check(start.startswith("MATCH_START 2 "), "two players start it (P3 is gone)")
check(first("p2", "MATCH_START 2 ")[0] is not None, "P2 starts the match too")
print("PASS: lobby test" if ok else "FAIL: lobby test")
sys.exit(0 if ok else 1)
PY
exit $fail
