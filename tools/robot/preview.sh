#!/usr/bin/env bash
# Renders the shots described in a job file (see preview.gd) without a GPU.
# Usage: tools/robot/preview.sh JOB.json [gl]   ("gl" uses the faster, simpler renderer)
set -euo pipefail
JOB="$(realpath "$1")"
cd "$(dirname "$0")/../.."
if [ "${2:-}" = "gl" ]; then
  LIBGL_ALWAYS_SOFTWARE=1 timeout 300 xvfb-run -a -s "-screen 0 1920x1200x24 +extension GLX +render" \
    "${GODOT:-godot}" --rendering-driver opengl3 --path . --script tools/robot/preview.gd -- --job="$JOB" 2>&1 \
    | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0" || true
else
  VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 300 xvfb-run -a -s "-screen 0 1920x1200x24" \
    "${GODOT:-godot}" --rendering-driver vulkan --path . --script tools/robot/preview.gd -- --job="$JOB" 2>&1 \
    | grep -E "^saved|ERROR|error" | grep -v "audio_driver\|init_output_device\|status < 0" || true
fi
