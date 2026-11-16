#!/usr/bin/env bash
# A short time-limit match (lobby rule "time"): checks the match ends when the clock
# runs out, with no kill target, and every copy gets the same results.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT=$((25300 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/timed_*.log
COMMON=(--scripted-input --scripted-fire --sync-log --quit-after=40)
if [[ -n "${MAP:-}" ]]; then COMMON+=("--map=$MAP"); fi   # MAP=testing_grounds picks the map
"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --autostart=2 --rules=time:0.25 \
  "${COMMON[@]}" > "$OUT/timed_1.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 "${COMMON[@]}" > "$OUT/timed_2.log" 2>&1 &
for _ in $(seq 1 40); do
  sleep 1
  if grep -q "^MATCH_OVER" "$OUT/timed_1.log" && grep -q "^MATCH_OVER" "$OUT/timed_2.log"; then break; fi
done
pkill -f -- "--port=$PORT" || true
pkill -f -- "--join=127.0.0.1:$PORT" || true
wait || true
if grep -h "SCRIPT ERROR" "$OUT"/timed_*.log; then echo "FAIL: script errors"; exit 1; fi
a=$(grep -h "^MATCH_OVER" "$OUT/timed_1.log" | head -1)
b=$(grep -h "^MATCH_OVER" "$OUT/timed_2.log" | head -1)
if [[ -z "$a" || "$a" != "$b" ]]; then echo "FAIL: time-limit match did not end the same on both copies"; exit 1; fi
echo "PASS: 15-second time-limit match ended on both copies with matching results"
