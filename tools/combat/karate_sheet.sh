#!/usr/bin/env bash
# Renders Karate's gear and aura picture sheet without a GPU (see karate_sheet.gd).
# Usage: tools/combat/karate_sheet.sh OUT.png [WIDTHxHEIGHT] [more options for karate_sheet.gd]
set -euo pipefail
OUT="$(realpath -m "$1")"; SIZE="${2:-1200x1800}"; shift 2 || shift 1
W="${SIZE%x*}"; H="${SIZE#*x}"
cd "$(dirname "$0")/../.."
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 900 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --resolution "${W}x${H}" --path . --script tools/combat/karate_sheet.gd -- \
  --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error|SCRIPT" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
