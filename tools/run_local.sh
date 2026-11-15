#!/usr/bin/env bash
# Opens several copies of Jumpy Shooty on this computer, already connected.
# The first copy hosts; the others join it.
# Usage: tools/run_local.sh [PLAYERS]   (2 to 5, default 2). Set GODOT if needed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PLAYERS="${1:-2}"
POS=("0,40,960,540" "960,40,960,540" "0,580,960,540" "960,580,960,540" "480,300,960,540")
"$GODOT" --path . -- --host --name=Host --window="${POS[0]}" &
sleep 2
for i in $(seq 2 "$PLAYERS"); do
  "$GODOT" --path . -- --join=127.0.0.1 --name="P$i" --window="${POS[$((i-1))]}" &
done
wait
