#!/usr/bin/env bash
# Runs every automated test. Needs Godot ("godot" on PATH, or set GODOT) and python3.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
echo "== Importing project"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "== Movement checks"
run_script() {  # fails on any script error, even if the script itself reports PASS
  local out
  out=$("$GODOT" --headless --path . --script "$1" 2>&1) || { echo "$out"; return 1; }
  echo "$out" | grep -v "^Godot Engine"
  if echo "$out" | grep -q "SCRIPT ERROR"; then echo "FAIL: script errors above"; return 1; fi
}
run_script tests/movement_test.gd
echo "== Robot model and animator checks"
run_script tests/robot_test.gd
echo "== Weapons: damage, falloff and reloading"
run_script tests/weapon_test.gd
echo "== Map scenes: every map loads and builds; blocks and resize handles"
run_script tests/map_scene_test.gd
echo "== Controls: rebinding, conflicts, saving and reset"
run_script tests/controls_check.gd
echo "== Main menu: the mode switch refills the map list"
run_script tests/menu_mode_test.gd
echo "== Deathmatch: maps, weapon pickups, inventory rules, pause menu loadout"
run_script tests/deathmatch_test.gd
echo "== Testing Grounds: every practice course can be completed"
run_script tests/course_test.gd
echo "== Construction Site: spawn points, bot navigation and every movement route"
run_script tests/site_test.gd
echo "== Office: spawn points, bot navigation and every movement route"
run_script tests/office_test.gd
echo "== Breakable walls and floors: which pieces break, spawns stay safe, holes let shots through"
run_script tests/destruction_test.gd
echo "== Debug menu cheats and the target dummies"
run_script tests/debug_test.gd
echo "== Practice mode boots without errors on every map"
for map in construction_site office kilnworks testing_grounds rooftop_run foundry sky_ruins; do
  out=$("$GODOT" --headless --path . -- --practice --map="$map" --quit-after=3 2>&1)
  if echo "$out" | grep -q "SCRIPT ERROR\|^ERROR"; then echo "$out" | grep -A3 "ERROR"; exit 1; fi
done
echo "PASS"
echo "== Sync: 2 players, clean network (Testing Grounds)"
MAP=testing_grounds tests/run_sync_test.sh 2
echo "== Sync: 5 players, bad network (100 ms latency, 60 ms jitter, 10% loss) (Construction Site)"
MAP=construction_site tests/run_sync_test.sh 5 "100,60,10"
echo "== Match: 3 players, laggy network, two matches back to back (Construction Site)"
MAP=construction_site tests/run_match_test.sh 3 "100,40,5"
echo "== Breakable walls and floors online: a floor and a wall break, a late joiner sees them, everyone agrees"
tests/run_break_test.sh
echo "== Time-limit match (lobby rule) (Testing Grounds)"
MAP=testing_grounds tests/run_timed_match_test.sh
echo "== 1v1 bot: every difficulty, plus a fight and a rematch (Testing Grounds)"
MAP=testing_grounds tests/run_bot_test.sh
echo "== 1v1 bot: every difficulty, plus a fight and a rematch (Construction Site)"
MAP=construction_site tests/run_bot_test.sh
echo "== 1v1 bot: every difficulty, plus a fight and a rematch (Office)"
MAP=office tests/run_bot_test.sh
echo "== Bots climb the Construction Site tower to a player on top"
tests/run_bot_climb_test.sh
echo "== Race mode: bots finish every race map, fail conditions, results, an online race"
tests/run_race_test.sh
echo "== Sound effects: every sound loads; yours, the bots' and other players' play (Testing Grounds)"
tests/run_audio_test.sh
echo "ALL TESTS PASSED"
