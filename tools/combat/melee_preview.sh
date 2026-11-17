#!/usr/bin/env bash
# Renders a melee weapon on its own without a GPU (see melee_preview.gd).
# Usage: tools/combat/melee_preview.sh WEAPON OUT_DIR [r,g,b]
set -euo pipefail
OUT="$(realpath -m "$2")"; mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 300 xvfb-run -a -s "-screen 0 1600x900x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --resolution 1600x900 --path . --script tools/combat/melee_preview.gd -- \
  --weapon="$1" --out="$OUT" ${3:+--color="$3"} 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
