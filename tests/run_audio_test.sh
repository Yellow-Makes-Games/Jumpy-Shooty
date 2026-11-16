#!/usr/bin/env bash
# Automated sound test. Checks that:
#  - every sound loads and the code only asks for sounds that exist (tests/audio_test.gd)
#  - in a bot match, your own gun, reloads, steps, jumps, landings and hit markers play
#    in your head, and the bots' shots, impacts and movement play placed in the world
#  - online, each copy hears the other player's shots and footsteps placed in the world,
#    and hears hits and kills
#  - there are no script errors
# Usage: tests/run_audio_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/audio_*.log
fail=0

out=$("$GODOT" --headless --path . --script tests/audio_test.gd 2>&1) || { echo "$out"; exit 1; }
echo "$out" | grep -v "^Godot Engine"

"$GODOT" --headless --path . -- --bot=3 --bots=2 --weapon=sniper --bot-weapon=rifle --map=testing_grounds \
  --scripted-input --scripted-fire --sound-log --quit-after=30 > "$OUT/audio_bot.log" 2>&1 || true

PORT=$((25400 + RANDOM % 200))
COMMON=(--scripted-input --scripted-fire --sound-log --map=testing_grounds --quit-after=30)
"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --weapon=shotgun --autostart=2 "${COMMON[@]}" \
  > "$OUT/audio_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --weapon=pistol "${COMMON[@]}" \
  > "$OUT/audio_client.log" 2>&1 &
wait || true

if grep -h "SCRIPT ERROR" "$OUT"/audio_*.log; then echo "FAIL: script errors"; fail=1; fi
need() {  # need LOG PATTERN WHAT
  if ! grep -qE "$2" "$OUT/$1"; then echo "FAIL: $3 ($1: no '$2')"; fail=1; fi
}
need audio_bot.log "^SFX fire_sniper_fp" "your own shot plays"
need audio_bot.log "^SFX bolt_(up|back|fwd|down)" "the sniper's bolt is worked after a shot"
need audio_bot.log "^SFX mag_(out|in)_rifle" "your reload plays"
need audio_bot.log "^SFX step$" "your footsteps play"
need audio_bot.log "^SFX (jump|land)" "your jumps and landings play"
need audio_bot.log "^SFX (hitmarker|kill)" "hit markers play when you hit"
need audio_bot.log "^SFX3D fire_rifle " "the bots' shots are placed in the world"
need audio_bot.log "^SFX3D impact_wall" "bullets hitting walls are heard"
need audio_bot.log "^SFX3D impact_body" "bullets hitting robots are heard"
need audio_bot.log "^SFX3D step " "the bots' footsteps are placed in the world"
need audio_bot.log "^SFX match_start" "the match start plays"
need audio_host.log "^SFX3D fire_pistol " "online: the host hears the client's pistol in the world"
need audio_client.log "^SFX3D fire_shotgun " "online: the client hears the host's shotgun in the world"
need audio_client.log "^SFX3D pump_(back|fwd)" "online: the client hears the host pump the shotgun"
need audio_client.log "^SFX3D step " "online: the client hears the host's footsteps"
need audio_host.log "^SFX fire_shotgun_fp" "online: the host hears its own shotgun"
if ! grep -qhE "^SFX (hitmarker|hurt|kill)" "$OUT/audio_host.log" "$OUT/audio_client.log"; then
  echo "FAIL: online: nobody heard a hit"; fail=1
fi
if [[ $fail -eq 0 ]]; then echo "PASS"; else exit 1; fi
