#!/usr/bin/env bash
# Automated ground slam test (see GroundSlam). Checks that:
#  - in Practice, dropped from high up with a hammer: winding up hangs you in the air,
#    crouch held as you let go drives a slam, the host rules on it and it hits the
#    target dummy beside where you land, and the boom plays
#  - online, a client's slam reaches the host: the host rules on it, it hits the
#    host's player standing where the client lands, and both copies hear it
#  - there are no script errors
# Usage: tests/run_slam_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/slam_*.log
PORT=$((25400 + RANDOM % 200))
DROP=(--map=testing_grounds --spawn=47.6,14,2,-90 --sync-log --sound-log)
SLAM=(--weapon=hammer --hold=0.3:fire:1.1 --hold=1.0:crouch:0.8)
fail=0
check() {   # check "what" file pattern
  if grep -q -E "$3" "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; fail=1; fi
}

timeout 120 "$GODOT" --headless --fixed-fps 60 --path . -- --practice --game-clock "${DROP[@]}" "${SLAM[@]}" --quit-after=3 \
  > "$OUT/slam_practice.log" 2>&1 || true
timeout 60 "$GODOT" --headless --path . -- --host --name=P1 --autostart=2 --port="$PORT" "${DROP[@]}" --quit-after=14 \
  > "$OUT/slam_host.log" 2>&1 &
sleep 1
timeout 60 "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 "${DROP[@]}" "${SLAM[@]}" --from-start --quit-after=16 \
  > "$OUT/slam_client.log" 2>&1 &
wait

echo "Ground slam checks"
check "practice: the slam starts, fully wound up" "$OUT/slam_practice.log" "^ANIM GROUND_SLAM 1 1\.00"
check "practice: the host rules on it and it hits the dummy" "$OUT/slam_practice.log" "^GROUND_SLAM 1 hammer [1-9]"
check "practice: the boom plays where it landed" "$OUT/slam_practice.log" "^SFX3D ground_slam"
check "online: the client slams" "$OUT/slam_client.log" "^ANIM GROUND_SLAM [0-9]+ "
check "online: the host rules on it and it hits the host's player" "$OUT/slam_host.log" "^GROUND_SLAM [0-9]{2,} hammer [1-9]"
check "online: the host hears it" "$OUT/slam_host.log" "^SFX3D ground_slam"
check "online: the client hears it" "$OUT/slam_client.log" "^SFX3D ground_slam"
if grep -h "SCRIPT ERROR" "$OUT"/slam_*.log; then
  echo "  FAIL  script errors above"
  fail=1
fi
if [[ $fail -ne 0 ]]; then
  echo "FAIL: ground slam checks failed (logs in $OUT/slam_*.log)"
  exit 1
fi
echo "PASS: ground slam"
