#!/usr/bin/env bash
# The secret code over the network, with real copies of the game (see SecretRockets):
#  - P2, a client (not the host), types the code on the arrow keys in the lobby
#    (--secret-code-at); the host turns the Auto Rocket Launcher on and both copies
#    are told the setting and who typed it; P2 is handed the weapon;
#  - P2 readies up at the same moment (the host hands the weapon over itself, so the
#    Ready cannot beat it): the match starts with P2 on the Auto Rocket Launcher, and the
#    host flies P2's rockets fired full auto (many a second);
#  - when the match ends the host locks it again: both copies are told, and back in the
#    lobby P2 has its own weapon (the pistol) again;
#  - a Deathmatch (on a map without a rocket launcher): after the code every copy has an
#    Auto Rocket Launcher on the map and no plain rocket launcher;
#  - no script errors anywhere.
# (The rules, the weapon and the lobby page are checked step by step in tests/secret_rockets_test.gd.)
# Usage: tests/run_secret_rockets_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/secret_*.log
PORT=$((26500 + RANDOM % 100))
MAP="${MAP:-construction_site}"
COMMON=(--sync-log --scripted-input --scripted-fire --map="$MAP" --auto-return)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --weapon=sniper --start-when-ready --time-limit=14 \
  --quit-after=40 "${COMMON[@]}" > "$OUT/secret_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --weapon=pistol --secret-code-at=3 --ready-at=3 \
  --quit-after=38 "${COMMON[@]}" > "$OUT/secret_client.log" 2>&1 &
wait || true
# A Deathmatch on the Office (no rocket launcher of its own on the map).
PORT=$((PORT + 100))
"$GODOT" --headless --path . -- --host --port="$PORT" --name=P1 --game=dm --map=office --start-when-ready --time-limit=30 \
  --quit-after=16 --sync-log --scripted-input > "$OUT/secret_dm_host.log" 2>&1 &
sleep 1
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --name=P2 --secret-code-at=2 --ready-at=4 \
  --quit-after=14 --sync-log --scripted-input > "$OUT/secret_dm_client.log" 2>&1 &
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/secret_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import re, sys
out = sys.argv[1]
ok = True


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def lines(name):
    return open(f"{out}/secret_{name}.log", errors="replace").read().splitlines()


host, client = lines("host"), lines("client")
# P2's id: the one that is not the host in the host's loadouts.
ids = set()
for l in host:
    m = re.match(r"LOADOUTS 1 (.*)", l)
    if m:
        ids |= {int(p.split(":")[0]) for p in m.group(1).split()}
others = sorted(i for i in ids if i != 1)
check(len(others) == 1, f"the host sees one other player ({others})")
p2 = others[0] if others else -1
for name, log in [("host", host), ("client", client)]:
    codes = [l for l in log if l.startswith("SECRET_CODE ")]
    check(any(l.endswith(f"by {p2}") for l in codes), f"{name}: told P2 typed the code ({codes})")
    told = [l.split()[-1] for l in log if l.startswith("LOBBY_AUTO_ROCKETS ")]
    check("true" in told, f"{name}: told the Auto Rocket Launcher is unlocked ({told})")
    after = told[told.index("true"):] if "true" in told else []
    check("false" in after, f"{name}: told it is locked again after the match ({told})")
start = next((i for i, l in enumerate(host) if l.startswith("MATCH_START")), None)
check(start is not None, "the match starts")
at_start = [l for l in host[:start] if l.startswith("LOADOUTS 1 ")][-1:] if start is not None else []
check(bool(at_start) and f"{p2}:auto_rocket" in at_start[0], f"P2 starts the match with the Auto Rocket Launcher ({at_start})")
check(bool(at_start) and "1:sniper" in at_start[0], f"the host keeps its own weapon ({at_start})")
times = [float(l.split()[-1]) for l in host if l.startswith(f"PROJECTILE {p2} auto_rocket")]
gaps = [b - a for a, b in zip(times, times[1:])]
check(len(times) >= 5, f"the host flies P2's auto rockets ({len(times)})")
check(bool(gaps) and min(gaps) < 0.2, f"...fired full auto, many a second (closest {min(gaps) if gaps else 0:.3f} s apart)")
over = next((i for i, l in enumerate(host) if l.startswith("MATCH_OVER")), None)
check(over is not None, "the match ends")
later = [l for l in host[over:] if l.startswith("LOADOUTS 1 ")] if over is not None else []
lobby = [l for l in host[over:] if re.match(r"\[net\] %d took the " % p2, l)] if over is not None else []
check(any(f"{p2}:pistol" in l for l in later) or any(l.endswith("pistol") for l in lobby),
      f"back in the lobby P2 has the pistol again ({later[-1:] + lobby[-1:]})")
for name in ["dm_host", "dm_client"]:
    picks = [l.split()[-1].split(",") for l in lines(name) if l.startswith("PICKUPS ")]
    check(bool(picks) and "auto_rocket" in picks[-1] and "rocket_launcher" not in picks[-1],
          f"{name}: the Deathmatch has an Auto Rocket Launcher on the map ({picks[-1] if picks else 'none'})")
sys.exit(0 if ok else 1)
PY
if [ "$fail" = 0 ]; then echo "PASS: secret code over the network"; else echo "FAIL: secret code over the network (logs in $OUT/secret_*.log)"; exit 1; fi
