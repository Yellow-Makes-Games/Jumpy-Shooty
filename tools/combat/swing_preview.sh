#!/usr/bin/env bash
# Films a robot swinging a melee weapon without a GPU (see swing_preview.gd), and makes
# OUT_DIR/swing.mp4 from the frames if ffmpeg is there.
# Usage: tools/combat/swing_preview.sh WEAPON OUT_DIR [more options for swing_preview.gd]
set -euo pipefail
WEAPON="$1"; OUT="$(realpath -m "$2")"; shift 2
mkdir -p "$OUT"; rm -f "$OUT"/f_*.png
cd "$(dirname "$0")/../.."
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 900 xvfb-run -a -s "-screen 0 1440x540x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --resolution 1440x540 --path . --script tools/combat/swing_preview.gd -- \
  --weapon="$WEAPON" --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use" || true
if command -v ffmpeg >/dev/null; then
  ffmpeg -y -loglevel error -framerate 60 -i "$OUT/f_%04d.png" -pix_fmt yuv420p -crf 20 "$OUT/swing.mp4"
fi
