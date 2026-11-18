#!/usr/bin/env bash
# Renders guns on their own without a GPU (see gun_preview.gd).
# Usage: tools/combat/gun_preview.sh OUT_DIR [--guns=a,b] [--glb=FILE] [--before=FILE] [--color=r,g,b]
set -euo pipefail
OUT="$(realpath -m "$1")"; mkdir -p "$OUT"; shift
cd "$(dirname "$0")/../.."
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 1500 xvfb-run -a -s "-screen 0 1600x900x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --resolution 960x420 --path . --script tools/combat/gun_preview.gd -- \
  --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
