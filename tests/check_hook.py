#!/usr/bin/env python3
"""Checks that every game copy draws every other player's Grappling Hook 2 the way
that player's own game had it.

Reads logs written with --sync-log (see Player._log_own_hook). Every copy prints
  HOOKEV SELF <id> <shot> <moment> <time> [caught <player>|missed]
                    a moment of its own shot: launch, stop (the flight ended), taut
                    (the rope pulled tight) or release, on its own clock
  HOOKEV SEEN <viewer> <id> <shot> <moment> <time>
                    the same moment as the viewer rebuilt it from snapshots, on the
                    clock of the player whose hook it is
  HOOK SELF <id> <shot> <time> <stage> x y z slack
                    every step a shot is out: where its hook is and the rope's slack
  HOOK SEEN <viewer> <id> <shot> <time> <stage> x y z slack frame_dt
                    every frame the viewer draws someone's shot: the moment (their
                    clock) it shows, where it draws the hook and the slack

Two checks for every viewer and every other player:
 1. Moments: each launch, stop, taut and release the player logged is seen by the
    viewer, at the same time to within TIME_LIMIT.
 2. Hook: for each frame the viewer drew, the hook is where the player's own game
    had it at that moment. The player's game logs it once per step (0.7 m of flight)
    and reads its clock then, and steps bunch up when several headless copies share
    a CPU, so "where it was at that moment" is the nearest point of the path its hook
    took within WINDOW of that moment. Frames where the
    viewer itself stalled (frame_dt > 50 ms) are skipped. A shot hooked on a player
    is left out of this check: every copy ends that rope on the player as it draws
    them, on purpose (see Player._hook_anchor).

Usage: python3 tests/check_hook.py tests/out/hook_*.log
Exit code 0 = pass, 1 = fail.
"""
import bisect
import sys
from collections import defaultdict

TIME_LIMIT = 0.03      # seconds a moment may differ
WINDOW = 0.035         # seconds either side to look for the player's own steps
EDGE = 0.02            # seconds at each end of a shot's own log left out (nothing to compare with beyond them)
ERR_P95_LIMIT = 0.15   # metres
ERR_MAX_LIMIT = 0.4    # metres
SLACK_P95_LIMIT = 0.25 # metres
MOMENTS = ("launch", "stop", "taut", "release")


def main(paths):
    own_ev = defaultdict(dict)    # id -> {(shot, moment): time}
    seen_ev = defaultdict(dict)   # (viewer, id) -> {(shot, moment): time}
    on_player = defaultdict(set)  # id -> shots hooked on a player
    own = defaultdict(list)       # (id, shot) -> [(time, stage, (x, y, z), slack)]
    seen = defaultdict(list)      # (viewer, id) -> [(shot, time, stage, (x, y, z), slack, dt)]
    ends = {}                     # id -> last time it logged anything of its own
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                p = line.split()
                if len(p) < 6:
                    continue
                if p[0] == "HOOKEV" and p[1] == "SELF":
                    own_ev[int(p[2])][(int(p[3]), p[4])] = float(p[5])
                    if len(p) >= 8 and p[6] == "caught" and int(p[7]) != 0:
                        on_player[int(p[2])].add(int(p[3]))
                elif p[0] == "HOOKEV" and p[1] == "SEEN" and len(p) >= 7:
                    seen_ev[(int(p[2]), int(p[3]))][(int(p[4]), p[5])] = float(p[6])
                elif p[0] == "HOOK" and p[1] == "SELF" and len(p) >= 9:
                    own[(int(p[2]), int(p[3]))].append((float(p[4]), int(p[5]), tuple(map(float, p[6:9])), float(p[9])))
                elif p[0] == "HOOK" and p[1] == "SEEN" and len(p) >= 12:
                    seen[(int(p[2]), int(p[3]))].append((int(p[4]), float(p[5]), int(p[6]), tuple(map(float, p[7:10])), float(p[10]), float(p[11])))
                elif p[0] == "SYNC" and p[1] == "SELF":
                    ends[int(p[2])] = float(p[3])
    if not own_ev:
        print("FAIL: nobody fired Grappling Hook 2")
        return 1
    ok = True
    players = sorted(own_ev)
    viewers = sorted({v for v, _ in seen_ev} | set(players))
    for target in players:
        shots = sorted({s for s, _ in own_ev[target]})
        for viewer in viewers:
            if viewer == target:
                continue
            got = seen_ev.get((viewer, target), {})
            missing, worst, count = 0, 0.0, 0
            for (shot, moment), t in sorted(own_ev[target].items()):
                if shot == shots[-1] or t > ends.get(viewer, t) - 0.5:
                    continue   # fired as the test ended (or after this viewer left)
                if (shot, moment) not in got:
                    missing += 1
                    continue
                count += 1
                worst = max(worst, abs(got[(shot, moment)] - t))
            passed = count > 0 and missing == 0 and worst <= TIME_LIMIT
            ok &= passed
            print(f"{'PASS' if passed else 'FAIL'}: viewer {viewer} saw {count} moments of {target}'s {len(shots)} shots "
                  f"({missing} missing), worst timing {worst * 1000:.1f} ms")

            errors, slacks, stalls, wrong_stage = [], [], 0, 0
            for shot, t, stage, pos, slack, dt in seen.get((viewer, target), []):
                if shot in on_player[target]:
                    continue
                truth = own.get((target, shot))
                if not truth:
                    continue
                if dt > 0.05:
                    stalls += 1
                    continue
                times = [x[0] for x in truth]
                lo = bisect.bisect_left(times, t - WINDOW)
                hi = bisect.bisect_right(times, t + WINDOW)
                if lo >= hi or t < times[0] + EDGE or t > times[-1] - EDGE:
                    continue   # the player's own game logged nothing near that moment (it stalled), or it is the very start or end of what it logged
                near = truth[max(lo - 1, 0):min(hi + 1, len(truth))]   # (and a step either side, to join them up)
                errors.append(min([_to_segment(pos, a[2], b[2]) for a, b in zip(near, near[1:])] or [_dist(near[0][2], pos)]))
                slacks.append(min(abs(x[3] - slack) for x in near))
                if all(x[1] != stage for x in near):
                    wrong_stage += 1
            if not errors:
                print(f"FAIL: viewer {viewer} drew none of {target}'s hooks")
                ok = False
                continue
            errors.sort()
            slacks.sort()
            p95 = errors[int(len(errors) * 0.95)]
            s95 = slacks[int(len(slacks) * 0.95)]
            passed = p95 <= ERR_P95_LIMIT and errors[-1] <= ERR_MAX_LIMIT and s95 <= SLACK_P95_LIMIT and wrong_stage <= len(errors) * 0.02
            ok &= passed
            print(f"{'PASS' if passed else 'FAIL'}: viewer {viewer} draws {target}'s hook: {len(errors)} frames "
                  f"({stalls} viewer stalls skipped), hook off by median {errors[len(errors) // 2]:.3f} m, p95 {p95:.3f} m, "
                  f"max {errors[-1]:.3f} m; slack p95 {s95:.3f} m; {wrong_stage} frames in another stage")
    return 0 if ok else 1


def _to_segment(p, a, b):
    """Distance from p to the stretch from a to b."""
    ab = [b[k] - a[k] for k in range(3)]
    l2 = sum(x * x for x in ab)
    if l2 <= 1e-12:
        return _dist(p, a)
    u = max(0.0, min(1.0, sum((p[k] - a[k]) * ab[k] for k in range(3)) / l2))
    return _dist(p, tuple(a[k] + ab[k] * u for k in range(3)))


def _dist(a, b):
    return sum((a[k] - b[k]) ** 2 for k in range(3)) ** 0.5


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
