#!/usr/bin/env bash
# Breakable walls and floors, online (Construction Site, laggy network):
#  - the host stands on the tower's first floor and shoots the floor under its feet:
#    the floor breaks and it falls through to the ground;
#  - a client shoots a block wall on the same floor until it breaks;
#  - a second client joins while the match is on and must be shown what is already
#    broken;
#  - every copy ends with the same cracked and broken pieces, with no script errors.
# Usage: tests/run_break_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT=$((25300 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/break_*.log
COMMON=(--sync-log --map=construction_site --net-sim=80,30,3)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --autostart=2 --spawn=-9,4.2,-7,0,-89 \
  --weapon=sniper --hold=5:fire:0.3 --hold=6.6:fire:0.3 --hold=8.2:fire:0.3 --hold=9.8:fire:0.3 --hold=11.4:fire:0.3 --quit-after=22 "${COMMON[@]}" > "$OUT/break_1.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --spawn=-10,4.2,-11,0 --weapon=rifle \
  --hold=5:fire:5 --quit-after=22 "${COMMON[@]}" > "$OUT/break_2.log" 2>&1 &
sleep 11
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P3 --spawn=30,0.2,30,0 --weapon=pistol \
  --quit-after=10 "${COMMON[@]}" > "$OUT/break_3.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/break_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import glob, sys
out = sys.argv[1]
ok = True
final = {}
for path in sorted(glob.glob(f"{out}/break_*.log")):
    state = None
    for line in open(path, errors="replace"):
        if line.startswith("BROKEN_STATE "):
            state = line.split(" ", 1)[1].strip()
    final[path] = state
    print(f"{path}: {state}")
states = set(final.values())
if None in states:
    print("FAIL: a copy never heard about any broken piece (the late joiner must be told)"); ok = False
elif len(states) != 1:
    print("FAIL: copies disagree about what is broken"); ok = False
else:
    broken = int(list(states)[0].split()[0].split("/")[1])
    if broken < 2:
        print(f"FAIL: expected the floor and the wall to break, {broken} broken"); ok = False
# The host was standing on the first floor (y about 4) and shot it out from under itself
# with the sniper rifle (three shots break a piece of concrete floor).
ys = []
for line in open(f"{out}/break_1.log", errors="replace"):
    p = line.split()
    if line.startswith("SYNC SELF 1 "):
        ys.append(float(p[5]))
if not ys or max(ys) < 3.5:
    print("FAIL: the host never stood on the first floor"); ok = False
elif min(ys) > 1.0:
    print(f"FAIL: the host did not fall through the broken floor (lowest {min(ys):.2f} m)"); ok = False
else:
    print(f"the host fell through the floor it broke: {max(ys):.1f} m -> {min(ys):.1f} m")
print("PASS: break test" if ok else "FAIL: break test")
sys.exit(0 if ok else 1)
PY
exit $fail
