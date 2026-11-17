#!/usr/bin/env bash
# Automated multiplayer sync test: runs one host and N-1 clients headless on this
# machine, all moving on their own, then checks that every copy draws every other
# player close to where they really were, with no pops, doing what they were
# really doing (the same animation), as the robot that player picked (the copies
# alternate between the characters).
#
# Usage: tests/run_sync_test.sh [PLAYERS] [NET_SIM]
#   PLAYERS  2..5 (default 2)
#   NET_SIM  optional bad-network simulation "LATENCY_MS,JITTER_MS,LOSS_PERCENT"
# Set GODOT to your Godot binary if it is not on PATH as "godot".
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PLAYERS="${1:-2}"
SIM="${2:-}"
SECONDS_TO_RUN=14
PORT=$((24700 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/sync_*.log
EXTRA=()
if [[ -n "$SIM" ]]; then EXTRA+=("--net-sim=$SIM"); fi
if [[ -n "${MAP:-}" ]]; then EXTRA+=("--map=$MAP"); fi   # MAP=testing_grounds picks the map (default: the game's default)

# The host quits first, so this also checks that clients handle "host left".
CHARACTERS=(needle vanguard)
"$GODOT" --headless --path . -- --host --name=P1 --character=needle --autostart="$PLAYERS" --scripted-input --sync-log \
  --quit-after=$((SECONDS_TO_RUN - 2)) "${EXTRA[@]}" --port="$PORT" > "$OUT/sync_1.log" 2>&1 &
sleep 1
for i in $(seq 2 "$PLAYERS"); do
  "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name="P$i" --character="${CHARACTERS[$(((i + 1) % 2))]}" --scripted-input --sync-log \
    --quit-after=$SECONDS_TO_RUN "${EXTRA[@]}" > "$OUT/sync_$i.log" 2>&1 &
done
wait
if grep -h "SCRIPT ERROR\|^ERROR" "$OUT"/sync_*.log; then
  echo "FAIL: script errors above"
  exit 1
fi
for i in $(seq 2 "$PLAYERS"); do
  if ! grep -q "host disconnected" "$OUT/sync_$i.log"; then
    echo "FAIL: client $i did not notice the host leaving"
    exit 1
  fi
done
echo "PASS: all clients noticed the host leaving"
fail=0
python3 tests/check_sync.py "$OUT"/sync_*.log || fail=1
echo "-- Animation: every copy shows what each player is doing"
python3 tests/check_anim.py --need=loco,air,grapple,dive,belly_slide,flip_front,float --characters=2 "$OUT"/sync_*.log || fail=1
exit $fail
