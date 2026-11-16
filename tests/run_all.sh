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
echo "== Testing Grounds: every practice course can be completed"
run_script tests/course_test.gd
echo "== Practice mode boots without errors"
out=$("$GODOT" --headless --path . -- --practice --quit-after=3 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR\|^ERROR"; then echo "$out" | grep -A3 "ERROR"; exit 1; fi
echo "PASS"
echo "== Sync: 2 players, clean network"
tests/run_sync_test.sh 2
echo "== Sync: 5 players, bad network (100 ms latency, 60 ms jitter, 10% loss)"
tests/run_sync_test.sh 5 "100,60,10"
echo "== Match: 3 players, laggy network, two matches back to back"
tests/run_match_test.sh 3 "100,40,5"
echo "== Time-limit match (lobby rule)"
tests/run_timed_match_test.sh
echo "ALL TESTS PASSED"
