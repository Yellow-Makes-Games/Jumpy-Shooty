#!/usr/bin/env bash
# Renders screenshots in a software renderer (no GPU needed). Used by Claude to
# check visuals from the cloud workspace. Usage: tools/screenshot.sh OUT.png [extra dev args...]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(realpath -m "$1")"; shift
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1600x900x24 +extension GLX +render" \
  "${GODOT:-godot}" --rendering-driver opengl3 --path . -- --screenshot=3:"$OUT" --quit-after=3.5 "$@" 2>&1 \
  | grep -E "screenshot|SCRIPT ERROR|^ERROR" | grep -v "audio_driver\|init_output_device" || true
