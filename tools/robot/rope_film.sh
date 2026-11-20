#!/usr/bin/env bash
# Films the grappling hook in the real game without a GPU (see rope_film.gd): writes
# OUT_DIR/SCENE_first.mp4, OUT_DIR/SCENE_third.mp4 or OUT_DIR/SCENE_side.mp4.
# Usage: tools/robot/rope_film.sh OUT_DIR SCENE(swing|pump|player|dive|dive_low|dive_go|drag|wall) first|third|side [more dev options, e.g. --weapon=sword --character=orbit]
# SIZE=WxH sets the picture size (default 1280x720).
set -euo pipefail
OUT="$(realpath -m "$1")"; SCENE="$2"; VIEW="$3"; shift 3
SIZE="${SIZE:-1280x720}"
W="${SIZE%x*}"; H="${SIZE#*x}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="${SCENE}_${VIEW}"
THIRD=""; [ "$VIEW" = "third" ] && THIRD="--third-person"; [ "$VIEW" = "side" ] && THIRD="--side"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  "${GODOT:-godot}" --fixed-fps 60 --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution "${W}x${H}" --path . \
  --script tools/robot/rope_film.gd -- --window=0,0,"$W","$H" --scene="$SCENE" $THIRD "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The match itself, without the loading before it.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" -vf "trim=start_frame=$FROM:end_frame=$TO,setpts=PTS-STARTPTS" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "$OUT/$NAME.avi" "$OUT/$NAME.wav"
  echo "saved $OUT/$NAME.mp4"
fi
