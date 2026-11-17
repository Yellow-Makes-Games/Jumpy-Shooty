#!/usr/bin/env bash
# Renders screenshots in a software renderer (no GPU needed). Used by Claude to
# check visuals from the cloud workspace. Usage: tools/screenshot.sh OUT.png [extra dev args...]
# SIZE=WxH sets the window size (default 1600x900), to check other resolutions and shapes;
# AT=SECONDS when to take it (default 3).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(realpath -m "$1")"; shift
SIZE="${SIZE:-1600x900}"
AT="${AT:-3}"
W="${SIZE%x*}"; H="${SIZE#*x}"
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 ${W}x${H}x24 +extension GLX +render" \
  "${GODOT:-godot}" --rendering-driver opengl3 --resolution "${W}x${H}" --path . -- --window=0,0,"$W","$H" \
  --screenshot="$AT":"$OUT" --quit-after="$(awk "BEGIN{print $AT+0.5}")" "$@" 2>&1 \
  | grep -E "screenshot|SCRIPT ERROR|^ERROR" | grep -v "audio_driver\|init_output_device\|ERR_CANT_OPEN\|resources still in use" || true
