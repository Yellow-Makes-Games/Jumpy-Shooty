#!/usr/bin/env bash
# Renders a map as a player sees it with the game's real renderer (Forward+ on Vulkan),
# in software when there is no GPU (see graphics_preview.gd).
# Usage: tools/graphics_preview.sh MAP_ID OUT_DIR [--tag=before] [--quality=high] [--spawns=0,2]
set -euo pipefail
MAP="$1"; OUT="$(realpath -m "$2")"; shift 2
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
ICD="/usr/share/vulkan/icd.d/lvp_icd.json"
[ -f "$ICD" ] || ICD="/opt/lavapipe/lvp_icd.json"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$ICD}" timeout 900 xvfb-run -a -s "-screen 0 1600x900x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --path . --script tools/graphics_preview.gd -- \
  --map="$MAP" --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
