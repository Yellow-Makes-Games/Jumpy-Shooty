#!/usr/bin/env bash
# Films a gun's recoil in the real game without a GPU (see recoil_film.gd): writes
# OUT_DIR/GUN_SCENE_VIEW.mp4.
# Usage: tools/robot/recoil_film.sh OUT_DIR GUN SCENE(shots|air|move) first|third|side|front|back [more dev options, e.g. --character=orbit]
# SIZE=WxH sets the picture size (default 1280x720).
set -euo pipefail
OUT="$(realpath -m "$1")"; GUN="$2"; SCENE="$3"; VIEW="$4"; shift 4
SIZE="${SIZE:-1280x720}"
W="${SIZE%x*}"; H="${SIZE#*x}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="${GUN}_${SCENE}_${VIEW}"
CAM=""; [ "$VIEW" = "third" ] && CAM="--third-person"; [ "$VIEW" = "side" ] && CAM="--side"; [ "$VIEW" = "front" ] && CAM="--front"; [ "$VIEW" = "back" ] && CAM="--back"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  "${GODOT:-godot}" --fixed-fps 60 --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution "${W}x${H}" --path . \
  --script tools/robot/recoil_film.gd -- --window=0,0,"$W","$H" --weapon="$GUN" --scene="$SCENE" $CAM "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The shooting itself, without the loading before it.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" -vf "trim=start_frame=$FROM:end_frame=$TO,setpts=PTS-STARTPTS" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "$OUT/$NAME.avi" "$OUT/$NAME.wav"
  echo "saved $OUT/$NAME.mp4"
fi
