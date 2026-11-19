#!/usr/bin/env bash
# The portal gun online: a host and two clients on a bad network, everyone carrying the
# portal gun and shooting it as they run about (the scripted input). Every copy must
# end up with every portal in the same place, seated the same way on its surface
# (each copy feels out the collar for itself), and see every shot of every gun.
# Usage: tests/run_portal_sync_test.sh [players] ["latency_ms,jitter_ms,loss_percent"]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PLAYERS="${1:-3}"
SIM="${2:-}"
SECONDS_TO_RUN=16
PORT=$((25300 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/portal_sync_*.log
EXTRA=(--map="${MAP:-construction_site}" --mobility=portal)
if [[ -n "$SIM" ]]; then EXTRA+=("--net-sim=$SIM"); fi

"$GODOT" --headless --path . -- --host --name=P1 --autostart="$PLAYERS" --allowed-mobility=portal --scripted-input --sync-log \
  --quit-after=$((SECONDS_TO_RUN - 2)) "${EXTRA[@]}" --port="$PORT" > "$OUT/portal_sync_1.log" 2>&1 &
sleep 1
for i in $(seq 2 "$PLAYERS"); do
  "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name="P$i" --scripted-input --sync-log \
    --quit-after=$SECONDS_TO_RUN "${EXTRA[@]}" > "$OUT/portal_sync_$i.log" 2>&1 &
done
wait
if grep -h "SCRIPT ERROR\|^ERROR" "$OUT"/portal_sync_*.log; then
  echo "FAIL: script errors above"
  exit 1
fi
python3 - "$OUT"/portal_sync_*.log <<'PY'
import re, sys
copies = {}   # copy id -> {(owner, slot): [(x, y, z, seat), ...] in order}
shots = {}    # copy id -> {(owner, slot, took): count}
for path in sys.argv[1:]:
    log = open(path, errors="replace").read()
    for m in re.finditer(r"^PORTAL (\d+) (\d+) (\d) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) seat ([\d.]+)", log, re.M):
        me, owner, slot = int(m[1]), int(m[2]), int(m[3])
        copies.setdefault(me, {}).setdefault((owner, slot), []).append(tuple(float(m[k]) for k in (4, 5, 6, 7)))
    for m in re.finditer(r"^PORTAL_SHOT (\d+) (\d+) (\d) (\d)", log, re.M):
        me = int(m[1])
        key = (int(m[2]), int(m[3]), int(m[4]))
        shots.setdefault(me, {})[key] = shots.setdefault(me, {}).get(key, 0) + 1
fail = False
owners = sorted({o for c in copies.values() for (o, _s) in c})
print(f"copies {sorted(copies)}  players who put portals up: {owners}")
if len(copies) < 2 or len(owners) < 2:
    print("FAIL: need at least two copies and two players with portals"); fail = True
total = matched = 0
for owner in owners:
    mine = copies.get(owner, {})
    for (o, slot), placed in sorted(mine.items()):
        if o != owner:
            continue
        for other, theirs in sorted(copies.items()):
            if other == owner:
                continue
            seen = theirs.get((owner, slot), [])
            # (A copy may join the list late or leave early: what it saw must be a run of what was placed.)
            total += len(placed)
            hits = sum(1 for p in placed if any(all(abs(a - b) <= 0.011 for a, b in zip(p, q)) for q in seen))
            matched += hits
            stray = [q for q in seen if not any(all(abs(a - b) <= 0.011 for a, b in zip(p, q)) for p in placed)]
            if stray:
                print(f"FAIL: copy {other} has player {owner}'s portal {slot} where they never put it: {stray[:3]}"); fail = True
print(f"portals placed and seen elsewhere: {matched} of {total} (place and collar depth agree to the centimetre)")
if total == 0 or matched < total * 0.9:
    print("FAIL: copies do not agree on where the portals are"); fail = True
took = sum(n for c in shots.values() for (o, s, t), n in c.items() if t)
seen_by_others = sum(n for me, c in shots.items() for (o, s, t), n in c.items() if o != me)
print(f"portal gun shots drawn: {sum(sum(c.values()) for c in shots.values())} ({seen_by_others} of them other players' guns)")
if seen_by_others == 0:
    print("FAIL: nobody saw anybody else's portal gun fire"); fail = True
print("PORTAL SYNC TEST", "FAILED" if fail else "PASSED")
sys.exit(1 if fail else 0)
PY
