#!/usr/bin/env bash
# Grappling Hook 2 online: one host and N-1 clients headless on this machine, all with
# Grappling Hook 2, all moving and firing it on their own (--scripted-input). Checks
# that every copy draws every other player's hook and rope where that player's own
# game had them, moment for moment: the launch, the bite, the rope pulling tight and
# the release at the same times, and the hook in the same place all the way
# (tests/check_hook.py). The usual movement check (tests/check_sync.py) is printed
# too, for information: tests/run_sync_test.sh is the test of that.
#
# Usage: tests/run_hook_sync_test.sh [PLAYERS] [NET_SIM]
#   PLAYERS  2..5 (default 2)
#   NET_SIM  optional bad-network simulation "LATENCY_MS,JITTER_MS,LOSS_PERCENT"
#   MAP=id   the map (default testing_grounds: walls all round to hook, and nowhere
#            to fall off, so nobody spends the test waiting to respawn)
# Set GODOT to your Godot binary if it is not on PATH as "godot".
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PLAYERS="${1:-2}"
SIM="${2:-}"
SECONDS_TO_RUN=18
PORT=$((24900 + RANDOM % 200))
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/hook_*.log
EXTRA=(--mobility=grapple2)
if [[ -n "$SIM" ]]; then EXTRA+=("--net-sim=$SIM"); fi
EXTRA+=("--map=${MAP:-testing_grounds}")

"$GODOT" --headless --path . -- --host --name=P1 --autostart="$PLAYERS" --scripted-input --sync-log \
  --quit-after=$((SECONDS_TO_RUN - 2)) "${EXTRA[@]}" --port="$PORT" > "$OUT/hook_1.log" 2>&1 &
sleep 1
for i in $(seq 2 "$PLAYERS"); do
  "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name="P$i" --scripted-input --sync-log \
    --quit-after=$SECONDS_TO_RUN "${EXTRA[@]}" > "$OUT/hook_$i.log" 2>&1 &
done
wait
if grep -h "SCRIPT ERROR\|^ERROR" "$OUT"/hook_*.log; then
  echo "FAIL: script errors above"
  exit 1
fi
fail=0
python3 tests/check_hook.py "$OUT"/hook_*.log || fail=1
echo "-- Movement (for information): every copy draws every player where they were"
python3 tests/check_sync.py "$OUT"/hook_*.log || true
exit $fail
