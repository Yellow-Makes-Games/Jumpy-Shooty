#!/usr/bin/env bash
# Films every explosive weapon's blast in the real game without a GPU (see explosion_film.gd):
# writes OUT_DIR/explosions.mp4 and, for each blast, OUT_DIR/explosions_NAME.png (a strip of
# stills a moment apart).
# Usage: tools/combat/explosion_film.sh OUT_DIR [--map=construction_site] [--only=wall|ground|first]
# FPS=30 films at half the frames (default 60); SIZE=WxH sets the size (default 1280x720).
set -euo pipefail
OUT="$(realpath -m "$1")"; shift
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
NAME="explosions"
FPS="${FPS:-60}"
SIZE="${SIZE:-1280x720}"
ICD="/usr/share/vulkan/icd.d/lvp_icd.json"
[ -f "$ICD" ] || ICD="/opt/lavapipe/lvp_icd.json"
VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$ICD}" timeout 3000 xvfb-run -a -s "-screen 0 ${SIZE}x24" \
  "${GODOT:-godot}" --fixed-fps "$FPS" --write-movie "$OUT/$NAME.avi" --rendering-driver vulkan --resolution "$SIZE" --path . \
  --script tools/combat/explosion_film.gd -- "$@" > "$OUT/$NAME.log" 2>&1 || true
grep -E "^FILM|SCRIPT ERROR" "$OUT/$NAME.log" || true
FROM="$(grep -m1 "^FILM START" "$OUT/$NAME.log" | awk '{print $3}')"
TO="$(grep -m1 "^FILM END" "$OUT/$NAME.log" | awk '{print $3}')"
if command -v ffmpeg >/dev/null && [ -n "$FROM" ] && [ -n "$TO" ]; then
  ffmpeg -y -loglevel error -i "$OUT/$NAME.avi" \
    -vf "select='between(n,$FROM,$TO)',setpts=N/FRAME_RATE/TB" -an -pix_fmt yuv420p -crf 20 "$OUT/$NAME.mp4"
  # A strip of stills for each blast: 0.03, 0.1, 0.2, 0.4, 0.8 and 1.4 seconds after it goes off.
  grep "^FILM BLAST" "$OUT/$NAME.log" | while read -r _ _ FRAME LABEL; do
    SEL=""
    for T in 0.03 0.1 0.2 0.4 0.8 1.4; do
      N="$(awk "BEGIN{printf \"%d\", $FRAME + $T * $FPS}")"
      SEL="${SEL:+$SEL+}eq(n\,$N)"
    done
    ffmpeg -nostdin -y -loglevel error -i "$OUT/$NAME.avi" -vf "select='$SEL',scale=640:-1,tile=3x2" -frames:v 1 -vsync vfr "$OUT/${NAME}_${LABEL}.png"
  done
  rm -f "${OUT:?}/${NAME:?}.avi" "${OUT:?}/${NAME:?}.wav"
  echo "saved $OUT/$NAME.mp4"
fi
