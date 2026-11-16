#!/usr/bin/env python3
"""Checks how faithfully each game copy shows the other players.

Reads logs written with --sync-log. Every copy prints
  SYNC SELF <id> <time> x y z          its own true position (its own clock)
  SYNC SEEN <viewer> <target> <time> x y z frame_dt
                                       where it draws another player, the moment
                                       (in the target's clock) it shows, and how
                                       long the viewer's frame took.
Frames where the viewer itself stalled (frame_dt > 50 ms, which happens when
several headless copies fight over the CPU on a test machine) are skipped, since
they say nothing about network smoothness.
For every SEEN sample we look up where the target really was at that moment and
measure the distance. We also look for visible pops: a frame where the drawn
player moves much further than the real player moved over the same time.

Usage: python3 tests/check_sync.py tests/out/*.log
Exit code 0 = pass, 1 = fail.
"""
import bisect
import sys
from collections import defaultdict

ERR_P95_LIMIT = 0.15   # metres
ERR_MAX_LIMIT = 0.60   # metres
POP_LIMIT = 0.35       # metres of extra movement in one frame


def main(paths):
    self_log = defaultdict(list)   # id -> [(t, (x,y,z))]
    seen_log = defaultdict(list)   # (viewer, target) -> [(t, (x,y,z))]
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                parts = line.split()
                if len(parts) < 3 or parts[0] != "SYNC":
                    continue
                if parts[1] == "SELF":
                    self_log[int(parts[2])].append((float(parts[3]), tuple(map(float, parts[4:7]))))
                elif parts[1] == "SEEN":
                    dt = float(parts[8]) if len(parts) > 8 else 0.0
                    seen_log[(int(parts[2]), int(parts[3]))].append((float(parts[4]), tuple(map(float, parts[5:8])), dt))

    if not seen_log:
        print("FAIL: no SEEN samples; did the copies connect and start a match?")
        return 1

    ok = True
    for (viewer, target), samples in sorted(seen_log.items()):
        if viewer == target:
            continue  # a copy that already left the session; not a real view
        truth = sorted(self_log.get(target, []))
        if len(truth) < 2:
            print(f"FAIL: no SELF log for player {target}")
            ok = False
            continue
        times = [t for t, _ in truth]
        errors, pops = [], 0
        prev = None
        warm = samples[0][0] + 1.0  # ignore the first second (buffer filling, spawn teleport)
        stalls = 0
        for t, pos, dt in samples:
            if t < warm or t < times[0] or t > times[-1]:
                prev = None
                continue
            if dt > 0.05:
                stalls += 1
                prev = None
                continue
            real = _interp(truth, times, t)
            errors.append(_dist(pos, real))
            if prev is not None:
                pt, ppos, preal = prev
                drawn_step = _dist(pos, ppos)
                real_step = _dist(real, preal)
                if drawn_step - real_step > POP_LIMIT:
                    pops += 1
            prev = (t, pos, real)
        if not errors:
            print(f"FAIL: viewer {viewer} -> target {target}: no overlapping samples")
            ok = False
            continue
        errors.sort()
        p50 = errors[len(errors) // 2]
        p95 = errors[int(len(errors) * 0.95)]
        mx = errors[-1]
        passed = p95 <= ERR_P95_LIMIT and mx <= ERR_MAX_LIMIT and pops == 0
        ok &= passed
        print(f"{'PASS' if passed else 'FAIL'}: viewer {viewer} sees {target}: "
              f"{len(errors)} frames ({stalls} viewer stalls skipped), error median {p50:.3f} m, p95 {p95:.3f} m, max {mx:.3f} m, pops {pops}")
    ok &= _check_ropes(paths)
    return 0 if ok else 1


def _check_ropes(paths):
    """Every grapple a player fires should be drawn by everyone else.
    Allows one miss per pair, for a rope fired just before the test ended."""
    fired = {}  # player -> times they hooked on
    seen = {}   # (viewer, player) -> times the viewer showed their rope
    for path in paths:
        with open(path) as f:
            for line in f:
                parts = line.split()
                if len(parts) == 4 and parts[0] == "ROPE" and parts[1] == "SELF" and parts[3] == "on":
                    fired[parts[2]] = fired.get(parts[2], 0) + 1
                elif len(parts) == 5 and parts[0] == "ROPE" and parts[1] == "SEEN" and parts[4] == "on":
                    key = (parts[2], parts[3])
                    seen[key] = seen.get(key, 0) + 1
    if not fired:
        print("FAIL: nobody fired the grapple")
        return False
    ok = True
    viewers = {v for v, _ in seen} | set(fired)
    for player, count in sorted(fired.items()):
        for viewer in sorted(viewers - {player}):
            got = seen.get((viewer, player), 0)
            passed = got >= count - 1
            ok &= passed
            print(f"{'PASS' if passed else 'FAIL'}: viewer {viewer} saw {got} of {player}'s {count} grapples")
    return ok


def _interp(truth, times, t):
    i = bisect.bisect_right(times, t)
    if i <= 0:
        return truth[0][1]
    if i >= len(truth):
        return truth[-1][1]
    (t0, a), (t1, b) = truth[i - 1], truth[i]
    u = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
    return tuple(a[k] + (b[k] - a[k]) * u for k in range(3))


def _dist(a, b):
    return sum((a[k] - b[k]) ** 2 for k in range(3)) ** 0.5


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
