#!/usr/bin/env bash
# Films reloads off the ground in the real game without a GPU (see reload_film.gd): writes
# OUT_DIR/reload_GUN_SCENES_VIEW.mp4.
# Usage: tools/robot/reload_film.sh OUT_DIR GUN SCENES(all, or a comma list of rope,jump,glide,flip,wall) first|third|side [more dev options, e.g. --character=orbit]
# SIZE=WxH sets the picture size (default 1280x720); FPS=30 films at half the frames (default 60).
set -euo pipefail
OUT="$(realpath -m "$1")"; GUN="$2"; SCENES="$3"; VIEW="$4"; shift 4
SIZE="${SIZE:-1280x720}"
W="${SIZE%x*}"; H="${SIZE#*x}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="reload_${GUN}_${SCENES//,/-}_${VIEW}"
CAM=""; [ "$VIEW" = "third" ] && CAM="--third-person"; [ "$VIEW" = "side" ] && CAM="--side"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  "${GODOT:-godot}" --fixed-fps "${FPS:-60}" --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution "${W}x${H}" --path . \
  --script tools/robot/reload_film.gd -- --window=0,0,"$W","$H" --weapon="$GUN" --scenes="$SCENES" $CAM "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The reloads themselves, without the loading before them.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" -vf "trim=start_frame=$FROM:end_frame=$TO,setpts=PTS-STARTPTS" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "$OUT/$NAME.avi" "$OUT/$NAME.wav"
  echo "saved $OUT/$NAME.mp4"
fi
