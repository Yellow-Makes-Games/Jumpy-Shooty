#!/usr/bin/env bash
# Automated bot test. Runs a 1v1 against each bot difficulty, headless, with the
# player moving on its own (and not shooting), plus one Expert match where the
# player shoots back. Checks that:
#  - the bot finds the player and shoots at every difficulty; Normal and up hit a
#    moving player, and even Easy hits a player standing still
#  - harder bots are more accurate (Expert beats Easy)
#  - the harder bots use the movement set: slides, dives, flips, grapples
#  - the bot dodges when it gets shot
#  - matches end, and "Rematch" starts a new one
#  - there are no script errors
# Usage: tests/run_bot_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/bot_*.log
COMMON=(--headless --path . -- --scripted-input --sync-log)

for level in 0 1 2 3; do
  timeout 120 "$GODOT" "${COMMON[@]}" --bot="$level" --time-limit=80 --quit-after=85 \
    > "$OUT/bot_$level.log" 2>&1 &
done
# Easy against a player who stands still: even the weakest bot must land hits.
timeout 90 "$GODOT" --headless --path . -- --sync-log --bot=0 --time-limit=40 --quit-after=45 \
  > "$OUT/bot_still.log" 2>&1 &
# Expert again, but the player fights back; first to 2 so it ends, then rematches.
timeout 90 "$GODOT" "${COMMON[@]}" --bot=3 --scripted-fire --kill-target=2 --time-limit=40 \
  --auto-return --quit-after=60 > "$OUT/bot_fight.log" 2>&1 &
wait || true

python3 - "$OUT" <<'EOF'
import re, sys
out = sys.argv[1]
names = ["Easy", "Normal", "Hard", "Expert"]
fail = False
rates = {}
moves = set()

def read(name):
    return open(f"{out}/bot_{name}.log", encoding="utf-8", errors="replace").read()

def bot_stats(log):
    shots = re.findall(r"^SHOT 9001 (.*)$", log, re.M)
    hits = [s for s in shots if s.startswith("hit")]
    kinds = set(re.findall(r"^BOT_MOVE 9001 (\w+)", log, re.M))
    ropes = len(re.findall(r"^ROPE SELF 9001 on", log, re.M))
    spots = re.findall(r"^BOT 9001 (\S+) (\S+) (\S+)", log, re.M)
    return shots, hits, kinds, ropes, spots

for level in range(4):
    log = read(level)
    shots, hits, kinds, ropes, spots = bot_stats(log)
    errors = log.count("SCRIPT ERROR")
    moved = len({(round(float(x)), round(float(z))) for x, _, z in spots})
    rate = len(hits) / max(len(shots), 1)
    rates[level] = rate
    moves |= kinds
    print(f"{names[level]:7} shots {len(shots):3}  hits {len(hits):3} ({rate:.0%})  "
          f"places {moved:3}  ropes {ropes}  moves {sorted(kinds)}  errors {errors}")
    if errors:
        print("  FAIL: script errors"); fail = True
    if not shots:
        print("  FAIL: the bot never shot"); fail = True
    if level > 0 and not hits:
        print("  FAIL: the bot never hit"); fail = True
    if moved < 8:
        print("  FAIL: the bot barely moved"); fail = True
    if "MATCH_OVER" not in log:
        print("  FAIL: the match never ended"); fail = True

if rates[3] <= rates[0]:
    print("FAIL: Expert should be more accurate than Easy"); fail = True

log = read("still")
shots, hits, kinds, ropes, spots = bot_stats(log)
print(f"Easy vs a player standing still: shots {len(shots)}  hits {len(hits)}  errors {log.count('SCRIPT ERROR')}")
if not hits or log.count("SCRIPT ERROR"):
    print("  FAIL: Easy should hit a player who stands still"); fail = True

log = read("fight")
shots, hits, kinds, ropes, spots = bot_stats(log)
moves |= kinds
overs = log.count("MATCH_OVER")
print(f"Fight   shots {len(shots):3}  hits {len(hits):3}  moves {sorted(kinds)}  matches {overs}  "
      f"errors {log.count('SCRIPT ERROR')}")
if log.count("SCRIPT ERROR"):
    print("  FAIL: script errors"); fail = True
if overs < 2:
    print("  FAIL: expected a match and a rematch"); fail = True
if "FLIP" not in kinds:
    print("  FAIL: the bot never flip-dodged while being shot"); fail = True
for needed in ["SLIDE", "DIVE", "FLIP", "GRAPPLE"]:
    if needed not in moves:
        print(f"FAIL: no bot ever used {needed}"); fail = True

print("BOT TEST", "FAILED" if fail else "PASSED")
sys.exit(1 if fail else 0)
EOF
