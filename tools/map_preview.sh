#!/usr/bin/env bash
# Renders pictures of a map in a software renderer (no GPU needed).
# Usage: tools/map_preview.sh construction_site OUT_DIR [more map_preview.gd options]
# (a map id from game/arena/maps.gd, or a map scene's res:// path)
set -euo pipefail
MAP="$1"; OUT="$(realpath -m "$2")"; shift 2
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
LIBGL_ALWAYS_SOFTWARE=1 timeout 300 xvfb-run -a -s "-screen 0 2400x1400x24 +extension GLX +render" \
  "${GODOT:-godot}" --rendering-driver opengl3 --path . --script tools/map_preview.gd -- --map="$MAP" --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0" || true
