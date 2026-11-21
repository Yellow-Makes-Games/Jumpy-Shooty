#!/usr/bin/env bash
# Films Karate in the real game without a GPU (see karate_film.gd): writes OUT_DIR/karate_SCENE_VIEW.mp4.
# Usage: tools/combat/karate_film.sh OUT_DIR SCENE(all|combo|heavy|air|slam|moves) first|third|side|front|back [more options, e.g. --pick=2,1 --character=orbit]
# SIZE=WxH sets the picture size (default 1280x720).
set -euo pipefail
OUT="$(realpath -m "$1")"; SCENE="$2"; VIEW="$3"; shift 3
SIZE="${SIZE:-1280x720}"
W="${SIZE%x*}"; H="${SIZE#*x}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="karate_${SCENE}_${VIEW}"
CAM=""; [ "$VIEW" != "first" ] && CAM="--$VIEW"; [ "$VIEW" = "third" ] && CAM="--third-person"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  "${GODOT:-godot}" --fixed-fps 60 --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution "${W}x${H}" --path . \
  --script tools/combat/karate_film.gd -- --window=0,0,"$W","$H" --weapon=karate --scene="$SCENE" $CAM "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The fighting itself, without the loading before it.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" -vf "trim=start_frame=$FROM:end_frame=$TO,setpts=PTS-STARTPTS" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "$OUT/$NAME.avi" "$OUT/$NAME.wav"
  echo "saved $OUT/$NAME.mp4"
fi
