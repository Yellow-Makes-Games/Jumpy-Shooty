#!/usr/bin/env bash
# Films the emote wheel and the emotes in the real game without a GPU (see
# emote_film.gd): writes OUT_DIR/emote_VIEW.mp4.
# Usage: tools/robot/emote_film.sh OUT_DIR first|side [more dev options, e.g. --weapon=rifle --character=orbit]
# FPS=30 films at half the frames (default 60).
set -euo pipefail
OUT="$(realpath -m "$1")"; VIEW="$2"; shift 2
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="emote_${VIEW}"
CAM=""; [ "$VIEW" = "side" ] && CAM="--side"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" \
  "${GODOT:-godot}" --fixed-fps "${FPS:-60}" --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution 1280x720 --path . \
  --script tools/robot/emote_film.gd -- $CAM "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The match itself, without the loading before it.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" -vf "trim=start_frame=$FROM:end_frame=$TO,setpts=PTS-STARTPTS" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "${OUT:?}/${NAME:?}.avi" "${OUT:?}/${NAME:?}.wav"
  echo "saved $OUT/$NAME.mp4"
fi
