#!/usr/bin/env bash
# The host's random map and lobby song, with real copies of the game:
#  - the host sets a random map from a pool of two (--map=random --map-pool=...) and a
#    lobby song (--song), then picks another song a few seconds later (--song-at);
#  - P2, in the lobby from the start, is told the random map and its pool and hears
#    the host's songs: the same song, started at the same moment on the host's clock;
#  - when P2 readies up the match starts: the host picks a map from the pool and every
#    copy plays that map; P3, who joins mid-match, loads the same map and hears the same song;
#  - no script errors anywhere.
# (The rules and the lobby's controls are checked step by step in tests/host_controls_test.gd.)
# Usage: tests/run_host_controls_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/hostctl_*.log
PORT=$((26300 + RANDOM % 100))
COMMON=(--sync-log --scripted-input)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --map=random --map-pool=office,kilnworks \
  --song=immersive_bark_2 --song-at=4:polyphonic_anthem_1 --start-when-ready --time-limit=60 --quit-after=24 "${COMMON[@]}" \
  > "$OUT/hostctl_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --ready-at=7 --quit-after=22 "${COMMON[@]}" \
  > "$OUT/hostctl_early.log" 2>&1 &
sleep 13
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P3 --quit-after=9 "${COMMON[@]}" \
  > "$OUT/hostctl_late.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/hostctl_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import re, sys
out = sys.argv[1]
ok = True
POOL = {"office", "kilnworks"}


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def lines(name):
    return open(f"{out}/hostctl_{name}.log", errors="replace").read().splitlines()


picks = [l.split()[2] for l in lines("host") if l.startswith("RANDOM_MAP ")]
check(len(picks) == 1 and picks[0] in POOL, f"host: picked one map from the pool ({picks})")
pick = picks[0] if picks else "?"

for name in ["host", "early", "late"]:
    played = [l for l in lines(name) if l.startswith("MATCH_MAP ")]
    check(bool(played) and all(l.split()[2] == pick for l in played), f"{name}: plays the map the host picked ({played})")
    told = [l for l in lines(name) if l.startswith("LOBBY_MAP ")]
    last = told[-1] if told else ""
    check("random=true" in last and "pool=office,kilnworks" in last, f"{name}: told the random map and its pool ({last or 'never'})")
check(any("(late)" in l for l in lines("late") if l.startswith("MATCH_MAP ")), "late: joined mid-match")
told = [l for l in lines("late") if l.startswith("LOBBY_MAP ")]
check(bool(told) and f"map={pick}" in told[0], f"late: the first settings it gets have the real map ({told[0] if told else 'never'})")

# The songs: the host's picks, each with its start time on the host's clock.
host_songs = {}
for l in lines("host"):
    m = re.match(r"MUSIC 1 (\S+) (-?[0-9.]+)$", l)
    if m:
        host_songs.setdefault(m.group(1), []).append(float(m.group(2)))
check("immersive_bark_2" in host_songs, f"host: plays its lobby song ({sorted(host_songs)})")
check("polyphonic_anthem_1" in host_songs, "host: switches to the song it picked later")
order = [m.group(1) for l in lines("host") for m in [re.match(r"MUSIC 1 (\S+) ", l)] if m]
check("immersive_bark_2" in order and "polyphonic_anthem_1" in order[order.index("immersive_bark_2"):], f"host: in that order ({order})")


def seen(name):
    out_ = []
    for l in lines(name):
        m = re.match(r"MUSIC SEEN \d+ (\S+) (-?[0-9.]+)$", l)
        if m:
            out_.append((m.group(1), float(m.group(2))))
    return out_


for name in ["early", "late"]:
    got = seen(name)
    names = [s for s, _ in got]
    want = ["immersive_bark_2", "polyphonic_anthem_1"] if name == "early" else ["polyphonic_anthem_1"]
    check(all(w in names for w in want), f"{name}: hears the host's songs ({names})")
    same = all(any(abs(at - h) < 0.01 for h in host_songs.get(s, [])) for s, at in got if s in want)
    check(same and bool(got), f"{name}: each started at the same moment as the host's")
    # It stays on the host's pick (no song of its own) until the match.
    check("polyphonic_anthem_1" in names and names[-1] == "polyphonic_anthem_1", f"{name}: ends on the song the host picked last")
sys.exit(0 if ok else 1)
PY
if [ "$fail" -ne 0 ]; then echo "HOST CONTROLS TEST FAILED (logs in $OUT/hostctl_*.log)"; exit 1; fi
echo "HOST CONTROLS TEST PASSED"
