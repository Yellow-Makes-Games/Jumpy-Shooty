#!/usr/bin/env bash
# Films a robot on the grappling hook's rope without a GPU (see rope_preview.gd), and makes
# OUT_DIR/rope.mp4 from the frames if ffmpeg is there.
# Usage: tools/robot/rope_preview.sh OUT_DIR [more options for rope_preview.gd]
set -euo pipefail
OUT="$(realpath -m "$1")"; shift
mkdir -p "$OUT"; rm -f "$OUT"/f_*.png
cd "$(dirname "$0")/../.."
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 1800 xvfb-run -a -s "-screen 0 1600x720x24" \
  "${GODOT:-godot}" --rendering-driver vulkan --resolution 1600x720 --path . --script tools/robot/rope_preview.gd -- \
  --out="$OUT" "$@" 2>&1 \
  | grep -E "^saved|^let go|^roll|^tight|^there|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0\|resources still in use\|ALSA\|VK_KHR_surface\|err != OK" || true
if command -v ffmpeg >/dev/null && [ -f "$OUT/f_0002.png" ]; then
  ffmpeg -y -loglevel error -framerate 60 -i "$OUT/f_%04d.png" -pix_fmt yuv420p -crf 20 "$OUT/rope.mp4"
fi
