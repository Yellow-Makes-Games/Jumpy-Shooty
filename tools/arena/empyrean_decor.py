"""Empyrean Tower, the third part of tools/arena/empyrean.py: the decor pass. Everything
here is dressing laid over the structure and the rooms' main pieces: pilasters, ribs
and beams, sconces and lanterns, banners and carpets, wall units and tables with their
clutter, each tier's extra character, turrets and lit slit windows on the shell, cargo
on the docking ring. Most of it is drawn only (not solid): what stands on a floor in the
open is solid, what hugs a wall, hangs or lies flat is not.

Both halves in everything: stone pilasters by turns with alloy ones, flames by turns
with tube lamps, tapestries by turns with screens, bookcases with data cabinets.

See empyrean.py for the plan and the conventions (P, rot, sectors of 15 degrees)."""
import math
import random
from arena_builder import xform, fmt, IDENTITY, yaw_cols, norm, cross
from cirrus import FLIP, LIE_X, LIE_Z
import empyrean as E
from empyrean import P, rot, ri, ro, rc, chord, TIER, L1, L2, L3, RS, ACCENT, TOP, LANE, FEAT, SEG, DOOR_N, DOOR_W
import empyrean_dressing as D
from empyrean_dressing import spot

CLOTH = ["cloth_blue", "cloth_red", "cloth_green", "cloth_teal", "cloth_violet", "cloth_blue"]
BOOKS = ("books_red", "books_blue", "books_green")


# ---------------------------------------------------------------------------
# Small pieces

def banner(m, g, r, deg, top, wide, long, cloth, acc):
    """A cloth banner hanging flat against (or below) something at radius r, facing in and out."""
    m.pb(g, "Banner", cloth, r - 0.04, r + 0.04, deg, wide, top - long, top, solid=False)
    m.pb(g, "BannerRod", "brass", r - 0.1, r + 0.1, deg, wide + 0.5, top, top + 0.12, solid=False)
    m.pb(g, "BannerTrim", "brass", r - 0.05, r + 0.05, deg, wide, top - long, top - long + 0.14, solid=False)
    s = wide * 0.38
    m.pb(g, "BannerEmblem", acc, r - 0.07, r + 0.07, deg, s, top - long * 0.42 - s * 0.5, top - long * 0.42 + s * 0.5, solid=False)


def side_banner(m, g, r0, r1, deg, top, long, cloth, acc):
    """A banner on a wall that runs out from the shaft (a feature room's end wall): it hangs
    along the radius, from r0 to r1, at angle deg."""
    m.pb(g, "Banner", cloth, r0, r1, deg, 0.08, top - long, top, solid=False)
    m.pb(g, "BannerRod", "brass", r0 - 0.25, r1 + 0.25, deg, 0.2, top, top + 0.12, solid=False)
    mid = (r0 + r1) * 0.5
    s = (r1 - r0) * 0.36
    m.pb(g, "BannerEmblem", acc, mid - s * 0.5, mid + s * 0.5, deg, 0.14, top - long * 0.4 - s * 0.5, top - long * 0.4 + s * 0.5, solid=False)


def sconce(m, g, r, deg, y, acc, out=1, flame=True):
    """A wall light on a face at radius r: `out` = 1 if the room is on the far side from the
    shaft, -1 if on the shaft's side. A brass cup with an arcane flame, or an alloy tube lamp."""
    a, b = (r, r + 0.4 * out) if out > 0 else (r - 0.4, r)
    m.pb(g, "SconceArm", "brass" if flame else "alloy_dark", a, b, deg, 0.16, y, y + 0.12, solid=False)
    at = P(r + 0.4 * out, deg, y)
    if flame:
        m.block(g, "SconceCup", "brass", (at[0], at[1] + 0.2, at[2]), (0.4, 0.24, 0.4), shape="cone", cols=FLIP, sides=6, solid=False)
        m.block(g, "SconceFlame", "flame", (at[0], at[1] + 0.58, at[2]), (0.24, 0.5, 0.24), shape="cone", sides=6, solid=False)
    else:
        m.block(g, "SconceLamp", acc, (at[0], at[1] + 0.45, at[2]), (0.16, 0.9, 0.16), solid=False)
        m.block(g, "SconceCap", "alloy_dark", (at[0], at[1] + 0.95, at[2]), (0.26, 0.1, 0.26), solid=False)


def lantern(m, g, at, drop, acc, flame=True):
    """A lantern on a chain: `at` is where the chain is fixed, the lantern hangs `drop` below."""
    m.cyl(g, "LanternChain", "alloy_dark", (at[0], at[1] - drop + 0.5, at[2]), 0.08, drop - 0.5, sides=4, solid=False)
    m.block(g, "LanternCage", "brass" if flame else "alloy", (at[0], at[1] - drop + 0.1, at[2]), (0.5, 0.7, 0.5), shape="bevel", bevel=0.14, solid=False)
    m.block(g, "LanternLight", "flame" if flame else acc, (at[0], at[1] - drop + 0.1, at[2]), (0.56, 0.36, 0.56), shape="bevel", bevel=0.1, solid=False)


def pilaster(m, g, r, deg, y0, y1, n, acc, deep=0.35, wide=0.8):
    """A pilaster on the outer wall's inner face (radius r): stone with a brass capital,
    or (odd n) alloy with a strip of light."""
    stone = n % 2 == 0
    m.pb(g, "Pilaster", "stone_dark" if stone else "alloy_dark", r - deep, r + 0.5, deg, wide, y0, y1, solid=False)
    m.pb(g, "PilasterCap", "brass", r - deep - 0.12, r + 0.3, deg, wide + 0.24, y1 - 0.7, y1 - 0.45, solid=False)
    if not stone:
        m.pb(g, "PilasterLight", acc, r - deep - 0.03, r - deep, deg, 0.14, y0 + 0.6, y1 - 1.0, solid=False)
    else:
        m.pb(g, "PilasterFoot", "stone_dark", r - deep - 0.1, r + 0.3, deg, wide + 0.2, y0, y0 + 0.4, solid=False)


def clutter(m, g, x, y, z, seed, acc, n=3):
    """Things on a table top at (x, y, z): books, a candle, a flask, a scroll, a gadget, a crystal."""
    rng = random.Random(seed)
    for k in range(n):
        px, pz = x + (k - (n - 1) * 0.5) * 0.6, z + rng.uniform(-0.25, 0.25)
        pick = (seed + k * 3) % 6
        if pick == 0:
            for b in range(rng.randint(2, 3)):
                m.block(g, "Book", BOOKS[(seed + b) % 3], (px, y + 0.06 + b * 0.11, pz), (0.42, 0.1, 0.3), cols=yaw_cols(rng.uniform(-0.5, 0.5)), solid=False)
        elif pick == 1:
            m.cyl(g, "Candle", "parchment", (px, y, pz), 0.1, 0.26, sides=5, solid=False)
            m.block(g, "CandleFlame", "flame", (px, y + 0.36, pz), (0.09, 0.2, 0.09), shape="cone", sides=5, solid=False)
        elif pick == 2:
            D.alembic(m, g, px, y, pz)
        elif pick == 3:
            m.lying_cyl(g, "Scroll", "parchment", (px, y + 0.07, pz), 0.14, 0.5, axis="z", sides=6, solid=False)
        elif pick == 4:
            m.block(g, "Gadget", "alloy_dark", (px, y + 0.1, pz), (0.4, 0.2, 0.3), shape="bevel", bevel=0.05, solid=False)
            m.box(g, "GadgetScreen", "screen", (px - 0.14, y + 0.2, pz - 0.1), (px + 0.14, y + 0.215, pz + 0.1), solid=False)
            m.box(g, "GadgetHolo", "holo", (px - 0.16, y + 0.4, pz - 0.01), (px + 0.16, y + 0.7, pz + 0.01), solid=False)
        else:
            m.cone(g, "Crystal", acc, (px, y, pz), 0.2, 0.5, sides=5, solid=False)


def table(m, g, x, z, seed, acc, wide=2.2, deep=1.1, kind="wood"):
    """A work table (solid) with things on it."""
    m.bev(g, "Table", kind, (x - wide / 2, 0, z - deep / 2), (x + wide / 2, 0.85, z + deep / 2), bevel=0.07)
    m.box(g, "TableTop", "brass" if kind == "wood" else "alloy", (x - wide / 2 - 0.05, 0.85, z - deep / 2 - 0.05), (x + wide / 2 + 0.05, 0.9, z + deep / 2 + 0.05), solid=False)
    clutter(m, g, x, 0.9, z, seed, acc)


def crates(m, g, x, z, seed, acc):
    """A stack of cargo (solid): wooden chests bound in brass and alloy cases with a status light."""
    rng = random.Random(seed)
    spots = [(x, 0.0, z, 1.2), (x + 1.3, 0.0, z + rng.uniform(-0.3, 0.3), 1.0), (x + 0.2, 1.2, z + 0.05, 0.9)]
    for k, (px, py, pz, s) in enumerate(spots[:rng.randint(2, 3)]):
        wood = (seed + k) % 2 == 0
        m.block(g, "Crate", "wood" if wood else "alloy_dark", (px, py + s * 0.5, pz), (s, s, s), shape="bevel", bevel=0.06, cols=yaw_cols(rng.uniform(-0.3, 0.3)))
        if wood:
            m.block(g, "CrateBand", "brass", (px, py + s * 0.5, pz), (s + 0.04, 0.14, s + 0.04), solid=False)
        else:
            m.block(g, "CrateLight", acc, (px, py + s * 0.75, pz), (s + 0.03, 0.08, s * 0.5), solid=False)


def barrel(m, g, x, z, kind="wood", top=None, wide=0.9, high=1.2):
    m.cyl(g, "Barrel", kind, (x, 0, z), wide, high, sides=8)
    m.block(g, "BarrelBand", "brass", (x, high * 0.3, z), (wide + 0.06, 0.1, wide + 0.06), shape="tube", sides=8, inner=wide - 0.1, solid=False)
    m.block(g, "BarrelBand", "brass", (x, high * 0.75, z), (wide + 0.06, 0.1, wide + 0.06), shape="tube", sides=8, inner=wide - 0.1, solid=False)
    if top:
        m.cyl(g, "BarrelTop", top, (x, high, z), wide - 0.2, 0.04, sides=8, solid=False)


def globe(m, g, x, z, acc, wide=1.0):
    """A globe on a brass stand, a ring of light round it."""
    m.cyl(g, "GlobeStand", "brass", (x, 0, z), 0.22, 1.0, sides=6)
    m.block(g, "GlobeFoot", "stone_dark", (x, 0.1, z), (0.8, 0.2, 0.8), shape="bevel", bevel=0.06, solid=False)
    m.block(g, "Globe", "cloth_blue", (x, 1.0 + wide * 0.75, z), (wide, wide * 0.5, wide), shape="dome", sides=10, solid=False)
    m.block(g, "GlobeUnder", "cloth_teal", (x, 1.0 + wide * 0.25, z), (wide, wide * 0.5, wide), cols=FLIP, shape="dome", sides=10, solid=False)
    Y = norm((0.35, 1.0, 0.0))
    X = norm(cross(Y, (0, 0, 1)))
    m.block(g, "GlobeRing", acc, (x, 1.0 + wide * 0.5, z), (wide + 0.3, 0.05, wide + 0.3), cols=(X, Y, cross(X, Y)), shape="tube", sides=16, inner=wide + 0.18, solid=False)


def wall_unit(m, s, kind, wide, acc, seed, cloth):
    """Something standing against a wall. Built in a group whose +z is into the wall: it
    takes x from -wide/2 to wide/2 and about 0.7 m of depth."""
    h = wide / 2
    if kind == 0:
        D.shelf(m, s, -h, h, 0, 3.4, seed, deep=0.7)
    elif kind == 1:
        D.server(m, s, -h, h, 0, 3.4, acc, seed, deep=0.7)
    elif kind == 2:
        # a potion shelf: bottles of every colour in rows
        m.box(s, "ShelfBack", "wood", (-h, 0.9, 0.2), (h, 3.3, 0.35), solid=False)
        rng = random.Random(seed)
        for row in range(3):
            y = 1.1 + row * 0.75
            m.box(s, "ShelfBoard", "wood", (-h, y - 0.06, -0.2), (h, y, 0.3), solid=False)
            for b in range(int(wide / 0.45)):
                x = -h + 0.3 + b * 0.45
                col = (ACCENT[(seed + row + b) % 6], "fluid", "glass_clear")[rng.randrange(3)]
                if rng.random() < 0.8:
                    m.cone(s, "Bottle", col, (x, y, 0.02), 0.2, rng.uniform(0.28, 0.46), top=0.07, sides=5, solid=False)
        m.bev(s, "Cupboard", "wood", (-h, 0, -0.25), (h, 0.9, 0.35), bevel=0.06)
    elif kind == 3:
        # a wall screen over a small console
        m.box(s, "ScreenFrame", "alloy_dark", (-h, 1.3, 0.12), (h, 3.1, 0.34), solid=False)
        m.box(s, "WallScreen", "screen", (-h + 0.15, 1.45, 0.08), (h - 0.15, 2.95, 0.12), solid=False)
        m.box(s, "ScreenBar", acc, (-h + 0.3, 1.7, 0.05), (h * 0.3, 1.82, 0.08), solid=False)
        m.box(s, "ScreenBar", "alloy_dark", (-h + 0.3, 2.1, 0.05), (h - 0.4, 2.2, 0.08), solid=False)
        m.box(s, "ScreenBar", acc, (-h + 0.3, 2.5, 0.05), (0.2, 2.6, 0.08), solid=False)
        m.bev(s, "ScreenDesk", "alloy", (-h * 0.7, 0, -0.3), (h * 0.7, 0.8, 0.34), bevel=0.1)
        m.box(s, "DeskLight", acc, (-h * 0.6, 0.3, -0.33), (h * 0.6, 0.38, -0.3), solid=False)
    elif kind == 4:
        # a tapestry over a chest
        m.box(s, "Tapestry", cloth, (-h + 0.1, 1.0, 0.24), (h - 0.1, 4.2, 0.3), solid=False)
        m.box(s, "TapestryRod", "brass", (-h - 0.1, 4.2, 0.16), (h + 0.1, 4.32, 0.34), solid=False)
        m.block(s, "TapestryRing", acc, (0, 2.9, 0.2), (wide * 0.5, 0.1, wide * 0.5), cols=LIE_Z, shape="tube", sides=12, inner=wide * 0.5 - 0.2, solid=False)
        m.box(s, "TapestryStar", "glow", (-0.1, 2.5, 0.19), (0.1, 3.3, 0.23), solid=False)
        m.bev(s, "Chest", "wood", (-0.8, 0, -0.3), (0.8, 0.75, 0.3), bevel=0.1)
        m.box(s, "ChestBand", "brass", (-0.84, 0.42, -0.34), (0.84, 0.54, 0.34), solid=False)
    elif kind == 5:
        crates(m, s, -0.5, 0.0, seed, acc)
        barrel(m, s, h - 0.5, -0.2, top=acc if seed % 2 else None)
    else:
        # a chart board: parchment in a brass frame, lines of light drawn across it by a projector below
        m.box(s, "ChartFrame", "brass", (-h, 1.1, 0.22), (h, 3.2, 0.34), solid=False)
        m.box(s, "Chart", "parchment", (-h + 0.12, 1.22, 0.17), (h - 0.12, 3.08, 0.22), solid=False)
        for k in range(3):
            m.block(s, "ChartLine", acc if k % 2 else "glow", (-0.2 + k * 0.3, 2.0 + k * 0.3, 0.15), (wide * 0.6, 0.05, 0.03), cols=((0.9, 0.44 - k * 0.4, 0), (-0.44 + k * 0.4, 0.9, 0), (0, 0, 1)), solid=False)
        m.bev(s, "Projector", "alloy_dark", (-0.4, 0, -0.3), (0.4, 0.6, 0.3), bevel=0.1)
        m.block(s, "ProjectorBeam", "holo", (0, 0.9, -0.05), (0.5, 0.6, 0.3), shape="cone", cols=FLIP, sides=4, solid=False)


# ---------------------------------------------------------------------------
# The five lower tiers: what every one of them gets

def corridor_trim(m, g, i):
    """The corridor: a beam across the inner lane and a pilaster on the outer wall at every
    sector line, and a light on the corridor wall at every other one."""
    y0, Rc, acc = TIER * i, rc(i), ACCENT[i]
    for lvl, base in enumerate((0.0, L1, L2)):
        yb = y0 + base
        top = y0 + (L1, L2, L3)[lvl] - 0.5
        rw = ri(top)
        for k in range(1, 14):
            deg = (FEAT + k) * 15.0
            m.pb(g, "Beam", "stone_dark" if k % 2 else "alloy_dark", Rc + 0.2, Rc + LANE + 0.1, deg, 0.5, top - 0.4, top, solid=False)
            skip = (lvl == 0 and (deg in (210.0, 300.0) or (i == 3 and deg == 255.0))) or (lvl == 1 and (deg in (180.0, 270.0) or (i in (1, 2, 4) and deg == 255.0)))
            if not skip:
                pilaster(m, g, rw, deg, yb, top, k + lvl, acc)
            if k % 2 == 0:
                sconce(m, g, Rc + 0.2, deg, yb + 2.7, acc, out=1, flame=(k + lvl) % 4 == 0)


def rooms_decor(m, g, i):
    """The rooms on the shaft side of the corridor: wall units along the corridor wall,
    tables with their clutter, a runner of carpet."""
    y0, Rc, acc, cloth = TIER * i, rc(i), ACCENT[i], CLOTH[i]
    c = lambda k: (FEAT + k + 0.5) * 15.0
    for lvl, base in enumerate((0.0, L1, L2)):
        yb = y0 + base
        for n, k in enumerate((0, 1, 3, 4, 6, 7, 9, 10, 12, 13)):       # (every sector of wall that has no door)
            s = spot(m, g, "WallUnit", Rc - 0.6, c(k), yb)
            wall_unit(m, s, (k * 3 + lvl + i) % 7, min(3.4, chord(Rc, 24) - 1.6), acc, i * 100 + lvl * 20 + k, cloth)
        for n, k in enumerate(((0, 13), (0, 2, 5, 9), (0, 2, 5, 9))[lvl]):
            if i == 2 and lvl == 1 and k == 13:
                continue
            s = spot(m, g, "Table", (RS + Rc) * 0.5 + 1.0, c(k), yb, face=c(k) + 90.0)
            table(m, s, 0, 0, i * 50 + lvl * 9 + k, acc, kind="wood" if (k + lvl) % 2 else "alloy_dark")
            if (k + lvl + i) % 2:
                barrel(m, s, 1.9, 0.5, top=acc)
            else:
                globe(m, s, -1.9, 0.3, acc, wide=0.8)
            # a round rug under it, and a lantern over it
            m.cyl(s, "Rug", "carpet" if (k + i) % 2 else CLOTH[i], (0, 0.0, 0), 4.6, 0.02, sides=16, solid=False)
            m.block(s, "RugRim", "brass", (0, 0.015, 0), (4.6, 0.02, 4.6), shape="tube", sides=16, inner=4.3, solid=False)
            lantern(m, s, (0, (L1, L2 - L1, L3 - L2)[lvl] - 0.5, 0), 1.7, acc, flame=(k + lvl) % 2 == 0)
        # The corridor's outer wall, where no ramp runs along it: a banner or a screen between the pilasters.
        free = ((2, 3, 6, 7, 10, 11), (4, 6, 7, 9), (0, 1, 6, 12, 13))[lvl]
        top = y0 + (L1, L2, L3)[lvl] - 0.5
        for n, k in enumerate(free):
            deg = c(k)
            if min(abs(deg - d) for d in (180.0, DOOR_N, 255.0, 270.0, DOOR_W)) < 9.0:
                continue
            rw = ri(top) - 0.1
            if (n + lvl + i) % 2:
                banner(m, g, rw, deg, top - 0.5, 1.8, 3.0, cloth if n % 2 else "cloth_violet", acc)
            else:
                m.pb(g, "WallScreenFrame", "alloy_dark", rw - 0.1, rw + 0.3, deg, 2.2, yb + 1.5, yb + 3.3, solid=False)
                m.pb(g, "WallScreen", "screen", rw - 0.14, rw - 0.1, deg, 1.9, yb + 1.65, yb + 3.15, solid=False)
                m.pb(g, "WallScreenLine", acc, rw - 0.17, rw - 0.14, deg, 1.3, yb + 2.5, yb + 2.62, solid=False)
                m.pb(g, "WallScreenLine", "alloy_dark", rw - 0.17, rw - 0.14, deg, 1.5, yb + 2.0, yb + 2.1, solid=False)
        # Lanterns down the corridor's inner lane, hung from every other beam.
        for k in range(1, 14, 2):
            lantern(m, g, P(Rc + LANE * 0.5 + 0.1, (FEAT + k) * 15.0, top - 0.4), 1.5, acc, flame=(k // 2 + lvl) % 2 == 0)
        # a carpet runner down the corridor's inner lane, sector by sector
        if lvl == 0:
            for k in range(14):
                m.pb(g, "Runner", "carpet", Rc + 0.7, Rc + LANE - 0.5, c(k), chord(Rc + LANE, 24) + 0.02, yb + 0.0, yb + 0.02, solid=False)


def feature_trim(m, g, i):
    """The feature room's architecture: pilasters and wall units along the back wall under
    the balcony, vault ribs with bosses under the ceiling, banners on the end walls and
    hanging from the balcony."""
    y0, Rc, acc, cloth = TIER * i, rc(i), ACCENT[i], CLOTH[i]
    under = y0 + L1 - 0.5
    rw = ri(under)
    for k in range(1, FEAT):
        if k != 5:
            pilaster(m, g, rw, k * 15.0, y0, under, k, acc)
    for k in (0, 1, 2, 3, 6, 7, 8, 9):
        s = spot(m, g, "WallUnit", ri(y0 + 3.4) - 0.5, k * 15.0 + 7.5, y0)
        wall_unit(m, s, (k * 2 + i) % 7, 3.6, acc, i * 31 + k, cloth)
    # the vault: ribs from the shaft's rim to the back wall, a ring rib half way, a boss where they cross
    ceil = y0 + L3 - 0.5
    mid = (RS + Rc) * 0.5
    for k in range(FEAT + 1):
        deg = k * 15.0
        if k in (0, FEAT):
            deg += 1.2 if k == 0 else -1.2
        m.pb(g, "VaultRib", "stone_dark" if k % 2 else "alloy_dark", RS + 0.3, ri(ceil) - 0.1, deg, 0.6, ceil - 0.55, ceil, solid=False)
        at = P(mid, deg, ceil - 0.75)
        m.block(g, "Boss", "brass", at, (1.1, 0.5, 1.1), shape="cone", cols=FLIP, sides=8, solid=False)
        m.block(g, "BossLight", acc if k % 2 else "glow", (at[0], at[1] - 0.3, at[2]), (0.4, 0.2, 0.4), shape="cone", cols=FLIP, sides=6, solid=False)
    for k in range(FEAT):
        m.pb(g, "VaultRing", "stone_dark", mid - 0.25, mid + 0.25, k * 15.0 + 7.5, chord(mid + 0.25, 24), ceil - 0.4, ceil, solid=False)
        m.pb(g, "VaultRingOuter", "brass", Rc - 0.15, Rc + 0.15, k * 15.0 + 7.5, chord(Rc + 0.15, 24), ceil - 0.25, ceil, solid=False)
    # banners: two great ones on each end wall, one hanging from the balcony at each gap in its parapet
    for deg, way in ((0.0, 1.0), (150.0, -1.0)):
        off = math.degrees(0.42 / (RS + 9.0)) * way
        side_banner(m, g, RS + 7.2, min(RS + 10.6, Rc - 0.6), deg + off, y0 + L3 - 1.6, 9.5, cloth, acc)
        if Rc - RS > 12.5:
            side_banner(m, g, RS + 11.4, Rc - 0.5, deg + off, y0 + L3 - 1.6, 6.0, "cloth_violet" if cloth != "cloth_violet" else "cloth_blue", "glow")
    for k in (1, 4, 7):
        banner(m, g, Rc - 0.12, k * 15.0 + 7.5, under, 2.4, 3.3, cloth, acc)
    # sconces on the balcony fronts between them
    for n, k in enumerate((0, 3, 6, 9)):
        sconce(m, g, Rc - 0.14, k * 15.0 + 7.5, y0 + L1 - 1.6, acc, out=-1, flame=n % 2 == 0)
    if i in (1, 2, 3):
        # a carpet from the great arch to the shaft
        m.pb(g, "Carpet", "carpet", RS + 2.8, ri(y0) - 1.4, 75.0, 3.2, y0, y0 + 0.02, solid=False)
        for side in (-1, 1):
            m.pb(g, "CarpetEdge", "brass", RS + 2.8, ri(y0) - 1.4, 75.0 + side * math.degrees(1.5 / (RS + 9.0)), 0.12, y0, y0 + 0.025, solid=False)


def hall_decor(m, g, i):
    """The upper hall: ribs under its ceiling, lanterns round the colonnade, banners and
    screens along the wall, cargo."""
    y0, acc, cloth = TIER * i, ACCENT[i], CLOTH[i]
    yb = y0 + L3
    ceil = y0 + TIER - 0.6
    for k in range(24):
        deg = k * 15.0
        if deg in (225.0, 240.0, 270.0, 285.0):
            continue      # (where the long ramps go up through the ceiling)
        m.pb(g, "HallRib", "alloy_dark" if k % 2 else "stone_dark", RS + 0.4, ri(ceil) - 0.1, deg, 0.5, ceil - 0.4, ceil, solid=False)
    for k in range(1, 24, 2):
        deg = k * 15.0 + 7.5
        lantern(m, g, P(RS + 1.3, deg, ceil), 2.6 + (k % 4) * 0.4, acc, flame=k % 4 == 1)
    rw = ri(yb + 5.0)
    walls = [k for k in range(24) if k not in (FEAT + 4, FEAT + 5, FEAT + 8, FEAT + 9)]
    for n, k in enumerate(walls):
        deg = k * 15.0 + 7.5
        if n % 2 == 0:
            banner(m, g, rw - 0.12, deg, yb + 8.6, 2.2, 5.4, cloth if n % 4 else "cloth_violet", acc)
        else:
            s = spot(m, g, "HallUnit", rw - 0.55, deg, yb)
            wall_unit(m, s, (3, 1, 6, 0)[(n // 2) % 4], 3.2, acc, i * 17 + k, cloth)
        if k < FEAT and k % 2 == 0:
            sconce(m, g, rw, deg + 5.0, yb + 3.0, acc, out=-1, flame=k % 4 == 0)
    for n, deg in enumerate((37.5, 67.5, 97.5, 127.5)):
        s = spot(m, g, "Cargo", ri(yb) - 2.8, deg, yb)
        crates(m, s, 0, 0, i * 7 + n, acc)
        if n % 2:
            barrel(m, s, -1.4, 0.3, kind="alloy", top=acc)


# ---------------------------------------------------------------------------
# Each tier's own extras

def engine_extras(m, g):
    acc = "accent_cyan"
    for n, deg in enumerate((30.0, 46.0, 104.0, 124.0)):        # pistons against the back wall
        s = spot(m, g, "Piston", ri(0) - 2.6, deg, 0.0)
        m.cyl(s, "PistonCase", "alloy", (0, 0, 0), 1.7, 3.6, sides=10)
        m.cyl(s, "PistonRod", "alloy_dark", (0, 3.6, 0), 0.7, 2.2, sides=8)
        m.block(s, "PistonBand", "brass", (0, 3.2, 0), (1.86, 0.3, 1.86), shape="tube", sides=10, inner=1.6, solid=False)
        m.block(s, "Gauge", "brass", (0, 2.0, -0.88), (0.6, 0.1, 0.6), cols=LIE_Z, shape="cyl", sides=10, solid=False)
        m.block(s, "GaugeFace", acc, (0, 2.0, -0.94), (0.44, 0.05, 0.44), cols=LIE_Z, shape="cyl", sides=10, solid=False)
    for n, (r, deg) in enumerate(((RS + 11.5, 34.0), (RS + 13.0, 62.0), (RS + 13.0, 88.0), (RS + 11.5, 112.0))):     # coolant drums
        s = spot(m, g, "Drums", r, deg, 0.0)
        barrel(m, s, 0, 0, kind="alloy", top=acc)
        barrel(m, s, 1.0, 0.4, kind="alloy_dark", top=acc if n % 2 else "glow", high=1.0)
        if n % 2 == 0:
            barrel(m, s, 0.4, -0.9, kind="wood")
    for k in range(16):          # dashes of warning light round the kerb
        m.pb(g, "KerbMark", "hazard_glow" if k % 2 else "glow", 4.35, 4.95, k * 22.5 + 11.25, 0.16, 0.0, 0.03, solid=False)
    for n, deg in enumerate((38.0, 112.0)):           # rune obelisks between the machines
        s = spot(m, g, "Obelisk", RS + 4.0, deg, 0.0)
        D.pylon(m, s, 0, 0, 4.4, acc, arcane=True)
    for n, deg in enumerate((22.0, 50.0, 96.0, 118.0)):          # cable trays from each machine up to the balcony
        a = P(RS + 6.5 + (n % 2) * 3.5, deg, 3.4 + (n % 2) * 1.2)
        b = P(rc(0) - 0.2, deg, L1 - 0.7)
        m.rod(g, "CableTray", "alloy_dark", a, b, thick=0.14, wide=0.5)
        m.rod(g, "Cable", "conduit" if n % 2 else "glow", (a[0], a[1] + 0.1, a[2]), (b[0], b[1] + 0.1, b[2]), thick=0.06, wide=0.12)


def library_extras(m, g):
    y0, acc, Rc = TIER, "accent_gold", rc(1)
    for n, deg in enumerate((28.0, 52.0, 98.0, 122.0)):          # reading tables under the balcony
        s = spot(m, g, "ReadingTable", Rc + 2.4, deg, y0, face=deg + 90.0)
        table(m, s, 0, 0, 200 + n, acc, wide=2.6)
        m.block(s, "Stool", "wood", (0.6, 0.25, 1.0), (0.5, 0.5, 0.5), shape="bevel", bevel=0.08, solid=False)
        m.block(s, "Stool", "wood", (-0.7, 0.25, -1.0), (0.5, 0.5, 0.5), shape="bevel", bevel=0.08, solid=False)
    for n, deg in enumerate((60.0, 90.0)):
        s = spot(m, g, "Globe", RS + 2.6, deg, y0)
        globe(m, s, 0, 0, acc, wide=1.3)
    for n, deg in enumerate((66.0, 84.0)):             # lecterns either side of the carpet
        s = spot(m, g, "Lectern", RS + 12.0, deg, y0)
        m.cone(s, "LecternPost", "stone_dark", (0, 0, 0), 0.7, 1.1, top=0.35, sides=6)
        m.block(s, "LecternTop", "wood", (0, 1.2, 0), (0.9, 0.08, 0.6), cols=((1, 0, 0), (0, 0.94, 0.34), (0, -0.34, 0.94)), solid=False)
        D.holo_book(m, s, 0, 1.75, 0)
    rng = random.Random(77)
    for n in range(10):          # piles of books on the floor, by the stacks
        at = P(rng.uniform(RS + 4.0, Rc - 2.0), rng.choice([25.5, 41.0, 57.0, 93.0, 109.0, 125.0]) + rng.uniform(-0.5, 0.5), y0)
        for b in range(rng.randint(2, 4)):
            m.block(g, "BookPile", BOOKS[(n + b) % 3], (at[0], at[1] + 0.07 + b * 0.13, at[2]), (0.5, 0.12, 0.36), cols=yaw_cols(rng.uniform(0, 3.1)), solid=False)
    for n, deg in enumerate((15.0, 45.0, 105.0, 135.0)):         # catalogue screens hanging over the aisles
        at = P(RS + 7.5, deg + 7.5, y0 + 7.4)
        m.block(g, "Catalogue", "alloy_dark", at, (2.2, 1.2, 0.16), cols=rot(deg + 7.5), solid=False)
        m.block(g, "CatalogueScreen", "holo_gold" if n % 2 else "holo", P(RS + 7.4, deg + 7.5, y0 + 7.4), (1.9, 0.95, 0.04), cols=rot(deg + 7.5), solid=False)
        m.cyl(g, "CatalogueHanger", "brass", (at[0], at[1] + 0.6, at[2]), 0.08, L3 - 0.5 - 8.0, sides=4, solid=False)


def labs_extras(m, g):
    y0, acc, Rc = TIER * 2, "accent_green", rc(2)
    for n, deg in enumerate((28.0, 56.0, 122.0)):               # cauldrons over a flame, under the balcony
        s = spot(m, g, "Cauldron", Rc + 2.6, deg, y0)
        m.block(s, "CauldronFire", "flame", (0, 0.2, 0), (0.9, 0.4, 0.9), shape="cone", sides=6, solid=False)
        m.block(s, "Cauldron", "alloy_dark", (0, 0.95, 0), (1.5, 1.0, 1.5), cols=FLIP, shape="dome", sides=10)
        m.block(s, "CauldronRim", "brass", (0, 1.45, 0), (1.6, 0.12, 1.6), shape="tube", sides=10, inner=1.3, solid=False)
        m.cyl(s, "CauldronBrew", "fluid", (0, 1.38, 0), 1.3, 0.05, sides=10, solid=False)
        for leg in range(3):
            a = leg * 2.094
            m.bar(s, "CauldronLeg", "brass", (math.sin(a) * 0.9, 0, math.cos(a) * 0.9), (math.sin(a) * 0.5, 0.7, math.cos(a) * 0.5), thick=0.1, solid=False)
    for n, deg in enumerate((42.0, 106.0, 136.0)):               # arc coils
        s = spot(m, g, "Coil", Rc + 3.4, deg, y0)
        m.cyl(s, "CoilBase", "alloy_dark", (0, 0, 0), 1.2, 0.5, sides=8)
        m.cyl(s, "CoilPost", "alloy", (0, 0.5, 0), 0.4, 3.4, sides=8)
        for k in range(4):
            m.block(s, "CoilRing", "brass" if k % 2 else acc, (0, 1.1 + k * 0.7, 0), (1.0 - k * 0.12, 0.12, 1.0 - k * 0.12), shape="tube", sides=10, inner=0.7 - k * 0.12, solid=False)
        m.block(s, "CoilOrb", acc, (0, 4.15, 0), (0.6, 0.5, 0.6), shape="dome", sides=8, solid=False)
    rng = random.Random(21)
    for n in range(12):          # herbs drying under the balcony
        at = P(Rc + rng.uniform(0.6, 4.0), rng.uniform(6.0, 144.0), y0 + L1 - 0.5)
        L = rng.uniform(0.6, 1.3)
        m.cyl(g, "Herbs", "leaf" if n % 3 else "leaf_alien", (at[0], at[1] - L, at[2]), 0.3, L, sides=5, solid=False)
    for n, deg in enumerate((36.0, 70.0, 80.0, 114.0)):          # specimen jars on stands
        s = spot(m, g, "Specimen", RS + 2.4, deg, y0)
        m.cyl(s, "JarStand", "stone_dark", (0, 0, 0), 0.7, 0.9, sides=8)
        m.cyl(s, "Jar", "glass_clear", (0, 0.9, 0), 0.55, 0.9, sides=8, solid=False, unbreakable=True)
        m.cyl(s, "JarFluid", "fluid", (0, 0.92, 0), 0.42, 0.6, sides=8, solid=False)
        m.cyl(s, "JarLid", "alloy", (0, 1.8, 0), 0.6, 0.1, sides=8, solid=False)
        m.block(s, "JarLight", acc, (0, 0.88, 0), (0.76, 0.06, 0.76), shape="tube", sides=8, inner=0.6, solid=False)


def menagerie_extras(m, g):
    y0, acc, Rc = TIER * 3, "accent_teal", rc(3)
    s = spot(m, g, "Fountain", Rc + 0.4, 75.0, y0)
    m.cyl(s, "Basin", "stone", (0, 0, 0), 3.6, 0.6, sides=12)
    m.cyl(s, "Water", "fluid", (0, 0.5, 0), 3.1, 0.06, sides=12, solid=False)
    m.cone(s, "Spout", "stone_dark", (0, 0, 0), 1.0, 2.2, top=0.5, sides=6)
    m.cone(s, "SpoutCrystal", "crystal", (0, 2.2, 0), 0.7, 1.4, sides=6, solid=False)
    m.block(s, "Pump", "alloy", (0, 0.66, 0), (3.9, 0.14, 3.9), shape="tube", sides=12, inner=3.6, solid=False)
    m.block(s, "PumpLight", acc, (0, 0.3, 0), (3.66, 0.1, 3.66), shape="tube", sides=12, inner=3.58, solid=False)
    rng = random.Random(63)
    for n in range(7):           # mushrooms that glow, in clumps
        base = P(Rc + rng.uniform(1.0, 4.4), rng.choice([12.0, 30.0, 48.0, 100.0, 116.0, 134.0]) + rng.uniform(-3, 3), y0)
        for k in range(3):
            x, z = base[0] + rng.uniform(-0.6, 0.6), base[2] + rng.uniform(-0.6, 0.6)
            h = rng.uniform(0.4, 1.3)
            m.cyl(g, "MushroomStem", "parchment", (x, y0, z), 0.16, h, sides=5, solid=False)
            m.block(g, "MushroomCap", ("accent_teal", "accent_violet", "leaf_alien")[(n + k) % 3], (x, y0 + h + 0.12, z), (0.4 + h * 0.5, 0.26, 0.4 + h * 0.5), shape="dome", sides=7, solid=False)
    for n, deg in enumerate((24.0, 52.0, 126.0)):                # terrariums on alloy stands
        s = spot(m, g, "Terrarium", Rc + 3.2, deg, y0)
        m.bev(s, "Stand", "alloy_dark", (-1.0, 0, -0.6), (1.0, 0.8, 0.6), bevel=0.1)
        m.box(s, "Glass", "glass_clear", (-0.95, 0.8, -0.55), (0.95, 2.0, 0.55), solid=False, unbreakable=True)
        m.block(s, "Fern", "leaf", (-0.3, 1.15, 0), (0.9, 0.7, 0.8), shape="dome", sides=6, solid=False)
        m.block(s, "Bloom", "leaf_alien", (0.45, 1.05, 0.1), (0.5, 0.5, 0.5), shape="dome", sides=6, solid=False)
        m.box(s, "Lid", "alloy", (-1.0, 2.0, -0.6), (1.0, 2.12, 0.6), solid=False)
        m.box(s, "LidLight", acc, (-0.8, 1.96, -0.2), (0.8, 2.0, 0.2), solid=False)
    for n, deg in enumerate((45.0, 105.0, 135.0)):               # perches
        s = spot(m, g, "Perch", RS + 2.4, deg, y0)
        m.cyl(s, "PerchPost", "wood", (0, 0, 0), 0.24, 3.2, sides=6)
        m.box(s, "PerchBar", "wood", (-0.9, 3.0, -0.08), (0.9, 3.16, 0.08), solid=False)
        m.block(s, "PerchRing", "brass", (0.6, 2.6, 0), (0.6, 0.06, 0.6), cols=LIE_Z, shape="tube", sides=10, inner=0.5, solid=False)
    for n in range(10):          # moss on the flags
        at = P(rng.uniform(RS + 1.5, ri(y0) - 1.5), rng.uniform(4.0, 146.0), y0 + 0.02)
        m.cyl(g, "Moss", "leaf", at, rng.uniform(1.2, 2.8), 0.02, sides=7, solid=False)


def summoning_extras(m, g):
    y0, acc, Rc = TIER * 4, "accent_violet", rc(4)
    def candles(cx, cz, r, n, name):
        for k in range(n):
            a = k * 6.283 / n
            x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
            h = 0.3 + (k % 3) * 0.14
            m.cyl(g, name, "parchment", (x, y0, z), 0.13, h, sides=5, solid=False)
            m.block(g, name + "Flame", "flame", (x, y0 + h + 0.12, z), (0.1, 0.24, 0.1), shape="cone", sides=5, solid=False)
    a = P(RS + 6.0, 75.0, 0)
    candles(a[0], a[2], 4.2, 12, "AltarCandle")
    for r, deg in ((RS + 5.0, 28.0), (RS + 4.6, 118.0)):
        c = P(r, deg, 0)
        candles(c[0], c[2], 2.9, 6, "CircleCandle")
    # rings of runes turning slowly high over the altar (scenery)
    for n, (wide, speed, y) in enumerate(((5.0, 9.0, 8.0), (7.0, -6.0, 9.2))):
        sp = m.node("AltarHalo", g, "spinner", [("transform", xform(IDENTITY, (a[0], y0 + y, a[2]))), ("speed", fmt(speed))])
        m.block(sp, "Halo", "brass" if n else "alloy", (0, 0, 0), (wide, 0.16, wide), shape="tube", sides=24, inner=wide - 0.4, solid=False)
        for k in range(8):
            m.block(sp, "HaloRune", acc if k % 2 else "glow", P(wide * 0.5 - 0.1, k * 45.0), (0.5, 0.3, 0.12), cols=rot(k * 45.0), solid=False)
    for n, deg in enumerate((16.0, 40.0, 110.0, 132.0)):         # crystal clusters under the balcony
        s = spot(m, g, "Crystals", Rc + 3.0, deg, y0)
        m.cone(s, "Crystal", "crystal", (0, 0, 0), 0.9, 2.2, sides=6)
        m.block(s, "CrystalLean", acc, (0.6, 0.6, 0.2), (0.5, 1.4, 0.5), cols=((0.94, 0.34, 0), (-0.34, 0.94, 0), (0, 0, 1)), shape="cone", sides=6, solid=False)
        m.block(s, "CrystalLean", "crystal", (-0.5, 0.5, -0.2), (0.4, 1.1, 0.4), cols=((0.94, -0.34, 0), (0.34, 0.94, 0), (0, 0, 1)), shape="cone", sides=6, solid=False)
        m.block(s, "CrystalSeat", "alloy_dark", (0, 0.08, 0), (2.0, 0.16, 2.0), shape="cyl", sides=8, solid=False)
    for n, deg in enumerate((64.0, 86.0)):            # power cells feeding the altar
        s = spot(m, g, "PowerCell", Rc + 0.4, deg, y0)
        m.bev(s, "Cell", "alloy", (-0.7, 0, -0.5), (0.7, 1.8, 0.5), bevel=0.14)
        m.box(s, "CellLight", acc, (-0.4, 0.4, -0.53), (0.4, 1.4, -0.5), solid=False)
        m.box(s, "CellBand", "brass", (-0.74, 1.5, -0.54), (0.74, 1.62, 0.54), solid=False)


def observatory_extras(m, g):
    i = 5
    y0, acc = TIER * i, "accent_silver"
    for k in range(24):          # pilasters the room's whole height, leaning with the wall
        deg = k * 15.0
        if 60 < deg < 90 or 150 <= deg <= 172.5 or 205 < deg < 225 or 295 < deg < 315 or 330 <= deg <= 352.5:
            continue
        ym = y0 + 15.0
        m.block(g, "Pilaster", "stone_dark" if k % 2 else "alloy_dark", P(ri(ym) - 0.1, deg, ym), (0.9, 29.0, 0.5), cols=E.lean(deg), solid=False)
        m.block(g, "PilasterLight", acc if k % 2 == 0 else "glow", P(ri(ym) - 0.38, deg, ym), (0.14, 24.0, 0.04), cols=E.lean(deg), solid=False)
        m.pb(g, "PilasterCap", "brass", ri(TOP - 1) - 0.5, ri(TOP - 1) + 0.2, deg, 1.2, TOP - 1.2, TOP - 0.4, solid=False)
    for n, deg in enumerate((55.0, 95.0)):            # chart tables, a map of stars in light over each
        s = spot(m, g, "ChartTable", RS + 8.6, deg, y0, face=deg + 90.0)
        table(m, s, 0, 0, 500 + n, acc, wide=2.8, deep=1.4, kind="alloy_dark" if n else "wood")
        m.block(s, "StarChart", "holo", (0, 1.9, 0), (1.8, 0.03, 1.1), solid=False)
        for k in range(5):
            m.block(s, "ChartStar", "glow", (-0.7 + k * 0.35, 1.95, -0.3 + (k * 7 % 5) * 0.15), (0.08, 0.08, 0.08), solid=False)
    for n, (r, deg, speed) in enumerate(((RS + 8.5, 20.0, 12.0), (RS + 8.5, 120.0, -9.0), (RS + 8.5, 246.0, 7.0))):     # small orreries
        s = spot(m, g, "Orrery", r, deg, y0)
        m.bev(s, "Plinth", "stone" if n % 2 else "alloy", (-0.6, 0, -0.6), (0.6, 1.0, 0.6), bevel=0.15)
        m.cyl(s, "Stem", "brass", (0, 1.0, 0), 0.12, 0.9, sides=6, solid=False)
        m.block(s, "Sun", "glow", (0, 2.0, 0), (0.4, 0.4, 0.4), shape="dome", sides=8, solid=False)
        sp = m.node("Turning", s, "spinner", [("transform", xform(IDENTITY, (0, 2.0, 0))), ("speed", fmt(speed))])
        for k, wide in enumerate((1.2, 1.8, 2.4)):
            m.block(sp, "Orbit", "brass", (0, 0, 0), (wide, 0.04, wide), shape="tube", sides=20, inner=wide - 0.08, solid=False)
            m.block(sp, "World", ACCENT[(k * 2 + n) % 6], P(wide * 0.5, k * 130.0), (0.18, 0.18, 0.18), shape="bevel", bevel=0.05, solid=False)
    for n, deg in enumerate((100.0, 280.0)):
        s = spot(m, g, "Globe", RS + 3.0, deg, y0)
        globe(m, s, 0, 0, acc, wide=1.4)
    for n, deg in enumerate((32.0, 152.0)):           # spyglasses on tripods, on the gallery
        s = spot(m, g, "Spyglass", ri(y0 + 10.0) - 2.2, deg, y0 + 9.0)
        for leg in range(3):
            a = leg * 2.094
            m.bar(s, "TripodLeg", "brass", (math.sin(a) * 0.6, 0, math.cos(a) * 0.6), (0, 1.3, 0), thick=0.07, solid=False)
        Y = norm((0.0, 0.35, 0.94))
        m.block(s, "Tube", "brass", (0, 1.4, 0.2), (0.24, 1.5, 0.24), cols=((1, 0, 0), Y, cross((1, 0, 0), Y)), shape="cyl", sides=8, solid=False)
        m.block(s, "TubeSensor", "alloy_dark", (0, 1.62, 0.2), (0.3, 0.3, 0.4), solid=False)
    for n in range(8):           # star lanterns from the ceiling
        deg = n * 45.0 + 10.0
        lantern(m, g, P(12.5, deg, TOP), 6.0 + (n % 3) * 2.5, acc, flame=n % 2 == 0)
    for n, deg in enumerate((10.0, 130.0, 200.0, 250.0)):        # banners between the pilasters
        banner(m, g, ri(y0 + 18.0) - 0.3, deg, y0 + 24.0, 2.6, 8.0, CLOTH[i] if n % 2 else "cloth_violet", acc)
    for n, deg in enumerate((230.0, 262.0, 20.0)):
        s = spot(m, g, "Cargo", ri(y0) - 2.6, deg, y0)
        crates(m, s, 0, 0, 900 + n, acc)


# ---------------------------------------------------------------------------
# The shaft

def shaft_decor(m):
    g = m.group("Decor", "Shaft")
    # Two chains of lanterns the whole height of the shaft, a flame and a lamp by turns.
    for n, deg in enumerate((100.0, 280.0)):
        at = P(RS - 0.8, deg, 0)
        m.cyl(g, "LanternChain", "alloy_dark", (at[0], 3.0, at[2]), 0.1, TIER * 5 - 4.0, sides=4, solid=False)
        y = 6.0
        k = 0
        while y < TIER * 5 - 3.0:
            flame = (k + n) % 2 == 0
            m.block(g, "LanternCage", "brass" if flame else "alloy", (at[0], y, at[2]), (0.6, 0.8, 0.6), shape="bevel", bevel=0.16, solid=False)
            m.block(g, "LanternLight", "flame" if flame else ACCENT[min(int(y // TIER), 5)], (at[0], y, at[2]), (0.66, 0.42, 0.66), shape="bevel", bevel=0.12, solid=False)
            y += 9.5
            k += 1
    # Lamp posts at each bridge's ends and a banner under its middle.
    turns = [165.0, 15.0, 135.0]
    n = 0
    for i in range(5):
        for y in (TIER * i, TIER * i + L3):
            if y == 0.0:
                continue
            deg = turns[n % 3]
            n += 1
            th = math.radians(deg + 90.0)
            for end in (-1, 1):
                for side in (-1, 1):
                    base = P(end * (RS - 0.4), deg, y)
                    x, z = base[0] + math.sin(th) * 1.7 * side, base[2] + math.cos(th) * 1.7 * side
                    m.cyl(g, "BridgePost", "brass" if n % 2 else "alloy_dark", (x, y + 0.9, z), 0.18, 1.5, sides=6, solid=False)
                    m.block(g, "BridgeLantern", "flame" if (n + (end > 0)) % 2 else ACCENT[i], (x, y + 2.6, z), (0.4, 0.5, 0.4), shape="bevel", bevel=0.1, solid=False)
            for side in (-1, 1):
                c = (math.sin(th) * 1.72 * side, y - 0.5, math.cos(th) * 1.72 * side)
                m.block(g, "BridgeBanner", CLOTH[i] if side > 0 else "cloth_violet", (c[0], c[1] - 1.6, c[2]), (2.0, 3.2, 0.06), cols=rot(deg + 90.0), solid=False)
                m.block(g, "BridgeEmblem", ACCENT[i], (c[0] + math.sin(th) * 0.04 * side, c[1] - 1.4, c[2] + math.cos(th) * 0.04 * side), (0.8, 0.8, 0.06), cols=rot(deg + 90.0), solid=False)


# ---------------------------------------------------------------------------
# Outside

def exterior_decor(m):
    f = m.folder("Decor", "Exterior")
    # String courses: a moulding round the tower at every storey.
    g = m.group("StringCourses", f)
    for i in range(E.TIERS):
        for n, lvl in enumerate((L1, L2, L3)):
            y = TIER * i + lvl
            m.block(g, "StringCourse", "stone_dark" if (n + i) % 2 else "alloy_dark", (0, y, 0), (2 * ro(y) + 0.5, 0.45, 2 * ro(y) + 0.5), shape="tube", sides=SEG,
                    inner=2 * ro(y) - 0.4, solid=False)
    # Slit windows: a lit slot through the wall here and there, warm in stone, cool in alloy.
    g = m.group("Slits", f)
    for i in range(E.TIERS):
        cuts = E.openings(i)
        for lv, (base, up) in enumerate(((0.0, 2.8), (L1, 2.8), (L2, 2.8), (L3, 5.0))):
            for s in range(SEG):
                if (s * 5 + i * 3 + lv * 7) % 6 or s % 6 == 1 or any(((s + d) % SEG) in cuts for d in (-2, -1, 0, 1, 2)):
                    continue
                y = TIER * i + base + up
                deg = (s + 0.5) * 7.5
                m.block(g, "Slit", "screen" if E.alloy_segment(i, s) else "slit", P(ro(y) - 0.5, deg, y), (0.36, 1.8, 1.25), cols=rot(deg), solid=False)
    # Turrets: little round towers corbelled out from the ribs, a mast and a lamp on each roof.
    g = m.folder("Turrets", f)
    for i in range(5):
        picks = (1, 5) if i == 2 else ((i * 3) % 8, (i * 3 + 4) % 8)
        for k in picks:
            deg = k * 45.0 + 11.25
            y = TIER * i + (L2 + 2.0 if i == 2 else L3 + 2.0)
            t = m.group("Turret", g, at=P(ro(y) + 1.5, deg, y), yaw=math.radians(deg))
            m.cone(t, "Corbel", "stone_dark", (0, 0, 0), 4.4, 2.8, top=1.0, sides=10, flip=True)
            m.cyl(t, "Drum", "stone", (0, 0, 0), 4.4, 5.2, sides=10)
            m.block(t, "Collar", "alloy_dark", (0, 4.5, 0), (4.6, 0.5, 4.6), shape="tube", sides=10, inner=4.2, solid=False)
            m.block(t, "Band", "brass", (0, 0.3, 0), (4.6, 0.4, 4.6), shape="tube", sides=10, inner=4.2, solid=False)
            for a in (-0.75, 0.0, 0.75):
                m.block(t, "TurretSlit", "slit", (math.sin(a) * 2.14, 2.6, math.cos(a) * 2.14), (0.3, 1.5, 0.2), cols=yaw_cols(a), solid=False)
            m.cone(t, "TurretRoof", "roof", (0, 5.2, 0), 5.4, 4.6, sides=10)
            m.cone(t, "Finial", "brass", (0, 9.6, 0), 0.5, 1.0, sides=6, solid=False)
            m.cyl(t, "Mast", "alloy", (0.9, 6.4, 0.6), 0.14, 3.6 if i != 2 else 2.2, sides=5, solid=False)
            m.block(t, "MastLamp", ACCENT[i], (0.9, 10.1 if i != 2 else 8.7, 0.6), (0.3, 0.3, 0.3), shape="bevel", bevel=0.08, solid=False)
    # Balconies: a lantern post at each outer corner, a banner hanging from the middle.
    g = m.group("BalconyDecor", f)
    for i in range(E.TIERS):
        y = TIER * i
        if i == 3:
            continue
        for deg, width in ((75.0, 30.0), (DOOR_N, 22.5), (DOOR_W, 22.5)):
            depth = 5.0
            lift = (deg == E.LIFT_C and i <= 2) or (deg == E.LIFT_D and i >= 4)
            if deg == E.LIFT_C and i <= 2:
                depth = (E.C_R + 2.4 - ro(y)) if i == 0 else (E.C_R - 1.75 - ro(y))
            if deg == E.LIFT_D and i >= 4:
                depth = E.D_R - 1.75 - ro(y)
            r1 = ro(y) + depth
            for side in (-1, 1):
                at = P(r1 - 0.5, deg + side * (width * 0.5 - 1.6), y)
                m.cyl(g, "LanternPost", "brass" if side > 0 else "alloy_dark", at, 0.18, 2.6, sides=6, solid=False)
                m.block(g, "PostLantern", "flame" if side > 0 else ACCENT[i], (at[0], at[1] + 2.8, at[2]), (0.44, 0.5, 0.44), shape="bevel", bevel=0.1, solid=False)
            if not lift:
                banner(m, g, r1 + 0.1, deg, y - 0.7, 2.6, 4.4, CLOTH[i], ACCENT[i])
    # The docking ring: cargo, fuel pods, lamp posts round the rim, a console by the pad.
    g = m.group("Cargo", "Exterior/DockingRing")
    y = E.RING_Y
    for n, deg in enumerate((96.0, 150.0, 180.0, 286.0, 4.0)):
        s = spot(m, g, "Stack", E.RING_R - 2.6, deg, y)
        crates(m, s, 0, 0, 40 + n, "accent_teal")
        if n % 2 == 0:
            barrel(m, s, -1.6, 0.2, kind="alloy", top="accent_teal")
    for n, deg in enumerate((228.0, 282.0)):
        s = spot(m, g, "FuelPod", E.RING_R + 2.5, deg, y)
        m.lying_cyl(s, "Pod", "alloy", (0, 1.0, 0), 1.6, 4.0, axis="x", sides=10)
        for x in (-1.2, 1.2):
            m.block(s, "PodBand", "brass", (x, 1.0, 0), (1.76, 0.3, 1.76), cols=LIE_X, shape="tube", sides=10, inner=1.5, solid=False)
            m.box(s, "PodFoot", "alloy_dark", (x - 0.25, 0, -0.7), (x + 0.25, 0.4, 0.7))
        m.block(s, "PodGauge", "accent_teal", (0, 1.0, -0.82), (1.2, 0.3, 0.05), solid=False)
    for k in range(12):
        deg = k * 30.0
        if abs((deg - E.PAD_DEG + 180) % 360 - 180) < 24:
            continue
        at = P(E.RING_R - 0.7, deg, y)
        m.cyl(g, "RingPost", "alloy_dark", at, 0.2, 3.0, sides=6, solid=False)
        m.block(g, "RingLamp", "flame" if k % 2 else "accent_teal", (at[0], at[1] + 3.2, at[2]), (0.5, 0.5, 0.5), shape="bevel", bevel=0.12, solid=False)
    s = spot(m, g, "PadConsole", E.RING_R - 1.5, 240.0, y, face=60.0)
    D.console(m, s, acc="accent_teal")
    # More hanging from the root: crystals, chains and a few lanterns.
    g = m.group("RootDecor", f)
    rng = random.Random(404)
    for k in range(12):
        deg = k * 30.0 + 5.0
        r = rng.uniform(10.0, 26.0)
        y = -rng.uniform(5.0, 12.0) - (27.0 - r) * 0.8
        if k % 3 == 0:
            lantern(m, g, P(r, deg, y), rng.uniform(4.0, 8.0), "accent_cyan", flame=k % 2 == 0)
        elif k % 3 == 1:
            m.cone(g, "RootCrystal", ACCENT[k % 6], P(r, deg, y), rng.uniform(1.0, 1.8), rng.uniform(3.0, 6.0), sides=6, flip=True, solid=False)
        else:
            L = rng.uniform(6.0, 12.0)
            m.cyl(g, "Chain", "alloy_dark", P(r, deg, y - L), 0.24, L, sides=5, solid=False)
            m.block(g, "ChainHook", "brass", P(r, deg, y - L - 0.4), (0.9, 0.8, 0.9), shape="bevel", bevel=0.25, solid=False)


def decorate(m, folders):
    for i in range(5):
        g = m.group("Trim", folders[i])
        corridor_trim(m, g, i)
        feature_trim(m, g, i)
        g = m.group("Furnishings", folders[i])
        rooms_decor(m, g, i)
        hall_decor(m, g, i)
    engine_extras(m, m.group("Extras", folders[0]))
    library_extras(m, m.group("Extras", folders[1]))
    labs_extras(m, m.group("Extras", folders[2]))
    menagerie_extras(m, m.group("Extras", folders[3]))
    summoning_extras(m, m.group("Extras", folders[4]))
    observatory_extras(m, m.group("Extras", folders[5]))
    shaft_decor(m)
    exterior_decor(m)
