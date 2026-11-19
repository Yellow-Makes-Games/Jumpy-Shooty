#!/usr/bin/env bash
# Renders the portrait banner (the character on its stage) with the game's real renderer
# (Forward+ on Vulkan), in software when there is no GPU (see portrait_preview.gd).
# Usage: tools/portrait_preview.sh OUT_DIR [--character=needle] [--quality=high] [--hold=side] ...
# FPS=30 steps the game that many frames a second however slowly it renders (for clips).
set -euo pipefail
OUT="$(realpath -m "$1")"; shift
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
ICD="/usr/share/vulkan/icd.d/lvp_icd.json"
[ -f "$ICD" ] || ICD="/opt/lavapipe/lvp_icd.json"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$ICD}" timeout 1800 xvfb-run -a -s "-screen 0 2560x1440x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --fixed-fps "${FPS:-30}" --path . --script tools/portrait_preview.gd -- \
  --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error|at: " | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use\|audio_server" || true
