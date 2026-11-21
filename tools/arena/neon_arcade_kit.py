"""Neon Arcade's kit: the palette, the map writer and the things the map is furnished
with (arcade machines, furniture, cars, street furniture). Nothing here says where
anything stands: tools/arena/neon_arcade.py (the arcade) and neon_arcade_block.py (the
city block round it) do.

A thing looks along a `face` ("+z" south, "-z" north, "+x" east, "-x" west) and is made
of boxes square to the map, so nothing here is turned at an angle. Every thing is a
group of its own: its drawn parts go with its solid body when a building comes down.
"""
import math
from arena_builder import Map, SCRIPTS, fmt, color
from cirrus import CirrusMap, _turn

PAL = "res://game/maps/palettes/neon_arcade.tres"

COLORS = {
    # the arcade
    "brick": (0.36, 0.29, 0.44), "wall": (0.16, 0.15, 0.23), "wall_panel": (0.27, 0.22, 0.38), "pillar": (0.3, 0.27, 0.42),
    "partition": (0.45, 0.3, 0.6), "mezz_floor": (0.3, 0.2, 0.43), "ceiling": (0.13, 0.12, 0.18), "roof": (0.3, 0.3, 0.34),
    "carpet": (0.2, 0.14, 0.32), "carpet_teal": (0.1, 0.26, 0.3), "tile_dark": (0.2, 0.2, 0.25),
    "glass": (0.6, 0.85, 0.95, 0.24), "glass_rail": (0.5, 0.86, 0.96, 0.3), "glass_dark": (0.1, 0.13, 0.18),
    "steel": (0.42, 0.44, 0.5), "truss": (0.3, 0.31, 0.36), "chrome": (0.8, 0.82, 0.87), "frame": (0.11, 0.11, 0.15),
    "grate": (0.26, 0.27, 0.31),
    # machines and prizes
    "cab_red": (0.72, 0.16, 0.22), "cab_blue": (0.16, 0.3, 0.74), "cab_black": (0.1, 0.1, 0.13), "cab_yellow": (0.92, 0.7, 0.14),
    "cab_green": (0.14, 0.58, 0.36), "cab_purple": (0.5, 0.22, 0.74), "counter": (0.86, 0.35, 0.56), "shelf": (0.36, 0.3, 0.45),
    "prize": (0.96, 0.6, 0.2), "prize_blue": (0.35, 0.6, 0.96), "prize_green": (0.4, 0.86, 0.45), "prize_pink": (0.98, 0.5, 0.75),
    "stage": (0.12, 0.12, 0.16), "hockey": (0.9, 0.92, 0.96), "claw_glass": (0.65, 0.9, 1.0, 0.3), "lane": (0.8, 0.62, 0.4),
    # light
    "screen": (0.3, 0.85, 1.0), "screen_pink": (1.0, 0.35, 0.75), "screen_green": (0.4, 1.0, 0.5), "marquee": (1.0, 0.9, 0.55),
    "neon_pink": (1.0, 0.25, 0.7), "neon_cyan": (0.2, 0.95, 1.0), "neon_yellow": (1.0, 0.86, 0.2), "neon_green": (0.35, 1.0, 0.45),
    "neon_orange": (1.0, 0.5, 0.12), "neon_purple": (0.66, 0.36, 1.0), "neon_red": (1.0, 0.16, 0.16), "neon_white": (0.95, 0.97, 1.0),
    "dance_pad": (0.9, 0.3, 0.9), "lamp": (1.0, 0.95, 0.85), "lamp_warm": (1.0, 0.76, 0.42), "window_lit": (1.0, 0.85, 0.55),
    "lantern": (1.0, 0.3, 0.18), "beacon": (1.0, 0.2, 0.15), "signal_green": (0.3, 1.0, 0.5), "signal_amber": (1.0, 0.7, 0.15),
    # furniture
    "sofa": (0.2, 0.7, 0.75), "sofa_red": (0.72, 0.2, 0.24), "cushion": (0.95, 0.8, 0.4), "table": (0.85, 0.85, 0.9),
    "wood": (0.46, 0.32, 0.22), "wood_light": (0.7, 0.54, 0.36), "seat_red": (0.8, 0.14, 0.18), "white_goods": (0.9, 0.91, 0.93),
    "drum": (0.14, 0.2, 0.26), "paper": (0.93, 0.89, 0.78), "bed": (0.56, 0.62, 0.8), "pot": (0.66, 0.38, 0.28),
    "leaves": (0.22, 0.52, 0.3), "leaves_pink": (0.94, 0.5, 0.68), "bark": (0.34, 0.25, 0.2), "soil": (0.26, 0.2, 0.16),
    "felt": (0.1, 0.45, 0.3), "bowl": (0.95, 0.94, 0.9), "vinyl": (0.07, 0.07, 0.08),
    # the neighbours
    "brick_red": (0.54, 0.26, 0.22), "brick_tan": (0.63, 0.52, 0.4), "stucco": (0.74, 0.78, 0.8), "diner_wall": (0.8, 0.83, 0.88),
    "wall_warm": (0.7, 0.56, 0.4), "wall_teal": (0.18, 0.4, 0.44), "wall_cream": (0.9, 0.85, 0.74), "wall_flat": (0.7, 0.68, 0.8),
    "ceiling_light": (0.8, 0.79, 0.76), "floor_wood": (0.5, 0.36, 0.25), "tile": (0.86, 0.86, 0.84), "tile_teal": (0.3, 0.62, 0.64),
    "lino": (0.42, 0.4, 0.5), "column": (0.84, 0.84, 0.8), "canopy": (0.9, 0.9, 0.86), "awning_red": (0.8, 0.2, 0.2),
    "awning_teal": (0.14, 0.6, 0.6), "awning_yellow": (0.95, 0.75, 0.2), "shutter": (0.46, 0.48, 0.52),
    # the street
    "sidewalk": (0.56, 0.56, 0.58), "street": (0.2, 0.2, 0.23), "lot": (0.27, 0.27, 0.3), "alley": (0.33, 0.31, 0.34),
    "plaza": (0.62, 0.58, 0.56), "kerb": (0.74, 0.74, 0.72), "paint": (0.88, 0.88, 0.84), "paint_yellow": (0.95, 0.78, 0.15),
    "court": (0.2, 0.36, 0.5), "tyre": (0.08, 0.08, 0.09), "car_red": (0.75, 0.14, 0.16), "car_blue": (0.14, 0.3, 0.66),
    "car_yellow": (0.95, 0.74, 0.1), "car_white": (0.9, 0.9, 0.92), "car_green": (0.16, 0.45, 0.32), "car_black": (0.12, 0.12, 0.15),
    "dumpster": (0.16, 0.38, 0.3), "container": (0.7, 0.32, 0.16), "crate": (0.62, 0.46, 0.28), "cardboard": (0.72, 0.56, 0.38),
    "hydrant": (0.84, 0.18, 0.14), "mailbox": (0.14, 0.26, 0.6), "ac_unit": (0.7, 0.72, 0.74), "tank": (0.52, 0.38, 0.28),
    "hazard": (0.95, 0.72, 0.1), "cone": (1.0, 0.45, 0.1), "fence": (0.5, 0.52, 0.56), "rail": (0.42, 0.44, 0.5),
    "metal": (0.3, 0.31, 0.36), "water": (0.3, 0.8, 0.95), "hedge": (0.18, 0.4, 0.26), "planter": (0.5, 0.48, 0.5),
    # beyond the block
    "backdrop": (0.3, 0.28, 0.4), "backdrop_dark": (0.21, 0.2, 0.3), "backdrop_far": (0.16, 0.15, 0.24),
}
# The pattern each colour is drawn with (MapScenery.SURFACES).
SURFACE = {
    "brick": "bricks", "brick_red": "bricks", "brick_tan": "bricks", "stucco": "blocks", "diner_wall": "panels_plain",
    "wall": "panels", "wall_warm": "planks_upright", "wall_teal": "panels_plain", "wall_cream": "tiles", "pillar": "panels",
    "partition": "panels_plain", "mezz_floor": "checker", "carpet": "confetti", "carpet_teal": "confetti", "tile_dark": "tiles",
    "roof": "tarmac", "sidewalk": "pavers", "street": "tarmac", "lot": "tarmac", "alley": "cobbles", "plaza": "slabs",
    "backdrop": "windows_lit", "backdrop_dark": "windows_lit", "backdrop_far": "windows_lit", "stage": "planks",
    "ac_unit": "slats", "shutter": "slats", "shelf": "planks", "floor_wood": "planks", "tile": "checker", "tile_teal": "tiles",
    "lino": "checker", "grate": "grating", "container": "corrugated", "crate": "planks", "wood": "planks", "lane": "planks",
    "tank": "planks_upright", "hazard": "hazard", "canopy": "panels_plain", "truss": "plates", "dumpster": "panels_plain",
}
GLOW = {"water": 0.9, "screen": 1.6, "screen_pink": 1.6, "screen_green": 1.6, "marquee": 1.4, "neon_pink": 3.0, "neon_cyan": 3.0,
        "neon_yellow": 3.0, "neon_green": 3.0, "neon_orange": 3.0, "neon_purple": 3.0, "neon_red": 3.0, "neon_white": 2.6,
        "lamp": 1.5, "lamp_warm": 1.4, "window_lit": 0.8, "dance_pad": 1.2, "beacon": 2.5, "lantern": 1.8,
        "signal_green": 2.4, "signal_amber": 2.4}
# How tough each kind that breaks is (a block breaks only if its Breakable is ticked).
BREAKABLE = {"glass": 25, "glass_rail": 40, "claw_glass": 25, "partition": 100, "mezz_floor": 120, "floor_wood": 110,
             "roof": 260, "brick": 180, "brick_red": 180, "brick_tan": 180, "stucco": 160, "diner_wall": 120, "canopy": 240,
             "shutter": 90, "fence": 70}
MATERIAL = {
    "partition": "wood", "mezz_floor": "wood", "floor_wood": "wood", "wood": "wood", "wood_light": "wood", "shelf": "wood",
    "stage": "wood", "crate": "wood", "lane": "wood", "tank": "wood", "bark": "wood", "counter": "wood",
    "steel": "metal", "truss": "metal", "chrome": "metal", "frame": "metal", "grate": "metal", "diner_wall": "metal",
    "shutter": "metal", "container": "metal", "dumpster": "metal", "ac_unit": "metal", "fence": "metal", "white_goods": "metal",
    "car_red": "metal", "car_blue": "metal", "car_yellow": "metal", "car_white": "metal", "car_green": "metal",
    "car_black": "metal", "cab_red": "wood", "cab_blue": "wood", "cab_black": "wood", "cab_yellow": "wood",
    "cab_green": "wood", "cab_purple": "wood", "glass": "glass", "glass_rail": "glass", "claw_glass": "glass",
    "glass_dark": "glass", "carpet": "rubber", "carpet_teal": "rubber", "sofa": "rubber", "sofa_red": "rubber",
    "rail": "metal", "metal": "metal", "hedge": "dirt", "leaves": "dirt", "leaves_pink": "dirt", "soil": "dirt", "tyre": "rubber", "court": "rubber",
}

FACE_KEY = {"+x": "1000,0,0", "-x": "-1000,0,0", "+y": "0,1000,0", "-y": "0,-1000,0", "+z": "0,0,1000", "-z": "0,0,-1000"}
EXTRA_SCRIPTS = {
    "item": "res://game/arena/map_item_spawn.gd",
    "frame": "res://game/arena/map_frame.gd",
}


def carve(u0, u1, v0, v1, holes=(), cuts_u=(), cuts_v=()):
    """The rectangles (a0, a1, b0, b1) that cover u0..u1 by v0..v1 but for `holes` (each
    (a0, a1, b0, b1)), none of them crossing a cut line. Each is as tall (along v) as it
    can be, then as wide: a wall with windows comes out as piers, sills and lintels."""
    r = lambda t: round(t, 4)
    us = sorted(set([r(u0), r(u1)] + [r(c) for c in cuts_u if u0 < c < u1] + [r(min(max(h[i], u0), u1)) for h in holes for i in (0, 1)]))
    vs = sorted(set([r(v0), r(v1)] + [r(c) for c in cuts_v if v0 < c < v1] + [r(min(max(h[i], v0), v1)) for h in holes for i in (2, 3)]))
    hard_u = set(r(c) for c in cuts_u)
    hard_v = set(r(c) for c in cuts_v)
    nu, nv = len(us) - 1, len(vs) - 1

    def filled(i, j):
        if i < 0 or j < 0 or i >= nu or j >= nv:
            return False
        cu, cv = (us[i] + us[i + 1]) * 0.5, (vs[j] + vs[j + 1]) * 0.5
        return not any(h[0] < cu < h[1] and h[2] < cv < h[3] for h in holes)

    used = set()
    out = []
    for i in range(nu):
        for j in range(nv):
            if (i, j) in used or not filled(i, j):
                continue
            j1 = j + 1
            while j1 < nv and filled(i, j1) and (i, j1) not in used and vs[j1] not in hard_v:
                j1 += 1
            i1 = i + 1
            while i1 < nu and us[i1] not in hard_u and all(filled(i1, k) and (i1, k) not in used for k in range(j, j1)) \
                    and (j == 0 or vs[j] in hard_v or not filled(i1, j - 1) or (i1, j - 1) in used) \
                    and (j1 == nv or vs[j1] in hard_v or not filled(i1, j1)):
                i1 += 1
            for a in range(i, i1):
                for b in range(j, j1):
                    used.add((a, b))
            out.append((us[i], us[i1], vs[j], vs[j1]))
    return out


class ArcadeMap(CirrusMap):
    """The map writer, with what this map adds: blocks that break and blocks with a face
    of another kind, walls and floors with openings, glass, buildings that come down
    (MapFrame), power-ups and writing made of blocks."""

    def block(self, parent, name, kind, center, size, breaks=False, faces=None, unbreakable=False, **kw):
        """breaks: Breakable is ticked. faces: {"+x": kind...}: faces painted another kind."""
        path = Map.block(self, parent, name, kind, center, size, **kw)
        props = self.nodes[-1].props
        if breaks:
            props.append(("breakable", "true"))
        if faces:
            props.append(("face_kinds", "{%s}" % ", ".join('"%s": "%s"' % (FACE_KEY[k], faces[k]) for k in sorted(faces))))
        return path

    def rail_box(self, parent, lo, hi):
        """A railing filling the box lo..hi (1 m high, thin one way): two bars and posts
        to look at, and a solid panel you cannot see to lean on. (As CirrusMap's, but the
        end posts stand a hair past the bars' ends, so no two colours share a plane.)"""
        self.box(parent, "RailPanel", "rail", lo, hi, drawn=False)
        along_x = (hi[0] - lo[0]) >= (hi[2] - lo[2])
        y0, y1 = lo[1], hi[1]
        for name, a, b in (("RailTop", y1 - 0.09, y1), ("RailBar", y0 + 0.42, y0 + 0.5)):
            self.strip(parent, name, "rail", (lo[0], a, lo[2]), (hi[0], b, hi[2]))
        length = (hi[0] - lo[0]) if along_x else (hi[2] - lo[2])
        count = max(2, int(round(length / 2.2)) + 1)
        for i in range(count):
            c = (lo[0] if along_x else lo[2]) + 0.04 + (length - 0.08) * i / (count - 1)
            if along_x:
                self.strip(parent, "RailPost", "metal", (c - 0.05, y0, lo[2] - 0.01), (c + 0.05, y1 - 0.09, hi[2] + 0.01))
            else:
                self.strip(parent, "RailPost", "metal", (lo[0] - 0.01, y0, c - 0.05), (hi[0] + 0.01, y1 - 0.09, c + 0.05))

    def write(self, path):
        SCRIPTS.update(EXTRA_SCRIPTS)
        try:
            Map.write(self, path)
        finally:
            for k in EXTRA_SCRIPTS:
                del SCRIPTS[k]

    # -- walls, floors and glass ------------------------------------------------
    def wall(self, parent, name, kind, a, b, y0, y1, thick=0.5, holes=(), inside=None, side=1, cuts=(), breaks=True, **kw):
        """A wall along x or z from (x, z) `a` to `b`. holes: (from, to, bottom, top), from
        and to being x (or z) in the map. inside: the kind its face toward `side` (+1:
        south or east, -1: north or west) is painted; the rest of it is `kind`."""
        along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
        c0, c1 = sorted((a[0], b[0])) if along_x else sorted((a[1], b[1]))
        line = a[1] if along_x else a[0]
        faces = None
        if inside:
            faces = {(("+z" if side > 0 else "-z") if along_x else ("+x" if side > 0 else "-x")): inside}
        for (p0, p1, q0, q1) in carve(c0, c1, y0, y1, holes, cuts_u=cuts):
            if along_x:
                self.box(parent, name, kind, (p0, q0, line - thick / 2), (p1, q1, line + thick / 2), breaks=breaks, faces=faces, **kw)
            else:
                self.box(parent, name, kind, (line - thick / 2, q0, p0), (line + thick / 2, q1, p1), breaks=breaks, faces=faces, **kw)

    def deck(self, parent, name, kind, x0, x1, z0, z1, top, thick=0.3, holes=(), cuts_x=(), cuts_z=(), under=None, over=None,
             breaks=True, **kw):
        """A floor or a roof with its top at `top`. holes: (x0, x1, z0, z1). under, over:
        the kind its underside (a ceiling) and its top are painted."""
        faces = {}
        if under:
            faces["-y"] = under
        if over:
            faces["+y"] = over
        for (p0, p1, q0, q1) in carve(x0, x1, z0, z1, holes, cuts_x, cuts_z):
            self.box(parent, name, kind, (p0, top - thick, q0), (p1, top, q1), breaks=breaks, faces=faces or None, **kw)

    def pane(self, parent, kind, axis, line, c0, c1, y0, y1, bars=(0, 0), thick=0.1, name="Pane", bar="frame"):
        """A sheet of glass standing in the line of a wall (`axis` "x": the wall runs along
        x at z = line), with glazing bars lying on both its faces: they break with it."""
        if axis == "x":
            self.box(parent, name, kind, (c0, y0, line - thick / 2), (c1, y1, line + thick / 2), breaks=True)
        else:
            self.box(parent, name, kind, (line - thick / 2, y0, c0), (line + thick / 2, y1, c1), breaks=True)
        for out in (-1, 1):
            face = line + out * thick / 2
            for k in range(1, bars[0] + 1):
                c = c0 + (c1 - c0) * k / (bars[0] + 1)
                self.on_wall(parent, "GlazingBar", bar, axis, face, out, c - 0.03, c + 0.03, y0, y1, 0.025)
            for k in range(1, bars[1] + 1):
                y = y0 + (y1 - y0) * k / (bars[1] + 1)
                self.on_wall(parent, "GlazingBar", bar, axis, face, out, c0, c1, y - 0.03, y + 0.03, 0.025)

    def trim(self, parent, axis, line, thick, c0, c1, y0, y1, kind="frame", wide=0.12, proud=0.04, sill=True, sides=(-1, 1)):
        """A frame round an opening in a wall, lying on the wall's faces."""
        for out in sides:
            face = line + out * thick / 2
            self.on_wall(parent, "Trim", kind, axis, face, out, c0 - wide, c1 + wide, y1, y1 + wide, proud)
            if sill:
                self.on_wall(parent, "Trim", kind, axis, face, out, c0 - wide, c1 + wide, y0 - wide, y0, proud)
            self.on_wall(parent, "Trim", kind, axis, face, out, c0 - wide, c0, y0, y1, proud)
            self.on_wall(parent, "Trim", kind, axis, face, out, c1, c1 + wide, y0, y1, proud)

    def frame(self, name, parts, lines_x, lines_z, tops, **settings):
        """A MapFrame: the buildings under `parts` (groups at the top of the scene) can come down."""
        nums = lambda v: "PackedFloat32Array(%s)" % ", ".join(fmt(x) for x in v)
        props = [("parts", "Array[NodePath]([%s])" % ", ".join('NodePath("../%s")' % p for p in parts)),
                 ("lines_x", nums(lines_x)), ("lines_z", nums(lines_z)), ("floor_tops", nums(tops))]
        for k, v in settings.items():
            props.append((k, v if isinstance(v, str) else ("true" if v is True else "false" if v is False else fmt(v))))
        self._add(name, "Node3D", ".", props, "frame", False)

    def item(self, pos, kind):
        """A Deathmatch power-up (MapItemSpawn)."""
        if ("ItemSpawns", "Node3D") not in [(n.name, n.type) for n in self.nodes if n.parent == "."]:
            self._add("ItemSpawns", "Node3D", ".", [], None, False)
        from arena_builder import xform, IDENTITY
        self.item_count = getattr(self, "item_count", 0) + 1
        self._add("%s%d" % (kind, self.item_count), "Marker3D", "ItemSpawns", [("transform", xform(IDENTITY, pos)), ("item", '"%s"' % kind)],
                  "item", False)

    # -- writing made of blocks (a Label3D would hang in the air when its wall fell) ----
    def text(self, parent, text, axis, face, out, mid, y0, px, kind, depth=0.06, lift=0.0, name="Letter"):
        """`text` in a 5 x 7 dot face, on a wall (see on_wall), read from the side the wall
        faces: `mid` is the middle of it along the wall, y0 its foot, px one dot (metres)."""
        # (Left to right for the reader: +x on a wall facing south, -x north, -z east, +z west.)
        way = (1 if out > 0 else -1) if axis == "x" else (-1 if out > 0 else 1)
        widths = [len(FONT[ch][0]) for ch in text]
        total = sum(widths) + len(text) - 1
        u = -total / 2.0
        for ch, w in zip(text, widths):
            rows = FONT[ch]
            used = set()
            for cx in range(w):
                for ry in range(7):
                    if rows[ry][cx] != "1" or (cx, ry) in used:
                        continue
                    r1 = ry + 1
                    while r1 < 7 and rows[r1][cx] == "1" and (cx, r1) not in used:
                        r1 += 1
                    c1 = cx + 1
                    while c1 < w and all(rows[k][c1] == "1" and (c1, k) not in used for k in range(ry, r1)) \
                            and (ry == 0 or rows[ry - 1][c1] != "1") and (r1 == 7 or rows[r1][c1] != "1"):
                        c1 += 1
                    for a in range(cx, c1):
                        for b in range(ry, r1):
                            used.add((a, b))
                    ua, ub = sorted((mid + way * (u + cx) * px, mid + way * (u + c1) * px))
                    self.on_wall(parent, name, kind, axis, face, out, ua, ub, y0 + (7 - r1) * px, y0 + (7 - ry) * px, depth, lift=lift)
            u += w + 1
        return total * px


FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["111", "010", "010", "010", "010", "010", "111"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["010", "110", "010", "010", "010", "010", "111"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    " ": ["00", "00", "00", "00", "00", "00", "00"],
    "-": ["000", "000", "000", "111", "000", "000", "000"],
    "!": ["1", "1", "1", "1", "1", "0", "1"],
    ">": ["1000", "0100", "0010", "0001", "0010", "0100", "1000"],
}


def write_palette(path):
    out = ['[gd_resource type="Resource" script_class="MapPalette" format=3]', "",
           '[ext_resource type="Script" path="res://game/arena/map_palette.gd" id="1_pal"]', "", "[resource]",
           'script = ExtResource("1_pal")']

    def dict_lines(name, typ, d, conv):
        return "%s = Dictionary[String, %s]({\n%s\n})" % (name, typ, ",\n".join('"%s": %s' % (k, conv(d[k])) for k in sorted(d)))

    num = lambda v: "%s.0" % int(v) if float(v) == int(v) else fmt(v)
    out.append(dict_lines("colors", "Color", COLORS, color))
    out.append(dict_lines("glow", "float", GLOW, num))
    out.append(dict_lines("surface", "String", SURFACE, lambda v: '"%s"' % v))
    out.append("roughness = 0.72")
    out.append(dict_lines("breakable", "float", BREAKABLE, num))
    out.append(dict_lines("material", "String", MATERIAL, lambda v: '"%s"' % v))
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")


# ---------------------------------------------------------------------------
# Things. Each stands at (x, z) on a floor at y and looks along `face`.

DIRS = {"+z": {"+z": "+z", "-z": "-z", "+x": "+x", "-x": "-x"},
        "-z": {"+z": "-z", "-z": "+z", "+x": "-x", "-x": "+x"},
        "+x": {"+z": "+x", "-z": "-x", "+x": "+z", "-x": "-z"},
        "-x": {"+z": "-x", "-z": "+x", "+x": "-z", "-x": "+z"}}
AXIS_OF = {"+z": ("x", 1), "-z": ("x", -1), "+x": ("z", 1), "-x": ("z", -1)}   # a wall facing that way: (on_wall's axis, out)


class At:
    """Places the parts of a thing that stands at `at` and looks along `face`: each part
    is given in the thing's own frame (it looks along its own +z, x to its side)."""

    def __init__(self, m, g, at, face="+z"):
        self.m, self.g, self.at, self.face = m, g, at, face

    def _ends(self, lo, hi):
        a, b = _turn(self.face, lo, hi)
        return tuple(p + q for p, q in zip(self.at, a)), tuple(p + q for p, q in zip(self.at, b))

    def pt(self, p):
        return self._ends(p, p)[0]

    def b(self, name, kind, lo, hi, bevel=None, **kw):
        """A box that is only drawn."""
        kw.setdefault("solid", False)
        a, b = self._ends(lo, hi)
        if bevel:
            return self.m.bev(self.g, name, kind, a, b, bevel, **kw)
        return self.m.box(self.g, name, kind, a, b, **kw)

    def s(self, name, kind, lo, hi, bevel=None, **kw):
        """A solid box."""
        return self.b(name, kind, lo, hi, bevel, solid=True, **kw)

    def cyl(self, name, kind, base, d, h, sides=8, **kw):
        kw.setdefault("solid", False)
        return self.m.cyl(self.g, name, kind, self.pt(base), d, h, sides=sides, **kw)

    def pipe(self, name, kind, a, b, d, sides=8, **kw):
        return self.m.pipe(self.g, name, kind, self.pt(a), self.pt(b), d, sides=sides, **kw)

    def ball(self, name, kind, mid, size, sides=8, **kw):
        kw.setdefault("solid", False)
        self.m.dome(self.g, name, kind, self.pt(mid), (size, size * 0.5, size), sides=sides, **kw)
        self.m.dome(self.g, name, kind, self.pt(mid), (size, size * 0.5, size), sides=sides, flip=True, **kw)

    def dome(self, name, kind, base, size, sides=10, **kw):
        kw.setdefault("solid", False)
        return self.m.dome(self.g, name, kind, self.pt(base), size, sides=sides, **kw)

    def cone(self, name, kind, base, d, h, top=0.0, sides=10, **kw):
        kw.setdefault("solid", False)
        return self.m.cone(self.g, name, kind, self.pt(base), d, h, top=top, sides=sides, **kw)

    def wedge(self, name, kind, lo, hi, tall="-z", **kw):
        """A slope filling the box, its tall side toward `tall` (in the thing's own frame)."""
        kw.setdefault("solid", False)
        a, b = self._ends(lo, hi)
        return self.m.wedge(self.g, name, kind, a, b, tall=DIRS[self.face][tall], **kw)

    def text(self, text, z, x_mid, y0, px, kind, depth=0.04, lift=0.0):
        """Writing on the thing's front, at its own z."""
        axis, out = AXIS_OF[self.face]
        p = self.pt((x_mid, 0, z))
        self.m.text(self.g, text, axis, p[2] if axis == "x" else p[0], out, p[0] if axis == "x" else p[2], self.at[1] + y0, px, kind,
                    depth, lift)


def cabinet(m, parent, x, z, face, kind, y=0.0, screen="screen", neon="neon_cyan"):
    """An upright arcade cabinet, 1.1 m wide and 2.1 m high."""
    a = At(m, m.group("Cabinet", parent), (x, y, z), face)
    a.s("Body", kind, (-0.5, 0, -0.45), (0.5, 2.1, 0.32))
    a.b("Bezel", "cab_black", (-0.45, 1.14, 0.2), (0.45, 1.82, 0.36))
    a.b("Screen", screen, (-0.37, 1.22, 0.3), (0.37, 1.74, 0.39))
    a.b("Marquee", "marquee", (-0.46, 1.86, 0.2), (0.46, 2.06, 0.38))
    a.b("Marquee", neon, (-0.3, 1.92, 0.3), (0.3, 2.0, 0.4))
    a.b("Panel", "cab_black", (-0.52, 0.94, 0.2), (0.52, 1.08, 0.7), bevel=0.04)
    a.cyl("Stick", "steel", (-0.26, 1.08, 0.52), 0.04, 0.14, sides=6)
    a.ball("StickBall", "cab_red", (-0.26, 1.25, 0.52), 0.1, sides=6)
    for k, kind_ in enumerate(("prize", "prize_blue", "prize_green")):
        a.cyl("Button", kind_, (0.06 + k * 0.13, 1.08, 0.52), 0.08, 0.03, sides=6)
    a.b("CoinDoor", "steel", (-0.2, 0.3, 0.2), (0.2, 0.7, 0.35))
    a.b("CoinSlot", "neon_orange", (-0.05, 0.5, 0.3), (0.05, 0.58, 0.37))
    a.b("Kick", "cab_black", (-0.52, 0, -0.47), (0.52, 0.16, 0.34))
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.4, s * 0.53))
        a.b("Stripe", "hockey", (x0, 1.42, -0.3), (x1, 1.56, 0.22))
        a.b("Stripe", neon, (x0, 1.18, -0.3), (x1, 1.26, 0.22))
    return a


def racer(m, parent, x, z, face, kind, y=0.0):
    """A sit-down racing game: a seat, a wheel and a screen."""
    a = At(m, m.group("Racer", parent), (x, y, z), face)
    a.s("Dash", kind, (-0.55, 0, 0.55), (0.55, 1.9, 1.15))
    a.s("Base", "cab_black", (-0.5, 0, -0.95), (0.5, 0.22, 0.55))
    a.s("Seat", "cab_black", (-0.34, 0.22, -0.9), (0.34, 0.55, -0.2), bevel=0.06)
    a.b("SeatBack", kind, (-0.34, 0.55, -0.98), (0.34, 1.35, -0.74), bevel=0.08)
    a.b("Bezel", "cab_black", (-0.48, 1.0, 0.45), (0.48, 1.75, 0.6))
    a.b("Screen", "screen", (-0.4, 1.08, 0.4), (0.4, 1.67, 0.52))
    a.b("Marquee", "marquee", (-0.5, 1.9, 0.5), (0.5, 2.12, 1.1))
    a.pipe("Column", "steel", (0, 0.85, 0.5), (0, 0.98, 0.22), 0.08)
    a.pipe("Wheel", "cab_black", (0, 0.98, 0.24), (0, 1.0, 0.17), 0.42, sides=12, inner=0.3)
    a.b("Pedals", "chrome", (-0.2, 0.22, 0.3), (0.2, 0.3, 0.5))
    a.b("Shifter", "chrome", (0.4, 0.22, -0.2), (0.48, 0.6, -0.12))
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.5, s * 0.58))
        a.b("Stripe", "neon_yellow", (x0, 0.5, 0.6), (x1, 0.62, 1.1))
    return a


def dance_machine(m, parent, x, z, face, y=0.0):
    """A dance game: a lit pad to stand on, a bar behind it and a tall screen in front."""
    a = At(m, m.group("DanceMachine", parent), (x, y, z), face)
    a.s("Tower", "cab_black", (-0.95, 0, -1.7), (0.95, 2.5, -1.2))
    a.b("Screen", "screen_pink", (-0.75, 1.1, -1.3), (0.75, 2.1, -1.15))
    a.b("Marquee", "marquee", (-0.9, 2.2, -1.3), (0.9, 2.42, -1.16))
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.62, s * 0.92))
        a.b("Speaker", "truss", (x0, 0.2, -1.3), (x1, 0.95, -1.16))
    a.s("Pad", "cab_black", (-0.9, 0, -1.2), (0.9, 0.12, 0.6))
    for (dx, dz, kind) in ((0, 0.45, "neon_cyan"), (0, -0.45, "neon_cyan"), (-0.5, 0, "neon_pink"), (0.5, 0, "neon_pink")):
        a.b("Arrow", kind, (dx - 0.2, 0.1, -0.3 + dz - 0.2), (dx + 0.2, 0.14, -0.3 + dz + 0.2))
    a.b("PadMiddle", "dance_pad", (-0.2, 0.1, -0.5), (0.2, 0.135, -0.1))
    for s in (-1, 1):
        a.pipe("BarPost", "chrome", (s * 0.8, 0.12, 0.55), (s * 0.8, 1.0, 0.55), 0.06)
    a.pipe("Bar", "chrome", (-0.8, 1.0, 0.55), (0.8, 1.0, 0.55), 0.06)
    return a


def skee_ball(m, parent, x, z, face, y=0.0, neon="neon_orange"):
    """A skee-ball lane: 1.1 m wide, 3.4 m long, the target hood at its far (front) end."""
    a = At(m, m.group("SkeeBall", parent), (x, y, z), face)
    a.s("Lane", "cab_blue", (-0.55, 0, -1.7), (0.55, 0.8, 0.6))
    a.b("LaneTop", "lane", (-0.45, 0.8, -1.7), (0.45, 0.83, 0.6))
    a.wedge("Jump", "lane", (-0.45, 0.83, 0.3), (0.45, 1.05, 0.6), tall="+z")
    a.s("Hood", "cab_blue", (-0.55, 0, 0.6), (0.55, 2.0, 1.7))
    a.b("Target", "cab_black", (-0.47, 0.9, 0.52), (0.47, 1.9, 0.66))
    for k, (dy, d, kind) in enumerate(((1.15, 0.62, "hockey"), (1.42, 0.42, "prize"), (1.66, 0.26, "neon_red"))):
        a.pipe("Ring", kind, (0, dy, 0.5 - k * 0.01), (0, dy, 0.44 - k * 0.01), d, sides=12, inner=d - 0.08)
    a.b("Score", "screen_green", (-0.3, 2.0, 0.6), (0.3, 2.25, 0.75))
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.5, s * 0.58))
        a.b("Rail", neon, (x0, 0.8, -1.7), (x1, 0.9, 0.6))
    a.b("BallReturn", "cab_black", (-0.5, 0.25, -1.76), (0.5, 0.6, -1.66))
    return a


def hoops(m, parent, x, z, face, y=0.0):
    """A basketball game: a cage, a hoop and a ramp the balls roll back down."""
    a = At(m, m.group("Hoops", parent), (x, y, z), face)
    a.s("Base", "cab_red", (-0.6, 0, -1.2), (0.6, 0.9, 0.9))
    a.wedge("Ramp", "cab_black", (-0.5, 0.9, -1.0), (0.5, 1.35, 0.6), tall="-z")
    a.s("Back", "cab_red", (-0.6, 0.9, -1.2), (0.6, 2.6, -1.0))
    a.b("Board", "hockey", (-0.4, 1.7, -1.02), (0.4, 2.3, -0.96))
    a.pipe("Hoop", "neon_orange", (0, 1.8, -0.72), (0, 1.84, -0.72), 0.46, sides=12, inner=0.38)
    a.b("Score", "screen", (-0.4, 2.36, -1.02), (0.4, 2.56, -0.95))
    for s in (-1, 1):
        a.pipe("CagePost", "steel", (s * 0.58, 0.9, 0.85), (s * 0.58, 2.6, -1.0), 0.04)
    for k, dx in enumerate((-0.3, 0.05, 0.32)):
        a.ball("Ball", "prize", (dx, 1.05 + 0.08 * k, 0.3 - 0.3 * k), 0.24, sides=8)
    return a


def claw_machine(m, parent, x, z, face, kind="cab_yellow", y=0.0, neon="neon_pink"):
    """A claw machine: a glass case of prizes that breaks."""
    a = At(m, m.group("ClawMachine", parent), (x, y, z), face)
    a.s("Base", kind, (-0.7, 0, -0.7), (0.7, 1.0, 0.7))
    a.s("Top", kind, (-0.7, 2.3, -0.7), (0.7, 2.55, 0.7))
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        a.b("Post", kind, (sx * 0.7 - 0.05, 1.0, sz * 0.7 - 0.05), (sx * 0.7 + 0.05, 2.3, sz * 0.7 + 0.05))
    a.b("Glass", "claw_glass", (-0.66, 1.0, -0.66), (0.66, 2.3, 0.66))
    for k, (dx, dz, kind_) in enumerate(((-0.35, -0.3, "prize"), (0.1, -0.2, "prize_blue"), (0.38, 0.25, "prize_pink"),
                                         (-0.2, 0.3, "prize_green"), (0.0, 0.05, "cab_yellow"))):
        a.ball("Prize", kind_, (dx, 1.14 + 0.03 * (k % 2), dz), 0.3, sides=6)
    a.b("Gantry", "steel", (-0.6, 2.2, -0.05), (0.6, 2.26, 0.05))
    a.cyl("Cable", "steel", (0.15, 1.75, 0), 0.02, 0.45, sides=4)
    a.cone("Claw", "chrome", (0.15, 1.6, 0), 0.24, 0.16, top=0.06, sides=6)
    a.b("Controls", "cab_black", (-0.5, 0.82, 0.6), (0.5, 0.98, 0.88), bevel=0.04)
    a.cyl("Stick", "cab_red", (-0.2, 0.98, 0.76), 0.06, 0.14, sides=6)
    a.b("Chute", "cab_black", (0.2, 0.15, 0.6), (0.56, 0.5, 0.73))
    a.b("Neon", neon, (-0.72, 2.36, -0.72), (0.72, 2.46, 0.72))
    return a


def pinball(m, parent, x, z, face, kind, y=0.0):
    """A pinball table: you stand at its front, the backbox is at its back."""
    a = At(m, m.group("Pinball", parent), (x, y, z), face)
    a.s("Table", kind, (-0.4, 0.55, -0.7), (0.4, 1.0, 0.7))
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        a.b("Leg", "chrome", (sx * 0.36 - 0.04, 0, sz * 0.64 - 0.04), (sx * 0.36 + 0.04, 0.55, sz * 0.64 + 0.04))
    a.s("Backbox", "cab_black", (-0.42, 1.0, -0.7), (0.42, 1.95, -0.42))
    a.b("Lights", "screen", (-0.34, 1.1, -0.5), (0.34, 1.86, -0.39))
    a.b("Playfield", "cab_black", (-0.34, 1.0, -0.42), (0.34, 1.03, 0.64))
    for k, (dx, dz, kind_) in enumerate(((-0.15, -0.2, "screen_pink"), (0.12, -0.05, "neon_yellow"), (-0.02, 0.2, "screen_green"))):
        a.cyl("Bumper", kind_, (dx, 1.03, dz), 0.12, 0.05, sides=8)
    for s in (-1, 1):
        a.b("Flipper", "hockey", (s * 0.06 if s > 0 else -0.2, 1.03, 0.48), (0.2 if s > 0 else -0.06, 1.06, 0.54))
    return a


def air_hockey(m, parent, x, z, y=0.0, along="x"):
    """An air hockey table, 3 m by 1.8 m, its length along `along`."""
    a = At(m, m.group("AirHockey", parent), (x, y, z), "+z" if along == "x" else "+x")
    a.s("Table", "cab_blue", (-1.5, 0, -0.9), (1.5, 0.82, 0.9), bevel=0.06)
    a.b("Ice", "hockey", (-1.38, 0.8, -0.78), (1.38, 0.86, 0.78))
    for (lo, hi) in (((-1.5, -0.9), (1.5, -0.78)), ((-1.5, 0.78), (1.5, 0.9)), ((-1.5, -0.78), (-1.38, 0.78)), ((1.38, -0.78), (1.5, 0.78))):
        a.b("Rim", "neon_cyan", (lo[0], 0.82, lo[1]), (hi[0], 0.94, hi[1]))
    a.b("CentreLine", "cab_red", (-0.02, 0.86, -0.78), (0.02, 0.875, 0.78))
    for s in (-1, 1):
        x0, x1 = sorted((s * 1.3, s * 1.39))
        a.b("Goal", "cab_black", (x0, 0.86, -0.3), (x1, 0.89, 0.3))
        a.cyl("Mallet", "cab_red" if s < 0 else "cab_yellow", (s * 0.9, 0.86, 0.1 * s), 0.26, 0.07, sides=10)
        a.cyl("MalletKnob", "cab_red" if s < 0 else "cab_yellow", (s * 0.9, 0.93, 0.1 * s), 0.1, 0.1, sides=8)
    a.cyl("Puck", "neon_orange", (0.3, 0.86, -0.2), 0.16, 0.03, sides=10)
    a.b("ScoreArm", "steel", (-0.04, 0.94, 0.82), (0.04, 1.7, 0.88))
    a.b("Score", "screen_green", (-0.4, 1.6, 0.8), (0.4, 1.86, 0.94))
    return a


def vending(m, parent, x, z, face, kind, y=0.0):
    a = At(m, m.group("Vending", parent), (x, y, z), face)
    a.s("Body", kind, (-0.6, 0, -0.42), (0.6, 2.15, 0.4), bevel=0.05)
    a.b("Window", "lamp", (-0.48, 0.85, 0.3), (0.2, 2.0, 0.43))
    for k in range(4):
        a.b("Shelf", "frame", (-0.46, 1.08 + k * 0.24, 0.32), (0.18, 1.11 + k * 0.24, 0.45))
        for j in range(4):
            a.b("Can", ("prize", "prize_blue", "prize_green", "prize_pink")[(k + j) % 4], (-0.44 + j * 0.16, 1.11 + k * 0.24, 0.34),
                (-0.34 + j * 0.16, 1.26 + k * 0.24, 0.46))
    a.b("Keypad", "frame", (0.28, 1.1, 0.3), (0.52, 1.6, 0.43))
    a.b("CoinSlot", "neon_green", (0.34, 1.26, 0.4), (0.46, 1.32, 0.45))
    a.b("Slot", "frame", (-0.4, 0.22, 0.3), (0.4, 0.56, 0.43))
    return a


def photo_booth(m, parent, x, z, face, y=0.0):
    """A photo booth: you go in at its front, a curtain half across."""
    a = At(m, m.group("PhotoBooth", parent), (x, y, z), face)
    a.s("Back", "cab_purple", (-0.9, 0, -0.7), (0.9, 2.2, -0.55))
    a.s("Side", "cab_purple", (-0.9, 0, -0.55), (-0.78, 2.2, 0.7))
    a.s("Side", "cab_purple", (0.78, 0, -0.55), (0.9, 2.2, 0.7))
    a.s("Roof", "cab_purple", (-0.9, 2.2, -0.7), (0.9, 2.35, 0.7))
    a.b("Screen", "screen", (-0.3, 1.2, -0.56), (0.3, 1.7, -0.5))
    a.b("Bench", "cab_black", (0.2, 0, -0.5), (0.76, 0.5, 0.4))
    a.b("Curtain", "sofa_red", (-0.78, 0.5, 0.62), (0.1, 2.2, 0.68))
    a.b("Sign", "neon_yellow", (-0.8, 2.35, 0.5), (0.8, 2.6, 0.62))
    a.b("Strip", "paper", (0.9, 1.1, 0.0), (0.93, 1.7, 0.3))
    return a


def token_machine(m, parent, x, z, face, y=0.0):
    a = At(m, m.group("TokenMachine", parent), (x, y, z), face)
    a.s("Body", "cab_yellow", (-0.45, 0, -0.3), (0.45, 1.8, 0.3), bevel=0.05)
    a.b("Screen", "screen_green", (-0.3, 1.15, 0.2), (0.3, 1.55, 0.33))
    a.b("Slot", "frame", (-0.25, 0.85, 0.2), (0.25, 1.0, 0.33))
    a.b("Tray", "chrome", (-0.3, 0.4, 0.2), (0.3, 0.55, 0.45))
    a.cyl("Coin", "prize", (0, 1.8, 0), 0.5, 0.06, sides=12)
    return a


def sofa(m, parent, x, z, face, wide=2.4, kind="sofa", y=0.0):
    """A sofa `wide` across, its back away from the way it looks."""
    a = At(m, m.group("Sofa", parent), (x, y, z), face)
    h = wide / 2
    a.s("Seat", kind, (-h, 0, -0.45), (h, 0.48, 0.45), bevel=0.08)
    a.b("Back", kind, (-h, 0.3, -0.5), (h, 1.0, -0.22), bevel=0.1, tint=(0.86, 0.86, 0.86))
    for s in (-1, 1):
        x0, x1 = sorted((s * (h - 0.2), s * (h + 0.04)))
        a.b("Arm", kind, (x0, 0.2, -0.46), (x1, 0.7, 0.46), bevel=0.08, tint=(0.92, 0.92, 0.92))
    a.b("Cushion", "cushion", (-h + 0.35, 0.48, -0.2), (-h + 0.85, 0.82, 0.02), bevel=0.1)
    return a


def table(m, parent, x, z, y=0.0, wide=1.6, deep=0.9, height=0.76, kind="table", solid=True):
    a = At(m, m.group("Table", parent), (x, y, z))
    a.b("Top", kind, (-wide / 2, height - 0.07, -deep / 2), (wide / 2, height, deep / 2), bevel=0.025, solid=solid)
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        a.b("Leg", "steel", (sx * (wide / 2 - 0.1) - 0.03, 0, sz * (deep / 2 - 0.1) - 0.03), (sx * (wide / 2 - 0.1) + 0.03, height - 0.07, sz * (deep / 2 - 0.1) + 0.03))
    return a


def round_table(m, parent, x, z, y=0.0, d=1.0, height=0.76, kind="table"):
    g = m.group("Table", parent)
    m.cyl(g, "Top", kind, (x, y + height - 0.06, z), d, 0.06, sides=12)
    m.cyl(g, "Leg", "steel", (x, y, z), 0.1, height - 0.06, sides=6, solid=False)
    m.cyl(g, "Foot", "steel", (x, y, z), d * 0.55, 0.04, sides=10, solid=False)
    return g


def stool(m, parent, x, z, y=0.0, height=0.7, kind="seat_red"):
    g = m.group("Stool", parent)
    m.cyl(g, "Seat", kind, (x, y + height - 0.1, z), 0.42, 0.1, sides=10, solid=False)
    m.cyl(g, "Leg", "chrome", (x, y, z), 0.08, height - 0.1, sides=6, solid=False)
    m.cyl(g, "Foot", "chrome", (x, y, z), 0.38, 0.03, sides=10, solid=False)
    return g


def chair(m, parent, x, z, face, y=0.0, kind="steel", seat="seat_red"):
    a = At(m, m.group("Chair", parent), (x, y, z), face)
    a.b("Seat", seat, (-0.24, 0.42, -0.24), (0.24, 0.5, 0.24), bevel=0.03)
    a.b("Back", seat, (-0.24, 0.6, -0.28), (0.24, 1.0, -0.22), bevel=0.025)
    for sx in (-1, 1):
        a.b("Legs", kind, (sx * 0.22 - 0.025, 0, -0.26), (sx * 0.22 + 0.025, 0.42, 0.22))
        a.b("Legs", kind, (sx * 0.22 - 0.025, 0.42, -0.27), (sx * 0.22 + 0.025, 0.62, -0.23))
    return a


def booth(m, parent, x, z, y=0.0, along="x", kind="seat_red"):
    """A diner booth: a table between two benches that face each other along `along`."""
    a = At(m, m.group("Booth", parent), (x, y, z), "+z" if along == "x" else "+x")
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.55, s * 1.1))
        a.s("Bench", kind, (x0, 0, -0.75), (x1, 0.48, 0.75), bevel=0.06)
        xb0, xb1 = sorted((s * 1.0, s * 1.18))
        a.b("BenchBack", kind, (xb0, 0.3, -0.75), (xb1, 1.2, 0.75), bevel=0.06, tint=(0.88, 0.88, 0.88))
    a.s("Top", "table", (-0.42, 0.7, -0.7), (0.42, 0.77, 0.7), bevel=0.03)
    a.cyl("Leg", "chrome", (0, 0, 0), 0.1, 0.7, sides=6)
    a.cyl("Sauce", "seat_red", (0.15, 0.77, -0.5), 0.07, 0.18, sides=6)
    a.cyl("Mustard", "cab_yellow", (0.02, 0.77, -0.5), 0.07, 0.18, sides=6)
    a.b("Napkins", "chrome", (-0.2, 0.77, -0.56), (-0.08, 0.92, -0.44))
    return a


def plant(m, parent, x, z, y=0.0, size=1.0, kind="leaves", pot="pot"):
    g = m.group("Plant", parent)
    s = size
    m.cone(g, "Pot", pot, (x, y + 0.5 * s, z), 0.62 * s, 0.5 * s, top=0.42 * s, sides=8, flip=True)
    m.cyl(g, "Stem", "bark", (x, y + 0.5 * s, z), 0.08 * s, 0.5 * s, sides=5, solid=False)
    for (dx, dy, dz, r) in ((0, 1.0, 0, 0.95), (0.22, 1.35, -0.12, 0.62), (-0.2, 1.3, 0.16, 0.56)):
        m.dome(g, "Leaves", kind, (x + dx * s, y + dy * s, z + dz * s), (r * s, r * s * 0.5, r * s), sides=8, solid=False)
        m.dome(g, "Leaves", kind, (x + dx * s, y + dy * s, z + dz * s), (r * s, r * s * 0.3, r * s), sides=8, flip=True, solid=False,
               tint=(0.84, 0.84, 0.84))
    return g


def bin_(m, parent, x, z, y=0.0, kind="steel"):
    g = m.group("Bin", parent)
    m.cyl(g, "Bin", kind, (x, y, z), 0.5, 0.85, sides=10)
    m.cyl(g, "BinLid", "frame", (x, y + 0.85, z), 0.56, 0.08, sides=10, solid=False)
    m.cyl(g, "BinBand", "neon_green", (x, y + 0.6, z), 0.53, 0.05, sides=10, solid=False)
    return g


def ceiling_lamp(m, parent, x, y, z, drop=0.5, d=0.6, kind="lamp_warm"):
    """A lamp hanging `drop` under a ceiling at y."""
    m.strip(parent, "LampCord", "frame", (x - 0.015, y - drop, z - 0.015), (x + 0.015, y, z + 0.015))
    m.cone(parent, "LampShade", "frame", (x, y - drop - 0.2, z), d, 0.2, top=d * 0.3, sides=10, solid=False)
    m.cyl(parent, "LampGlow", kind, (x, y - drop - 0.23, z), d * 0.7, 0.03, sides=10, solid=False)


def tube_light(m, parent, lo, hi, y, kind="lamp"):
    """A strip light flat under a ceiling at y, from (x, z) `lo` to `hi`: it breaks with the ceiling."""
    m.strip(parent, "TubeLight", kind, (lo[0], y - 0.05, lo[1]), (hi[0], y, hi[1]))


def poster(m, parent, axis, face, out, u, y, w, h, kind, neon):
    """A framed poster on a wall: a dark board, a block of colour, a pale star, a neon frame."""
    m.on_wall(parent, "Poster", "cab_black", axis, face, out, u - w / 2, u + w / 2, y, y + h, 0.04)
    m.on_wall(parent, "PosterArt", kind, axis, face, out, u - w / 2 + 0.25, u + w / 2 - 0.25, y + 0.25, y + h - 0.25, 0.02, lift=0.04)
    m.on_wall(parent, "PosterStar", "hockey", axis, face, out, u - 0.22, u + 0.22, y + h / 2 - 0.22, y + h / 2 + 0.22, 0.02, lift=0.06)
    for (a, b, c, d) in ((u - w / 2, u + w / 2, y, y + 0.07), (u - w / 2, u + w / 2, y + h - 0.07, y + h),
                         (u - w / 2, u - w / 2 + 0.07, y + 0.07, y + h - 0.07), (u + w / 2 - 0.07, u + w / 2, y + 0.07, y + h - 0.07)):
        m.on_wall(parent, "PosterNeon", neon, axis, face, out, a, b, c, d, 0.03, lift=0.04)


def neon_box(m, parent, axis, face, out, u0, u1, y0, y1, kind, wide=0.08, depth=0.05, lift=0.0, name="Neon"):
    """A rectangle of neon tube on a wall."""
    m.on_wall(parent, name, kind, axis, face, out, u0, u1, y0, y0 + wide, depth, lift=lift)
    m.on_wall(parent, name, kind, axis, face, out, u0, u1, y1 - wide, y1, depth, lift=lift)
    m.on_wall(parent, name, kind, axis, face, out, u0, u0 + wide, y0 + wide, y1 - wide, depth, lift=lift)
    m.on_wall(parent, name, kind, axis, face, out, u1 - wide, u1, y0 + wide, y1 - wide, depth, lift=lift)


def awning(m, parent, axis, face, out, u0, u1, y, reach=1.4, drop=0.5, kind="awning_red", stripe="paper", stripes=0):
    """A sloping cloth awning over a shop front, its top edge on the wall at y."""
    tall = {("x", 1): "-z", ("x", -1): "+z", ("z", 1): "-x", ("z", -1): "+x"}[(axis, out)]
    n = stripes or 1
    for k in range(n):
        a, b = u0 + (u1 - u0) * k / n, u0 + (u1 - u0) * (k + 1) / n
        kind_ = kind if k % 2 == 0 else stripe
        d0, d1 = sorted((face, face + out * reach))
        if axis == "x":
            m.wedge(parent, "Awning", kind_, (a, y - drop, d0), (b, y, d1), tall=tall, solid=False)
            m.strip(parent, "AwningEdge", kind_, (a, y - drop - 0.18, face + out * reach - 0.02), (b, y - drop, face + out * reach + 0.02),
                    tint=(0.85, 0.85, 0.85))
        else:
            m.wedge(parent, "Awning", kind_, (d0, y - drop, a), (d1, y, b), tall=tall, solid=False)
            m.strip(parent, "AwningEdge", kind_, (face + out * reach - 0.02, y - drop - 0.18, a), (face + out * reach + 0.02, y - drop, b),
                    tint=(0.85, 0.85, 0.85))


# -- the street ---------------------------------------------------------------

def car(m, parent, x, z, face, kind, taxi=False):
    """A parked car you can climb on, its nose toward `face`."""
    a = At(m, m.group("Car", parent), (x, 0, z), face)
    a.s("Block", "frame", (-0.9, 0, -2.0), (0.9, 0.3, 2.0), drawn=False)
    a.s("Body", kind, (-0.92, 0.26, -2.15), (0.92, 0.92, 2.15), bevel=0.12)
    a.s("Cabin", "glass_dark", (-0.8, 0.9, -1.35), (0.8, 1.42, 0.75), bevel=0.14)
    a.b("Roof", kind, (-0.74, 1.4, -1.2), (0.74, 1.47, 0.6), bevel=0.03)
    for wz in (-1.35, 1.35):
        a.pipe("Wheel", "tyre", (-0.95, 0.33, wz), (0.95, 0.33, wz), 0.66, sides=10)
        a.pipe("Hub", "chrome", (-0.97, 0.33, wz), (0.97, 0.33, wz), 0.3, sides=8)
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.45, s * 0.8))
        a.b("Headlamp", "lamp", (x0, 0.55, 2.08), (x1, 0.72, 2.17))
        a.b("TailLamp", "beacon", (x0, 0.58, -2.17), (x1, 0.72, -2.08))
    a.b("Bumper", "chrome", (-0.9, 0.3, 2.1), (0.9, 0.44, 2.2))
    a.b("Bumper", "chrome", (-0.9, 0.3, -2.2), (0.9, 0.44, -2.1))
    a.b("Plate", "paper", (-0.25, 0.46, -2.22), (0.25, 0.58, -2.16))
    if taxi:
        a.b("TaxiSign", "neon_yellow", (-0.3, 1.47, -0.45), (0.3, 1.65, -0.2))
        a.b("TaxiBand", "cab_black", (-0.94, 0.56, -1.2), (0.94, 0.66, 1.2))
    return a


def truck(m, parent, x, z, face, kind="car_white"):
    """A box truck, its cab toward `face`: the box is 3.3 m high and can be stood on."""
    a = At(m, m.group("Truck", parent), (x, 0, z), face)
    a.s("Block", "frame", (-1.1, 0, -3.4), (1.1, 0.6, 3.4), drawn=False)
    a.s("Box", kind, (-1.25, 0.9, -3.5), (1.25, 3.3, 1.2))
    a.s("Cab", "car_blue", (-1.15, 0.5, 1.4), (1.15, 2.4, 3.3), bevel=0.14)
    a.b("Chassis", "frame", (-1.0, 0.5, -3.4), (1.0, 0.9, 1.5))
    a.b("Windscreen", "glass_dark", (-1.0, 1.5, 3.2), (1.0, 2.2, 3.34))
    for s in (-1, 1):
        x0, x1 = sorted((s * 1.1, s * 1.18))
        a.b("Window", "glass_dark", (x0, 1.5, 2.0), (x1, 2.15, 3.0))
        xa, xb = sorted((s * 0.5, s * 1.0))
        a.b("Headlamp", "lamp", (xa, 0.8, 3.26), (xb, 1.0, 3.34))
        ta, tb = sorted((s * 0.45, s * 0.9))
        a.b("TailLamp", "beacon", (ta, 0.6, -3.47), (tb, 0.8, -3.38))
    for wz in (-2.4, 2.4):
        a.pipe("Wheel", "tyre", (-1.2, 0.48, wz), (1.2, 0.48, wz), 0.96, sides=10)
    a.b("Shutter", "shutter", (-1.1, 1.0, -3.54), (1.1, 3.1, -3.46))
    a.b("Stripe", "neon_pink", (-1.28, 1.9, -3.4), (1.28, 2.15, 1.1))
    a.b("Bumper", "chrome", (-1.15, 0.5, 3.28), (1.15, 0.72, 3.4))
    return a


def lamp_post(m, parent, x, z, face, height=6.0, kind="lamp", reach=1.6):
    """A street lamp, its arm reaching the way it looks."""
    a = At(m, m.group("StreetLamp", parent), (x, 0, z), face)
    m.cyl(a.g, "Post", "steel", a.pt((0, 0, 0)), 0.2, height, sides=8)
    a.cyl("Foot", "steel", (0, 0, 0), 0.4, 0.5, sides=8)
    a.pipe("Arm", "steel", (0, height - 0.1, 0), (0, height + 0.1, reach), 0.1)
    a.b("Head", "frame", (-0.2, height + 0.02, reach - 0.4), (0.2, height + 0.18, reach + 0.3), bevel=0.04)
    a.b("Lamp", kind, (-0.15, height - 0.03, reach - 0.3), (0.15, height + 0.04, reach + 0.2))
    return a


def traffic_light(m, parent, x, z, face, height=5.2, reach=3.0):
    """A traffic light on a mast with an arm over the road: it shows green the way it looks."""
    a = At(m, m.group("TrafficLight", parent), (x, 0, z), face)
    m.cyl(a.g, "Mast", "steel", a.pt((0, 0, 0)), 0.22, height, sides=8)
    a.pipe("Arm", "steel", (0, height - 0.2, 0), (reach, height - 0.2, 0), 0.12)
    for (dx, y) in ((reach, height - 0.75), (0.0, 2.6)):
        a.b("Head", "frame", (dx - 0.2, y, 0.08), (dx + 0.2, y + 1.1, 0.34), bevel=0.04)
        for k, kind in enumerate(("neon_red", "signal_amber", "signal_green")):
            lit = k == 2
            a.cyl("Light", kind if lit else "frame", (dx, y + 0.78 - k * 0.32, 0.33), 0.2, 0.2, sides=8,
                  tint=None if lit else ((0.9, 0.3, 0.3) if k == 0 else (0.9, 0.7, 0.3)))
    return a


def hydrant(m, parent, x, z):
    g = m.group("Hydrant", parent)
    m.cyl(g, "Body", "hydrant", (x, 0, z), 0.3, 0.6, sides=8)
    m.dome(g, "Cap", "hydrant", (x, 0.6, z), (0.3, 0.16, 0.3), sides=8, solid=False)
    m.cyl(g, "Foot", "hydrant", (x, 0, z), 0.42, 0.08, sides=8, solid=False, tint=(0.8, 0.8, 0.8))
    m.pipe(g, "Outlet", "chrome", (x - 0.24, 0.4, z), (x + 0.24, 0.4, z), 0.14)
    return g


def mailbox(m, parent, x, z, face):
    a = At(m, m.group("Mailbox", parent), (x, 0, z), face)
    a.s("Body", "mailbox", (-0.3, 0.12, -0.28), (0.3, 1.05, 0.28), bevel=0.05)
    a.pipe("Top", "mailbox", (-0.3, 1.05, 0), (0.3, 1.05, 0), 0.56, sides=10)
    a.b("Slot", "frame", (-0.2, 0.9, 0.24), (0.2, 0.97, 0.31))
    a.b("Label", "paper", (-0.18, 0.5, 0.26), (0.18, 0.72, 0.3))
    for s in (-1, 1):
        a.b("Leg", "frame", (s * 0.24 - 0.04, 0, -0.2), (s * 0.24 + 0.04, 0.12, 0.2))
    return a


def news_box(m, parent, x, z, face, kind="cab_red"):
    a = At(m, m.group("NewsBox", parent), (x, 0, z), face)
    a.s("Body", kind, (-0.25, 0, -0.22), (0.25, 1.0, 0.22), bevel=0.04)
    a.b("Window", "paper", (-0.19, 0.45, 0.16), (0.19, 0.9, 0.24))
    a.b("Head", "frame", (-0.25, 0.55, 0.2), (0.25, 0.62, 0.26))
    return a


def bollard(m, parent, x, z, lit="neon_cyan"):
    g = m.group("Bollard", parent)
    m.cyl(g, "Bollard", "steel", (x, 0, z), 0.26, 0.9, sides=8)
    m.cyl(g, "BollardLight", lit, (x, 0.74, z), 0.29, 0.07, sides=8, solid=False)
    return g


def street_tree(m, parent, x, z, kind="leaves", size=1.0, grate=True):
    """A street tree in a square grate."""
    g = m.group("Tree", parent)
    s = size
    if grate:
        m.strip(g, "TreeGrate", "grate", (x - 0.8, 0, z - 0.8), (x + 0.8, 0.03, z + 0.8))
    m.cone(g, "Trunk", "bark", (x, 0, z), 0.5 * s, 3.0 * s, top=0.28 * s, sides=8)
    for i, (dx, dy, dz, r) in enumerate(((0.0, 3.7, 0.0, 1.8), (1.0, 3.1, 0.5, 1.3), (-0.9, 3.2, -0.7, 1.4))):
        tint = (1.0, 1.0, 1.0) if i else (1.08, 1.08, 1.0)
        m.dome(g, "Leaves", kind, (x + dx * s, dy * s, z + dz * s), (2 * r * s, 0.95 * r * s, 2 * r * s), sides=10, solid=False, tint=tint)
        m.dome(g, "Leaves", kind, (x + dx * s, dy * s, z + dz * s), (2 * r * s, 0.6 * r * s, 2 * r * s), sides=10, flip=True, solid=False,
               tint=(0.86, 0.86, 0.86))
    return g


def bench(m, parent, x, z, face, kind="wood_light"):
    """A street bench 2 m long, its back away from the way it looks."""
    a = At(m, m.group("Bench", parent), (x, 0, z), face)
    a.s("Body", kind, (-1.0, 0, -0.25), (1.0, 0.46, 0.25), drawn=False)
    a.b("Seat", kind, (-1.05, 0.38, -0.25), (1.05, 0.46, 0.27), bevel=0.03)
    a.b("Back", kind, (-1.05, 0.6, -0.3), (1.05, 0.98, -0.22), bevel=0.03)
    for dx in (-0.8, 0.8):
        a.b("Leg", "frame", (dx - 0.04, 0, -0.24), (dx + 0.04, 0.38, 0.24))
        a.b("Leg", "frame", (dx - 0.04, 0.38, -0.29), (dx + 0.04, 0.95, -0.23))
    return a


def dumpster(m, parent, x, z, face, kind="dumpster"):
    """A dumpster 2.2 m wide, 1.3 m high: a step up to things."""
    a = At(m, m.group("Dumpster", parent), (x, 0, z), face)
    a.s("Body", kind, (-1.1, 0.1, -0.7), (1.1, 1.25, 0.7))
    a.b("Lid", "frame", (-1.14, 1.25, -0.74), (1.14, 1.33, 0.74), bevel=0.03)
    for s in (-1, 1):
        x0, x1 = sorted((s * 1.1, s * 1.22))
        a.b("Sleeve", kind, (x0, 0.7, -0.4), (x1, 0.9, 0.4), tint=(0.8, 0.8, 0.8))
        for wz in (-0.5, 0.5):
            a.cyl("Wheel", "tyre", (s * 0.9, 0, wz), 0.16, 0.1, sides=6)
    a.b("Rib", kind, (-1.12, 0.6, -0.72), (1.12, 0.68, 0.72), tint=(0.8, 0.8, 0.8))
    return a


def crate(m, parent, x, z, y=0.0, size=1.0, kind="crate"):
    g = m.group("Crate", parent)
    h = size / 2
    m.box(g, "Crate", kind, (x - h, y, z - h), (x + h, y + size, z + h))
    for (lo, hi) in (((x - h - 0.02, y, z - h - 0.02), (x - h + 0.08, y + size + 0.02, z - h + 0.08)),
                     ((x + h - 0.08, y, z - h - 0.02), (x + h + 0.02, y + size + 0.02, z - h + 0.08)),
                     ((x - h - 0.02, y, z + h - 0.08), (x - h + 0.08, y + size + 0.02, z + h + 0.02)),
                     ((x + h - 0.08, y, z + h - 0.08), (x + h + 0.02, y + size + 0.02, z + h + 0.02))):
        m.strip(g, "CrateEdge", "wood", lo, hi)
    return g


def boxes(m, parent, x, z, y=0.0, n=3, kind="cardboard", seed=0):
    """A small pile of cardboard boxes (drawn only)."""
    g = m.group("Boxes", parent)
    for k in range(n):
        s = 0.5 + 0.12 * ((k * 7 + seed) % 3)
        dx = 0.62 * (k % 2) - 0.2 + 0.05 * ((seed + k) % 3)
        dz = 0.18 * ((k * 3 + seed) % 3) - 0.18
        yy = y + (0.56 if k >= 2 else 0.0)
        m.strip(g, "Box", kind, (x + dx - s / 2, yy, z + dz - s / 2), (x + dx + s / 2, yy + s * 0.9, z + dz + s / 2),
                tint=(1.0, 1.0, 1.0) if k % 2 else (0.9, 0.9, 0.9))
        m.strip(g, "BoxTape", "paper", (x + dx - 0.04, yy + s * 0.9, z + dz - s / 2), (x + dx + 0.04, yy + s * 0.9 + 0.01, z + dz + s / 2))
    return g


def pallet(m, parent, x, z, y=0.0, load=None):
    """A pallet, with a wrapped load on it or bare."""
    g = m.group("Pallet", parent)
    m.box(g, "Pallet", "crate", (x - 0.6, y, z - 0.5), (x + 0.6, y + 0.15, z + 0.5), solid=load is None)
    if load:
        m.box(g, "Load", load, (x - 0.55, y + 0.15, z - 0.45), (x + 0.55, y + 1.25, z + 0.45))
        m.strip(g, "Strap", "frame", (x - 0.57, y + 0.7, z - 0.47), (x + 0.57, y + 0.76, z + 0.47))
    return g


def barrier(m, parent, x, z, along="x", wide=2.4):
    """A road-works barrier: striped boards on two legs, with a lamp."""
    a = At(m, m.group("Barrier", parent), (x, 0, z), "+z" if along == "x" else "+x")
    h = wide / 2
    a.s("Body", "hazard", (-h, 0, -0.12), (h, 1.1, 0.12), drawn=False)
    a.b("Board", "hazard", (-h, 0.75, -0.04), (h, 1.05, 0.04))
    a.b("Board", "hazard", (-h, 0.3, -0.04), (h, 0.55, 0.04))
    for s in (-1, 1):
        a.b("Leg", "frame", (s * (h - 0.15) - 0.04, 0, -0.3), (s * (h - 0.15) + 0.04, 1.1, 0.3))
        a.cyl("Lamp", "signal_amber", (s * (h - 0.15), 1.1, 0), 0.16, 0.14, sides=8)
    return a


def traffic_cone(m, parent, x, z):
    g = m.group("Cone", parent)
    m.strip(g, "ConeFoot", "cone", (x - 0.2, 0, z - 0.2), (x + 0.2, 0.04, z + 0.2))
    m.cone(g, "Cone", "cone", (x, 0.04, z), 0.3, 0.56, top=0.06, sides=8, solid=False)
    m.cone(g, "ConeBand", "paint", (x, 0.26, z), 0.22, 0.12, top=0.165, sides=8, solid=False)
    return g


def ac_unit(m, parent, x, z, y, face="+z", size=(2.4, 1.6, 2.0)):
    a = At(m, m.group("ACUnit", parent), (x, y, z), face)
    w, h, d = size
    a.s("Body", "ac_unit", (-w / 2, 0, -d / 2), (w / 2, h, d / 2))
    a.cyl("Fan", "frame", (0, h, 0), min(w, d) * 0.7, 0.04, sides=12)
    a.cyl("FanHub", "steel", (0, h + 0.04, 0), 0.3, 0.06, sides=8)
    a.b("Grille", "truss", (-w / 2 + 0.2, 0.3, d / 2 - 0.02), (w / 2 - 0.2, h - 0.3, d / 2 + 0.04))
    a.pipe("Pipe", "steel", (w / 2, 0.3, -d / 4), (w / 2 + 0.5, 0.3, -d / 4), 0.12)
    return a


def water_tank(m, parent, x, z, y, d=3.2, legs=2.2, h=3.0):
    """A wooden water tank on steel legs, as on old city roofs."""
    g = m.group("WaterTank", parent)
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        m.box(g, "TankLeg", "steel", (x + sx * d * 0.32 - 0.08, y, z + sz * d * 0.32 - 0.08), (x + sx * d * 0.32 + 0.08, y + legs, z + sz * d * 0.32 + 0.08))
    m.strip(g, "TankBrace", "steel", (x - d * 0.36, y + legs * 0.5, z - d * 0.36), (x + d * 0.36, y + legs * 0.5 + 0.08, z + d * 0.36))
    m.cyl(g, "TankDeck", "steel", (x, y + legs, z), d + 0.2, 0.12, sides=12)
    m.cyl(g, "Tank", "tank", (x, y + legs + 0.12, z), d, h, sides=12)
    for k in (0.25, 0.75):
        m.cyl(g, "TankHoop", "frame", (x, y + legs + 0.12 + h * k, z), d + 0.06, 0.08, sides=12, solid=False)
    m.cone(g, "TankRoof", "truss", (x, y + legs + 0.12 + h, z), d + 0.4, 0.9, sides=12, solid=False)
    return g


def lantern(m, parent, x, y, z, kind="lantern", drop=0.3):
    """A paper lantern hanging under y."""
    m.strip(parent, "LanternCord", "frame", (x - 0.01, y - drop, z - 0.01), (x + 0.01, y, z + 0.01))
    m.dome(parent, "Lantern", kind, (x, y - drop - 0.2, z), (0.36, 0.2, 0.36), sides=8, solid=False)
    m.dome(parent, "Lantern", kind, (x, y - drop - 0.2, z), (0.36, 0.2, 0.36), sides=8, flip=True, solid=False)
    m.cyl(parent, "LanternCap", "frame", (x, y - drop - 0.02, z), 0.14, 0.04, sides=6, solid=False)


def flight(m, g, name, a, b, width, kind="grate"):
    """An open steel stair from `a` up to `b` (along x or along z): a ramp to walk, treads,
    two stringers and handrails to see."""
    f = m.group(name, g)
    m.slab(f, "Ramp", kind, a, b, width, thick=0.2, drawn=False)
    along_z = abs(b[2] - a[2]) >= abs(b[0] - a[0])
    n = int(math.ceil(abs(b[1] - a[1]) / 0.25 - 1e-6))
    for i in range(n):
        t = (i + 0.5) / n
        y = a[1] + (b[1] - a[1]) * (i + 1) / n
        if along_z:
            z = a[2] + (b[2] - a[2]) * t
            d = abs(b[2] - a[2]) / n * 0.5
            m.strip(f, "Tread", kind, (a[0] - width / 2, y - 0.06, z - d), (a[0] + width / 2, y, z + d))
        else:
            x = a[0] + (b[0] - a[0]) * t
            d = abs(b[0] - a[0]) / n * 0.5
            m.strip(f, "Tread", kind, (x - d, y - 0.06, a[2] - width / 2), (x + d, y, a[2] + width / 2))
    for s in (-1, 1):
        off = s * (width / 2 + 0.04)
        shift = (lambda p, dy: (p[0] + off, p[1] + dy, p[2])) if along_z else (lambda p, dy: (p[0], p[1] + dy, p[2] + off))
        m.rod(f, "Stringer", "truss", shift(a, -0.12), shift(b, -0.12), thick=0.24, wide=0.07)
        m.rod(f, "Handrail", "steel", shift(a, 1.0), shift(b, 1.0), thick=0.06)
        for t in (0.03, 0.34, 0.66, 0.97):
            p = shift(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)), 0.0)
            m.strip(f, "RailPost", "steel", (p[0] - 0.03, p[1], p[2] - 0.03), (p[0] + 0.03, p[1] + 1.03, p[2] + 0.03))
    return f


def fence(m, g, a, b, height=2.8, kind="container", name="Fence"):
    """A solid fence of corrugated sheet from (x, z) `a` to `b`, with posts and a top rail."""
    along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
    c0, c1 = sorted((a[0], b[0])) if along_x else sorted((a[1], b[1]))
    line = a[1] if along_x else a[0]
    if along_x:
        m.box(g, name, kind, (c0, 0, line - 0.08), (c1, height, line + 0.08))
        m.strip(g, name + "Rail", "steel", (c0, height, line - 0.12), (c1, height + 0.1, line + 0.12))
    else:
        m.box(g, name, kind, (line - 0.08, 0, c0), (line + 0.08, height, c1))
        m.strip(g, name + "Rail", "steel", (line - 0.12, height, c0), (line + 0.12, height + 0.1, c1))
    n = max(1, int(round((c1 - c0) / 4.0)))
    for k in range(n + 1):
        c = c0 + (c1 - c0) * k / n
        if along_x:
            m.strip(g, name + "Post", "steel", (c - 0.1, 0, line - 0.14), (c + 0.1, height + 0.1, line + 0.14))
        else:
            m.strip(g, name + "Post", "steel", (line - 0.14, 0, c - 0.1), (line + 0.14, height + 0.1, c + 0.1))


# -- more to look at ------------------------------------------------------------

ART = {
    "heart": ("0110110", "1111111", "1111111", "0111110", "0011100", "0001000"),
    "bolt": ("00111", "01110", "11100", "11111", "00111", "01110", "11100", "10000"),
    "star": ("0001000", "0001000", "1111111", "0111110", "0011100", "0110110", "1100011"),
    "arrow": ("00100", "01110", "11111", "00100", "00100", "00100"),
    "note": ("00111", "00101", "00100", "00100", "01100", "11100", "01000"),
}


def pixel_art(m, parent, axis, face, out, mid, y0, px, art, kind, depth=0.05, lift=0.0, name="Pixel"):
    """A picture in big square dots on a wall (see on_wall), read from the side the wall
    faces: runs of dots along a row are one piece."""
    rows = ART[art]
    w, h = len(rows[0]), len(rows)
    way = (1 if out > 0 else -1) if axis == "x" else (-1 if out > 0 else 1)
    for r, row in enumerate(rows):
        c = 0
        while c < w:
            if row[c] != "1":
                c += 1
                continue
            c1 = c
            while c1 < w and row[c1] == "1":
                c1 += 1
            ua, ub = sorted((mid + way * (c - w / 2.0) * px, mid + way * (c1 - w / 2.0) * px))
            m.on_wall(parent, name, kind, axis, face, out, ua, ub, y0 + (h - r - 1) * px, y0 + (h - r) * px, depth, lift=lift)
            c = c1
    return w * px, h * px


def blade_sign(m, parent, axis, face, out, u, y0, text, kind, px=0.09, board="cab_black", edge=None, name="BladeSign"):
    """A sign standing out from a wall like a blade, its letters one under the other on
    both sides: read from either way along the street."""
    g = m.group(name, parent)
    wide = 9 * px                       # the board, out from the wall
    step = 8.4 * px
    high = len(text) * step + 0.6 * px
    near, far = face + out * 0.3, face + out * (0.3 + wide)
    d0, d1 = sorted((near, far))
    mid = (near + far) / 2
    if axis == "x":
        m.strip(g, "Board", board, (u - 0.07, y0, d0), (u + 0.07, y0 + high, d1))
        if edge:
            e0, e1 = sorted((far, far + out * 0.05))
            m.strip(g, "Edge", edge, (u - 0.1, y0 - 0.04, e0), (u + 0.1, y0 + high + 0.04, e1))
        for y in (y0 + 0.3, y0 + high - 0.3):
            w0, w1 = sorted((face, near))
            m.strip(g, "Bracket", "steel", (u - 0.03, y - 0.03, w0), (u + 0.03, y + 0.03, w1))
    else:
        m.strip(g, "Board", board, (d0, y0, u - 0.07), (d1, y0 + high, u + 0.07))
        if edge:
            e0, e1 = sorted((far, far + out * 0.05))
            m.strip(g, "Edge", edge, (e0, y0 - 0.04, u - 0.1), (e1, y0 + high + 0.04, u + 0.1))
        for y in (y0 + 0.3, y0 + high - 0.3):
            w0, w1 = sorted((face, near))
            m.strip(g, "Bracket", "steel", (w0, y - 0.03, u - 0.03), (w1, y + 0.03, u + 0.03))
    other = "z" if axis == "x" else "x"
    for k, ch in enumerate(text):
        if ch == " ":
            continue
        y = y0 + high - (k + 1) * step + 0.7 * px
        for s in (-1, 1):
            m.text(g, ch, other, u + s * 0.07, s, mid, y, px, kind, depth=0.04)
    return g


def wall_lamp(m, parent, axis, face, out, u, y, kind="lamp_warm"):
    """A bulkhead lamp over a door."""
    m.on_wall(parent, "WallLamp", "frame", axis, face, out, u - 0.22, u + 0.22, y, y + 0.12, 0.32)
    m.on_wall(parent, "WallLampGlow", kind, axis, face, out, u - 0.15, u + 0.15, y - 0.06, y, 0.2, lift=0.07)


def drainpipe(m, parent, axis, face, out, u, y0, y1):
    """A downpipe on a wall, with a hopper at its head and straps down it."""
    c = face + out * 0.13
    a, b = ((u, y0, c), (u, y1, c)) if axis == "x" else ((c, y0, u), (c, y1, u))
    m.pipe(parent, "Drainpipe", "steel", a, b, 0.14, sides=6)
    m.on_wall(parent, "DrainHopper", "steel", axis, face, out, u - 0.16, u + 0.16, y1 - 0.02, y1 + 0.26, 0.3, tint=(0.85, 0.85, 0.85))
    y = y0 + 1.2
    while y < y1 - 0.6:
        m.on_wall(parent, "DrainStrap", "frame", axis, face, out, u - 0.12, u + 0.12, y, y + 0.06, 0.23)
        y += 2.4


def wall_vent(m, parent, axis, face, out, u, y, w=1.2, h=0.8):
    m.on_wall(parent, "Vent", "grate", axis, face, out, u - w / 2, u + w / 2, y, y + h, 0.08)
    n = int(h / 0.2)
    for k in range(n):
        yy = y + 0.1 + k * (h - 0.2) / max(1, n - 1)
        m.on_wall(parent, "VentSlat", "frame", axis, face, out, u - w / 2 + 0.08, u + w / 2 - 0.08, yy - 0.03, yy + 0.03, 0.03, lift=0.08)


def bike(m, parent, x, z, face, kind="cab_red"):
    """A bicycle standing along the way it looks (drawn only)."""
    a = At(m, m.group("Bike", parent), (x, 0, z), face)
    for wz in (-0.52, 0.52):
        a.pipe("Wheel", "tyre", (-0.04, 0.35, wz), (0.04, 0.35, wz), 0.7, sides=12, inner=0.6)
        a.pipe("Hub", "chrome", (-0.06, 0.35, wz), (0.06, 0.35, wz), 0.08, sides=6)
    pts = {"rear": (0, 0.35, -0.52), "seat": (0, 0.86, -0.22), "bb": (0, 0.34, -0.02), "head": (0, 0.88, 0.34), "front": (0, 0.35, 0.52)}
    for (p, q) in (("rear", "seat"), ("seat", "bb"), ("bb", "rear"), ("bb", "head"), ("seat", "head"), ("head", "front")):
        m.rod(a.g, "Frame", kind, a.pt(pts[p]), a.pt(pts[q]), thick=0.04)
    a.b("Saddle", "cab_black", (-0.07, 0.88, -0.36), (0.07, 0.94, -0.1))
    a.b("Bars", "chrome", (-0.26, 0.98, 0.3), (0.26, 1.02, 0.36))
    m.rod(a.g, "Stem", "chrome", a.pt((0, 0.86, 0.34)), a.pt((0, 1.0, 0.33)), thick=0.035)
    return a


def parking_meter(m, parent, x, z):
    g = m.group("ParkingMeter", parent)
    m.cyl(g, "Post", "steel", (x, 0, z), 0.1, 1.1, sides=6)
    m.bev(g, "Head", "frame", (x - 0.12, 1.1, z - 0.09), (x + 0.12, 1.45, z + 0.09), 0.04, solid=False)
    m.strip(g, "Dial", "screen_green", (x - 0.08, 1.24, z - 0.1), (x + 0.08, 1.38, z + 0.1))
    return g


def utility_pole(m, parent, x, z, height=9.0, along="z"):
    """A wooden pole with a cross-arm for wires and a transformer drum."""
    g = m.group("UtilityPole", parent)
    m.cyl(g, "Pole", "bark", (x, 0, z), 0.3, height, sides=8)
    for (y, half) in ((height - 0.5, 1.1), (height - 1.3, 0.8)):
        lo, hi = ((x - 0.07, y, z - half), (x + 0.07, y + 0.14, z + half)) if along == "x" else ((x - half, y, z - 0.07), (x + half, y + 0.14, z + 0.07))
        m.strip(g, "CrossArm", "wood", lo, hi)
        for s in (-1, 1):
            p = (x, y + 0.14, z + s * (half - 0.12)) if along == "x" else (x + s * (half - 0.12), y + 0.14, z)
            m.cyl(g, "Insulator", "bowl", p, 0.1, 0.14, sides=6, solid=False)
    off = (0.34, 0) if along == "z" else (0, 0.34)
    m.cyl(g, "Transformer", "ac_unit", (x + off[0], height - 2.9, z + off[1]), 0.5, 0.9, sides=8, solid=False)
    return g


def wire(m, parent, a, b, sag=0.5, name="Wire"):
    """A wire from a to b, hanging a little in the middle."""
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - sag, (a[2] + b[2]) / 2)
    m.rod(parent, name, "frame", a, mid, thick=0.03)
    m.rod(parent, name, "frame", mid, b, thick=0.03)


def sign_board(m, parent, x, z, face, text, kind="neon_yellow", px=0.03, board="cab_black"):
    """A pavement sign on two feet, written on both sides."""
    a = At(m, m.group("SignBoard", parent), (x, 0, z), face)
    a.b("Board", board, (-0.36, 0.2, -0.03), (0.36, 1.1, 0.03))
    for sx in (-0.3, 0.3):
        a.b("Foot", "steel", (sx - 0.025, 0, -0.2), (sx + 0.025, 0.2, 0.2))
    axis, out = AXIS_OF[face]
    for s in (1, -1):
        p = a.pt((0, 0, 0.03 * s))
        m.text(a.g, text, axis, p[2] if axis == "x" else p[0], out * s, p[0] if axis == "x" else p[2], 0.55, px, kind, depth=0.02)
        f0, f1 = p[2] if axis == "x" else p[0], p[0] if axis == "x" else p[2]
        m.on_wall(a.g, "Bar", kind, axis, f0, out * s, f1 - 0.28, f1 + 0.28, 0.32, 0.38, 0.02)
    return a


def phone_booth(m, parent, x, z, face):
    """A phone box: glass on three sides that breaks, open at its front."""
    a = At(m, m.group("PhoneBooth", parent), (x, 0, z), face)
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        a.s("Post", "cab_blue", (sx * 0.5 - 0.04, 0, sz * 0.5 - 0.04), (sx * 0.5 + 0.04, 2.3, sz * 0.5 + 0.04))
    a.s("Roof", "cab_blue", (-0.58, 2.3, -0.58), (0.58, 2.5, 0.58))
    a.b("Sign", "neon_cyan", (-0.45, 2.5, -0.45), (0.45, 2.64, 0.45))
    a.b("Phone", "cab_black", (-0.2, 1.0, -0.44), (0.2, 1.6, -0.3))
    a.b("PhoneScreen", "screen_green", (-0.12, 1.36, -0.3), (0.12, 1.52, -0.28))
    a.b("Shelf", "steel", (-0.3, 0.9, -0.46), (0.3, 0.94, -0.2))
    axis, out = AXIS_OF[face]
    back = a.pt((0, 0, -0.5))
    left, right = a.pt((-0.5, 0, 0)), a.pt((0.5, 0, 0))
    if axis == "x":      # it looks along z: its back is a pane along x, its sides along z
        m.pane(a.g, "glass", "x", back[2], x - 0.46, x + 0.46, 0.15, 2.18, name="BoothGlass", thick=0.06)
        for p in (left, right):
            m.pane(a.g, "glass", "z", p[0], z - 0.46, z + 0.46, 0.15, 2.18, name="BoothGlass", thick=0.06)
    else:
        m.pane(a.g, "glass", "z", back[0], z - 0.46, z + 0.46, 0.15, 2.18, name="BoothGlass", thick=0.06)
        for p in (left, right):
            m.pane(a.g, "glass", "x", p[2], x - 0.46, x + 0.46, 0.15, 2.18, name="BoothGlass", thick=0.06)
    return a


def ceiling_fan(m, parent, x, y, z, d=1.8):
    g = m.group("CeilingFan", parent)
    m.strip(g, "FanRod", "steel", (x - 0.02, y - 0.4, z - 0.02), (x + 0.02, y, z + 0.02))
    m.cyl(g, "FanHub", "chrome", (x, y - 0.5, z), 0.24, 0.1, sides=8, solid=False)
    m.strip(g, "FanBlade", "wood", (x - d / 2, y - 0.46, z - 0.08), (x + d / 2, y - 0.44, z + 0.08))
    m.strip(g, "FanBlade", "wood", (x - 0.08, y - 0.48, z - d / 2), (x + 0.08, y - 0.46, z + d / 2))
    m.dome(g, "FanLamp", "lamp_warm", (x, y - 0.5, z), (0.22, 0.12, 0.22), sides=8, flip=True, solid=False)
    return g


def deck_chair(m, parent, x, z, face, y=0.0, kind="awning_teal"):
    a = At(m, m.group("DeckChair", parent), (x, y, z), face)
    a.s("Seat", kind, (-0.32, 0.25, -0.3), (0.32, 0.33, 0.7))
    a.wedge("Back", kind, (-0.32, 0.33, -0.75), (0.32, 0.95, -0.3), tall="-z")
    for (sx, sz) in ((-1, -0.25), (1, -0.25), (-1, 0.6), (1, 0.6)):
        a.b("Leg", "wood_light", (sx * 0.3 - 0.025, 0, sz - 0.025), (sx * 0.3 + 0.025, 0.25, sz + 0.025))
    return a


def dish(m, parent, x, z, y, face="+z", d=1.4):
    """A satellite dish on a short mast."""
    a = At(m, m.group("Dish", parent), (x, y, z), face)
    m.cyl(a.g, "Mast", "steel", a.pt((0, 0, 0)), 0.1, 1.0, sides=6)
    a.dome("Dish", "ac_unit", (0, 1.0, 0), (d, d * 0.25, d), sides=12, flip=True)
    m.rod(a.g, "Feed", "steel", a.pt((0, 1.0, 0)), a.pt((0, 1.55, 0.3)), thick=0.04)
    a.ball("FeedHorn", "frame", (0, 1.6, 0.32), 0.14, sides=6)
    return a


def weeds(m, parent, spots, kind="leaves"):
    g = m.group("Weeds", parent)
    for k, (x, z) in enumerate(spots):
        m.cone(g, "Weed", kind, (x, 0, z), 0.28 + 0.06 * (k % 3), 0.3 + 0.1 * (k % 2), sides=5, solid=False,
               tint=(1, 1, 1) if k % 2 else (0.85, 0.9, 0.85))
    return g
