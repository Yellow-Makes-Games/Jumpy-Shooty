#!/usr/bin/env bash
# Automated match test: a host and clients run headless, move on their own, aim at
# the nearest opponent they can see and shoot. Checks that:
#  - hits land (the host's rewind matches what shooters saw), even on a laggy network
#  - kills, deaths and respawns happen
#  - the match ends at the kill target and every copy gets the same results
#  - every copy shows the others' animations, shots, reloads and deaths
#  - there are no script errors
# Usage: tests/run_match_test.sh [PLAYERS] [NET_SIM]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PLAYERS="${1:-3}"
SIM="${2:-}"
PORT=$((25000 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/match_*.log
EXTRA=()
if [[ -n "$SIM" ]]; then EXTRA+=("--net-sim=$SIM"); fi
if [[ -n "${MAP:-}" ]]; then EXTRA+=("--map=$MAP"); fi   # MAP=testing_grounds picks the map (default: the game's default)
COMMON=(--scripted-input --scripted-fire --sync-log --auto-return --quit-after=150)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --autostart="$PLAYERS" \
  --rules=kills:4 --time-limit=60 "${COMMON[@]}" "${EXTRA[@]}" > "$OUT/match_1.log" 2>&1 &
HOST=$!
sleep 1
for i in $(seq 2 "$PLAYERS"); do
  "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name="P$i" "${COMMON[@]}" "${EXTRA[@]}" \
    > "$OUT/match_$i.log" 2>&1 &
done
# Two matches back to back (results -> lobby -> play again). Stop everyone a few
# seconds after the host reports the second match is over.
for _ in $(seq 1 150); do
  sleep 1
  if [[ $(grep -c "^MATCH_OVER" "$OUT/match_1.log") -ge 2 ]]; then sleep 3; break; fi
done
pkill -f -- "--port=$PORT" || true
pkill -f -- "--join=127.0.0.1:$PORT" || true
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/match_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" "$PLAYERS" <<'PY' || fail=1
import glob, json, sys, re
out, players = sys.argv[1], int(sys.argv[2])
results = {}
hits = misses = heads = 0
for path in sorted(glob.glob(f"{out}/match_*.log")):
    for line in open(path, errors="replace"):
        if line.startswith("MATCH_OVER "):
            results.setdefault(path, []).append(json.loads(line[len("MATCH_OVER "):]))
        if path.endswith("match_1.log") and line.startswith("SHOT "):
            if " hit " in line:
                hits += 1
                if line.rstrip().endswith(" head"): heads += 1
            else: misses += 1
ok = True
shots = hits + misses
ratio = hits / shots if shots else 0
print(f"shots judged by host: {shots}, hits {hits} ({ratio:.0%}), headshots {heads}")
if hits and heads == 0:
    print("FAIL: no headshots registered although shooters aim at heads half the time"); ok = False
if shots < 20:
    print("FAIL: too few shots"); ok = False
elif ratio < 0.6:
    print("FAIL: hit rate too low; rewind may not match what shooters saw"); ok = False
if len(results) != players or any(len(r) < 2 for r in results.values()):
    print(f"FAIL: not every copy saw both matches end: { {k: len(v) for k, v in results.items()} }"); ok = False
else:
    print("both matches finished on every copy (results -> lobby -> play again works)")
    first = list(results.values())[0][1]
    if any(r[1] != first for r in results.values()):
        print("FAIL: copies disagree about the results"); ok = False
    top = first[0]
    print("results:", ", ".join(f"{r['name']} {r['kills']}K/{r['deaths']}D" for r in first))
    if top["kills"] < 4:
        print("FAIL: winner did not reach the kill target"); ok = False
    if sum(r["deaths"] for r in first) < 4:
        print("FAIL: too few deaths"); ok = False
print("PASS: match test" if ok else "FAIL: match test")
sys.exit(0 if ok else 1)
PY
echo "-- Animation: every copy shows what each player is doing"
python3 tests/check_anim.py --need=loco,air,death,reload "$OUT"/match_*.log || fail=1
exit $fail
