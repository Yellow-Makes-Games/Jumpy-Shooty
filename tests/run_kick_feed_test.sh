#!/usr/bin/env bash
# Automated kick kills in the kill feed (see Match.death_fx, HudStyle.kill_icon). Checks that:
#  - online, the host sprints at a client standing in front of the Testing Grounds wall
#    and kicks them into it: the host rules it a crash credited to the kick, and the
#    kill feed on both copies shows the boot and the wall ("FEED ... kick wall")
#  - online, the host shoots the client down to 20 HP with the railgun, then kicks them:
#    a kick kill, the boot alone on both copies' feeds
#  - there are no script errors
# Usage: tests/run_kick_feed_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/kick_feed_*.log
fail=0
check() {   # check "what" file pattern
  if grep -q -E "$3" "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; fail=1; fi
}

# run NAME HOST_SPAWN CLIENT_SPAWN HOST_ARGS...: the client just stands there.
run() {
  local name=$1 hspawn=$2 cspawn=$3 port=$((25600 + RANDOM % 200))
  shift 3
  timeout 90 "$GODOT" --headless --path . -- --host --name=P1 --autostart=2 --port="$port" --map=testing_grounds \
    --spawn="$hspawn" --sync-log --from-start "$@" --quit-after=20 > "$OUT/kick_feed_${name}_host.log" 2>&1 &
  sleep 1
  timeout 90 "$GODOT" --headless --path . -- --join="127.0.0.1:$port" --name=P2 --map=testing_grounds \
    --spawn="$cspawn" --sync-log --from-start --quit-after=21 > "$OUT/kick_feed_${name}_client.log" 2>&1 &
  wait
}

# The wall is at x = 17.5; the client stands 1.5 m in front of it, the host runs 9 m to them.
run wall 7,1,0,-90 16,1,0,-90 --hold=2.0:move_forward:3 --hold=2.0:sprint:3 --hold=2.5:kick:0.05
# Close up and level with the client's chest; the railgun's push leaves them against the wall.
run kick 14.5,1,0,-90,-5 16.5,1,0,-90 --weapon=railgun --hold=2.0:fire:0.1 --hold=3.6:kick:0.05

echo "Kick kill feed checks"
check "into a wall: the host's kick lands" "$OUT/kick_feed_wall_host.log" "^KICK 1 front 1"
check "into a wall: the crash kills, credited to the kicker" "$OUT/kick_feed_wall_host.log" "^SLAM [0-9]+ [0-9.]+ m/s [0-9]+ damage by 1$"
check "into a wall: the host's feed shows the boot and the wall" "$OUT/kick_feed_wall_host.log" "^FEED 1 1 [0-9]+ kick wall$"
check "into a wall: the client's feed shows the boot and the wall" "$OUT/kick_feed_wall_client.log" "^FEED [0-9]+ 1 [0-9]+ kick wall$"
check "kick: the railgun hits first" "$OUT/kick_feed_kick_host.log" "^SHOT 1 hit "
check "kick: the host's feed shows the boot" "$OUT/kick_feed_kick_host.log" "^FEED 1 1 [0-9]+ kick$"
check "kick: the client's feed shows the boot" "$OUT/kick_feed_kick_client.log" "^FEED [0-9]+ 1 [0-9]+ kick$"
if grep -h "SCRIPT ERROR" "$OUT"/kick_feed_*.log; then
  echo "  FAIL  script errors above"
  fail=1
fi
if [[ $fail -ne 0 ]]; then
  echo "FAIL: kick kill feed checks failed (logs in $OUT/kick_feed_*.log)"
  exit 1
fi
echo "PASS: kick kill feed"
