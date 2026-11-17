"""The building blocks of a race course: one function per kind of obstacle.

Each one builds from the cursor (see course.py), adds the bots' route points for
it, and leaves the cursor at the far edge of its last floor. The numbers follow
the Testing Grounds courses, which tests/course_test.gd proves can be done:
gaps up to 6 m with a jump, 10 m with a dive, 13 m with a flip and a dive; wall
panels 4 m apart; a 3 m wide chimney; grapple beams 12 m apart, 8.5 m up.
`T` is the map's theme: its kinds and how it dresses floors (see build_race_maps.py).
"""
import math


def floor(c, T, g, f0, f1, top=0.0, width=None, r=0.0, kind=None, open_side=0):
    w = width or c.W
    c.deck(g, f0, f1, kind or T.deck, top=top, width=w, r=r, thick=T.thick)
    T.under(c, g, f0, f1, top, w, r, open_side)


def gap_action(d):
    if d <= 5.5:
        return "JUMP"
    if d <= 8.0:
        return "LONG_JUMP"
    if d <= 9.5:
        return "DIVE_JUMP"
    return "FLIP_DIVE"


def start(c, T, name="Start"):
    g = c.group(name)
    floor(c, T, g, -16, 10)
    c.spawns(-8)
    c.point(6, 0, 0, "RUN", radius=2.0)
    T.start_dressing(c, g)
    c.advance(10)


def run(c, T, L, name="Run"):
    g = c.group(name)
    floor(c, T, g, 0, L)
    c.point(L - 1.5, 0, 0, "RUN", radius=2.0)
    c.advance(L)


def checkpoint(c, T, name="CheckpointPad", L=12):
    g = c.group(name)
    floor(c, T, g, 0, L)
    c.gate(4)
    c.advance(L)


def gaps(c, T, spans, name="Gaps"):
    """spans: [(gap, landing length, height change)] ..."""
    for s in spans:
        d, land = s[0], s[1]
        dy = s[2] if len(s) > 2 else 0.0
        g = c.group(name)
        c.point(-0.45, 0, 0, gap_action(d), radius=0.55)
        floor(c, T, g, d, d + land, top=dy)
        c.point(d + 3.0, dy, 0, "RUN", radius=1.8)
        c.advance(d + land, dy)


def vaults(c, T, n, h=1.0, name="Vaults"):
    g = c.group(name)
    L = n * 5 + 4
    floor(c, T, g, 0, L)
    for i in range(n):
        f = 3 + 5 * i
        c.box(g, "Low", f, f + 0.6, -c.W / 2, c.W / 2, 0, h, T.obstacle)
    c.point(L - 1.0, 0, 0, "RUN", radius=2.0)
    c.advance(L)


def climb(c, T, heights, name="Climb"):
    for h in heights:
        g = c.group(name)
        floor(c, T, g, 0, 6)
        c.point(5.0, 0, 0, "JUMP", radius=0.6)
        T.ledge(c, g, 6, h)
        c.advance(6, h)
    g = c.group(name)
    floor(c, T, g, 0, 7)
    c.point(4.0, 0, 0, "RUN", radius=1.6)
    c.advance(7)


def slide_under(c, T, L=10, name="SlideUnder"):
    """Low bars across the way, with walls each side: slide under them."""
    g = c.group(name)
    run_in = 4.0
    floor(c, T, g, 0, run_in + L + 5)
    W = c.W
    for side in (-1, 1):
        c.box(g, "Side", run_in, run_in + L + 1.5, side * W / 2, side * (W / 2 + 0.6), 0, 3.2, T.wall)
    f = run_in + 1.5
    while f < run_in + L:
        c.box(g, "Low", f, f + 0.6, -W / 2, W / 2, 1.4, 2.4, T.duct)
        c.box(g, "Low", f - 0.1, f + 0.7, -W / 2, W / 2, 2.4, 3.2, T.wall)
        f += 2.2
    c.point(1.2, 0, 0, "SLIDE", radius=1.2)
    c.point(run_in + L + 2.5, 0, 0, "RUN", radius=2.0)
    c.advance(run_in + L + 5)


def crawl(c, T, L=8, name="Crawl"):
    """A tunnel too low to crouch through: dive onto your front and slide, then crawl."""
    g = c.group(name)
    W = c.W
    run_in = 7.0
    floor(c, T, g, 0, run_in + L + 5)
    for side in (-1, 1):
        c.box(g, "Side", run_in, run_in + L, side * 1.6, side * W / 2, 0, 2.2, T.wall)
    c.box(g, "Roof", run_in, run_in + L, -W / 2, W / 2, 0.95, 2.2, T.duct)
    T.tunnel(c, g, run_in, run_in + L)
    c.point(1.5, 0, 0, "CRAWL", radius=0.9)
    c.point(run_in + L + 2.5, 0, 0, "RUN", radius=1.8)
    c.advance(run_in + L + 5)


def wallrun(c, T, side=-1, panels=2, name="WallRun", run_in=8.0):
    """Edge, then a drop with wall panels either side: run along one, kick to the other.
    `run_in` metres of floor first, so the way in is the same whatever came before (straight
    off a corner, the angle in was anyone's guess, and too shallow a one misses the wall)."""
    g = c.group(name)
    s = side
    if run_in:
        floor(c, T, g, 0, run_in)
        c.point(2.0, 0, -s * 0.5, "RUN", radius=1.0)   # then in at a slant, so the jump carries onto the wall
        c.advance(run_in)
    spans = [(1, 17, s)] + ([(15, 27, -s)] if panels > 1 else [])
    for f0, f1, sd in spans:
        c.box(g, "Panel", f0, f1, sd * 2.0, sd * 3.0, -4.0, 5.0, T.panel)
        T.panel_dressing(c, g, f0, f1, sd)
    end = spans[-1][1]
    land0 = end + 2
    # Long and wide: the last kick carries you well out sideways and forwards.
    floor(c, T, g, land0, land0 + 20, width=c.W + 4)
    c.point(-0.6, 0, s * 0.8, "WALL_RUN", radius=0.7)   # line up with the wall before the edge
    c.point(3.5, 0.5, s * 1.55, "RUN", radius=1.0)
    if panels > 1:
        c.point(13.5, 0.5, s * 1.55, "WALL_JUMP", radius=1.0)
        c.point(24.0, 0.5, -s * 1.55, "WALL_JUMP", radius=1.0)
    else:
        c.point(14.5, 0.5, s * 1.55, "WALL_JUMP", radius=1.0)
    c.point(land0 + 8, 0, 0, "RUN", radius=2.0)
    c.advance(land0 + 20)


def chimney(c, T, h=8.0, side=1, name="Chimney"):
    g = c.group(name)
    floor(c, T, g, 0, 9)
    for sd in (-1, 1):
        c.box(g, "Wall", 4, 9, sd * 1.5, sd * 2.5, 0, h + 1.5, T.panel)
    c.box(g, "Back", 3.0, 4.0, -2.5, -1.5, 0, h + 1.5, T.panel)   # a doorway's edge: shows where to go in
    c.box(g, "Back", 3.0, 4.0, 1.5, 2.5, 0, h + 1.5, T.panel)
    top = c.group(name + "Top")
    c.box(top, "Tower", 9, 17, -c.W / 2, c.W / 2, -1, h, T.tower)
    floor(c, T, top, 9, 17, top=h)
    c.point(6.8, 0, side * 1.05, "CHIMNEY", radius=0.5)
    c.point(12.5, h, 0, "RUN", radius=1.8)
    c.advance(17, h)


def grapple(c, T, n=3, name="Grapple"):
    g = c.group(name)
    beams = [7 + 12 * i for i in range(n)]
    for i, f in enumerate(beams):
        T.beam(c, g, f, 8.5)
    land0 = 12 * n + 4
    floor(c, T, g, land0, land0 + 9)
    c.point(-0.8, 0, 0, "GRAPPLE", aim=(beams[0] + 0.8, 8.0, 0), radius=0.6)
    for i in range(1, n):
        f = beams[i - 1] + 1.5
        c.point(f, -1.0, 0, "GRAPPLE", aim=(beams[i] - f, 9.0, 0), radius=2.5)
    c.point(land0 + 4, 0, 0, "RUN", radius=2.2)
    c.advance(land0 + 9)


def pistons(c, T, n=4, name="Pistons"):
    """Platforms rising and sinking out of a hazard (molten metal, the void's edge)."""
    g = c.group(name)
    D, P = 6.0, 8.5   # platform depth, pitch (a full-speed jump carries about 7.5 m)
    L = 2.5 + P * n
    T.pool(c, g, 0, L, -2.4)
    period, hold, lag = 5.0, 0.35, 0.2
    starts = [2.5 + P * i for i in range(n)]
    for i, a in enumerate(starts):
        m = c.mover(g, "Piston", a + D / 2, 0, 0, travel=(0, -3.6, 0), period=period, hold=hold, phase=-lag * i)
        c.mblock(m, "Top", 0, -0.5, 0, (4.0, 1.0, D), T.platform)
        c.mblock(m, "Stem", 0, -4.0, 0, (1.2, 6.0, 1.2), T.stem)
    floor(c, T, g, L, L + 9)
    c.point(-5.5, 0, 0, "WAIT_GROUND", aim=(5.5 + starts[0] + D / 2, 0, 0), radius=0.8)
    c.point(-0.45, 0, 0, "JUMP", radius=0.55)
    for i, a in enumerate(starts):
        nxt = (starts[i + 1] + D / 2) if i + 1 < n else L + 3
        c.point(a + D / 2, 0, 0, "WAIT_GROUND", aim=(nxt - (a + D / 2), 0, 0), radius=1.0)
        c.point(a + D - 0.45, 0, 0, "JUMP", radius=0.55)
    c.point(L + 3.5, 0, 0, "RUN", radius=2.0)
    c.advance(L + 9)


def presses(c, T, n=3, name="Presses"):
    g = c.group(name)
    W = c.W
    L = 4 * n + 6
    floor(c, T, g, 0, L)
    for sd in (-1, 1):
        c.box(g, "Side", 0, L, sd * W / 2, sd * (W / 2 + 1), 0, 6.5, T.wall)
    c.box(g, "Roof", 0, L, -W / 2 - 1, W / 2 + 1, 6.5, 7.3, T.wall)
    period, hold = 4.0, 0.42
    for i in range(n):
        f = 3 + 4 * i
        m = c.mover(g, "Press", f, 0, 0, travel=(0, -2.4, 0), period=period, hold=hold, phase=-0.09 * i)
        c.mblock(m, "Head", 0, 3.7, 0, (W - 0.1, 2.6, 2.0), T.press, hazard=True, solid=False)
        c.mblock(m, "Edge", 0, 2.45, 0, (W - 0.1, 0.12, 2.04), T.hot, solid=False)
        c.mblock(m, "Ram", 0, 5.6, 0, (1.0, 1.4, 1.0), T.stem)
    c.point(0.4, 0, 0, "WAIT_CLEAR", aim=(2.6, 1.0, 0), radius=0.8)
    c.point(L - 2, 0, 0, "RUN", radius=2.0)
    c.advance(L)


def sweepers(c, T, n=2, name="Sweepers"):
    """Long bars swinging round a post at the side, at knee height: jump them, or
    run through while the bar is out over the edge."""
    g = c.group(name)
    gapf = 18
    L = gapf * n + 2
    floor(c, T, g, 0, L)
    reach = c.W + 0.5
    for i in range(n):
        f = 9 + gapf * i
        sd = -1 if i % 2 == 0 else 1
        pr = sd * (c.W / 2 + 0.6)
        c.block(g, "Post", c.w(f, 1.5, pr), (0.8, 3.0, 0.8), T.stem, shape="cyl", sides=12)
        c.box(g, "Foot", f - 1, f + 1, pr - 1, pr + 1, -0.3, 0.1, T.stem)
        m = c.mover(g, "Sweeper", f, 0, pr, spin=(80 if i % 2 == 0 else -80), phase=0.5 * i)
        c.mblock(m, "Bar", 0, 0.75, -sd * reach / 2, (reach, 0.45, 0.45), T.beam_hazard, hazard=True, solid=False)
        clear = math.sqrt((reach + 0.8) ** 2 - pr ** 2) + 0.3   # where the path leaves the bar's circle
        c.point(f - clear, 0, 0, "WAIT_CLEAR", radius=0.9)
        c.point(f + clear, 0, 0, "RUN", radius=1.5)
    c.advance(L)


def strips(c, T, n=4, name="Strips"):
    g = c.group(name)
    P = 12.0   # a running jump carries 7.5 m (11 m bunny-hopping): land well clear of the next strip
    L = P * n + 4
    floor(c, T, g, 0, L)
    for i in range(n):
        f = 4 + P * i
        c.box(g, "Live", f, f + 2.0, -c.W / 2, c.W / 2, 0, 0.35, T.hot, hazard=True, solid=False)
        c.point(f - 1.5, 0, 0, "JUMP", radius=0.55)
    c.point(L - 1.0, 0, 0, "RUN", radius=2.0)
    c.advance(L)


def slope(c, T, L, dy, slide=False, name="Slope"):
    g = c.group(name)
    c.ramp(g, 0, 0, L, dy, T.ramp, thick=T.thick)
    T.under_ramp(c, g, L, dy)
    if slide:
        c.point(0.8, 0, 0, "SLIDE", radius=1.2)
    floor(c, T, g, L, L + 8, top=dy)
    c.point(L + 3.5, dy, 0, "RUN", radius=2.0)
    c.advance(L + 8, dy)


def turn(c, T, right, name="Corner"):
    g = c.group(name)
    W = c.W
    floor(c, T, g, 0, W, open_side=1 if right else -1)   # no rail across the way out
    centre = c.w(W / 2)
    c.point(W / 2, 0, 0, "RUN", radius=2.6)
    c.turn(right)
    c.pos = (centre[0] + c.F[0] * W / 2, centre[1], centre[2] + c.F[2] * W / 2)


def finish(c, T, name="Finish"):
    g = c.group(name)
    floor(c, T, g, 0, 18)
    c.gate(6, finish=True)
    c.point(10, 0, 0, "RUN", radius=3.0)
    T.finish_dressing(c, g)
    c.advance(18)


# ---------------------------------------------------------------------------
# Sections built for the newer moves: rocket boots (E), the glide (hold Shift in
# the air), the grapple's pull, and the belly slide. Measured in the game with the
# race_lab strip (see build_race_maps.py): a flip and a dive clear 13 m on the
# level and 19 m off a 4 m drop, and 26 m off a ski jump at slide speed (a jump
# and a flip, 22 m); a sprinting jump with the boots fired just after take-off
# (tipped up by holding Space) clears 20 m easily and 37 m off a 6 m drop; the
# boots fired up from a jump reach a ledge 7 m up (a jump and a ledge grab reach
# 3.5 m).
# The glide holds you up but bleeds your speed, so it is for hanging in the air
# and for slow gaps, not for long fast ones: from a sprinting jump it reaches 16 m
# off a 3 m drop (the jump alone, 11 m), and 26 m off a 6 m drop with the boots
# fired in it; at slide speed off a ski jump it reaches 20 m, less than a flip
# does, which is why the ski jump is a flip and a dive.

def boost_gap(c, T, d=17.0, land=18, dy=0.0, name="BoostGap"):
    """A gap no jump can clear (13 m is the most a flip and a dive manage): jump and fire the
    rocket boots. The landing is long, because you come down fast."""
    g = c.group(name)
    T.takeoff(c, g, 0)
    c.point(-0.45, 0, 0, "BOOST_JUMP", radius=0.55)
    floor(c, T, g, d, d + land, top=dy)
    c.point(d + land - 4, dy, 0, "RUN", radius=2.0)
    c.advance(d + land, dy)


def boost_wall(c, T, h=7.0, name="BoostWall"):
    """A sheer wall too tall to climb (3.5 m is the most a jump and a ledge grab reach):
    boost up it and climb on. A straight run at it first, so you go up and not off the side."""
    g = c.group(name)
    W = 12.0
    floor(c, T, g, 0, W)
    T.takeoff(c, g, W - 1.5, mark_only=True)
    top = c.group(name + "Top")
    c.box(top, "Tower", W, W + 10, -c.W / 2, c.W / 2, -1, h, T.tower)
    floor(c, T, top, W, W + 10, top=h)
    c.point(3.0, 0, 0, "RUN", radius=1.5)
    c.point(W - 1.4, 0, 0, "BOOST_UP", radius=0.7)
    c.point(W + 4.5, h, 0, "RUN", radius=2.0)
    c.advance(W + 10, h)


def glide_gap(c, T, d=13.0, dy=-3.0, land=14, boost=False, name="GlideGap"):
    """A drop across, too far for a jump alone: jump, then hold Shift at the top of the jump
    and glide over. With `boost`, longer (20 m off a 6 m drop is a fair size): fire the boots
    in the glide as well."""
    g = c.group(name)
    T.takeoff(c, g, 0)
    c.point(-0.45, 0, 0, "GLIDE_JUMP", radius=0.55, boost=boost)
    floor(c, T, g, d, d + land, top=dy)
    c.point(d + land - 4, dy, 0, "RUN", radius=2.0)
    c.advance(d + land, dy)


def grapple_swing(c, T, anchors, land_gap=6.0, land=14, dy=0.0, boost=False, name="GrappleSwing"):
    """A wide drop with high anchors over it (anchors: [(f, height)], f from the edge). The
    pull flings you toward each one; let go past it to fly on to the next, and from the last
    one onto the landing. With `boost` the last release needs the boots too."""
    g = c.group(name)
    for f, hh in anchors:
        T.beam(c, g, f, hh)
    land0 = anchors[-1][0] + land_gap
    floor(c, T, g, land0, land0 + land, top=dy)
    f0, h0 = anchors[0]
    c.point(-0.8, 0, 0, "GRAPPLE", aim=(f0 + 0.8, h0 - 0.5, 0), radius=0.6, boost=boost and len(anchors) == 1)
    for i in range(1, len(anchors)):
        fp, hp = anchors[i - 1]
        f, hh = anchors[i]
        at = fp + 1.5
        c.point(at, hp - 9.5, 0, "GRAPPLE", aim=(f - at, hh - 0.5 - (hp - 9.5), 0), radius=2.5,
                boost=boost and i == len(anchors) - 1)
    c.point(land0 + 4, dy, 0, "RUN", radius=2.2)
    c.advance(land0 + land, dy)


def belly_chute(c, T, L=22.0, dy=-6.0, name="BellyChute"):
    """A low, steep tunnel: dive onto your front before it and belly-slide down, picking up
    speed. Too low to crouch through (0.95 m), so it is a crawl if you stop."""
    g = c.group(name)
    W = c.W
    run_in = 12.0   # room to land the dive before the mouth, coming in fast
    floor(c, T, g, 0, run_in)
    c.ramp(g, run_in, 0, run_in + L, dy, T.ramp, thick=T.thick)
    T.under_ramp_at(c, g, run_in, L, dy)
    # The roof follows the slope 0.95 m up; walls either side.
    roof_t = 0.8
    a = math.atan2(dy, L)
    lift = 0.95 / math.cos(a) + roof_t / math.cos(a)
    c.ramp(g, run_in, lift, run_in + L, dy + lift, T.duct, thick=roof_t, width=W, name="Roof")
    for sd in (-1, 1):
        c.ramp(g, run_in, 2.2, run_in + L, dy + 2.2, T.wall, thick=2.2, width=(W / 2 - 1.6), r=sd * (1.6 + (W / 2 - 1.6) / 2), name="Side")
    T.chute_mouth(c, g, run_in, 0)
    end = run_in + L
    floor(c, T, g, end, end + 14, top=dy)
    c.point(1.0, 0, 0, "CRAWL", radius=1.0)
    c.point(end + 6, dy, 0, "RUN", radius=2.0)
    c.advance(end + 14, dy)


def ski_jump(c, T, L=18.0, dy=-6.0, d=21.0, ddy=-4.0, land=16, action="FLIP_DIVE", boost=False, name="SkiJump"):
    """Slide down a slope straight off a lip, then flip and dive across the drop beyond: the
    slide's speed carries them much further than they go from a run."""
    g = c.group(name)
    c.ramp(g, 0, 0, L, dy, T.ramp, thick=T.thick)
    T.under_ramp(c, g, L, dy)
    lip = 3.0
    floor(c, T, g, L, L + lip, top=dy)
    T.takeoff(c, g, 0)
    c.point(0.8, 0, 0, "SLIDE", radius=1.2)
    c.point(L + lip - 0.45, dy, 0, action, radius=0.8, boost=boost)
    e = L + lip
    floor(c, T, g, e + d, e + d + land, top=dy + ddy)
    c.point(e + d + land - 4, dy + ddy, 0, "RUN", radius=2.0)
    c.advance(e + d + land, dy + ddy)
