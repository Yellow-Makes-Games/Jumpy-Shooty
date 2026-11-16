#!/usr/bin/env bash
# Checks that bots cope with a player up the Construction Site tower. The player
# stands still on a high floor and the bot starts on the ground: it has to take
# the stairs up to that floor, unless it shoots the player from below first (then
# the player respawns in the yard and there is nothing left to climb for). The
# weaker bots rarely manage that shot, so they are the ones that show the climb.
# Bots cannot see through walls, so the player fires a shot every few seconds: the
# bot has to hear it (or spot the player) to know where to go.
# Usage: tests/run_bot_climb_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/climb_*.log
# name : bot level : where the player stands (x,y,z,yaw) : the height that counts as
# having climbed to them (the floor below theirs: from there it has a clear shot)
SHOTS=()
for t in 3 6 9 12 15 18 21 24 27 30 33 36 39 42; do SHOTS+=("--press=$t:fire"); done
for t in 13 28; do SHOTS+=("--press=$t:reload"); done
CASES=("nest:0:4,24.1,0,0:19.5" "nest_again:0:-4,24.1,0,0:19.5" "floor20:1:-10,20.1,-10,0:15.5" "floor12:0:0,12.1,-10,0:7.5")
for c in "${CASES[@]}"; do
  IFS=: read -r name level spot _ <<< "$c"
  timeout 80 "$GODOT" --headless --path . -- --sync-log --bot="$level" --map=construction_site --spawn="$spot" \
    --time-limit=45 --quit-after=48 "${SHOTS[@]}" > "$OUT/climb_$name.log" 2>&1 &
done
wait || true
fail=0
climbed=0
for c in "${CASES[@]}"; do
  IFS=: read -r name level spot need <<< "$c"
  log="$OUT/climb_$name.log"
  top=$(grep "^BOT 9001" "$log" | awk '{ if ($4 > m) m = $4 } END { print m + 0 }')
  first=$(grep "^BOT 9001" "$log" | awk -v need="$need" '$4 >= need { print NR; exit }')
  errors=$(grep -c "SCRIPT ERROR" "$log" || true)
  kills=$(grep -o '"id":9001,"kills":[0-9]*' "$log" | tail -1 | grep -o '[0-9]*$' || echo 0)
  echo "$name: bot level $level got to ${top} m (needed $need) after ${first:-never} s, kills ${kills:-0}, errors $errors"
  if [[ "$errors" != "0" ]]; then echo "  FAIL: script errors"; fail=1; fi
  if [[ -z "$first" && "${kills:-0}" == "0" ]]; then echo "  FAIL: the bot neither got up there nor scored"; fail=1; fi
  if [[ -n "$first" ]]; then climbed=$((climbed + 1)); fi
done
if [[ $climbed -lt 2 ]]; then echo "FAIL: only $climbed of ${#CASES[@]} bots climbed to the player"; fail=1; fi
if [[ $fail == 1 ]]; then echo "BOT CLIMB TEST FAILED"; exit 1; fi
echo "BOT CLIMB TEST PASSED"
