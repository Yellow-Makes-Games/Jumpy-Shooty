#!/usr/bin/env bash
# Renders a map's sky with the game's real renderer (Forward+ on Vulkan), in software
# when there is no GPU (see sky_preview.gd).
# Usage: tools/sky_preview.sh MAP_ID OUT_DIR [--sky=res://game/maps/sky/presets/clear_day.tres]
#        [--views=sun;away;up] [--tag=after] [--still] [--clip=6 --fps=12]
set -euo pipefail
MAP="$1"; OUT="$(realpath -m "$2")"; shift 2
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
ICD="/usr/share/vulkan/icd.d/lvp_icd.json"
[ -f "$ICD" ] || ICD="/opt/lavapipe/lvp_icd.json"
FPS=12
for a in "$@"; do case "$a" in --fps=*) FPS="${a#--fps=}";; esac; done
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$ICD}" timeout 1800 xvfb-run -a -s "-screen 0 1600x900x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --fixed-fps "$FPS" --path . --script tools/sky_preview.gd -- \
  --map="$MAP" --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
