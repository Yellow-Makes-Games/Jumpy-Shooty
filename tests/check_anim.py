#!/usr/bin/env python3
"""Checks that every game copy shows other players doing what they are really doing.

Reads logs written with --sync-log. Whenever a body's animation changes, its copy prints
  ANIM SELF <id> <time> <animation>            what a player (or the bot) is doing
  ANIM SEEN <viewer> <id> <time> <animation>   what a copy draws for another player
  ANIM FIRE <id>                               a player fired
  ANIM SHOT <viewer> <id>                      a copy kicked another player's gun
<animation> is the animator's body source (loco, air, slide, wall_l, flip_back, ...)
plus "+reload" while the reload plays, or "-" once the body is gone (match over).
Each copy also prints, when it builds a player's body for a match,
  CHAR SELF <id> <character>                   the robot a player (or bot) plays as
  CHAR SEEN <viewer> <id> <character>          the robot a copy shows for another player
Times are on the player's own clock. The host also prints "SHOT <id> ..." for every
shot it accepts; a shot it turns down (fired a moment after dying) is not shown.

For each viewer and player we check:
  - agreement: at each moment, the viewer shows what the player was doing around
    then (within TOLERANCE seconds, since states change between network updates)
  - moves: each time a player held a move for a little while, the viewer showed it
  - shots: the viewer kicked the gun for (nearly) every shot fired
  - character: match after match, the viewer shows the robot the player picked

Usage: python3 tests/check_anim.py [--need=a,b,c] tests/out/*.log
  --need lists animations that must have been exercised by at least one player
  ("reload" counts whatever the body was doing at the time).
  --characters=N fails unless at least N different robots were played.
  --switched fails unless some player changed robot between matches.
Exit code 0 = pass, 1 = fail.
"""
import bisect
import sys
from collections import defaultdict

TOLERANCE = 0.25     # seconds
STEP = 0.02          # seconds between the moments we compare
MIN_HOLD = 0.2       # a move shorter than this may fall between two network updates
AGREE_LIMIT = 0.95   # share of moments that must agree
MOVES_LIMIT = 0.90   # share of held moves that must be shown
SHOTS_LIMIT = 0.90


def main(args):
    need = set()
    want_characters = 0
    want_switch = False
    paths = []
    for a in args:
        if a.startswith("--need="):
            need = set(a[7:].split(","))
        elif a.startswith("--characters="):
            want_characters = int(a[13:])
        elif a == "--switched":
            want_switch = True
        else:
            paths.append(a)
    real = defaultdict(list)    # id -> [(t, animation)]
    seen = defaultdict(list)    # (viewer, id) -> [(t, animation)]
    fired = defaultdict(int)
    judged = defaultdict(int)
    shots = defaultdict(int)
    played = defaultdict(list)       # id -> the character they played, match by match
    shown_as = defaultdict(list)     # (viewer, id) -> the character shown, match by match
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                p = line.split()
                if len(p) >= 3 and p[0] == "SHOT" and p[1].isdigit():
                    judged[int(p[1])] += 1
                if len(p) == 4 and p[0] == "CHAR" and p[1] == "SELF":
                    played[int(p[2])].append(p[3])
                elif len(p) == 5 and p[0] == "CHAR" and p[1] == "SEEN":
                    shown_as[(int(p[2]), int(p[3]))].append(p[4])
                if len(p) < 3 or p[0] != "ANIM":
                    continue
                if p[1] == "SELF" and len(p) == 5:
                    real[int(p[2])].append((float(p[3]), p[4]))
                elif p[1] == "SEEN" and len(p) == 6:
                    seen[(int(p[2]), int(p[3]))].append((float(p[4]), p[5]))
                elif p[1] == "FIRE":
                    fired[int(p[2])] += 1
                elif p[1] == "SHOT" and len(p) == 4:
                    shots[(int(p[2]), int(p[3]))] += 1
    if not real:
        print("FAIL: no ANIM lines; was the game run with --sync-log?")
        return 1

    ok = True
    used = {part for line in real.values() for _, name in line for part in name.split("+")} - {"-"}
    print("animations played: " + " ".join(sorted(used)))
    if judged:
        fired = judged
    missing = need - used
    if missing:
        print(f"FAIL: the test never exercised: {' '.join(sorted(missing))}")
        ok = False

    for (viewer, target), drawn in sorted(seen.items()):
        if viewer == target or target not in real:
            continue
        truth = sorted(real[target])
        drawn.sort()
        start = max(truth[0][0], drawn[0][0]) + 1.0
        end = min(truth[-1][0], drawn[-1][0])
        if end - start < 2.0:
            continue  # joined at the very end; nothing to compare
        # Agreement, both ways round.
        agree = total = 0
        t = start
        while t < end:
            a, b = _at(truth, t), _at(drawn, t)
            if a != "-" and b != "-":   # between matches there is nothing to compare
                total += 2
                agree += b in _around(truth, t)
                agree += a in _around(drawn, t)
            t += STEP
        if not total:
            continue
        share = agree / total
        # Held moves.
        held = shown = 0
        missed = defaultdict(int)
        for i, (t0, name) in enumerate(truth):
            t1 = truth[i + 1][0] if i + 1 < len(truth) else end
            if t0 < start or t1 > end or t1 - t0 < MIN_HOLD or name == "-":
                continue
            if "-" in _between(drawn, t0 - TOLERANCE, t1 + TOLERANCE):
                continue  # the viewer was between matches for part of it
            held += 1
            if name in _between(drawn, t0 - TOLERANCE, t1 + TOLERANCE):
                shown += 1
            else:
                missed[name] += 1
        moves = shown / held if held else 1.0
        passed = share >= AGREE_LIMIT and moves >= MOVES_LIMIT
        text = f"viewer {viewer} sees {target}: agreement {share:.1%}, moves shown {shown} of {held}"
        if missed:
            text += " (missed " + ", ".join(f"{n} x{c}" for n, c in sorted(missed.items())) + ")"
        if fired.get(target):
            got = shots.get((viewer, target), 0)
            text += f", shots {got} of {fired[target]}"
            passed &= got >= fired[target] * SHOTS_LIMIT - 1
        print(("PASS: " if passed else "FAIL: ") + text)
        ok &= passed
    ok &= _check_characters(played, shown_as, want_characters, want_switch)
    return 0 if ok else 1


def _check_characters(played, shown, want_characters, want_switch):
    """Every copy must show each player as the robot they picked, in every match."""
    ok = True
    used = sorted({c for line in played.values() for c in line})
    print("characters played: " + " ".join(used))
    if len(used) < want_characters:
        print(f"FAIL: expected at least {want_characters} different characters")
        ok = False
    if want_switch and not any(len(set(line)) > 1 for line in played.values()):
        print("FAIL: nobody changed character between matches")
        ok = False
    for (viewer, target), line in sorted(shown.items()):
        if viewer == target or target not in played:
            continue
        truth = played[target]
        # A copy that joined late or left early saw fewer matches; compare what overlaps.
        n = min(len(truth), len(line))
        passed = n > 0 and line[:n] == truth[:n]
        ok &= passed
        print(f"{'PASS' if passed else 'FAIL'}: viewer {viewer} shows {target} as {' then '.join(line[:n]) or 'nothing'}"
              + ("" if passed else f" (they played {' then '.join(truth[:n])})"))
    return ok


def _at(line, t):
    i = bisect.bisect_right(line, (t, "~")) - 1
    return line[max(i, 0)][1]


def _between(line, t0, t1):
    names = {_at(line, t0)}
    i = bisect.bisect_right(line, (t0, "~"))
    while i < len(line) and line[i][0] <= t1:
        names.add(line[i][1])
        i += 1
    return names


def _around(line, t):
    return _between(line, t - TOLERANCE, t + TOLERANCE)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
