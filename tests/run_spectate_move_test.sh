#!/usr/bin/env bash
# The host moves a player to the spectators, and they come back when there is room:
#  - the lobby takes 2 players; P2 joins; the host moves P2 to the spectators, and P2
#    is told so (MOVED_BY_HOST)
#  - P3 takes the free player slot, so the lobby is full again; P2 presses Play and
#    the host refuses (SPECTATE_FULL): no room
#  - the host kicks P3; P2 presses Play again and is back in as a player
#  - no script errors anywhere
# Usage: tests/run_spectate_move_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/specmove_*.log
PORT=$((26300 + RANDOM % 100))
COMMON=(--sync-log --scripted-input --map=construction_site)

# Times are seconds after each copy's lobby opens (P2 opens about 2 s after the host).
"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --lobby-size=2 --move-at=5:P2 --kick-at=17:P3 \
  --quit-after=28 "${COMMON[@]}" > "$OUT/specmove_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --play-at=11,20 --quit-after=26 "${COMMON[@]}" \
  > "$OUT/specmove_p2.log" 2>&1 &
sleep 7
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P3 --quit-after=18 "${COMMON[@]}" \
  > "$OUT/specmove_p3.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/specmove_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import sys
out = sys.argv[1]
ok = True


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def lines(name):
    return open(f"{out}/specmove_{name}.log", errors="replace").read().splitlines()


host = lines("host")
def at(prefix, start=0):
    for i in range(start, len(host)):
        if host[i].startswith(prefix):
            return i
    return None

moved = at("MOVED_TO_SPECTATORS ")
check(moved is not None, "the host moves P2 to the spectators")
p2 = host[moved].split()[1] if moved is not None else "?"
check(any(l == "MOVED_BY_HOST" for l in lines("p2")), "P2 is told the host moved it")
full = at(f"SPECTATE_FULL {p2}")
kicked = at("KICKED ")
back = at(f"SPECTATE {p2} off")
check(full is not None and kicked is not None and full < kicked, "while P3 fills the lobby, P2's Play is refused (no room)")
check(back is not None and kicked is not None and back > kicked, "once P3 is kicked, P2's Play puts it back in as a player")
presses = [l for l in lines("p2") if l == "PLAY_PRESSED"]
check(len(presses) == 2, f"P2 pressed Play twice ({len(presses)})")
print("PASS: spectate move test" if ok else "FAIL: spectate move test")
sys.exit(0 if ok else 1)
PY
exit $fail
