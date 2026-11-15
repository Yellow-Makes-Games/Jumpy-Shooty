#!/usr/bin/env python3
"""Checks how faithfully each game copy shows the other players.

Reads logs written with --sync-log. Every copy prints
  SYNC SELF <id> <time> x y z          its own true position (its own clock)
  SYNC SEEN <viewer> <target> <time> x y z
                                       where it draws another player, and the
                                       moment (in the target's clock) it shows.
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
                    seen_log[(int(parts[2]), int(parts[3]))].append((float(parts[4]), tuple(map(float, parts[5:8]))))

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
        for t, pos in samples:
            if t < warm or t < times[0] or t > times[-1]:
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
              f"{len(errors)} frames, error median {p50:.3f} m, p95 {p95:.3f} m, max {mx:.3f} m, pops {pops}")
    return 0 if ok else 1


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
