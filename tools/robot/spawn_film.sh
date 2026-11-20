#!/usr/bin/env bash
# Films a player arriving in the real game without a GPU (see spawn_film.gd): writes
# OUT_DIR/spawn_VIEW.mp4 (the two arrivals, without the wait between them).
# Usage: tools/robot/spawn_film.sh OUT_DIR first|side [more dev options, e.g. --weapon=rifle --character=orbit]
# FPS=30 films at half the frames (default 60).
set -euo pipefail
OUT="$(realpath -m "$1")"; VIEW="$2"; shift 2
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="spawn_${VIEW}"
CAM=""; [ "$VIEW" = "side" ] && CAM="--side"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" \
  "${GODOT:-godot}" --fixed-fps "${FPS:-60}" --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution 1280x720 --path . \
  --script tools/robot/spawn_film.gd -- $CAM "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
# The two arrivals, without the loading before them or the wait between them.
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
CUT="$(grep -m1 "^FILM CUT" "$OUT/$NAME.log" | awk '{print $3}')"
RESUME="$(grep -m1 "^FILM RESUME" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$CUT" ] && [ -n "$RESUME" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" \
    -vf "select='between(n,$FROM,$CUT)+between(n,$RESUME,$TO)',setpts=N/FRAME_RATE/TB" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  rm -f "${OUT:?}/${NAME:?}.avi" "${OUT:?}/${NAME:?}.wav"
  echo "saved $OUT/$NAME.mp4"
fi
