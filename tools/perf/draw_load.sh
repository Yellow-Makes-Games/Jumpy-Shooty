#!/usr/bin/env bash
# Triangles and draw calls in a frame of a map, from a few viewpoints (see draw_load.gd).
# Usage: tools/perf/draw_load.sh --map=empyrean
set -euo pipefail
cd "$(dirname "$0")/../.."
LIBGL_ALWAYS_SOFTWARE=1 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24 +extension GLX +render" \
  "${GODOT:-godot}" --rendering-driver opengl3 --resolution 1280x720 --path . --script tools/perf/draw_load.gd -- "$@" 2>&1 \
  | grep -E "DRAW|SCRIPT ERROR" || true
