"""Dresses the Castle: python3 tools/arena/castle_dressing.py

The Castle (game/maps/castle.tscn) is built by hand in the editor. This script only
rebuilds its `Dressing` branch: several hundred drawn-only pieces (never solid, so they
change neither collision nor the bots' navigation) that would be tedious to place by
hand: copings on every merlon, pilasters and torches along the curtain walls, door and
window surrounds on the keep, the great hall's fittings, market goods, weeds and straw,
and the lake, causeway and mountains outside the walls.

Run it again after moving the things it dresses (it reads their places from the scene):
it removes the old `Dressing` branch and writes a new one. Everything else in the scene
is left exactly as it was. The kinds it uses must be in palettes/castle.tres.

The rules it keeps (tests/map_flicker_test.gd checks them):
 - a detail stands proud of the surface behind it, and two details that overlap stand
   at different depths (2 cm or more apart), so no two faces share a plane;
 - paint on the ground is 2 cm thick or more, each kind at its own height;
 - on the two breakable hoardings only thin skins that lie inside one panel.
"""
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

from arena_builder import Map, fmt, yaw_cols  # noqa: E402

SCENE = "game/maps/castle.tscn"
PALETTE = "game/maps/palettes/castle.tres"
D = "Dressing"
TOWERS = {"NW": (-25.8, -25.8), "NE": (25.8, -25.8), "SW": (-25.8, 25.8), "SE": (25.8, 25.8)}
# The curtain walls' inner faces: name, the axis the wall runs along, the face, the way it looks.
WALLS = (("North", "x", -27.0, 1), ("South", "x", 27.0, -1), ("West", "z", -27.0, 1), ("East", "z", 27.0, -1))
# The keep's outer faces, the same way.
KEEP = (("North", "x", -9.0, -1), ("South", "x", 9.0, 1), ("West", "z", -9.0, -1), ("East", "z", 9.0, 1))


# -- reading the scene ---------------------------------------------------------
class Frame:
    """Where a node stands in the map: `rows` (its basis, row by row) and `origin`."""

    def __init__(self, rows=((1, 0, 0), (0, 1, 0), (0, 0, 1)), origin=(0, 0, 0)):
        self.rows, self.origin = rows, origin

    def point(self, p):
        return tuple(sum(self.rows[i][k] * p[k] for k in range(3)) + self.origin[i] for i in range(3))

    def cols(self):
        return tuple(tuple(self.rows[i][k] for i in range(3)) for k in range(3))

    def then(self, other):
        rows = tuple(tuple(sum(self.rows[i][k] * other.rows[k][j] for k in range(3)) for j in range(3)) for i in range(3))
        return Frame(rows, self.point(other.origin))


class Piece:
    def __init__(self, path, frame, size, kind, solid, shape):
        self.path, self.frame, self.size, self.kind, self.solid, self.shape = path, frame, size, kind, solid, shape

    def box(self):
        """Its bounds in the map: (lo, hi)."""
        lo, hi = [1e9] * 3, [-1e9] * 3
        for sx in (-0.5, 0.5):
            for sy in (-0.5, 0.5):
                for sz in (-0.5, 0.5):
                    p = self.frame.point((sx * self.size[0], sy * self.size[1], sz * self.size[2]))
                    for i in range(3):
                        lo[i], hi[i] = min(lo[i], p[i]), max(hi[i], p[i])
        return lo, hi


def read_scene(text):
    """The scene's sections (text), and its blocks outside the Dressing branch."""
    sections = re.split(r"\n(?=\[)", text.rstrip("\n"))
    kept, frames, pieces = [], {".": Frame()}, []
    for s in sections:
        head = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', s)
        if not head:
            kept.append(s)
            continue
        name, _type, parent = head.groups()
        if parent is None:
            kept.append(s)
            continue
        path = name if parent == "." else parent + "/" + name
        if path == D or path.startswith(D + "/"):
            continue
        kept.append(s)
        frame = frames[parent]
        t = re.search(r"^transform = Transform3D\(([^)]*)\)", s, re.M)
        if t:
            v = [float(x) for x in t.group(1).split(",")]
            frame = frame.then(Frame((tuple(v[0:3]), tuple(v[3:6]), tuple(v[6:9])), tuple(v[9:12])))
        frames[path] = frame
        if "map_block.gd" in SCRIPT_OF.get(_script(s), ""):
            size = re.search(r"^size = Vector3\(([^)]*)\)", s, re.M)
            kind = re.search(r'^kind = "([^"]*)"', s, re.M)
            shape = re.search(r"^shape = (\d)", s, re.M)
            pieces.append(Piece(path, frame, tuple(float(x) for x in size.group(1).split(",")) if size else (1.0, 1.0, 1.0),
                                kind.group(1) if kind else "", "solid = false" not in s, int(shape.group(1)) if shape else 0))
    return kept, pieces


SCRIPT_OF = {}


def _script(section):
    m = re.search(r'^script = ExtResource\("([^"]+)"\)', section, re.M)
    return m.group(1) if m else ""


# -- small helpers ---------------------------------------------------------------
def in_frame(m, frame, parent, name, kind, lo, hi, **kw):
    """A drawn-only box from `lo` to `hi` in a node's own frame (a cart, a turned panel)."""
    c = frame.point(tuple((a + b) * 0.5 for a, b in zip(lo, hi)))
    kw.setdefault("solid", False)
    return m.block(parent, name, kind, c, tuple(abs(b - a) for a, b in zip(lo, hi)), cols=frame.cols(), **kw)


def radial(m, parent, name, kind, centre, angle, r0, r1, y0, y1, width, **kw):
    """A drawn-only box on a round tower: `width` across, from radius r0 to r1, facing
    out along `angle` (radians; 0 is +z, a quarter turn is +x)."""
    r = (r0 + r1) * 0.5
    c = (centre[0] + math.sin(angle) * r, (y0 + y1) * 0.5, centre[1] + math.cos(angle) * r)
    return m.block(parent, name, kind, c, (width, y1 - y0, r1 - r0), cols=yaw_cols(angle), solid=False, **kw)


def torch(m, parent, name, axis, face, out, u, y):
    """A wall torch: an iron arm and cup, and the flame."""
    m.on_wall(parent, name + "Arm", "iron", axis, face, out, u - 0.04, u + 0.04, y - 0.05, y + 0.03, depth=0.34)
    m.on_wall(parent, name + "Cup", "iron", axis, face, out, u - 0.11, u + 0.11, y + 0.03, y + 0.17, depth=0.22, lift=0.2)
    m.on_wall(parent, name, "torch", axis, face, out, u - 0.08, u + 0.08, y + 0.17, y + 0.55, depth=0.16, lift=0.23)


def shield(m, parent, name, kind, axis, face, out, u, y, lift=0.0):
    """A painted shield with a boss."""
    m.on_wall(parent, name, kind, axis, face, out, u - 0.45, u + 0.45, y - 0.3, y + 0.6, depth=0.06, lift=lift)
    m.on_wall(parent, name + "Point", kind, axis, face, out, u - 0.25, u + 0.25, y - 0.6, y - 0.3, depth=0.06, lift=lift)
    m.on_wall(parent, name + "Band", "banner_gold", axis, face, out, u - 0.38, u + 0.38, y + 0.08, y + 0.22, depth=0.09, lift=lift)
    m.on_wall(parent, name + "Boss", "banner_gold", axis, face, out, u - 0.13, u + 0.13, y + 0.02, y + 0.28, depth=0.14, lift=lift)


def ivy(m, parent, name, rng, axis, face, out, u, width, height, lift=0.0, y0=0.0):
    """Ivy up a wall from `y0`: a few stems of small leafy patches that wander as they climb.
    It stays within `width` * 0.8 either side of `u` and below y0 + `height`."""
    for stem in range(3):
        c = u + (stem - 1) * width * 0.3
        top = height * (1.0, 0.72, 0.5)[stem] * rng.uniform(0.85, 1.0)
        y = y0
        while y < y0 + top - 0.3:
            t = (y - y0) / max(top, 0.1)
            w = width * (0.55 - 0.3 * t) * rng.uniform(0.7, 1.1)
            h = min(rng.uniform(0.38, 0.62), y0 + top - y)
            c = min(max(c, u - width * 0.5), u + width * 0.5)
            # The two greens overlap, so their edges are kept on two grids 2 cm apart and
            # their backs and fronts at different depths: no two of their faces can share a plane.
            light = rng.random() < 0.3
            snap = lambda v: round(v / 0.04) * 0.04 + (0.02 if light else 0.0)
            m.on_wall(parent, name, "ivy_light" if light else "ivy", axis, face, out, snap(c - w * 0.5), snap(c + w * 0.5),
                      snap(y) if y > y0 else y + (0.02 if light and y0 > 0 else 0.0), snap(y + h), depth=rng.choice((0.05, 0.09) if light else (0.05, 0.09, 0.13)),
                      lift=lift + (0.02 if light else 0.0))
            y += h * rng.uniform(0.55, 0.8)
            c += rng.uniform(-0.28, 0.28) * width * 0.6


# -- the pieces --------------------------------------------------------------------
def merlon_caps(m, pieces):
    """A pale coping stone on every merlon."""
    for p in pieces:
        leaf = p.path.rsplit("/", 1)[-1]
        if "Merlon" not in leaf:
            continue
        sx, sy, sz = p.size
        in_frame(m, p.frame, D + "/Copings", "Coping", "stone_light",
                 (-sx * 0.5 - 0.07, sy * 0.5, -sz * 0.5 - 0.07), (sx * 0.5 + 0.07, sy * 0.5 + 0.11, sz * 0.5 + 0.07))


def curtain_walls(m, rng):
    P = D + "/Walls"
    for name, axis, face, out in WALLS:
        runs = ((-21.6, -6.0), (6.0, 21.6)) if name == "South" else ((-21.6, 21.6),)
        for u0, u1 in runs:
            m.on_wall(P, name + "BaseCourse", "stone_dark", axis, face, out, u0, u1, 0.0, 0.5, depth=0.08)
        posts = (-19.0, -12.0, 12.0, 19.0) if name == "South" else (-19.0, -12.0, -5.0, 5.0, 12.0, 19.0)
        for i, u in enumerate(posts):
            m.on_wall(P, name + "Pilaster", "stone_light", axis, face, out, u - 0.45, u + 0.45, 0.0, 5.575, depth=0.14)
            m.on_wall(P, name + "PilasterFoot", "stone_dark", axis, face, out, u - 0.6, u + 0.6, 0.0, 0.62, depth=0.24)
            m.on_wall(P, name + "PilasterHead", "stone_light", axis, face, out, u - 0.58, u + 0.58, 5.2, 5.5, depth=0.2)
            if i % 2 == (0 if name in ("North", "South") else 1):
                torch(m, P, name + "Torch", axis, face, out, u, 3.1)
        # Shields between the pilasters, and ivy where the wall is bare.
        spots = {"North": (8.5, -15.5, 15.5), "South": (-15.5,), "West": (-8.5, 8.5, 15.5), "East": (-15.5, -8.5, 15.5)}[name]
        for i, u in enumerate(spots):
            shield(m, P, name + "Shield", "banner_red" if (i + len(name)) % 2 else "banner_blue", axis, face, out, u, 3.4)
        # Ivy in the widest bare stretches: clear of the pilasters, shields, banners, stairs and bridges.
        taken = [(u - 0.62, u + 0.62) for u in posts] + [(u - 0.5, u + 0.5) for u in spots] + [(-30.0, -21.3), (21.3, 30.0)]
        taken += {"North": [(-9.95, -8.05), (-2.25, 1.85)], "South": [(-10.05, 10.05), (14.55, 16.45)], "West": [(-1.3, 1.3)],
                  "East": [(1.7, 4.3)]}[name]
        taken.sort()
        gaps = sorted(((b[0] - a[1], (a[1] + b[0]) * 0.5) for a, b in zip(taken, taken[1:]) if b[0] - a[1] >= 2.4), reverse=True)
        for gap, u in gaps[:3]:
            w = min(2.4, (gap - 0.2) / 1.6)
            ivy(m, P, name + "Ivy", rng, axis, face, out, u, w, rng.uniform(3.0, 4.4), y0=0.5)
            ivy(m, P, name + "Ivy", rng, axis, face, out, u, w * 0.8, 0.5, lift=0.08)


def towers(m):
    for key, (cx, cz) in TOWERS.items():
        P = D + "/Tower" + key
        c = (cx, cz)
        inward = math.atan2(-cx, -cz)     # the way to the middle of the bailey
        m.cyl(P, "PlinthRing", "stone_light", (cx, 1.2, cz), 8.5, 0.22, sides=24, solid=False)
        m.cyl(P, "Band", "stone_light", (cx, 6.3, cz), 8.26, 0.3, sides=24, solid=False)
        m.cyl(P, "TopRing", "stone_light", (cx, 11.55, cz), 8.46, 0.28, sides=24, solid=False)
        # Arrow slits low down, lit windows higher up, to the bailey and out over the lake.
        for i, (turn, y, lit) in enumerate(((0, 2.6, False), (38, 8.2, True), (-38, 8.2, True),
                                             (150, 7.4, False), (-150, 7.4, False), (180, 3.4, False))):
            a = inward + math.radians(turn)
            radial(m, P, "SlitSurround", "stone_light", c, a, 3.86, 4.07, y - 0.28, y + 1.68, 0.74)
            radial(m, P, "Slit", "glass_lit" if lit else "shadow", c, a, 3.9, 4.12, y, y + 1.4, 0.3)
            radial(m, P, "SlitSill", "stone_light", c, a, 3.9, 4.2, y - 0.4, y - 0.28, 0.9)
        # A flag pole in the crenel that looks out over the water.
        a = inward + math.pi
        px, pz = cx + math.sin(a) * 4.55, cz + math.cos(a) * 4.55
        m.cyl(P, "FlagPole", "wood", (px, 10.4, pz), 0.14, 7.4, sides=8, solid=False)
        for y in (10.75, 12.5):
            radial(m, P, "FlagBracket", "iron", c, a, 3.9, 4.66, y, y + 0.1, 0.24)
        col = "banner_red" if key in ("NW", "SE") else "banner_blue"
        side = a + math.pi * 0.5
        fx, fz = px + math.sin(side) * 1.05, pz + math.cos(side) * 1.05
        m.block(P, "Flag", col, (fx, 17.1, fz), (1.9, 1.1, 0.05), cols=yaw_cols(side + math.pi * 0.5), solid=False)
        m.block(P, "FlagStripe", "banner_gold", (fx, 17.1, fz), (1.97, 0.26, 0.09), cols=yaw_cols(side + math.pi * 0.5), solid=False)
        m.cyl(P, "FlagPoleKnob", "banner_gold", (px, 17.8, pz), 0.26, 0.2, sides=8, solid=False)


def gatehouse(m):
    P = D + "/Gatehouse"
    # The portcullis as a grille: dark gaps with iron bars across them, on both faces.
    for tag, face, out in (("In", 29.3, -1), ("Out", 29.7, 1)):
        for i in range(7):
            x = -1.74 + i * 0.58
            m.on_wall(P, "PortcullisGap" + tag, "shadow", "x", face, out, x - 0.2, x + 0.2, 0.25, 4.3, depth=0.02)
        for i in range(6):
            y = 0.62 + i * 0.68
            m.on_wall(P, "PortcullisBar" + tag, "iron", "x", face, out, -2.0, 2.0, y - 0.07, y + 0.07, depth=0.05)
    # Pier footings and shields either side of the arch, windows in the upper storey.
    for s, tag in ((-1, "West"), (1, "East")):
        x0, x1 = sorted((s * 2.5, s * 6.0))
        m.on_wall(P, "PierFoot" + tag, "stone_dark", "x", 26.0, -1, x0, x1, 0.0, 0.5, depth=0.08)
        shield(m, P, "Shield" + tag, "banner_blue" if s < 0 else "banner_red", "x", 26.0, -1, s * 4.4, 2.5)
        x = s * 4.1
        m.on_wall(P, "WindowFrame" + tag, "stone_light", "x", 26.0, -1, x - 0.6, x + 0.6, 6.7, 8.3, depth=0.1)
        m.on_wall(P, "Window" + tag, "glass_lit", "x", 26.0, -1, x - 0.4, x + 0.4, 6.9, 8.1, depth=0.13)
        m.on_wall(P, "WindowBarV" + tag, "iron", "x", 26.0, -1, x - 0.035, x + 0.035, 6.84, 8.16, depth=0.16)
        m.on_wall(P, "WindowBarH" + tag, "iron", "x", 26.0, -1, x - 0.46, x + 0.46, 7.46, 7.53, depth=0.19)
        m.on_wall(P, "WindowSill" + tag, "stone_light", "x", 26.0, -1, x - 0.7, x + 0.7, 6.55, 6.7, depth=0.22)
    m.strip(P, "RoofRidge", "slate", (-6.4, 10.74, 27.8), (6.4, 10.92, 28.2))
    # Outside, the drawbridge is up against the gate, on its chains.
    m.strip(P, "Drawbridge", "door", (-2.3, 0.1, 30.14), (2.3, 5.2, 30.36))
    for y in (0.9, 2.6, 4.3):
        m.strip(P, "DrawbridgeStrap", "iron", (-2.3, y, 30.36), (2.3, y + 0.16, 30.4))
    for s in (-1, 1):
        m.rod(P, "DrawbridgeChain", "iron", (s * 2.05, 5.0, 30.42), (s * 2.05, 7.7, 30.04), thick=0.07)
        m.on_wall(P, "ChainSlot", "shadow", "x", 30.0, 1, s * 2.05 - 0.14, s * 2.05 + 0.14, 7.5, 7.9, depth=0.03)


def keep_outside(m, rng):
    P = D + "/Keep"
    for s in (-1, 1):
        for t in (-1, 1):
            x0, x1 = sorted((s * 9.16, s * 8.3))
            z0, z1 = sorted((t * 9.16, t * 8.3))
            m.strip(P, "CornerStones", "stone_light", (x0, 0.0, z0), (x1, 11.05, z1))
    for name, axis, face, out in KEEP:
        m.on_wall(P, name + "CorbelTable", "stone_dark", axis, face, out, -9.16 if axis == "x" else -9.0,
                  9.16 if axis == "x" else 9.0, 11.05, 11.5, depth=0.16)
        ground_door = axis == "x"          # north and south: a door at the ground and a window over it
        gap = 1.95
        for u0, u1 in ((-8.3, -gap), (gap, 8.3)) if ground_door else ((-8.3, 8.3),):
            m.on_wall(P, name + "BaseCourse", "stone_dark", axis, face, out, u0, u1, 0.0, 0.8, depth=0.12)
        for u0, u1 in ((-8.3, 8.3),) if ground_door else ((-8.3, -gap), (gap, 8.3)):
            m.on_wall(P, name + "StringCourse", "stone_light", axis, face, out, u0, u1, 5.75, 6.05, depth=0.1)
        y0, y1 = (0.0, 3.5) if ground_door else (6.0, 9.0)
        for s in (-1, 1):
            u0, u1 = sorted((s * 1.5, s * gap))
            m.on_wall(P, name + "DoorJamb", "stone_light", axis, face, out, u0, u1, y0, y1, depth=0.16)
        m.on_wall(P, name + "DoorHead", "stone_light", axis, face, out, -gap, gap, y1, y1 + 0.45, depth=0.2)
        m.on_wall(P, name + "DoorKeystone", "stone_dark", axis, face, out, -0.3, 0.3, y1 - 0.07, y1 + 0.62, depth=0.26)
        if ground_door:
            m.on_wall(P, name + "WindowSill", "stone_light", axis, face, out, -1.9, 1.9, 7.75, 8.0, depth=0.22)
            for s in (-1, 1):
                u0, u1 = sorted((s * 1.5, s * 1.85))
                m.on_wall(P, name + "WindowJamb", "stone_light", axis, face, out, u0, u1, 8.0, 10.5, depth=0.14)
            m.on_wall(P, name + "WindowHead", "stone_light", axis, face, out, -1.9, 1.9, 10.5, 10.85, depth=0.18)
        # Arrow slits: at the ground on every face; the west and east ones upstairs get surrounds.
        for u in (-6.2, 6.2) if ground_door else (-4.6, 4.6):
            m.on_wall(P, name + "SlitSurround", "stone_light", axis, face, out, u - 0.34, u + 0.34, 1.4, 3.2, depth=0.05)
            m.on_wall(P, name + "Slit", "shadow", axis, face, out, u - 0.14, u + 0.14, 1.65, 2.95, depth=0.09)
        if not ground_door:
            for u in (-5.6, -2.6, 2.6, 5.6):
                m.on_wall(P, name + "UpperSlitSurround", "stone_light", axis, face, out, u - 0.34, u + 0.34, 7.55, 9.25, depth=0.05)
    ivy(m, P, "Ivy", rng, "x", -9.0, -1, 4.3, 1.7, 4.4, y0=0.8)
    ivy(m, P, "Ivy", rng, "z", 9.0, 1, -6.6, 1.8, 3.6, y0=0.8)
    ivy(m, P, "Ivy", rng, "x", 9.0, 1, -4.3, 1.7, 3.8, y0=0.8)
    ivy(m, P, "Ivy", rng, "z", -9.0, -1, 6.6, 1.8, 4.2, y0=0.8)
    # The keep's standard, on the finial.
    m.cyl(P, "StandardPole", "wood", (0, 16.35, 0), 0.12, 4.0, sides=8, solid=False)
    m.strip(P, "Standard", "banner_red", (0.06, 18.7, -0.03), (2.7, 20.2, 0.03))
    m.strip(P, "StandardStripe", "banner_gold", (0.03, 19.3, -0.05), (2.74, 19.6, 0.05))
    m.cyl(P, "StandardKnob", "banner_gold", (0, 20.35, 0), 0.26, 0.22, sides=8, solid=False)


def great_hall(m):
    P = D + "/GreatHall"
    # A long rug from door to door.
    m.strip(P, "RugBorder", "banner_gold", (-1.5, 0.0, -6.6), (1.5, 0.02, 6.6))
    m.strip(P, "Rug", "banner_red", (-1.25, 0.0, -6.35), (1.25, 0.045, 6.35))
    for z in (-4.4, 0.0, 4.4):
        m.strip(P, "RugDiamond", "banner_gold", (-0.45, 0.0, z - 0.45), (0.45, 0.07, z + 0.45))
    for x in (-5.0, 5.0):
        for z in (-5.0, 5.0):
            m.strip(P, "PillarFoot", "stone_light", (x - 0.76, 0.0, z - 0.76), (x + 0.76, 0.36, z + 0.76))
            m.strip(P, "PillarHead", "stone_light", (x - 0.76, 5.12, z - 0.76), (x + 0.76, 5.48, z + 0.76))
    for x in (-6.6, -2.6, 2.6, 6.6):
        m.strip(P, "CeilingBeam", "wood", (x - 0.18, 5.28, -8.0), (x + 0.18, 5.6, 8.0))
    # The fireplace in the east wall.
    for s in (-1, 1):
        z0, z1 = sorted((s * 0.9, s * 1.3))
        m.on_wall(P, "FireJamb", "stone_light", "z", 8.0, -1, z0, z1, 0.0, 1.9, depth=0.36)
    m.on_wall(P, "FireMantel", "stone_light", "z", 8.0, -1, -1.55, 1.55, 1.9, 2.16, depth=0.48)
    m.on_wall(P, "FireHood", "stone", "z", 8.0, -1, -1.15, 1.15, 2.16, 4.4, depth=0.3)
    m.on_wall(P, "FireBack", "shadow", "z", 8.0, -1, -0.9, 0.9, 0.0, 1.9, depth=0.04)
    m.on_wall(P, "FireEmbers", "torch", "z", 8.0, -1, -0.55, 0.55, 0.0, 0.3, depth=0.26, lift=0.04)
    m.lying_cyl(P, "FireLog", "wood", (7.8, 0.34, -0.15), 0.2, 1.1, axis="z", sides=7, solid=False)
    m.lying_cyl(P, "FireLog", "wood", (7.72, 0.4, 0.2), 0.18, 0.9, axis="z", sides=7, solid=False)
    shield(m, P, "FireShield", "banner_blue", "z", 8.0, -1, 0.0, 3.1, lift=0.3)
    # Torches by the doors, tapestries on the west wall.
    for x in (-3.0, 3.0):
        torch(m, P, "Torch", "x", -8.0, 1, x, 2.9)
        torch(m, P, "Torch", "x", 8.0, -1, x, 2.9)
    for i, z in enumerate((-5.4, 5.2)):
        m.on_wall(P, "TapestryRod", "wood", "z", -8.0, 1, z - 1.35, z + 1.35, 4.82, 4.92, depth=0.12)
        m.on_wall(P, "Tapestry", "banner_blue" if i else "banner_red", "z", -8.0, 1, z - 1.2, z + 1.2, 2.0, 4.82, depth=0.05)
        m.on_wall(P, "TapestryBand", "banner_gold", "z", -8.0, 1, z - 1.24, z + 1.24, 1.96, 2.28, depth=0.08)
        m.on_wall(P, "TapestryBand", "banner_gold", "z", -8.0, 1, z - 1.24, z + 1.24, 4.3, 4.5, depth=0.08)
    shield(m, P, "WestShield", "banner_red", "z", -8.0, 1, 0.0, 3.2)
    # The table is laid (its top is at 0.94).
    top = 0.94
    for i, x in enumerate((-5.6, -4.6, -3.4, -2.4)):
        for z in (-2.95, -2.05):
            m.cyl(P, "Plate", "stone_light", (x, top, z), 0.34, 0.035, sides=10, solid=False)
        m.cyl(P, "Mug", "wood_light", (x + 0.3, top, -2.5 + (0.3 if i % 2 else -0.3)), 0.13, 0.2, sides=8, solid=False)
    m.strip(P, "Bread", "bread", (-4.25, top, -2.66), (-3.75, top + 0.16, -2.36))
    m.cyl(P, "Roast", "pumpkin", (-3.0, top, -2.5), 0.4, 0.2, sides=9, solid=False)
    for x in (-5.1, -2.9):
        m.cyl(P, "Candle", "stone_light", (x, top, -2.5), 0.07, 0.26, sides=6, solid=False)
        m.strip(P, "CandleFlame", "torch", (x - 0.03, top + 0.26, -2.53), (x + 0.03, top + 0.36, -2.47))
    # A ring of candles hangs over the rug.
    m.pipe(P, "ChandelierRing", "iron", (0, 4.2, 0), (0, 4.3, 0), diameter=2.3, sides=16, inner=2.0)
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        x, z = math.sin(a) * 1.075, math.cos(a) * 1.075
        m.cyl(P, "ChandelierCandle", "stone_light", (x, 4.3, z), 0.07, 0.2, sides=6, solid=False)
        m.strip(P, "ChandelierFlame", "torch", (x - 0.035, 4.5, z - 0.035), (x + 0.035, 4.62, z + 0.035))
    for i in range(4):
        a = math.radians(i * 90)
        m.rod(P, "ChandelierChain", "iron", (math.sin(a) * 1.075, 4.3, math.cos(a) * 1.075), (0, 5.6, 0), thick=0.04)


def upper_room(m):
    P = D + "/UpperRoom"
    m.strip(P, "RugBorder", "banner_gold", (-6.6, 6.0, -1.3), (6.6, 6.02, 1.3))
    m.strip(P, "Rug", "banner_blue", (-6.35, 6.0, -1.05), (6.35, 6.045, 1.05))
    for z in (-6.0, -3.0, 3.0, 6.0):
        m.strip(P, "CeilingBeam", "wood", (-8.0, 11.18, z - 0.18), (8.0, 11.5, z + 0.18))
    for s in (-1, 1):
        for i, z in enumerate((-4.8, 4.8)):
            col = "banner_red" if (i + (s > 0)) % 2 else "banner_blue"
            m.on_wall(P, "TapestryRod", "wood", "z", s * 8.0, -s, z - 1.35, z + 1.35, 9.72, 9.82, depth=0.12)
            m.on_wall(P, "Tapestry", col, "z", s * 8.0, -s, z - 1.2, z + 1.2, 7.0, 9.72, depth=0.05)
            m.on_wall(P, "TapestryBand", "banner_gold", "z", s * 8.0, -s, z - 1.24, z + 1.24, 6.96, 7.26, depth=0.08)
            torch(m, P, "Torch", "z", s * 8.0, -s, z * 0.48, 8.0)
    # A rack of spears on the north wall, shields on the south.
    m.on_wall(P, "SpearRack", "wood", "x", -8.0, 1, 3.4, 6.6, 7.0, 7.14, depth=0.2)
    m.on_wall(P, "SpearRack", "wood", "x", -8.0, 1, 3.4, 6.6, 8.3, 8.44, depth=0.2)
    for x in (3.9, 4.6, 5.3, 6.0):
        m.strip(P, "Spear", "wood_light", (x - 0.03, 6.0, -7.9), (x + 0.03, 9.0, -7.84))
        m.strip(P, "SpearTip", "iron", (x - 0.06, 9.0, -7.91), (x + 0.06, 9.34, -7.83))
    for i, x in enumerate((-6.0, -4.4, 4.4, 6.0)):
        shield(m, P, "Shield", "banner_red" if i % 2 else "banner_blue", "x", 8.0, -1, x, 8.2)
    for x in (-5.0, 5.0):
        shield(m, P, "NorthShield", "banner_blue" if x > 0 else "banner_red", "x", -8.0, 1, x - 2.4 if x > 0 else x, 8.6)


def terrace_and_bridges(m):
    P = D + "/Terrace"
    for x in (11.4, 16.6):
        for z in (-8.2, 8.2):
            m.strip(P, "PierFoot", "stone_dark", (x - 0.86, 0.0, z - 0.86), (x + 0.86, 0.42, z + 0.86))
            m.strip(P, "PierHead", "stone_light", (x - 0.86, 4.98, z - 0.86), (x + 0.86, 5.32, z + 0.86))
    for z in (-3.2, 3.2):
        m.rod(P, "LanternChain", "iron", (13.5, 5.5, z), (13.5, 4.86, z), thick=0.04)
        m.strip(P, "LanternTop", "iron", (13.32, 4.78, z - 0.18), (13.68, 4.86, z + 0.18))
        m.strip(P, "Lantern", "torch", (13.37, 4.4, z - 0.13), (13.63, 4.78, z + 0.13))
        m.strip(P, "LanternFoot", "iron", (13.34, 4.33, z - 0.16), (13.66, 4.4, z + 0.16))
    P = D + "/Bridges"
    # name, the deck's x range, its middle z, the ends that meet a wall to brace against
    for name, x0, x1, zc, ends in (("West", -27.0, -9.0, 0.0, ((-27.0, 1), (-9.0, -1))), ("East", 18.0, 27.0, 3.0, ((27.0, -1),))):
        n = int(round((x1 - x0 - 1.2) / 2.8))
        for s in (-1, 1):
            z = zc + s * 1.35
            for i in range(1, n):
                x = x0 + 0.6 + (x1 - x0 - 1.2) * i / n
                m.strip(P, name + "RailPost", "wood_light", (x - 0.07, 6.0, z - 0.07), (x + 0.07, 6.89, z + 0.07))
            m.strip(P, name + "MidRail", "wood_light", (x0 + 0.6, 6.4, z - 0.04), (x1 - 0.6, 6.5, z + 0.04))
            zj = zc + s * 1.0
            m.strip(P, name + "Joist", "wood", (x0, 5.42, zj - 0.13), (x1, 5.7, zj + 0.13))
            for x, way in ends:
                m.rod(P, name + "Brace", "wood", (x, 3.5, zj), (x + way * 2.4, 5.5, zj), thick=0.22)
                m.on_wall(P, name + "BraceCorbel", "stone_light", "z", x, way, zj - 0.24, zj + 0.24, 3.05, 3.6, depth=0.34)
        for i in range(1, n):
            x = x0 + (x1 - x0) * i / n
            m.strip(P, name + "CrossBeam", "wood", (x - 0.1, 5.5, zc - 1.4), (x + 0.1, 5.7, zc + 1.4))


def market(m):
    P = D + "/Market"
    # West stall (it runs along x): stripes over the awning, a valance, goods on the counter.
    for i in range(4):
        x = -16.65 + i * 1.1
        m.strip(P, "WestAwningStripe", "banner_red", (x - 0.27, 2.6, -15.84), (x + 0.27, 2.8, -12.16))
    for z0, z1 in ((-15.8, -15.76), (-12.24, -12.2)):
        m.strip(P, "WestValance", "cloth", (-17.2, 2.3, z0), (-12.8, 2.62, z1))
    top = 1.1
    m.strip(P, "WestApples", "apple", (-16.26, 1.4, -14.31), (-15.54, 1.57, -13.69))
    m.strip(P, "WestCrateB", "wood_light", (-14.2, top, -14.5), (-13.5, top + 0.34, -13.95))
    m.strip(P, "WestCabbages", "cabbage", (-14.14, top + 0.24, -14.44), (-13.56, top + 0.42, -14.01))
    for i, (x, z) in enumerate(((-15.25, -13.62), (-14.95, -14.3), (-15.2, -14.38))):
        m.cyl(P, "WestPumpkin", "pumpkin", (x, top, z), 0.34 - 0.05 * i, 0.24, sides=9, solid=False)
    for x in (-13.9, -13.55):
        m.strip(P, "WestLoaf", "bread", (x - 0.11, top, -13.75), (x + 0.11, top + 0.14, -13.4))
    m.strip(P, "WestHangingBar", "wood", (-16.7, 2.3, -15.54), (-13.3, 2.38, -15.46))
    for i, x in enumerate((-16.0, -15.4, -14.8, -14.2, -13.7)):
        m.strip(P, "WestHangingString", "rope", (x - 0.012, 1.95, -15.512), (x + 0.012, 2.3, -15.488))
        m.strip(P, "WestHanging", ("apple", "bread", "pumpkin")[i % 3], (x - 0.09, 1.6 + 0.06 * (i % 2), -15.58), (x + 0.09, 1.95, -15.42))
    # East stall (it runs along z).
    for i in range(4):
        z = 11.35 + i * 1.1
        m.strip(P, "EastAwningStripe", "cloth", (12.16, 2.6, z - 0.27), (15.84, 2.8, z + 0.27))
    for x0, x1 in ((12.2, 12.24), (15.76, 15.8)):
        m.strip(P, "EastValance", "banner_blue", (x0, 2.3, 10.8), (x1, 2.62, 15.2))
    m.strip(P, "EastBread", "bread", (13.71, 1.4, 13.55), (14.29, 1.56, 14.25))
    m.strip(P, "EastCrateB", "wood_light", (13.6, top, 11.5), (14.4, top + 0.34, 12.2))
    m.strip(P, "EastApples", "apple", (13.66, top + 0.24, 11.56), (14.34, top + 0.42, 12.14))
    for i, (x, z) in enumerate(((13.75, 12.75), (14.2, 12.6), (14.15, 13.1))):
        m.cyl(P, "EastCabbage", "cabbage", (x, top, z), 0.3 - 0.04 * i, 0.2, sides=8, solid=False)
    for z in (14.4, 14.62):
        m.cyl(P, "EastJug", "stone_dark", (13.7 + (z - 14.4), top, z), 0.18, 0.3, sides=8, solid=False)
    m.strip(P, "EastHangingBar", "wood", (15.46, 2.3, 11.3), (15.54, 2.38, 14.7))
    for i, z in enumerate((11.9, 12.5, 13.1, 13.7, 14.2)):
        m.strip(P, "EastHangingString", "rope", (15.488, 1.95, z - 0.012), (15.512, 2.3, z + 0.012))
        m.strip(P, "EastHanging", ("pumpkin", "apple", "bread")[i % 3], (15.42, 1.6 + 0.06 * (i % 2), z - 0.09), (15.58, 1.95, z + 0.09))


def props(m, pieces, rng):
    P = D + "/Props"
    by_path = {p.path: p for p in pieces}
    for p in pieces:
        leaf = p.path.rsplit("/", 1)[-1]
        sx, sy, sz = p.size
        if leaf.startswith("Barrel") or leaf == "HallBarrel":
            for y in (-0.28, 0.28):
                m.block(P, "BarrelHoop", "iron", p.frame.point((0, y * sy, 0)), (sx + 0.06, 0.07, sz + 0.06), cols=p.frame.cols(),
                        solid=False, shape="cyl", sides=14)
            m.block(P, "BarrelLid", "wood_light" if p.kind == "wood" else "wood", p.frame.point((0, sy * 0.5, 0)),
                    (sx - 0.16, 0.05, sz - 0.16), cols=p.frame.cols(), solid=False, shape="cyl", sides=14)
        elif leaf.startswith("Crate") or leaf == "HallCrate":
            other = "wood_light" if p.kind == "wood" else "wood"
            for y in (-0.36, 0.36):
                in_frame(m, p.frame, P, "CrateBand", other, (-sx * 0.5 - 0.03, y * sy - 0.06, -sz * 0.5 - 0.03),
                         (sx * 0.5 + 0.03, y * sy + 0.06, sz * 0.5 + 0.03))
        elif leaf.startswith("Hay") or leaf == "Load":
            for x in (-0.3, 0.3):
                in_frame(m, p.frame, P, "HayTwine", "rope", (x * sx - 0.03, -sy * 0.5 + 0.07, -sz * 0.5 - 0.025),
                         (x * sx + 0.03, sy * 0.5 + 0.025, sz * 0.5 + 0.025))
        elif leaf.startswith("Wheel"):
            m.block(P, "WheelHub", "iron", p.frame.origin, (0.3, sy + 0.08, 0.3), cols=p.frame.cols(), solid=False, shape="cyl", sides=8)
            m.block(P, "WheelTyre", "iron", p.frame.origin, (sx + 0.06, sy - 0.06, sz + 0.06), cols=p.frame.cols(), solid=False,
                    shape="cyl", sides=14)
    # A pitchfork stuck in each cart's hay.
    for cart in ("CartSouth", "CartNorth"):
        f = by_path["Bailey/%s/Body/Load" % cart].frame
        in_frame(m, f, P, "PitchforkShaft", "wood_light", (0.1, 0.3, -0.03), (0.16, 1.5, 0.03))
        in_frame(m, f, P, "PitchforkHead", "iron", (0.02, 0.22, -0.035), (0.24, 0.3, 0.035))
    # The well: a rim, the rope and a crank.
    m.pipe(P, "WellRim", "stone_light", (0, 0.9, 12), (0, 1.12, 12), diameter=2.76, sides=20, inner=2.24)
    m.strip(P, "WellRope", "rope", (-0.02, 2.5, 11.98), (0.02, 2.9, 12.02))
    m.lying_cyl(P, "WellSpool", "wood_light", (0, 3.0, 12), 0.34, 1.2, axis="x", sides=8, solid=False)
    m.strip(P, "WellCrank", "iron", (1.4, 2.97, 11.97), (1.62, 3.03, 12.03))
    m.strip(P, "WellCrankHandle", "iron", (1.56, 2.66, 11.97), (1.62, 2.97, 12.03))
    m.strip(P, "WellRoofRidge", "wood", (-1.56, 3.66, 11.9), (1.56, 3.8, 12.1))
    m.pipe(P, "BucketHoop", "iron", (0, 2.38, 12), (0, 2.44, 12), diameter=0.62, sides=8, inner=0.5)
    # Battens and a painted target on the two wooden hoardings: thin skins that break with them.
    for leaf, target_side in (("HoardingNorth", 1), ("HoardingEast", -1)):
        p = by_path["Bailey/" + leaf]
        sx, sy, sz = p.size
        for side in (-1, 1):
            z0, z1 = sorted((side * sz * 0.5, side * (sz * 0.5 + 0.05)))
            for y in (-0.95, 0.95):
                in_frame(m, p.frame, P, leaf + "Batten", "wood", (-sx * 0.5 + 0.06, y - 0.11, z0), (sx * 0.5 - 0.06, y + 0.11, z1))
            for x in (-sx * 0.5 + 0.2, sx * 0.5 - 0.2):
                zb0, zb1 = sorted((side * sz * 0.5, side * (sz * 0.5 + 0.08)))
                in_frame(m, p.frame, P, leaf + "Stile", "wood", (x - 0.12, -sy * 0.5 + 0.06, zb0), (x + 0.12, sy * 0.5 - 0.06, zb1))
        for i, (half, kind) in enumerate(((0.62, "cloth"), (0.42, "banner_red"), (0.2, "cloth"))):
            z0, z1 = sorted((target_side * sz * 0.5, target_side * (sz * 0.5 + 0.03 + 0.03 * i)))
            in_frame(m, p.frame, P, leaf + "Target", kind, (-half, -half + 0.05, z0), (half, half + 0.05, z1))
    # Ivy on the free-standing walls, a torch on each.
    rng2 = random.Random(77)
    ivy(m, P, "WallRunIvy", rng2, "z", -15.6, 1, 8.4, 1.8, 3.6)
    ivy(m, P, "WallRunIvy", rng2, "x", -19.6, 1, 10.8, 1.8, 3.8)
    ivy(m, P, "WallRunIvy", rng2, "x", -20.4, -1, 15.2, 1.6, 3.0)
    torch(m, P, "WallRunTorch", "z", -15.6, 1, 4.0, 2.7)
    torch(m, P, "WallRunTorch", "x", -19.6, 1, 14.5, 2.7)
    # Bunting from the gatehouse to the keep.
    cols = ("banner_red", "banner_gold", "banner_blue")
    for s in (-1, 1):
        a, b = (s * 4.6, 8.4, 25.95), (s * 4.6, 10.9, 9.25)
        n = 12
        last = a
        for i in range(1, n + 1):
            t = i / n
            sag = 1.5 * 4 * t * (1 - t)
            pt = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
            pt = (pt[0], pt[1] - sag, pt[2])
            m.rod(P, "BuntingRope", "rope", last, pt, thick=0.04)
            if i < n:
                m.strip(P, "BuntingFlag", cols[(i + (s > 0)) % 3], (pt[0] - 0.035, pt[1] - 0.52, pt[2] - 0.2), (pt[0] + 0.035, pt[1], pt[2] + 0.2))
            last = pt


def ground(m, pieces, rng):
    """Weeds along the walls, and worn earth and straw on the cobbles (each at its own height)."""
    P = D + "/Ground"
    solids = [p.box() for p in pieces if p.solid and p.path != "Ground/Floor"]
    solids = [(lo, hi) for lo, hi in solids if lo[1] < 0.6]
    paving = [p.box() for p in pieces if p.path.startswith("Ground/Paving")]

    def free(x0, z0, x1, z1, boxes, margin=0.0):
        for lo, hi in boxes:
            if x0 < hi[0] + margin and x1 > lo[0] - margin and z0 < hi[2] + margin and z1 > lo[2] - margin:
                return False
        return True

    # Tufts at the foot of the curtain walls and the keep.
    for walls, lift, reach, count in ((WALLS, 0.08, 21.0, 16), (KEEP, 0.12, 8.0, 7)):
        for name, axis, face, out in walls:
            made = 0
            while made < count:
                u = rng.uniform(-reach, reach)
                w, h, d = rng.uniform(0.25, 0.6), rng.uniform(0.12, 0.34), rng.uniform(0.1, 0.22)
                a, b = sorted((face + out * lift, face + out * (lift + d)))
                x0, z0, x1, z1 = (u - w / 2, a, u + w / 2, b) if axis == "x" else (a, u - w / 2, b, u + w / 2)
                made += 1
                if not free(x0, z0, x1, z1, solids, 0.12) or not free(x0, z0, x1, z1, paving, 0.1):
                    continue
                if walls is KEEP and abs(u) < 2.3 and axis == "x":
                    continue
                m.on_wall(P, "Weeds", "grass", axis, face, out, u - w / 2, u + w / 2, 0.0, h, depth=d, lift=lift)

    # Worn earth (2 cm) and straw (4 cm): patches near where people and carts stand.
    def patches(name, kind, top, spots):
        for cx, cz, spread, n in spots:
            for _ in range(n):
                # One blotch: a few small slabs turned different ways, so it has no straight outline.
                x, z = cx + rng.uniform(-spread, spread), cz + rng.uniform(-spread, spread)
                r = rng.uniform(0.5, 1.0)
                if not free(x - r * 1.6, z - r * 1.6, x + r * 1.6, z + r * 1.6, paving, 0.1) or abs(x) > 25.5 or abs(z) > 25.5:
                    continue
                for k in range(4):
                    w, l = r * rng.uniform(0.9, 1.5), r * rng.uniform(0.7, 1.2)
                    m.block(P, name, kind, (x + rng.uniform(-0.4, 0.4) * r, top * 0.5, z + rng.uniform(-0.4, 0.4) * r), (w, top, l),
                            cols=yaw_cols(rng.uniform(0, math.pi)), solid=False)

    patches("Earth", "dirt", 0.02, ((-15, -14, 3.0, 7), (14, 13, 3.0, 7), (0, 11, 2.6, 5), (-4, 14, 2.4, 4), (17, -12, 2.4, 4),
                                    (-8.4, 13, 2.0, 3), (8.4, 13, 2.0, 3), (13, -19, 2.4, 4), (-13, 6, 2.6, 4), (-20, -20, 3.0, 4),
                                    (20, 20, 3.0, 4), (20, -20, 3.0, 4), (-20, 20, 3.0, 4)))
    patches("Straw", "hay", 0.04, ((3, -11, 2.0, 6), (-4, 14, 1.8, 4), (17, -12, 1.8, 4), (16.5, 12.5, 1.8, 3), (-17.8, -10, 1.2, 3)))


def outside(m, rng):
    """Beyond the walls: the castle stands on a rock in a lake, mountains all round."""
    P = D + "/Outside"
    m.strip(P, "Lake", "lake", (-420, -12.0, -420), (420, -4.6, 420))
    m.strip(P, "Rock", "rock", (-31.3, -9.0, -31.3), (31.3, -0.25, 31.3))
    m.strip(P, "RockSkirt", "rock", (-33.0, -9.0, -33.0), (33.0, -2.7, 33.0))
    for key, (cx, cz) in TOWERS.items():
        m.cyl(P, "TowerFooting", "stone_dark", (cx, -9.4, cz), 9.5, 9.2, sides=24, solid=False)
    # Boulders at the water line.
    for i in range(26):
        side = i % 4
        u = rng.uniform(-30, 30)
        r = 33.0 + rng.uniform(-0.6, 1.8)
        x, z = ((u, -r), (r, u), (u, r), (-r, u))[side]
        if abs(x) < 4.5 and z > 0:
            continue                      # the causeway's place
        s = rng.uniform(1.6, 4.2)
        m.block(P, "Boulder", "rock", (x, -4.6 + s * rng.uniform(-0.1, 0.25), z), (s, s * rng.uniform(0.6, 1.0), s * rng.uniform(0.7, 1.2)),
                cols=yaw_cols(rng.uniform(0, math.pi)), solid=False)
    # The causeway from the far shore stops short of the gate: the drawbridge is up.
    m.strip(P, "CausewayDeck", "stone", (-2.7, -1.0, 37.0), (2.7, -0.3, 190.0))
    for s in (-1, 1):
        x0, x1 = sorted((s * 2.7, s * 2.3))
        m.strip(P, "CausewayParapet", "stone_light", (x0, -0.3, 37.0), (x1, 0.45, 190.0))
        m.strip(P, "CausewayPost", "stone", (s * 2.5 - 0.5, -0.3, 37.0 - 0.3), (s * 2.5 + 0.5, 1.9, 37.9))
        m.strip(P, "CausewayPostCap", "stone_light", (s * 2.5 - 0.6, 1.9, 36.6), (s * 2.5 + 0.6, 2.1, 38.0))
        m.strip(P, "CausewayLamp", "torch", (s * 2.5 - 0.12, 2.1, 37.18), (s * 2.5 + 0.12, 2.5, 37.42))
    for i in range(13):
        z = 39.0 + i * 12.0
        m.strip(P, "CausewayPier", "stone_dark", (-3.1, -9.6, z - 1.4), (3.1, -1.0, z + 1.4))
    m.strip(P, "CausewayRoad", "dirt", (-1.6, -0.3, 37.9), (1.6, -0.27, 190.0))
    # Two boats out on the water.
    for x, z, turn in ((-58.0, 46.0, 0.5), (66.0, -38.0, 2.2)):
        f = Frame(tuple(tuple(yaw_cols(turn)[k][i] for k in range(3)) for i in range(3)), (x, -4.6, z))
        in_frame(m, f, P, "BoatHull", "wood", (-2.6, -0.2, -0.9), (2.6, 0.7, 0.9))
        in_frame(m, f, P, "BoatBow", "wood", (2.6, 0.0, -0.55), (3.5, 0.7, 0.55))
        in_frame(m, f, P, "BoatRail", "wood_light", (-2.7, 0.7, -1.0), (2.7, 0.86, 1.0))
        in_frame(m, f, P, "BoatMast", "wood_light", (-0.1, 0.86, -0.1), (0.1, 7.4, 0.1))
        in_frame(m, f, P, "BoatSail", "cloth", (0.1, 2.0, -0.04), (3.1, 7.0, 0.04))
        in_frame(m, f, P, "BoatPennant", "banner_red", (-1.2, 7.0, -0.03), (-0.1, 7.4, 0.03))
    # A rocky islet with a ruined watch tower, north-west.
    m.cyl(P, "Islet", "rock", (-82.0, -9.8, -64.0), 30.0, 7.0, sides=9, solid=False)
    m.cyl(P, "IsletTop", "grass", (-82.0, -2.8, -64.0), 24.0, 0.7, sides=9, solid=False)
    m.cyl(P, "RuinTower", "stone", (-84.0, -2.1, -66.0), 7.0, 11.0, sides=12, solid=False)
    m.cyl(P, "RuinTowerBand", "stone_light", (-84.0, 6.0, -66.0), 7.5, 0.5, sides=12, solid=False)
    for i in range(5):
        a = math.radians(20 + i * 62)
        radial(m, P, "RuinTooth", "stone", (-84.0, -66.0), a, 2.7, 3.5, 8.9, 8.9 + (1.4, 2.6, 0.8, 2.0, 1.2)[i], 1.5)
    m.strip(P, "RuinWall", "stone", (-80.0, -2.1, -61.6), (-73.0, 2.2, -60.4))
    # Shores with pine woods, then the mountains.
    shore_rng = random.Random(5)
    for i in range(9):
        a = math.radians(i * 40 + 12)
        r = shore_rng.uniform(205, 240)
        x, z = math.sin(a) * r, math.cos(a) * r
        w = shore_rng.uniform(120, 170)
        if i == 0:
            x, z, r, a, w = 0.0, 262.0, 262.0, 0.0, 170.0     # where the causeway lands
        m.cyl(P, "Shore", "grass", (x, -10.2, z), w, shore_rng.uniform(7.2, 10.7), sides=10, solid=False)
        for k in range(5):
            b = a + shore_rng.uniform(-0.2, 0.2)
            rr = r - w * 0.5 + shore_rng.uniform(8, 40)
            tx, tz = math.sin(b) * rr, math.cos(b) * rr
            h = shore_rng.uniform(13, 20)
            m.cyl(P, "PineTrunk", "trunk", (tx, -3.5, tz), 1.3, h * 0.4, sides=6, solid=False)
            m.cyl(P, "Pine", "pine", (tx, -3.5 + h * 0.3, tz), h * 0.62, h * 0.34, sides=7, solid=False)
            m.cyl(P, "Pine", "pine", (tx, -3.5 + h * 0.6, tz), h * 0.42, h * 0.3, sides=7, solid=False)
            m.cyl(P, "Pine", "pine", (tx, -3.5 + h * 0.86, tz), h * 0.2, h * 0.3, sides=7, solid=False)
    # Green foothills behind the shores, then a ring of mountains, the tall ones with snow.
    for i in range(11):
        a = math.radians(i * (360 / 11.0) + 20)
        r = shore_rng.uniform(300, 330)
        peak(m, P, "Foothill", shore_rng, math.sin(a) * r, math.cos(a) * r, shore_rng.uniform(170, 230), shore_rng.uniform(34, 58), 4,
             ("grass", "grass", "pine", "pine"))
    for i in range(15):
        a = math.radians(i * (360 / 15.0) + 7)
        r = shore_rng.uniform(395, 425)
        h = shore_rng.uniform(120, 215)
        snow = 3 if h > 165 else 2 if h > 140 else 0
        peak(m, P, "Mountain", shore_rng, math.sin(a) * r, math.cos(a) * r, shore_rng.uniform(240, 300), h, 10,
             ("pine",) + ("mountain",) * (9 - snow) + ("snow",) * snow)


def peak(m, parent, name, rng, x, z, width, height, tiers, kinds):
    """A hill or mountain: round slabs stacked ever narrower, each sunk a little into the one below."""
    for k in range(tiers):
        t = k / float(tiers)
        d = width * (1.0 - t) ** 1.3 + width * 0.05
        h = height / tiers + 2.0
        y0 = -10.6 + height * t - (2.0 if k else 0.0)
        x += rng.uniform(-0.04, 0.04) * width
        z += rng.uniform(-0.04, 0.04) * width
        m.block(parent, name, kinds[k], (x, y0 + h * 0.5, z), (d, h, d), cols=yaw_cols(rng.uniform(0, 1.0)), solid=False,
                shape="cyl", sides=9)


def build():
    os.chdir(ROOT)
    text = open(SCENE).read()
    for path, rid in re.findall(r'\[ext_resource type="Script" path="([^"]+)" id="([^"]+)"\]', text):
        SCRIPT_OF[rid] = path
    block_id = [k for k, v in SCRIPT_OF.items() if v.endswith("map_block.gd")][0]
    kept, pieces = read_scene(text)

    m = Map("Castle", "", {}, None, {})
    m.nodes = []                        # only the dressing: the scene keeps its own spawns and signs
    m.folder(D)
    for g in ("Copings", "Walls", "TowerNW", "TowerNE", "TowerSW", "TowerSE", "Gatehouse", "Keep", "GreatHall", "UpperRoom",
              "Terrace", "Bridges", "Market", "Props", "Ground", "Outside"):
        m.group(g, D)
    rng = random.Random(1066)
    merlon_caps(m, pieces)
    curtain_walls(m, rng)
    towers(m)
    gatehouse(m)
    keep_outside(m, rng)
    great_hall(m)
    upper_room(m)
    terrace_and_bridges(m)
    market(m)
    props(m, pieces, rng)
    ground(m, pieces, rng)
    outside(m, rng)

    known = set(re.findall(r'^"([a-z_0-9]+)": Color', open(PALETTE).read(), re.M))
    out = list(kept)
    for n in m.nodes:
        lines = ['[node name="%s" type="%s" parent="%s"]' % (n.name, n.type, n.parent)]
        lines += ["%s = %s" % (k, v) for k, v in n.props if k == "transform"]
        if n.script:
            lines.append('script = ExtResource("%s")' % block_id)
        for k, v in n.props:
            if k == "kind" and v.strip('"') not in known:
                sys.exit("kind %s is not in %s" % (v, PALETTE))
            if k != "transform":
                lines.append("%s = %s" % (k, v))
        if n.group:
            lines.append("metadata/_edit_group_ = true")
        out.append("\n".join(lines) + "\n")
    with open(SCENE, "w") as fh:
        fh.write("\n".join(s.rstrip("\n") + "\n" for s in out))
    print("wrote %s: %d dressing pieces (%d other blocks read)" % (SCENE, len(m.nodes), len(pieces)))


if __name__ == "__main__":
    build()
