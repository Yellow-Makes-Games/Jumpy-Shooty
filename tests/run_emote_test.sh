#!/usr/bin/env bash
# Emotes in the real game (see Emote, EmoteWheel), headless. Checks that:
#  - in Practice (the film's own script, tools/robot/emote_film.gd): the wheel plays the
#    emote it is let go on; your camera is pulled back to third person while it lasts
#    and goes back after; the dance goes on until you walk off, which cuts it short; a
#    tap plays the last one again; a shot cuts that short
#  - online: a client's emote is shown on the host's copy, and so is its being cut short
#    when the client walks off
#  - there are no script errors
# Usage: tests/run_emote_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/emote_*.log
PORT=$((25600 + RANDOM % 200))
fail=0
check() {   # check "what" file pattern
  if grep -q -E "$3" "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; fail=1; fi
}

timeout 200 "$GODOT" --headless --fixed-fps 60 --path . --script tools/robot/emote_film.gd > "$OUT/emote_practice.log" 2>&1 || true
# Online: both stand where they start; the client taps the emote key (the first slot's
# emote, a wave), taps it again later and walks off in the middle of it.
COMMON=(--map=testing_grounds --sync-log)
timeout 60 "$GODOT" --headless --path . -- --host --name=P1 --autostart=2 --port="$PORT" "${COMMON[@]}" --quit-after=20 \
  > "$OUT/emote_host.log" 2>&1 &
sleep 1
timeout 60 "$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 "${COMMON[@]}" --from-start \
  --hold=2:emote:0.1 --hold=5:emote:0.1 --hold=5.8:move_forward:0.5 --quit-after=22 \
  > "$OUT/emote_client.log" 2>&1 &
wait

echo "Emote checks"
P="$OUT/emote_practice.log"
check "practice: the wheel plays what it is let go on" "$P" "^FILM picked: wave  \(emoting true"
check "practice: the camera pulls back while it lasts" "$P" "^FILM during: emoting true, third person true"
check "practice: ...and goes back when it ends" "$P" "^FILM after: emoting false, third person false"
check "practice: pointing, laughing and the dance too" "$P" "^FILM picked: dance  \(emoting true"
check "practice: walking off cuts the dance short" "$P" "^FILM walked off: emoting false"
check "practice: a tap plays the last one again" "$P" "^FILM tap: dance"
check "practice: ...which is still going" "$P" "^FILM before the shot: emoting true"
check "practice: a shot cuts it short" "$P" "^FILM shot: emoting false"
check "online: the client waves" "$OUT/emote_client.log" "^EMOTE [0-9]{2,} wave"
check "online: the host's copy shows it" "$OUT/emote_host.log" "^EMOTE_SHOWN 1 [0-9]{2,} wave"
check "online: the client walks off in the middle of the next" "$OUT/emote_client.log" "^EMOTE [0-9]{2,} cut"
check "online: the host's copy shows that too" "$OUT/emote_host.log" "^EMOTE_SHOWN 1 [0-9]{2,} cut"
if grep -h "SCRIPT ERROR" "$OUT"/emote_*.log; then
  echo "  FAIL  script errors above"
  fail=1
fi
if [[ $fail -ne 0 ]]; then
  echo "FAIL: emote checks failed (logs in $OUT/emote_*.log)"
  exit 1
fi
echo "PASS: emotes"
