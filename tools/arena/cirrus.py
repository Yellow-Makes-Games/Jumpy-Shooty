"""Cirrus: a university campus on floating islands (about 110 x 110 m, up to 16 players).

    python3 tools/arena/build_arena_maps.py cirrus

writes game/maps/cirrus.tscn and game/maps/palettes/cirrus.tres FROM SCRATCH. The scene is
an ordinary map scene and is what people edit afterwards (in the Godot editor), so running
this again OVERWRITES ANY HAND EDITS: only do it to rebuild the whole map on purpose.

Layout: the Quad, a round lawn in the middle with the clock tower on it, and five
building islands round it, each a MapIsland: Observatory (north), Labs (north-east),
Lecture Hall (south-east), Cafeteria (south-west) and Library (north-west). All five
are one island shape (a fan: narrow toward the quad, a wide deck behind with the
building on it) with a different building. There is no writing anywhere: each building
is told by its colour and its shape (a dome, glass and roof stacks, a shell roof, a
striped awning, a columned front).

Two layouts, changed by the clock (the LayoutEvent "Layout": every 60 s the bell goes,
five seconds later the islands move):
  Hub   every island level with the quad, 16 m of open sky between neighbours, and a
        skyway (a MapSpan fixed to the quad) from the quad to each island.
  Ring  every island swung 36 degrees round the quad, pulled 5 m in and sunk 15 m: the
        gaps between neighbours close to 10 m and a bridge (two MapSpans, one from
        each island) joins them into a loop. The skyways are drawn in, and the quad
        stands 15 m above the ring: only the grapple gets you up there.

The numbers behind the gaps (measured with the real movement code): a sprinting jump
clears 7.5 m, with a dive 12.5 m, with a flip 14 m; the rocket boots carry a jump 32 m on
the level and at most 10.5 m up (12.8 m with a ledge grab). So 16 m between neighbours is
beyond a jump and easy for the boots or the grapple, and 15 m is higher than the boots
reach from the ring's decks and bridges.

The look: nothing stepped or stacked. Roofs are slopes, cones and domes (MapBlock's
wedge, cone and dome shapes), furniture and trims are bevelled, stairs are closed in
by sloping sides, trees are round clumps.

Angles in this file are measured the way a node's yaw is: 0 = south (+z), 90 = east,
180 = north, 270 = west. An island is built in its own frame: -z toward the quad, +z
outward, y = 0 its deck.
"""
import math
from arena_builder import Map, yaw_cols, xform, fmt, vec, color, norm, cross, IDENTITY

PAL = "res://game/maps/palettes/cirrus.tres"
SKY = "res://game/maps/sky/cirrus_sky.gdshader"

# The islands: (name, angle in the Hub layout, accent kind, roof kind)
ISLANDS = [
    ("Observatory", 180.0, "accent_purple", "roof_slate"),
    ("Labs", 108.0, "accent_teal", "roof_slate"),
    ("LectureHall", 36.0, "accent_red", "roof_terracotta"),
    ("Cafeteria", 324.0, "accent_orange", "roof_terracotta"),
    ("Library", 252.0, "accent_blue", "roof_terracotta"),
]
R0 = 38.5          # an island's own origin is this far from the middle (Hub)
SWING = 36.0       # Ring: degrees round the quad...
PULL = 5.0         # ...metres in...
DROP = 15.0        # ...and metres down
QUAD_R = 14.3
TIP = 22.3         # the tip of an island's deck, metres from the middle (Hub)
STONE_R = 19.0     # the stepping stones' middles
MAST_R = 12.8
SIN36, COS36 = math.sin(math.radians(36.0)), math.cos(math.radians(36.0))


def edge_x(z):
    """How far out an island's deck may reach at its own z: its side edges are the lines
    8 m from the half-way lines to its neighbours, so the gap between two islands is 16 m
    all the way along."""
    return ((z + R0) * SIN36 - 8.0) / COS36


# An island's deck: a fan from its tip (ZT, half as wide as WT) to its shoulders (ZS,
# WS), then the main deck, as wide as the shoulders, back to MAIN_Z1.
ZT = TIP - R0
ZS = -2.0
WT = edge_x(ZT)
WS = edge_x(ZS)
MAIN_Z1 = 14.2
EDGE_LEN = (ZS - ZT) / COS36     # along a side edge of the fan, tip to shoulder
BRIDGE_DIR = (COS36, -SIN36)     # (x, z), for the +x side: square to the half-way line
BRIDGE_LEN = 4.99                # to the line half way to the neighbour, in the Ring layout
BRIDGE_W = 3.8
SKYWAY_W = 4.6
F2 = 5.5           # first upper floor
F3 = 11.0
RUN = 9.2          # metres a stair takes to climb one floor (31 degrees)

FLIP = ((1, 0, 0), (0, -1, 0), (0, 0, -1))     # upside down
LIE_Z = ((1, 0, 0), (0, 0, 1), (0, -1, 0))     # its own y along world z
LIE_X = ((0, -1, 0), (1, 0, 0), (0, 0, 1))     # its own y along world x
TURN = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))      # its own x along world z (a quarter turn)

COLORS = {
    # buildings
    "stone": (0.9, 0.84, 0.72), "stone_warm": (0.83, 0.72, 0.56), "stone_dark": (0.62, 0.55, 0.46),
    "column": (0.95, 0.91, 0.82), "trim": (0.74, 0.5, 0.24), "brass": (0.82, 0.64, 0.28), "metal": (0.3, 0.29, 0.31),
    "roof_terracotta": (0.72, 0.36, 0.24), "roof_slate": (0.34, 0.39, 0.46), "dome_copper": (0.4, 0.66, 0.6),
    "floor_wood": (0.6, 0.44, 0.3), "floor_tile": (0.82, 0.8, 0.75), "stair": (0.66, 0.6, 0.52), "stair_tread": (0.8, 0.75, 0.66),
    "rail": (0.66, 0.5, 0.26),
    # one accent per building
    "accent_purple": (0.5, 0.36, 0.78), "accent_teal": (0.14, 0.66, 0.68), "accent_red": (0.74, 0.2, 0.2),
    "accent_orange": (0.93, 0.52, 0.12), "accent_blue": (0.2, 0.36, 0.74),
    # ground
    "paving": (0.8, 0.74, 0.64), "path": (0.86, 0.8, 0.68), "lawn": (0.42, 0.62, 0.26),
    "hedge": (0.26, 0.46, 0.2), "leaves": (0.34, 0.58, 0.24), "leaves_gold": (0.8, 0.62, 0.2), "bark": (0.4, 0.29, 0.2),
    "rock": (0.56, 0.48, 0.4), "rock_dark": (0.4, 0.34, 0.3), "planter": (0.76, 0.7, 0.6), "soil": (0.34, 0.25, 0.18),
    # walkways
    "bridge_deck": (0.5, 0.48, 0.47), "span_light": (1.0, 0.7, 0.2), "mast": (0.36, 0.33, 0.32),
    # light
    "engine": (0.3, 0.9, 1.0), "engine_ring": (0.6, 0.42, 0.24), "lamp": (1.0, 0.86, 0.6),
    "window_lit": (1.0, 0.8, 0.45), "screen": (0.62, 0.8, 1.0), "bell": (0.86, 0.64, 0.24),
    "clock_face": (0.96, 0.93, 0.84), "clock_hand": (0.16, 0.15, 0.17),
    # glass: only glass_lab breaks
    "glass_lab": (0.62, 0.95, 0.96, 0.32), "glass_window": (0.75, 0.88, 1.0, 0.2), "glass_sky": (0.8, 0.92, 1.0, 0.16),
    # things
    "shelf": (0.42, 0.29, 0.2), "books_red": (0.62, 0.2, 0.18), "books_blue": (0.2, 0.32, 0.56), "books_green": (0.24, 0.44, 0.3),
    "books_gold": (0.78, 0.62, 0.3), "table": (0.68, 0.52, 0.36), "seat": (0.56, 0.18, 0.2), "counter": (0.78, 0.76, 0.72),
    "equipment": (0.55, 0.58, 0.62), "equipment_dark": (0.26, 0.28, 0.32), "telescope": (0.93, 0.93, 0.9),
    "statue": (0.36, 0.52, 0.46), "kiosk": (0.82, 0.3, 0.26), "banner_gold": (0.92, 0.72, 0.2), "banner_red": (0.72, 0.18, 0.2),
    "banner_blue": (0.2, 0.34, 0.7), "awning": (0.95, 0.92, 0.84),
}
GLOW = {"engine": 2.2, "lamp": 0.35, "window_lit": 0.2, "span_light": 2.4, "screen": 1.3, "clock_face": 0.5}
# The game's usual patterns, drawn twice the size and under half as strong (see
# write_palette): the walls read as walls, not as a grid of cubes.
SURFACE = {
    "stone": "blocks", "stone_warm": "blocks", "stone_dark": "blocks", "paving": "slabs", "path": "slabs",
    "lawn": "grass", "hedge": "clumps", "leaves": "clumps", "leaves_gold": "clumps", "bark": "bark", "rock": "strata",
    "rock_dark": "strata", "roof_terracotta": "shingles", "roof_slate": "shingles", "floor_wood": "planks",
    "floor_tile": "tiles", "bridge_deck": "plates", "soil": "dirt",
}
SURFACE_SCALE = 2.0
SURFACE_STRENGTH = 0.45
MATERIAL = {
    "lawn": "dirt", "soil": "dirt", "hedge": "dirt", "leaves": "dirt", "leaves_gold": "dirt", "floor_wood": "wood",
    "shelf": "wood", "table": "wood", "bark": "wood", "bridge_deck": "metal", "rail": "metal", "mast": "metal",
    "brass": "metal", "bell": "metal", "equipment": "metal", "equipment_dark": "metal", "telescope": "metal",
    "statue": "metal", "dome_copper": "metal", "glass_lab": "glass", "glass_window": "glass", "glass_sky": "glass",
}
BREAKABLE = {"glass_lab": 25}   # the labs' glass walls: a pistol shot shatters a pane. No other glass breaks.


def polar(r, deg, y=0.0):
    th = math.radians(deg)
    return (r * math.sin(th), y, r * math.cos(th))


def rot(deg):
    return yaw_cols(math.radians(deg))


class CirrusMap(Map):
    """arena_builder's Map with what only this map needs: nodes with other scripts (the
    islands, the walkways, the layout event, grapple points, bots' crossings), the
    shapes that are not boxes, and a sky made by a shader."""

    EXTRA = {
        "island": "res://game/arena/map_island.gd",
        "span": "res://game/arena/map_span.gd",
        "layout": "res://game/arena/layout_event.gd",
        "spinner": "res://game/arena/map_spinner.gd",
        "hook": "res://game/arena/map_grapple_point.gd",
        "link": "res://game/arena/map_jump_link.gd",
    }

    def node(self, name, parent, script, props, type_="Node3D", group=False):
        return self._add(name, type_, parent, props, script, group)

    def spawn_in(self, parent, pos, toward):
        """A spawn point inside a group (an island): pos and toward are in the group's frame."""
        self.spawn_count += 1
        yaw = math.atan2(-(toward[0] - pos[0]), -(toward[1] - pos[2]))
        self._add("Spawn%d" % self.spawn_count, "Marker3D", parent, [("transform", xform(yaw_cols(yaw), pos))], "spawn", False)

    def weapon_in(self, parent, pos, weapon):
        self.weapon_count += 1
        props = [("transform", xform(IDENTITY, pos)), ("weapon", '"%s"' % weapon)]
        self._add(weapon.title().replace("_", ""), "Marker3D", parent, props, "weapon", False)

    # -- shapes that are not boxes ---------------------------------------------
    def bev(self, parent, name, kind, lo, hi, bevel=0.08, **kw):
        """A box from corner `lo` to corner `hi` with its edges cut off."""
        c = tuple((a + b) * 0.5 for a, b in zip(lo, hi))
        s = tuple(abs(b - a) for a, b in zip(lo, hi))
        return self.block(parent, name, kind, c, s, shape="bevel", bevel=min(bevel, min(s) * 0.45), **kw)

    def dome(self, parent, name, kind, base, size, sides=12, flip=False, yaw=0.0, **kw):
        """Half a ball standing on `base` (the middle of its flat side), size (x, y, z);
        `flip`: hanging under `base` instead."""
        c = (base[0], base[1] + (-size[1] if flip else size[1]) * 0.5, base[2])
        cols = FLIP if flip else (yaw_cols(math.radians(yaw)) if yaw else IDENTITY)
        return self.block(parent, name, kind, c, size, cols=cols, shape="dome", sides=sides, **kw)

    def cone(self, parent, name, kind, base, diameter, height, top=0.0, sides=12, flip=False, yaw=0.0, **kw):
        """A cone standing on `base` (or, flipped, hanging under it: wide at `base`)."""
        c = (base[0], base[1] + (-height if flip else height) * 0.5, base[2])
        cols = FLIP if flip else (yaw_cols(math.radians(yaw)) if yaw else IDENTITY)
        return self.block(parent, name, kind, c, (diameter, height, diameter), cols=cols, shape="cone", sides=sides, top=top, **kw)

    def wedge(self, parent, name, kind, lo, hi, tall="-z", **kw):
        """A slope filling the box `lo`..`hi`, its tall side toward `tall` (-z, +z, -x or +x)."""
        c = tuple((a + b) * 0.5 for a, b in zip(lo, hi))
        dx, dy, dz = (abs(b - a) for a, b in zip(lo, hi))
        cols, size = {
            "-z": (IDENTITY, (dx, dy, dz)),
            "+z": (((-1, 0, 0), (0, 1, 0), (0, 0, -1)), (dx, dy, dz)),
            "+x": (((0, 0, 1), (0, 1, 0), (-1, 0, 0)), (dz, dy, dx)),
            "-x": (((0, 0, -1), (0, 1, 0), (1, 0, 0)), (dz, dy, dx)),
        }[tall]
        return self.block(parent, name, kind, c, size, cols=cols, shape="wedge", **kw)

    def tri(self, parent, name, kind, corner, leg_x, leg_z, y0, y1, **kw):
        """A right triangle seen from above (a wedge lying on its side): the right angle at
        `corner` (x, z), one leg `leg_x` long along x and the other `leg_z` along z (each
        may be negative), from height y0 to y1."""
        sx = 1.0 if leg_x > 0 else -1.0
        sz = 1.0 if leg_z > 0 else -1.0
        cols = ((0, -sx * sz, 0), (sx, 0, 0), (0, 0, sz))
        c = (corner[0] + leg_x * 0.5, (y0 + y1) * 0.5, corner[1] + leg_z * 0.5)
        return self.block(parent, name, kind, c, (y1 - y0, abs(leg_x), abs(leg_z)), cols=cols, shape="wedge", **kw)

    def rail_box(self, parent, lo, hi):
        """A railing filling the box lo..hi (1 m high, thin one way): two brass bars and
        a post at each end to look at, and an invisible solid panel to lean on."""
        self.box(parent, "RailPanel", "rail", lo, hi, drawn=False)
        along_x = (hi[0] - lo[0]) >= (hi[2] - lo[2])
        y0, y1 = lo[1], hi[1]
        for name, a, b in (("RailTop", y1 - 0.09, y1), ("RailBar", y0 + 0.42, y0 + 0.5)):
            self.strip(parent, name, "rail", (lo[0], a, lo[2]), (hi[0], b, hi[2]))
        length = (hi[0] - lo[0]) if along_x else (hi[2] - lo[2])
        count = max(2, int(round(length / 2.2)) + 1)
        for i in range(count):
            u = i / (count - 1)
            if along_x:
                x = lo[0] + 0.05 + (length - 0.1) * u
                self.strip(parent, "RailPost", "metal", (x - 0.05, y0, lo[2] - 0.01), (x + 0.05, y1 - 0.09, hi[2] + 0.01))
            else:
                z = lo[2] + 0.05 + (length - 0.1) * u
                self.strip(parent, "RailPost", "metal", (lo[0] - 0.01, y0, z - 0.05), (hi[0] + 0.01, y1 - 0.09, z + 0.05))

    def rail(self, parent, name, kind, a, b, y, height=1.1, thick=0.12, holes=(), **kw):
        """Brass railings ("rail") are drawn as bars; anything else is a low wall, as in arena_builder."""
        if kind != "rail":
            return Map.rail(self, parent, name, kind, a, b, y, height, thick, holes, **kw)
        along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
        length = abs(b[0] - a[0]) if along_x else abs(b[1] - a[1])
        start = min(a[0], b[0]) if along_x else min(a[1], b[1])
        line = a[1] if along_x else a[0]
        u = 0.0
        runs = []
        for h0, h1 in sorted(holes):
            if h0 - u > 0.05:
                runs.append((u, h0))
            u = h1
        if length - u > 0.05:
            runs.append((u, length))
        for u0, u1 in runs:
            if along_x:
                self.rail_box(parent, (start + u0, y, line - thick / 2), (start + u1, y + height, line + thick / 2))
            else:
                self.rail_box(parent, (line - thick / 2, y, start + u0), (line + thick / 2, y + height, start + u1))

    def write(self, path):
        scripts = dict(__import__("arena_builder").SCRIPTS)
        scripts.update(self.EXTRA)
        ids = {}
        out = ["[gd_scene format=3]", ""]
        for i, (k, p) in enumerate(scripts.items()):
            ids[k] = "%d_%s" % (i + 1, k)
            out.append('[ext_resource type="Script" path="%s" id="%s"]' % (p, ids[k]))
        out.append('[ext_resource type="Resource" path="%s" id="pal"]' % self.palette)
        out.append('[ext_resource type="Shader" path="%s" id="sky"]' % SKY)
        elev, azim, col, energy = self.sun
        e, az = math.radians(elev), math.radians(azim)
        Z = norm((math.sin(az) * math.cos(e), math.sin(e), -math.cos(az) * math.cos(e)))
        X = norm(cross((0, 1, 0), Z))
        out += ["", '[sub_resource type="ShaderMaterial" id="ShaderMaterial_sky"]', 'shader = ExtResource("sky")',
                "shader_parameter/sun_dir = %s" % vec(Z), "",
                '[sub_resource type="Sky" id="Sky_1"]', 'sky_material = SubResource("ShaderMaterial_sky")', "",
                '[sub_resource type="Environment" id="Environment_1"]', "background_mode = 2", 'sky = SubResource("Sky_1")']
        out += self.env["lines"]
        out += ["", '[node name="%s" type="Node3D"]' % self.root, 'script = ExtResource("%s")' % ids["root"],
                'palette = ExtResource("pal")']
        for k, v in self.settings.items():
            out.append("%s = %s" % (k, v))
        out += ["", '[node name="Environment" type="WorldEnvironment" parent="."]', 'environment = SubResource("Environment_1")', ""]
        out += ['[node name="Sun" type="DirectionalLight3D" parent="."]', "transform = %s" % xform((X, cross(Z, X), Z), (0, 0, 0)),
                "light_color = %s" % color(col), "light_energy = %s" % fmt(energy), "shadow_enabled = true",
                "directional_shadow_max_distance = 190.0", ""]
        for n in self.nodes:
            out.append('[node name="%s" type="%s" parent="%s"]' % (n.name, n.type, n.parent))
            for k, v in n.props:
                if k == "transform":
                    out.append("%s = %s" % (k, v))
            if n.script:
                out.append('script = ExtResource("%s")' % ids[n.script])
            for k, v in n.props:
                if k != "transform":
                    out.append("%s = %s" % (k, v))
            if n.group:
                out.append("metadata/_edit_group_ = true")
            out.append("")
        with open(path, "w") as fh:
            fh.write("\n".join(out))
        blocks = sum(1 for n in self.nodes if n.script == "block")
        print("wrote %s: %d nodes (%d blocks), %d spawns, %d weapon pickups" % (path, len(self.nodes), blocks, self.spawn_count, self.weapon_count))


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
    out.append("surface_scale = %s" % fmt(SURFACE_SCALE))
    out.append("surface_strength = %s" % fmt(SURFACE_STRENGTH))
    out.append("roughness = 0.88")
    out.append(dict_lines("breakable", "float", BREAKABLE, num))
    out.append(dict_lines("material", "String", MATERIAL, lambda v: '"%s"' % v))
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")


# ---------------------------------------------------------------------------
# Pieces every building uses. All in the frame of the group they are given.

def floor(m, g, name, kind, x0, x1, z0, z1, top, thick=0.3, holes=(), **kw):
    """A floor slab with rectangular holes (x0, x1, z0, z1) cut out of it."""
    xs = sorted(set([x0, x1] + [v for h in holes for v in h[:2] if x0 < v < x1]))
    zs = sorted(set([z0, z1] + [v for h in holes for v in h[2:] if z0 < v < z1]))
    for j in range(len(zs) - 1):
        run = None
        for i in range(len(xs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            hole = any(h[0] <= cx <= h[1] and h[2] <= cz <= h[3] for h in holes)
            if hole:
                if run:
                    m.box(g, name, kind, (run[0], top - thick, zs[j]), (run[1], top, zs[j + 1]), **kw)
                run = None
            else:
                run = (run[0], xs[i + 1]) if run else (xs[i], xs[i + 1])
        if run:
            m.box(g, name, kind, (run[0], top - thick, zs[j]), (run[1], top, zs[j + 1]), **kw)



def wall(m, g, name, kind, a, b, y0, y1, t, holes=(), **kw):
    """A straight wall along x or z from (x, z) `a` to `b`, from height y0 to y1, with
    openings (from, to, bottom, top): metres along the wall from its west or north end,
    and heights. Unlike arena_builder's wall, openings may stand one above another. A
    fifth number makes the top of the opening an arch that many metres high."""
    along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
    length = abs(b[0] - a[0]) if along_x else abs(b[1] - a[1])
    start = min(a[0], b[0]) if along_x else min(a[1], b[1])
    line = a[1] if along_x else a[0]
    us = sorted(set([0.0, length] + [v for h in holes for v in h[:2] if 0.0 < v < length]))
    for i in range(len(us) - 1):
        u0, u1 = us[i], us[i + 1]
        um = (u0 + u1) / 2
        gaps = sorted((max(h[2], y0), min(h[3], y1)) for h in holes if h[0] <= um <= h[1])
        y = y0
        runs = []
        for lo, hi in gaps:
            if lo > y + 0.01:
                runs.append((y, lo))
            y = max(y, hi)
        if y1 > y + 0.01:
            runs.append((y, y1))
        for lo, hi in runs:
            if along_x:
                m.box(g, name, kind, (start + u0, lo, line - t / 2), (start + u1, hi, line + t / 2), **kw)
            else:
                m.box(g, name, kind, (line - t / 2, lo, start + u0), (line + t / 2, hi, start + u1), **kw)
    for h in holes:
        if len(h) > 4 and h[4] > 0:
            u = start + (h[0] + h[1]) / 2
            size = (h[1] - h[0], h[4], t)
            if along_x:
                m.block(g, name + "Arch", kind, (u, h[3] - h[4] / 2, line), size, shape="arch", sides=8, **kw)
            else:
                m.block(g, name + "Arch", kind, (line, h[3] - h[4] / 2, u), size, cols=TURN, shape="arch", sides=8, **kw)


def walls(m, g, kind, x0, x1, z0, z1, y0, y1, t=0.4, front=(), back=(), west=(), east=(), name="Wall", **kw):
    """Four walls round a rectangle, their middles on its edges. front is the wall at z0
    (toward the quad), back at z1, west at x0, east at x1. Openings are (from, to, bottom,
    top[, arch]): metres along the wall from its west end (front, back) or its front end
    (west, east), and heights."""
    h = t / 2
    shift = lambda holes, d: [(o[0] + d, o[1] + d) + tuple(o[2:]) for o in holes]
    wall(m, g, name + "Front", kind, (x0 - h, z0), (x1 + h, z0), y0, y1, t, shift(front, h), **kw)
    wall(m, g, name + "Back", kind, (x0 - h, z1), (x1 + h, z1), y0, y1, t, shift(back, h), **kw)
    wall(m, g, name + "West", kind, (x0, z0 + h), (x0, z1 - h), y0, y1, t, shift(west, -h), **kw)
    wall(m, g, name + "East", kind, (x1, z0 + h), (x1, z1 - h), y0, y1, t, shift(east, -h), **kw)


def band(m, g, kind, x0, x1, z0, z1, y0, y1, t=0.4, out=0.08, name="Band"):
    """A drawn-only band of colour round the outside of a building's walls (its accent)."""
    h = t / 2
    m.strip(g, name, kind, (x0 - h - out, y0, z0 - h - out), (x1 + h + out, y1, z0 - h))
    m.strip(g, name, kind, (x0 - h - out, y0, z1 + h), (x1 + h + out, y1, z1 + h + out))
    m.strip(g, name, kind, (x0 - h - out, y0, z0 - h), (x0 - h, y1, z1 + h))
    m.strip(g, name, kind, (x1 + h, y0, z0 - h), (x1 + h + out, y1, z1 + h))



def roof(m, g, kind, x0, x1, z0, z1, top, holes=(), parapet=0.8):
    """A flat roof to walk on: the slab (with holes: hatches to drop in by, skylights), a
    cornice under its edge and a low stone parapet with a cap round it."""
    # (a plain ceiling under it, the roof's own colour only on top)
    floor(m, g, "Roof", "stone_warm", x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3, top, 0.35, holes)
    floor(m, g, "RoofSkin", kind, x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3, top + 0.02, 0.02, holes, solid=False)
    for lo, hi in (((x0 - 0.55, top - 0.75, z0 - 0.55), (x1 + 0.55, top - 0.35, z0 - 0.2)), ((x0 - 0.55, top - 0.75, z1 + 0.2), (x1 + 0.55, top - 0.35, z1 + 0.55)),
                   ((x0 - 0.55, top - 0.75, z0 - 0.2), (x0 - 0.2, top - 0.35, z1 + 0.2)), ((x1 + 0.2, top - 0.75, z0 - 0.2), (x1 + 0.55, top - 0.35, z1 + 0.2))):
        m.bev(g, "Cornice", "trim", lo, hi, 0.12, solid=False)
    if parapet > 0:
        low_wall(m, g, (x0 - 0.15, z0 - 0.15), (x1 + 0.15, z0 - 0.15), top, parapet)
        low_wall(m, g, (x0 - 0.15, z1 + 0.15), (x1 + 0.15, z1 + 0.15), top, parapet)
        low_wall(m, g, (x0 - 0.15, z0), (x0 - 0.15, z1), top, parapet)
        low_wall(m, g, (x1 + 0.15, z0), (x1 + 0.15, z1), top, parapet)
    for hx0, hx1, hz0, hz1 in holes:
        for lo, hi in (((hx0 - 0.15, top, hz0 - 0.15), (hx1 + 0.15, top + 0.18, hz0)), ((hx0 - 0.15, top, hz1), (hx1 + 0.15, top + 0.18, hz1 + 0.15)),
                       ((hx0 - 0.15, top, hz0), (hx0, top + 0.18, hz1)), ((hx1, top, hz0), (hx1 + 0.15, top + 0.18, hz1))):
            m.strip(g, "HatchRim", "metal", lo, hi)


def low_wall(m, g, a, b, y, height=0.9, holes=(), kind="stone"):
    """A low stone wall with a cap (a parapet, a balustrade) along x or z, with gaps."""
    along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
    length = abs(b[0] - a[0]) if along_x else abs(b[1] - a[1])
    start = min(a[0], b[0]) if along_x else min(a[1], b[1])
    line = a[1] if along_x else a[0]
    u = 0.0
    runs = []
    for h0, h1 in sorted(holes):
        if h0 - u > 0.05:
            runs.append((u, h0))
        u = h1
    if length - u > 0.05:
        runs.append((u, length))
    for u0, u1 in runs:
        if along_x:
            m.box(g, "Parapet", kind, (start + u0, y, line - 0.15), (start + u1, y + height - 0.1, line + 0.15))
            m.bev(g, "ParapetCap", "stone_warm", (start + u0 - 0.04, y + height - 0.1, line - 0.24), (start + u1 + 0.04, y + height, line + 0.24), 0.04)
        else:
            m.box(g, "Parapet", kind, (line - 0.15, y, start + u0), (line + 0.15, y + height - 0.1, start + u1))
            m.bev(g, "ParapetCap", "stone_warm", (line - 0.24, y + height - 0.1, start + u0 - 0.04), (line + 0.24, y + height, start + u1 + 0.04), 0.04)


def lit_windows(m, g, axis, face, out, spots, y0, y1, width=1.6, arched=False):
    """Drawn-only window panels on an outside wall (they light up at sunset): spots are
    positions along the wall. Arched: a round head on each."""
    for u in spots:
        m.on_wall(g, "WindowFrame", "metal", axis, face, out, u - width / 2 - 0.1, u + width / 2 + 0.1, y0 - 0.1, y1 + (0 if arched else 0.1), depth=0.06)
        m.on_wall(g, "Window", "window_lit", axis, face, out, u - width / 2, u + width / 2, y0, y1, depth=0.05, lift=0.06)
        if arched:
            cols = LIE_Z if axis == "x" else LIE_X
            at = lambda d: (u, y1, face + out * d) if axis == "x" else (face + out * d, y1, u)
            m.block(g, "WindowFrame", "metal", at(0.03), (width + 0.2, 0.05, width + 0.2), cols=cols, shape="cyl", sides=16, solid=False)
            m.block(g, "Window", "window_lit", at(0.08), (width, 0.04, width), cols=cols, shape="cyl", sides=16, solid=False)


def lamp_post(m, g, x, z, y=0.0, height=3.2):
    m.cyl(g, "LampPost", "metal", (x, y, z), 0.16, height, sides=8)
    m.dome(g, "Lamp", "lamp", (x, y + height + 0.24, z), (0.52, 0.26, 0.52), sides=8, solid=False)
    m.dome(g, "Lamp", "lamp", (x, y + height + 0.24, z), (0.52, 0.24, 0.52), sides=8, flip=True, solid=False)
    m.cone(g, "LampCap", "metal", (x, y + height + 0.4, z), 0.66, 0.22, sides=8, solid=False)


def tree(m, g, x, z, y=0.0, kind="leaves", size=1.0):
    """A tapering trunk and three round clumps of leaves."""
    t = m.group("Tree", g, at=(x, y, z))
    s = size
    m.cone(t, "Trunk", "bark", (0, 0, 0), 0.62 * s, 3.2 * s, top=0.34 * s, sides=8)
    for i, (dx, dy, dz, r) in enumerate(((0.0, 3.9, 0.0, 1.9), (1.15, 3.2, 0.55, 1.35), (-0.95, 3.3, -0.75, 1.45))):
        tint = (1.0, 1.0, 1.0) if i else (1.07, 1.07, 1.0)
        m.dome(t, "Leaves", kind, (dx * s, dy * s, dz * s), (2 * r * s, 0.95 * r * s, 2 * r * s), sides=10, solid=False, tint=tint)
        m.dome(t, "Leaves", kind, (dx * s, dy * s, dz * s), (2 * r * s, 0.6 * r * s, 2 * r * s), sides=10, flip=True, solid=False, tint=(0.88, 0.88, 0.88))


def bench(m, g, x, z, y=0.0):
    """A park bench along x: a slatted seat and back on two legs."""
    m.box(g, "BenchBody", "table", (x - 1.0, y, z - 0.26), (x + 1.0, y + 0.5, z + 0.3), drawn=False)
    m.bev(g, "BenchSeat", "table", (x - 1.05, y + 0.4, z - 0.26), (x + 1.05, y + 0.5, z + 0.22), 0.03, solid=False)
    m.bev(g, "BenchBack", "table", (x - 1.05, y + 0.62, z + 0.2), (x + 1.05, y + 1.0, z + 0.28), 0.03, solid=False)
    for dx in (-0.8, 0.8):
        m.strip(g, "BenchLeg", "metal", (x + dx - 0.04, y, z - 0.2), (x + dx + 0.04, y + 0.4, z + 0.26))
        m.strip(g, "BenchLeg", "metal", (x + dx - 0.04, y + 0.4, z + 0.2), (x + dx + 0.04, y + 0.95, z + 0.26))


def table(m, g, lo, hi, y=0.0, height=0.78, kind="table"):
    """A table from (x, z) `lo` to `hi`: a thin top on two trestles. Solid as one box."""
    (x0, z0), (x1, z1) = lo, hi
    m.box(g, "TableBody", kind, (x0, y, z0), (x1, y + height, z1), drawn=False)
    m.bev(g, "TableTop", kind, (x0 - 0.05, y + height - 0.08, z0 - 0.05), (x1 + 0.05, y + height, z1 + 0.05), 0.03, solid=False)
    if x1 - x0 >= z1 - z0:
        for x in (x0 + 0.35, x1 - 0.35):
            m.strip(g, "TableLeg", kind, (x - 0.06, y, z0 + 0.08), (x + 0.06, y + height - 0.08, z1 - 0.08), tint=(0.8, 0.8, 0.8))
    else:
        for z in (z0 + 0.35, z1 - 0.35):
            m.strip(g, "TableLeg", kind, (x0 + 0.08, y, z - 0.06), (x1 - 0.08, y + height - 0.08, z + 0.06), tint=(0.8, 0.8, 0.8))


def counter(m, g, lo, hi, y=0.0, height=1.05, kind="counter", top="table"):
    """A counter or a workbench from (x, z) `lo` to `hi`: a body set back under a top that
    overhangs, on a dark plinth. Solid as one box."""
    (x0, z0), (x1, z1) = lo, hi
    m.box(g, "CounterBody", kind, (x0, y, z0), (x1, y + height, z1), drawn=False)
    m.strip(g, "CounterPlinth", "metal", (x0 + 0.1, y, z0 + 0.1), (x1 - 0.1, y + 0.12, z1 - 0.1))
    m.strip(g, "CounterFront", kind, (x0 + 0.04, y + 0.12, z0 + 0.04), (x1 - 0.04, y + height - 0.09, z1 - 0.04))
    m.bev(g, "CounterTop", top, (x0 - 0.06, y + height - 0.09, z0 - 0.06), (x1 + 0.06, y + height, z1 + 0.06), 0.035, solid=False)


def engines(m, g, spots, y, size=2.2):
    """Glowing engines under an island (drawn only): a collar, a nozzle narrowing down
    from it, and the flame."""
    for x, z in spots:
        m.cyl(g, "EngineCollar", "engine_ring", (x, y - 0.5, z), size + 0.5, 0.5, sides=12, solid=False)
        m.cone(g, "EngineNozzle", "engine_ring", (x, y - 0.5, z), size, 0.9, top=size * 0.66, sides=12, flip=True, solid=False, tint=(0.82, 0.82, 0.82))
        m.cyl(g, "Engine", "engine", (x, y - 1.5, z), size * 0.62, 0.12, sides=12, solid=False)
        m.cone(g, "EngineFlame", "engine", (x, y - 1.5, z), size * 0.5, size * 0.7, sides=10, flip=True, solid=False, tint=(1.15, 1.15, 1.15))


def stairs(m, g, name, a, b, width, fill=True, base=None, sides=(True, True), side_kind="stone_warm"):
    """A staircase from its foot `a` to its head `b` (each x, y, z), along x or z. You walk
    on an invisible ramp (the bots' navigation mesh does too); the steps are drawn only,
    each with a lighter tread that overhangs the one below, and a sloping side closes
    them in so no zigzag shows. `fill`: solid down to `base` (the foot's height unless
    given); otherwise open underneath, with a sloping soffit. `sides`: which of the two
    sloping sides to make (the north or west one, the south or east one): leave out one
    that would lie inside a wall."""
    sg = m.group(name, g)
    m.slab(sg, "Ramp", "stair", a, b, width, thick=0.3, drawn=False, unbreakable=True)
    rise = b[1] - a[1]
    n = max(1, int(round(rise / 0.22)))
    dx, dz = b[0] - a[0], b[2] - a[2]
    along_x = abs(dx) >= abs(dz)
    floor_y = a[1] if base is None else base
    sgn = 1.0 if (dx if along_x else dz) > 0 else -1.0
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        top = a[1] + rise * t1
        low = floor_y if fill else top - 0.42
        if along_x:
            p, q = a[0] + dx * t0, a[0] + dx * t1
            m.strip(sg, "Step", "stair", (min(p, q), low, a[2] - width / 2), (max(p, q), top - 0.05, a[2] + width / 2))
            p -= sgn * 0.05
            m.strip(sg, "Tread", "stair_tread", (min(p, q), top - 0.05, a[2] - width / 2), (max(p, q), top, a[2] + width / 2))
        else:
            p, q = a[2] + dz * t0, a[2] + dz * t1
            m.strip(sg, "Step", "stair", (a[0] - width / 2, low, min(p, q)), (a[0] + width / 2, top - 0.05, max(p, q)))
            p -= sgn * 0.05
            m.strip(sg, "Tread", "stair_tread", (a[0] - width / 2, top - 0.05, min(p, q)), (a[0] + width / 2, top, max(p, q)))
    if fill:
        if along_x:
            m.wedge(sg, "Fill", "stair", (min(a[0], b[0]), floor_y, a[2] - width / 2), (max(a[0], b[0]), b[1], a[2] + width / 2),
                    tall="+x" if dx > 0 else "-x", drawn=False, unbreakable=True)
        else:
            m.wedge(sg, "Fill", "stair", (a[0] - width / 2, floor_y, min(a[2], b[2])), (a[0] + width / 2, b[1], max(a[2], b[2])),
                    tall="+z" if dz > 0 else "-z", drawn=False, unbreakable=True)
    else:
        m.slab(sg, "Soffit", side_kind, (a[0], a[1] - 0.2, a[2]), (b[0], b[1] - 0.2, b[2]), width, thick=0.26, solid=False)
    for on, s in zip(sides, (-1.0, 1.0)):
        if on:
            off = s * (width / 2 + 0.08)
            sa = (a[0], a[1] + 0.2, a[2] + off) if along_x else (a[0] + off, a[1] + 0.2, a[2])
            sb = (b[0], b[1] + 0.2, b[2] + off) if along_x else (b[0] + off, b[1] + 0.2, b[2])
            m.slab(sg, "Side", side_kind, sa, sb, 0.16, thick=0.8, solid=False)
    return sg


# ---------------------------------------------------------------------------
# The quad and the clock tower (they never move)

def quad(m):
    g = m.group("Quad", grouped=False)
    isl = m.group("Island", g)
    m.cyl(isl, "Lawn", "lawn", (0, -1.0, 0), QUAD_R * 2, 1.0, sides=36)
    m.cyl(isl, "Kerb", "stone_warm", (0, -1.2, 0), QUAD_R * 2 + 0.6, 1.02, sides=36, solid=False)
    # The rock under it: one long taper, and a darker root below.
    m.cone(isl, "Rock", "rock", (0, -1.0, 0), QUAD_R * 2 - 1.0, 7.0, top=13.0, sides=14, flip=True)
    m.cone(isl, "Rock", "rock_dark", (0, -8.0, 0), 13.0, 5.0, top=5.0, sides=10, flip=True)
    engines(m, isl, [(0, 0)], -13.0, 4.2)
    engines(m, isl, [polar(9.4, a)[::2] for a in (60, 180, 300)], -5.0, 1.8)
    # Paths from the tower out to each skyway, and a round apron under the tower.
    p = m.group("Paths", g)
    for _name, deg, _a, _r in ISLANDS:
        m.block(p, "Path", "path", polar(10.9, deg, 0.011), (3.2, 0.022, 7.0), cols=rot(deg), solid=False)
    m.cyl(p, "TowerApron", "path", (0, 0, 0), 17.0, 0.03, sides=28, solid=False)
    # Five planters round the rim, each with a banner mast: the mast's top is a grapple
    # point, the way up to the quad in the Ring layout. They stand 18 degrees to one side
    # of where each island is then; the other side is left open (the way back down).
    rim = m.group("Rim", g, grouped=False)
    banners = ["banner_gold", "banner_red", "banner_blue"]
    for i, (_n, isl_deg, _a, _r) in enumerate(ISLANDS):
        deg = isl_deg + SWING + 18.0
        pl = m.group("Planter", rim, at=polar(MAST_R, deg), yaw=math.radians(deg))
        m.bev(pl, "Planter", "planter", (-1.8, 0, -0.7), (1.8, 0.6, 0.7), 0.1)
        m.bev(pl, "Hedge", "hedge", (-1.65, 0.6, -0.55), (1.65, 1.15, 0.55), 0.22)
        m.cyl(pl, "Mast", "mast", (0, 1.15, 0), 0.26, 7.8, sides=8)
        m.strip(pl, "Banner", banners[i % 3], (0.15, 5.9, -0.04), (1.3, 8.7, 0.04))
        m.dome(pl, "Finial", "brass", (0, 8.95, 0), (0.5, 0.3, 0.5), sides=8, solid=False)
        m.node("Hook%d" % (i + 1), pl, "hook", [("transform", xform(IDENTITY, (0, 9.2, 0))), ("reach", "45.0")], type_="Marker3D")
    # Trees and benches: cover on the lawn, and something to break up the long views.
    for i, (_n, deg, _a, _r) in enumerate(ISLANDS):
        x, _y, z = polar(9.6, deg + 36.0)
        tree(m, g, x, z, kind="leaves_gold" if i % 2 else "leaves", size=1.15)
        bx, _y, bz = polar(8.8, deg + 16.0)
        b = m.group("Bench", g, at=(bx, 0, bz), yaw=math.radians(deg + 16.0))
        bench(m, b, 0, 0)
    tower(m, g)
    return g


TOWER_IN = 4.6      # half the inside of the tower
TOWER_OUT = 5.2
FLIGHTS = 9         # flights of the stair, each along one wall
STEP = 2.9          # each flight climbs this much (29 degrees)
BELFRY = FLIGHTS * STEP   # the belfry floor
STAIR_W = 2.0
CLOCK_Y = 23.2      # the middle of the clock faces
LEDGE_Y = 20.4      # the upper ledge


def tower(m, quad_group):
    g = m.group("ClockTower", quad_group, grouped=False)
    shell = m.group("Shell", g)
    I, O = TOWER_IN, TOWER_OUT
    mid = (I + O) / 2
    # Doors north and west (the stair starts along the south wall and climbs past the
    # east one); tall arched slits all the way up, a different pair of walls each time,
    # to hook and to shoot from.
    slit_ns = lambda y: (O - 0.7, O + 0.7, y, y + 2.6, 0.7)
    slit_we = lambda y: (I - 0.7, I + 0.7, y, y + 2.6, 0.7)
    wall(m, shell, "WallNorth", "stone", (-O, -mid), (O, -mid), 0, BELFRY - 0.4, O - I, [(O - 1.6, O + 1.6, 0.0, 4.2, 1.4), slit_ns(7.0), slit_ns(16.9)])
    wall(m, shell, "WallSouth", "stone", (-O, mid), (O, mid), 0, BELFRY - 0.4, O - I, [slit_ns(4.4), slit_ns(12.2)])
    wall(m, shell, "WallWest", "stone", (-mid, -I), (-mid, I), 0, BELFRY - 0.4, O - I, [(I - 1.6, I + 1.6, 0.0, 4.2, 1.4), slit_we(9.6), slit_we(16.6)])
    wall(m, shell, "WallEast", "stone", (mid, -I), (mid, I), 0, BELFRY - 0.4, O - I, [slit_we(6.8), slit_we(14.7)])
    m.box(shell, "Floor", "floor_tile", (-I, -0.02, -I), (I, 0.03, I), solid=False)
    # Outside: a pilaster up each corner, two cornices, and the upper ledge right under
    # the belfry's overhang (a power weapon's spot): ledges to hook and to stand on.
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.bev(shell, "Pilaster", "stone_warm", (sx * O - 0.8, 0, sz * O - 0.8), (sx * O + 0.8, 7.4, sz * O + 0.8), 0.18)
            m.bev(shell, "Pilaster", "stone_warm", (sx * O - 0.5, 7.4, sz * O - 0.5), (sx * O + 0.5, LEDGE_Y - 0.4, sz * O + 0.5), 0.12)
    for y, out, kind in ((9.0, 0.6, "trim"), (15.5, 0.6, "trim"), (LEDGE_Y, 1.0, "stone_warm")):
        for lo, hi in (((-O - out, y - 0.4, -O - out), (O + out, y, -O)), ((-O - out, y - 0.4, O), (O + out, y, O + out)),
                       ((-O - out, y - 0.4, -O), (-O, y, O)), ((O, y - 0.4, -O), (O + out, y, O))):
            m.bev(shell, "UpperLedge" if out > 0.7 else "Cornice", kind, lo, hi, 0.1)
    # A clock face on every side, between the upper ledge and the belfry. No numbers:
    # twelve marks, a short hand that stays put and a long one that counts the layout
    # down (a MapSpinner the LayoutEvent turns: once round, at twelve when the bell goes).
    for deg in (0, 90, 180, 270):
        c = m.group("Clock", g, at=polar(O, deg, CLOCK_Y), yaw=math.radians(deg))
        m.block(c, "Face", "clock_face", (0, 0, 0.09), (4.4, 0.18, 4.4), cols=LIE_Z, shape="cyl", sides=28, solid=False)
        m.block(c, "Rim", "brass", (0, 0, 0.05), (4.9, 0.1, 4.9), cols=LIE_Z, shape="cyl", sides=28, solid=False)
        for k in range(12):
            phi = math.radians(k * 30.0)
            cols = ((math.cos(phi), -math.sin(phi), 0), (math.sin(phi), math.cos(phi), 0), (0, 0, 1))
            long_mark = k % 3 == 0
            r = 1.72 if long_mark else 1.82
            m.block(c, "Mark", "clock_hand", (r * math.sin(phi), r * math.cos(phi), 0.2), (0.16 if long_mark else 0.1, 0.56 if long_mark else 0.36, 0.04), cols=cols, solid=False)
        phi = math.radians(300.0)
        cols = ((math.cos(phi), -math.sin(phi), 0), (math.sin(phi), math.cos(phi), 0), (0, 0, 1))
        m.block(c, "HourHand", "clock_hand", (0.5 * math.sin(phi), 0.5 * math.cos(phi), 0.22), (0.22, 1.25, 0.05), cols=cols, solid=False)
        hand = m.node("CountdownHand", c, "spinner", [("transform", xform(((1, 0, 0), (0, 0, 1), (0, -1, 0)), (0, 0, 0.26))),
                                                      ("speed", "0.0"), ("driven", "1")])
        m.block(hand, "Hand", "clock_hand", (0, 0.02, -0.72), (0.14, 0.05, 2.0), solid=False)
        m.block(hand, "Hub", "brass", (0, 0.06, 0), (0.42, 0.08, 0.42), shape="cyl", sides=12, solid=False)
    # The stair: nine flights round the inside walls, a landing in each corner, the
    # middle left open (a shaft to grapple up).
    st = m.group("Stair", g, grouped=False)
    a = I - STAIR_W / 2      # the middle of a flight, across it
    e = I - STAIR_W          # where a flight meets a landing
    for k in range(FLIGHTS):
        y = k * STEP
        side = k % 4
        if side == 0:
            p0, p1, land, open_side = (-e, y, a), (e, y + STEP, a), (e, I, e, I), (True, False)
        elif side == 1:
            p0, p1, land, open_side = (a, y, e), (a, y + STEP, -e), (e, I, -I, -e), (True, False)
        elif side == 2:
            p0, p1, land, open_side = (e, y, -a), (-e, y + STEP, -a), (-I, -e, -I, -e), (False, True)
        else:
            p0, p1, land, open_side = (-a, y, -e), (-a, y + STEP, e), (-I, -e, e, I), (False, True)
        stairs(m, st, "Flight%d" % (k + 1), p0, p1, STAIR_W, base=y - 0.05, sides=open_side)
        if k < FLIGHTS - 1:
            m.box(st, "Landing", "stair", (land[0], y + STEP - 0.3, land[2]), (land[1], y + STEP, land[3]))
    # The belfry: wider than the tower (it overhangs the upper ledge), an arch on each of
    # its four sides, the bell hanging in the middle.
    bf = m.group("Belfry", g, grouped=False)
    W = O + 1.0
    # (the last flight comes up along the south wall to the south-east corner: the floor
    # is left open over it and over the landing it starts from)
    floor(m, bf, "BelfryFloor", "stone_warm", -W, W, -W, W, BELFRY, 0.4, [(-I, e, e, I)])
    top = BELFRY + 5.4
    P = W - 0.7             # the middle of a corner pier
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.bev(bf, "Pier", "stone", (sx * P - 0.7, BELFRY, sz * P - 0.7), (sx * P + 0.7, top, sz * P + 0.7), 0.14)
    span = 2 * (P - 0.7)
    for s in (-1, 1):
        m.block(bf, "Arch", "stone", (0, top - 1.0, s * P), (span, 2.0, 1.0), shape="arch", sides=10, top=0.6)
        m.block(bf, "Arch", "stone", (s * P, top - 1.0, 0), (span, 2.0, 1.0), cols=TURN, shape="arch", sides=10, top=0.6)
        low_wall(m, bf, (-span / 2, s * P), (span / 2, s * P), BELFRY, 1.0)
        low_wall(m, bf, (s * P, -span / 2), (s * P, span / 2), BELFRY, 1.0)
    # (a rail round the stair hole, so nobody backs into it)
    m.rail(bf, "StairRail", "rail", (-I, e), (e, e), BELFRY, 1.0)
    m.rail(bf, "StairRail", "rail", (-I, e), (-I, I), BELFRY, 1.0)
    m.rail(bf, "StairRail", "rail", (-I, I), (e, I), BELFRY, 1.0)
    # The roof: an eave, and a tall four-sided spire, each side one clean slope (too
    # steep to stand on).
    m.bev(bf, "Eave", "trim", (-W - 0.6, top, -W - 0.6), (W + 0.6, top + 0.45, W + 0.6), 0.16)
    side = 2 * (W + 0.3)
    m.cone(bf, "Spire", "roof_slate", (0, top + 0.45, 0), side * math.sqrt(2.0), 11.5, sides=4, yaw=45.0)
    apex = top + 0.45 + 11.5
    m.cone(bf, "Finial", "brass", (0, apex - 0.7, 0), 0.5, 2.6, sides=8, solid=False)
    m.dome(bf, "FinialBall", "brass", (0, apex + 0.9, 0), (0.7, 0.35, 0.7), sides=8, solid=False)
    m.dome(bf, "FinialBall", "brass", (0, apex + 0.9, 0), (0.7, 0.35, 0.7), sides=8, flip=True, solid=False)
    # The bell: it hangs from a beam between two of the arches and swings when it tolls
    # (a MapSpinner the LayoutEvent rocks). Nobody rings it: the clock does.
    m.box(bf, "Yoke", "metal", (-P + 0.3, top - 0.5, -0.2), (P - 0.3, top - 0.1, 0.2))
    bell = m.node("Bell", bf, "spinner", [("transform", xform(((0, 1, 0), (1, 0, 0), (0, 0, -1)), (0, top - 0.5, 0))),
                                          ("speed", "0.0"), ("driven", "2")])
    up = ((0, -1, 0), (1, 0, 0), (0, 0, 1))      # a block's own y along the spinner's x (world up)
    m.block(bell, "Crown", "bell", (-0.35, 0, 0), (0.7, 0.7, 0.7), cols=up, shape="cyl", sides=10)
    m.block(bell, "Body", "bell", (-1.7, 0, 0), (2.9, 2.0, 2.9), cols=up, shape="cone", sides=16, top=1.5)
    m.block(bell, "Lip", "bell", (-2.8, 0, 0), (3.2, 0.22, 3.2), cols=up, shape="cyl", sides=16, tint=(1.1, 1.1, 1.1))
    m.block(bell, "Clapper", "metal", (-2.7, 0, 0), (0.3, 1.0, 0.3), cols=up, shape="cyl", sides=8)
    # The power weapon on the upper ledge, north side.
    m.weapon_in(g, (0, LEDGE_Y, -O - 0.5), "anti_materiel")


# ---------------------------------------------------------------------------
# One island: the deck, the rock under it, its two bridge halves

def island(m, name, deg, accent, roof_kind, building):
    at = polar(R0, deg)
    g = m.node(name, ".", "island", [("transform", xform(rot(deg), at)), ("swing", fmt(SWING)), ("pull", fmt(PULL)), ("drop", fmt(DROP))])
    d = m.group("Deck", g)
    # The deck: a fan (a strip down the middle and a triangle either side, so its side
    # edges are straight lines) and the main deck behind it.
    m.box(d, "Fan", "paving", (-WT, -0.8, ZT), (WT, 0, ZS))
    for sx in (-1, 1):
        m.tri(d, "FanSide", "paving", (sx * WT, ZS), sx * (WS - WT), ZT - ZS, -0.8, 0)
    m.box(d, "MainDeck", "paving", (-WS, -0.8, ZS), (WS, 0, MAIN_Z1))
    for lo, hi in (((-WT - 0.15, -1.0, ZT - 0.15), (WT + 0.15, -0.3, ZT)), ((-WS - 0.15, -1.0, MAIN_Z1), (WS + 0.15, -0.3, MAIN_Z1 + 0.15)),
                   ((-WS - 0.15, -1.0, ZS), (-WS, -0.3, MAIN_Z1)), ((WS, -1.0, ZS), (WS + 0.15, -0.3, MAIN_Z1))):
        m.strip(d, "Kerb", "stone_warm", lo, hi)
    # The rock under it: three round bellies, the lowest the darkest, and the engines.
    m.dome(d, "Rock", "rock", (0, -0.8, (ZS + MAIN_Z1) / 2), (2 * WS - 1.0, 8.0, MAIN_Z1 - ZS - 0.6), sides=12, flip=True)
    m.dome(d, "Rock", "rock", (0, -0.8, -8.0), (15.0, 5.5, 15.5), sides=10, flip=True)
    m.dome(d, "Rock", "rock_dark", (0, -4.0, 5.0), (17.0, 9.5, 10.5), sides=10, flip=True)
    engines(m, d, [(0, 5.0)], -13.3, 3.4)
    engines(m, d, [(-10.5, 6.0), (10.5, 6.0), (0, -8.0)], -5.9, 1.9)
    # Rails along the edges, open at the skyway, at the bridges and here and there.
    r = m.group("Rails", g)
    for sx in (-1, 1):
        yaw = math.atan2(sx * SIN36, COS36)
        edge = m.group("EdgeRail", r, at=(sx * WT, 0, ZT), yaw=yaw)
        m.strip(edge, "Kerb", "stone_warm", (0.0 if sx > 0 else -0.15, -1.0, 0.0), (0.15 if sx > 0 else 0.0, -0.3, EDGE_LEN))
        for t0, t1 in ((0.8, 7.2), (9.6, EDGE_LEN - 1.4)):
            m.rail_box(edge, (-sx * 0.2 - 0.06, 0, t0), (-sx * 0.2 + 0.06, 1.0, t1))
        m.rail(r, "Rail", "rail", (sx * (WS - 0.1), 2.0), (sx * (WS - 0.1), MAIN_Z1), 0, 1.0, holes=[(4.0, 6.4)])
    m.rail(r, "Rail", "rail", (-WS, MAIN_Z1 - 0.1), (WS, MAIN_Z1 - 0.1), 0, 1.0, holes=[(6.5, 9.5), (2 * WS - 9.5, 2 * WS - 6.5)])
    # Lamps down both edges, and the building's colour laid into the paving where the
    # skyway lands and flying on a banner either side of it.
    for z in (ZT + 0.6, (ZT + ZS) / 2, ZS - 0.4):
        for sx in (-1, 1):
            lamp_post(m, d, sx * (edge_x(z) - 0.7), z)
    m.strip(d, "Inlay", accent, (-2.0, 0, ZT + 0.6), (2.0, 0.022, ZT + 6.0))
    for sx in (-1, 1):
        m.cyl(d, "BannerMast", "mast", (sx * 3.4, 0, ZT + 3.0), 0.2, 6.0, sides=8)
        m.strip(d, "Banner", accent, (sx * 3.4 + 0.12, 3.2, ZT + 2.96), (sx * 3.4 + 1.3, 5.8, ZT + 3.04))
        m.dome(d, "Finial", "brass", (sx * 3.4, 6.0, ZT + 3.0), (0.4, 0.24, 0.4), sides=8, solid=False)
    bridges(m, g)
    building(m, g, accent, roof_kind)
    return g


def bridges(m, g):
    """A bridge half from each front corner of the main deck: four segments that come out
    in the Ring layout and meet the neighbour's half way across. The pad they leave from
    is part of the island."""
    for side, sx in (("East", 1), ("West", -1)):
        dx, dz = sx * BRIDGE_DIR[0], BRIDGE_DIR[1]
        yaw = math.atan2(dx, dz)
        cx, cz = sx * WS, ZS
        pad = m.group("BridgePad" + side, g, at=(cx, 0, cz), yaw=yaw)
        m.box(pad, "Pad", "bridge_deck", (-BRIDGE_W / 2, -0.3, -2.7), (BRIDGE_W / 2, 0.04, 0))
        for ex in (-1, 1):
            m.bev(pad, "GatePost", "stone_warm", (ex * (BRIDGE_W / 2 + 0.05) - 0.24, 0, -0.54), (ex * (BRIDGE_W / 2 + 0.05) + 0.24, 2.4, -0.06), 0.06)
            m.dome(pad, "GateLamp", "lamp", (ex * (BRIDGE_W / 2 + 0.05), 2.4, -0.3), (0.42, 0.3, 0.42), sides=8, solid=False)
        span = m.node("Bridge" + side, g, "span", [("transform", xform(yaw_cols(yaw), (cx, 0, cz))), ("out_in", "1"),
                                                   ("light_kinds", 'PackedStringArray("span_light")')])
        n = 4
        L = BRIDGE_LEN / n
        for i in range(n):
            s = m.group("Segment%d" % (i + 1), span)
            z0, z1 = i * L, (i + 1) * L
            m.box(s, "Deck", "bridge_deck", (-BRIDGE_W / 2, -0.3, z0), (BRIDGE_W / 2, 0.04, z1))
            for ex in (-1, 1):
                m.rail_box(s, (ex * (BRIDGE_W / 2 - 0.06) - 0.06, 0.04, z0), (ex * (BRIDGE_W / 2 - 0.06) + 0.06, 1.04, z1))
                m.strip(s, "Light", "span_light", (ex * (BRIDGE_W / 2 - 0.42) - 0.07, 0.04, z0 + 0.08), (ex * (BRIDGE_W / 2 - 0.42) + 0.07, 0.075, z1 - 0.08))
            m.strip(s, "Beam", "metal", (-0.5, -0.62, z0), (0.5, -0.3, z1))
            if i == n - 1:
                m.strip(s, "Coupler", "brass", (-BRIDGE_W / 2 - 0.08, -0.36, z1 - 0.3), (BRIDGE_W / 2 + 0.08, -0.3, z1 - 0.02))


def skyways(m):
    """A skyway from the quad to each island's tip (Hub layout): four segments fixed to
    the quad, drawn in from the island's end when the layout changes."""
    f = m.group("Skyways", grouped=False)
    start = QUAD_R - 0.6
    n = 4
    L = (TIP - start) / n
    for name, deg, accent, _r in ISLANDS:
        span = m.node("Skyway" + name, f, "span", [("transform", xform(rot(deg), polar(start, deg))), ("out_in", "0"),
                                                   ("light_kinds", 'PackedStringArray("span_light")')])
        for i in range(n):
            s = m.group("Segment%d" % (i + 1), span)
            z0, z1 = i * L, (i + 1) * L
            m.box(s, "Deck", "bridge_deck", (-SKYWAY_W / 2, -0.3, z0), (SKYWAY_W / 2, 0.04, z1))
            m.strip(s, "Runner", accent, (-0.9, 0.04, z0), (0.9, 0.062, z1))
            for ex in (-1, 1):
                m.rail_box(s, (ex * (SKYWAY_W / 2 - 0.06) - 0.06, 0.04, z0 + (0.7 if i == 0 else 0)), (ex * (SKYWAY_W / 2 - 0.06) + 0.06, 1.04, z1))
                m.strip(s, "Light", "span_light", (ex * (SKYWAY_W / 2 - 0.45) - 0.07, 0.04, z0 + 0.08), (ex * (SKYWAY_W / 2 - 0.45) + 0.07, 0.075, z1 - 0.08))
            m.strip(s, "Beam", "metal", (-0.6, -0.7, z0), (0.6, -0.3, z1))


def stones(m):
    """Five stepping stones just off the quad's rim, between the skyways: a hop from the
    quad, a long jump from an island's tip, and in the Ring layout a place to hook on
    the way up. A statue, two kiosks and two planters."""
    f = m.group("SteppingStones", grouped=False)
    kinds = ["statue", "kiosk", "planter", "kiosk", "planter"]
    for i, (name, deg, _a, _r) in enumerate(ISLANDS):
        g = m.group("Stone" + name, f, at=polar(STONE_R, deg + 36.0), yaw=math.radians(deg + 36.0))
        m.cyl(g, "Top", "paving", (0, 0.1, 0), 4.6, 0.5, sides=14)
        m.cone(g, "Rock", "rock", (0, 0.1, 0), 4.2, 2.6, top=1.6, sides=10, flip=True)
        engines(m, g, [(0, 0)], -2.5, 1.3)
        what = kinds[i]
        if what == "statue":
            m.bev(g, "Plinth", "stone_warm", (-0.7, 0.6, 0.5), (0.7, 1.4, 1.9), 0.1)
            m.cone(g, "Obelisk", "statue", (0, 1.4, 1.2), 1.0, 2.6, top=0.3, sides=4, yaw=45.0)
            m.dome(g, "Orb", "brass", (0, 4.0, 1.2), (0.6, 0.3, 0.6), sides=8, solid=False)
            m.dome(g, "Orb", "brass", (0, 4.0, 1.2), (0.6, 0.3, 0.6), sides=8, flip=True, solid=False)
        elif what == "kiosk":
            m.cyl(g, "Kiosk", "kiosk", (0, 0.6, 1.2), 1.9, 2.0, sides=10)
            m.cone(g, "KioskRoof", "awning", (0, 2.6, 1.2), 2.9, 0.9, top=0.3, sides=10)
            m.strip(g, "Hatch", "window_lit", (-0.5, 1.5, 0.2), (0.5, 2.2, 0.3))
        else:
            m.cyl(g, "Planter", "planter", (0, 0.6, 1.15), 2.3, 0.5, sides=12)
            m.cyl(g, "Soil", "soil", (0, 1.1, 1.15), 2.0, 0.06, sides=12, solid=False)
            tree(m, g, 0, 1.15, 1.1, kind="leaves_gold" if i % 2 else "leaves", size=0.62)
        lamp_post(m, g, -1.5, -0.9, 0.6, 3.4)
    return f


# ---------------------------------------------------------------------------
# The buildings. Each stands on its island's main deck: x from -14 to 14, z from -1.4
# (the front, facing the quad) to 13.6, unless it says otherwise. That leaves a walkway
# down each side wide enough for the bots' navigation mesh. Floors are 5.5 m apart and
# the big rooms are two floors high: room to grapple, flip and use the rocket boots.
#
# For the bots' navigation mesh a stair is 2.2 m wide and climbs at 31 degrees or less
# (5.5 m up takes 9.2 m along), with 2 m of clear floor before its foot and beyond its
# head, and nothing narrower than about 2 m on the way to either. Where a stair comes
# up through a floor, the hole starts while the stair still has 2.4 m of headroom.

BX0, BX1, BZ0, BZ1 = -14.0, 14.0, -1.4, 13.6
IX0, IX1, IZ0, IZ1 = BX0 + 0.2, BX1 - 0.2, BZ0 + 0.2, BZ1 - 0.2   # inside the walls
SW = 2.2           # a stair's width


def fx(x0, x1, y0, y1, arch=0.0, west=BX0):
    """An opening in a front or back wall, given by its x."""
    return (x0 - west, x1 - west, y0, y1, arch)


def sz(z0, z1, y0, y1, arch=0.0):
    """An opening in a side wall, given by its z."""
    return (z0 - BZ0, z1 - BZ0, y0, y1, arch)


def door_banners(m, g, accent, x, z=BZ0, y0=4.6, y1=8.2, half=2.4):
    """The building's colour on a banner either side of its front door."""
    for s in (-1, 1):
        m.strip(g, "DoorBanner", accent, (x + s * half - 0.45, y0, z - 0.3), (x + s * half + 0.45, y1, z - 0.24))
        m.strip(g, "BannerRod", "brass", (x + s * half - 0.55, y1, z - 0.34), (x + s * half + 0.55, y1 + 0.08, z - 0.2))


def library(m, g, accent, roof_kind):
    """Three floors of stacks round a tall hall: shelf lanes on the ground, mezzanines at
    5.5 and 11 m, a reading room under the skylight, and a perch under the roof that only
    the grapple reaches. Its shape: a columned porch with a low gable over the door, and
    tall round-headed windows."""
    b = m.group("Building", g, grouped=False)
    sh = m.group("Shell", b)
    top = 18.0
    walls(m, sh, "stone", BX0, BX1, BZ0, BZ1, 0, top,
          front=[fx(-1.6, 1.6, 0, 4.2, 1.3), fx(-10.5, -7.5, 1.2, 4.4, 1.0), fx(7.5, 10.5, 1.2, 4.4, 1.0),
                 fx(-10.5, -7.5, 6.7, 9.9, 1.0), fx(7.5, 10.5, 6.7, 9.9, 1.0), fx(-1.5, 1.5, 12.2, 15.4, 1.0)],
          back=[fx(-11.5, -8.5, 6.7, 9.9, 1.0), fx(8.0, 11.0, 12.2, 15.4, 1.0), fx(-4.5, -1.5, 12.2, 15.4, 1.0)],
          west=[sz(5.0, 8.2, 0, 4.0, 1.2), sz(2.0, 5.0, 12.2, 15.4, 1.0)],
          east=[sz(5.0, 8.2, 0, 4.0, 1.2), sz(8.0, 11.0, 6.7, 9.9, 1.0)])
    band(m, sh, accent, BX0, BX1, BZ0, BZ1, 4.95, 5.4)
    band(m, sh, "trim", BX0, BX1, BZ0, BZ1, 10.6, 10.9)
    band(m, sh, "stone_warm", BX0, BX1, BZ0, BZ1, 0.0, 0.7, out=0.1, name="Plinth")
    floor(m, sh, "Floor", "floor_wood", IX0, IX1, IZ0, IZ1, 0.03, 0.03, solid=False)
    # The roof: a skylight over the reading room, a hatch over the top mezzanine.
    roof(m, sh, roof_kind, BX0, BX1, BZ0, BZ1, top + 0.35, holes=[(-5.0, 5.0, 2.0, 8.0), (8.0, 9.8, 3.0, 4.8)])
    m.box(sh, "Skylight", "glass_sky", (-5.0, top + 0.1, 2.0), (5.0, top + 0.25, 8.0), unbreakable=True)
    for x in (-1.7, 1.7):
        m.strip(sh, "SkylightBar", "metal", (x - 0.06, top + 0.25, 2.0), (x + 0.06, top + 0.33, 8.0))
    # The porch: six columns, a beam across them and a low gable on top.
    po = m.group("Porch", b)
    pz = BZ0 - 3.0
    for x in (-8.5, -5.1, -1.9, 1.9, 5.1, 8.5):
        m.bev(po, "ColumnBase", "stone_warm", (x - 0.6, 0, pz - 0.6), (x + 0.6, 0.4, pz + 0.6), 0.08)
        m.cyl(po, "Column", "column", (x, 0.4, pz), 0.84, 7.8, sides=14)
        m.bev(po, "ColumnCap", "stone_warm", (x - 0.62, 8.2, pz - 0.62), (x + 0.62, 8.6, pz + 0.62), 0.1)
    m.box(po, "PorchBeam", "column", (-9.4, 8.6, pz - 0.7), (9.4, 9.5, BZ0 - 0.2))
    m.bev(po, "PorchCornice", "trim", (-9.7, 9.5, pz - 1.0), (9.7, 9.8, BZ0 - 0.2), 0.1)
    for s, tall in ((-1, "+x"), (1, "-x")):
        m.wedge(po, "Gable", "column", (min(0, s * 9.7), 9.8, pz - 0.9), (max(0, s * 9.7), 12.2, BZ0 - 0.2), tall=tall)
    m.block(po, "GableDisc", accent, (0, 10.7, pz - 0.92), (1.3, 0.06, 1.3), cols=LIE_Z, shape="cyl", sides=16, solid=False)
    lit_windows(m, sh, "x", BZ1 + 0.2, 1, [-9.0, -4.5, 0.0, 4.5, 9.0], 1.4, 3.8, arched=True)
    lit_windows(m, sh, "x", BZ1 + 0.2, 1, [3.0], 12.6, 14.6, arched=True)
    # Mezzanines: at 5.5 m along the west side and part of the back, at 11 m along the
    # east side and the back. Stairs: ground to 5.5 m against the back wall, 5.5 m to
    # 11 m against the front.
    mz = m.group("Mezzanines", b, grouped=False)
    floor(m, mz, "Mezzanine1", "floor_wood", IX0, -6.0, IZ0, IZ1, F2)
    floor(m, mz, "Mezzanine1", "floor_wood", -6.0, -1.2, 9.4, IZ1, F2)
    m.rail(mz, "Rail", "rail", (-6.0, 1.0), (-6.0, 9.4), F2, 1.0)
    m.rail(mz, "Rail", "rail", (-6.0, 9.4), (-1.2, 9.4), F2, 1.0)
    m.rail(mz, "Rail", "rail", (-1.2, 9.4), (-1.2, 11.2), F2, 1.0)
    stairs(m, mz, "StairUp", (8.0, 0, 12.3), (-1.2, F2, 12.3), SW, sides=(True, False))
    floor(m, mz, "Mezzanine2", "floor_wood", 6.0, IX1, IZ0, IZ1, F3)
    floor(m, mz, "Mezzanine2", "floor_wood", IX0, 6.0, 9.4, IZ1, F3)
    m.rail(mz, "Rail", "rail", (6.0, 1.0), (6.0, 9.4), F3, 1.0)
    m.rail(mz, "Rail", "rail", (IX0, 9.4), (6.0, 9.4), F3, 1.0)
    # (up from the west mezzanine along the front wall, to a landing that joins the east one)
    stairs(m, mz, "StairUp2", (-6.0, F2, -0.1), (3.2, F3, -0.1), SW, fill=False, sides=(False, True))
    floor(m, mz, "Landing2", "floor_wood", 3.2, 6.0, IZ0, 1.0, F3)
    m.rail(mz, "Rail", "rail", (3.2, 1.0), (6.0, 1.0), F3, 1.0)
    # The perch: hung from the roof over the hall, 4 m above the top mezzanine and with
    # no stair. The library's power weapon.
    pe = m.group("Perch", b)
    m.bev(pe, "Perch", "floor_wood", (-3.0, 14.7, 3.0), (1.0, 15.0, 6.6), 0.06)
    for x, z in ((-2.8, 3.2), (0.8, 3.2), (-2.8, 6.4), (0.8, 6.4)):
        m.strip(pe, "Hanger", "metal", (x - 0.05, 15.0, z - 0.05), (x + 0.05, top + 0.1, z + 0.05))
    m.weapon_in(pe, (-1.0, 15.0, 4.8), "rocket_launcher")
    # Shelf stacks on the ground: lanes running front to back, books on both faces.
    st = m.group("Stacks", b, grouped=False)
    books = ["books_red", "books_blue", "books_green", "books_gold"]
    for i, x in enumerate((-10.8, -8.0, 5.0, 7.8, 10.6)):
        z0, z1 = (1.6, 8.6) if x < 0 else (1.6, 8.8)
        s = m.group("Stack", st)
        m.box(s, "ShelfBody", "shelf", (x - 0.35, 0, z0), (x + 0.35, 3.2, z1), drawn=False)
        m.bev(s, "Shelf", "shelf", (x - 0.35, 0, z0), (x + 0.35, 3.2, z1), 0.06, solid=False)
        m.bev(s, "ShelfTop", "shelf", (x - 0.45, 3.2, z0 - 0.1), (x + 0.45, 3.32, z1 + 0.1), 0.04, solid=False, tint=(0.85, 0.85, 0.85))
        for j in range(3):
            for face in (-1, 1):
                x0, x1 = sorted((x + face * 0.35, x + face * 0.41))
                m.strip(s, "Books", books[(i + j) % 4], (x0, 0.35 + j * 0.95, z0 + 0.2), (x1, 1.05 + j * 0.95, z1 - 0.2))
    # Shelves along the mezzanine walls.
    m.box(st, "WallShelf", "shelf", (-13.0, F2, IZ1 - 0.6), (-7.5, F2 + 2.6, IZ1 - 0.05))
    m.strip(st, "Books", "books_red", (-12.9, F2 + 0.4, IZ1 - 0.66), (-7.6, F2 + 2.2, IZ1 - 0.6))
    m.box(st, "WallShelf", "shelf", (IX1 - 0.6, F3, 3.0), (IX1 - 0.05, F3 + 2.6, 7.4))
    m.strip(st, "Books", "books_gold", (IX1 - 0.66, F3 + 0.4, 3.1), (IX1 - 0.6, F3 + 2.2, 7.3))
    # The reading room: tables under the skylight, a lamp on each.
    for x in (-2.6, 1.4):
        table(m, st, (x - 0.7, 2.6), (x + 0.7, 6.0))
        m.dome(st, "ReadingLamp", "lamp", (x, 0.78, 4.3), (0.44, 0.3, 0.44), sides=8, solid=False)
    door_banners(m, sh, accent, 0.0, pz + 0.9, 4.6, 7.8, 3.5)
    sp = m.group("Spawns", g, grouped=False)
    m.spawn_in(sp, (-12.4, 0, 10.6), (-12.4, 0.0))           # behind the west stacks, looking down the wall lane
    m.spawn_in(sp, (-10.0, F2, 3.0), (0.0, 5.0))             # west mezzanine, looking over the hall
    m.spawn_in(sp, (10.0, F3, 6.0), (0.0, 5.0))              # top mezzanine
    m.spawn_in(sp, (5.0, 0, -8.0), (0.0, -16.0))             # the plaza, looking at the quad
    w = m.group("WeaponSpawns", g, grouped=False)
    m.weapon_in(w, (6.4, 0, 5.0), "katana")                  # a lane between the east stacks
    m.weapon_in(w, (0, 0, ZT + 2.6), "smg")                  # where the skyway lands
    m.weapon_in(w, (-8.0, F3, 11.4), "bolt_action")          # the top floor's back strip


def lecture_hall(m, g, accent, roof_kind):
    """One big room two floors high: a bowl of seating tiers climbing from the stage
    (east) to an upper concourse (west) at 5.5 m, an aisle up each side, and a projection
    booth high in the south-west corner. Its shape: a low shell of a roof over the stage."""
    b = m.group("Building", g, grouped=False)
    sh = m.group("Shell", b)
    top = 12.2
    walls(m, sh, "stone", BX0, BX1, BZ0, BZ1, 0, top,
          front=[fx(5.6, 8.8, 0, 4.2, 1.3), fx(-13.0, -10.0, F2 + 1.2, F2 + 4.4, 1.0), fx(-4.0, -1.0, 7.4, 10.6, 1.0)],
          back=[fx(6.0, 9.0, 1.2, 4.4, 1.0)],
          west=[sz(7.6, 10.6, F2, F2 + 2.8)], east=[sz(11.3, 13.3, 0, 3.6, 1.0)])
    band(m, sh, accent, BX0, BX1, BZ0, BZ1, 4.95, 5.4)
    band(m, sh, "stone_warm", BX0, BX1, BZ0, BZ1, 0.0, 0.7, out=0.1, name="Plinth")
    floor(m, sh, "Floor", "floor_wood", IX0, IX1, IZ0, IZ1, 0.03, 0.03, solid=False)
    roof(m, sh, roof_kind, BX0, BX1, BZ0, BZ1, top + 0.35, holes=[(-4.0, -2.2, 5.0, 6.8)])
    # The shell: half a flattened ball over the stage end of the roof.
    m.dome(sh, "RoofShell", roof_kind, (6.6, top + 0.35, 6.1), (13.6, 3.4, 13.6), sides=20)
    m.dome(sh, "RoofShellCap", "brass", (6.6, top + 3.65, 6.1), (1.4, 0.5, 1.4), sides=10, solid=False)
    door_banners(m, sh, accent, 7.2)
    lit_windows(m, sh, "z", BX1 + 0.2, 1, [1.5, 5.0, 8.5], 6.6, 9.6, arched=True)
    lit_windows(m, sh, "x", BZ1 + 0.2, 1, [-9.0, -4.5, 0.0], 7.0, 9.8, arched=True)
    # The stage and the giant screen.
    hall = m.group("Hall", b, grouped=False)
    m.box(hall, "Stage", "floor_wood", (9.0, 0, 1.0), (IX1, 0.6, 11.2), tint=(0.86, 0.86, 0.86))
    m.wedge(hall, "StageRamp", "stair", (7.2, 0, 4.0), (9.0, 0.6, 8.2), tall="+x")
    m.strip(hall, "ScreenFrame", "metal", (IX1 - 0.12, 1.6, 1.8), (IX1, 9.8, 10.4))
    m.strip(hall, "Screen", "screen", (IX1 - 0.2, 1.8, 2.0), (IX1 - 0.12, 9.6, 10.2))
    m.bev(hall, "Lectern", "table", (10.4, 0.6, 5.5), (11.1, 1.8, 6.7), 0.08)
    # Seven tiers, each 0.79 m up and 1.8 m deep, with a row of seats; then the concourse.
    N = 7
    CX = 5.0 - N * 1.8      # where the concourse begins
    for i in range(N):
        x1 = 5.0 - i * 1.8
        x0 = x1 - 1.8
        y = F2 * (i + 1) / N
        m.box(hall, "Tier", "stone_dark", (x0, 0, 1.0), (x1, y, 11.2))
        for z0, z1 in ((1.5, 5.6), (6.6, 10.7)):
            m.bev(hall, "Seats", "seat", (x0 + 0.3, y, z0), (x0 + 1.0, y + 0.45, z1), 0.08)
            m.bev(hall, "SeatBacks", "seat", (x0 + 0.12, y + 0.3, z0), (x0 + 0.34, y + 1.0, z1), 0.06, solid=False, tint=(0.85, 0.85, 0.85))
    floor(m, hall, "Concourse", "floor_wood", IX0, CX, IZ0, IZ1, F2, 0.3)
    m.box(hall, "ConcourseBase", "stone_dark", (IX0, 0, IZ0), (CX, F2 - 0.3, IZ1))
    # An aisle up each side wall: ground to the concourse.
    stairs(m, hall, "AisleNorth", (5.0, 0, -0.1), (CX, F2, -0.1), SW, sides=(False, True))
    stairs(m, hall, "AisleSouth", (5.0, 0, 12.3), (CX, F2, 12.3), SW, sides=(True, False))
    # The projection booth: a box in the south-west corner above the concourse, a stair
    # up to it along the west wall.
    bo = m.group("ProjectionBooth", b)
    BY = 8.8
    m.box(bo, "BoothFloor", "floor_wood", (IX0, BY - 0.3, 6.7), (-10.4, BY, IZ1))
    wall(m, bo, "BoothFront", "stone_warm", (-10.4, 6.7), (-10.4, IZ1), BY, top, 0.3, [(1.2, 5.6, BY + 0.9, BY + 2.6)])
    m.block(bo, "Projector", "equipment_dark", (-11.6, BY + 1.3, 10.0), (0.7, 1.3, 0.7), cols=LIE_X, shape="cyl", sides=10, solid=False)
    m.bev(bo, "ProjectorStand", "equipment", (-12.0, BY, 9.7), (-11.2, BY + 0.9, 10.3), 0.06)
    stairs(m, bo, "BoothStair", (-12.6, F2, 1.2), (-12.6, BY, 6.7), SW, sides=(False, True))
    # A balcony outside the west door (the door is under the booth).
    m.bev(b, "Balcony", "stone_warm", (BX0 - 2.8, F2 - 0.3, 5.8), (BX0 - 0.2, F2, 10.9), 0.08)
    m.rail(b, "BalconyRail", "rail", (BX0 - 2.7, 5.8), (BX0 - 2.7, 10.9), F2, 1.0)
    m.rail(b, "BalconyRail", "rail", (BX0 - 2.7, 5.86), (BX0 - 0.2, 5.86), F2, 1.0)
    m.rail(b, "BalconyRail", "rail", (BX0 - 2.7, 10.84), (BX0 - 0.2, 10.84), F2, 1.0)
    sp = m.group("Spawns", g, grouped=False)
    m.spawn_in(sp, (11.6, 0.6, 8.6), (0.0, 6.0))             # the stage, looking up the tiers
    m.spawn_in(sp, (-10.8, F2, 3.4), (0.0, 6.0))             # the concourse, looking down at the stage
    m.spawn_in(sp, (-12.2, BY, 11.6), (-5.0, 10.0))          # the booth, looking through its window
    m.spawn_in(sp, (15.4, 0, 6.0), (15.4, -4.0))             # the east walkway
    w = m.group("WeaponSpawns", g, grouped=False)
    m.weapon_in(w, (11.6, 0.6, 2.4), "break_action")
    m.weapon_in(w, (0, 0, ZT + 2.6), "shotgun")
    m.weapon_in(w, (-12.4, BY, 8.2), "sniper")               # the booth


def labs(m, g, accent, roof_kind):
    """Two floors. Ground: a corridor along the front and three labs behind glass walls
    that shatter when shot (never the only way through: every lab has an open door).
    Upstairs: an open lab floor with more glass, and a balcony over the door. Its shape:
    a wall of glass across the upper floor, and stacks and vents on the roof."""
    b = m.group("Building", g, grouped=False)
    sh = m.group("Shell", b)
    top = 11.6
    walls(m, sh, "stone", BX0, BX1, BZ0, BZ1, 0, top,
          front=[fx(2.0, 5.2, 0, 4.0), fx(8.0, 12.0, 1.2, 4.2), fx(2.0, 5.2, F2, F2 + 3.6),
                 fx(-12.6, -1.4, F2 + 0.9, F2 + 4.5), fx(8.0, 12.0, F2 + 1.0, F2 + 4.2)],
          back=[fx(-11.0, -8.0, 1.2, 4.2), fx(-1.5, 1.5, 1.2, 4.2), fx(8.0, 11.0, 1.2, 4.2), fx(-5.0, 5.0, F2 + 1.0, F2 + 4.2)],
          west=[sz(-0.8, 2.0, 0, 3.8), sz(7.0, 10.0, F2 + 1.0, F2 + 4.2)], east=[sz(-0.8, 2.0, 0, 3.8), sz(7.0, 10.0, F2 + 1.0, F2 + 4.2)])
    band(m, sh, accent, BX0, BX1, BZ0, BZ1, 4.95, 5.4)
    band(m, sh, "stone_warm", BX0, BX1, BZ0, BZ1, 0.0, 0.7, out=0.1, name="Plinth")
    floor(m, sh, "Floor", "floor_tile", IX0, IX1, IZ0, IZ1, 0.03, 0.03, solid=False)
    roof(m, sh, roof_kind, BX0, BX1, BZ0, BZ1, top + 0.35, holes=[(10.0, 11.8, 0.2, 2.0)])
    door_banners(m, sh, accent, 3.6, BZ0, 9.6, 11.2, 2.5)
    # The glass wall across the upper floor's front: you see through it, it does not break.
    m.box(sh, "GlassWall", "glass_window", (-12.6, F2 + 0.9, BZ0 - 0.05), (-1.4, F2 + 4.5, BZ0 + 0.05), unbreakable=True)
    for x in (-10.36, -8.12, -5.88, -3.64):
        m.strip(sh, "Mullion", "metal", (x - 0.05, F2 + 0.9, BZ0 - 0.12), (x + 0.05, F2 + 4.5, BZ0 + 0.12))
    m.strip(sh, "Mullion", "metal", (-12.6, F2 + 2.65, BZ0 - 0.1), (-1.4, F2 + 2.75, BZ0 + 0.1))
    lit_windows(m, sh, "x", BZ1 + 0.2, 1, [-11.0, 11.0], F2 + 1.2, F2 + 4.0)
    # On the roof: three stacks, two vent units and a duct.
    rf = m.group("RoofPlant", b, grouped=False)
    R = top + 0.35
    for x, z, h in ((-10.5, 10.5, 3.2), (-8.6, 10.5, 2.4), (-6.7, 10.5, 2.8)):
        m.cyl(rf, "Stack", "equipment", (x, R, z), 1.0, h, sides=12)
        m.cone(rf, "StackCap", "equipment_dark", (x, R + h + 0.25, z), 1.5, 0.5, top=0.3, sides=12, solid=False)
        m.cyl(rf, "StackNeck", "equipment_dark", (x, R + h, z), 0.5, 0.25, sides=8, solid=False)
    for x in (-2.0, 3.6):
        m.bev(rf, "VentUnit", "equipment", (x, R, 8.6), (x + 3.4, R + 1.5, 11.4), 0.14)
        m.cyl(rf, "VentFan", "equipment_dark", (x + 1.7, R + 1.5, 10.0), 1.8, 0.12, sides=14, solid=False)
    m.lying_cyl(rf, "Duct", "equipment", (-3.6, R + 0.5, 10.0), 0.8, 3.4, axis="x", sides=10)
    m.weapon_in(rf, (-6.0, R, 4.5), "laser_rifle")
    # Ground: the corridor is z -1.2..3.4; three labs behind it, a glass front on each
    # beside its open doorway, and glass between the labs.
    gl = m.group("GroundLabs", b, grouped=False)
    cz = 3.4
    # (solid posts where panes meet; each pane stops just short of the lintel so nothing rests on it)
    for x in (-11.1, -7.9, -4.6, -1.3, 1.3, 4.6, 7.9, 11.1):
        m.box(gl, "Post", "metal", (x - 0.1, 0, cz - 0.1), (x + 0.1, 3.6, cz + 0.1))
    m.box(gl, "Lintel", "metal", (IX0, 3.6, cz - 0.1), (IX1, 4.0, cz + 0.1))
    m.box(gl, "Transom", "glass_window", (IX0, 4.0, cz - 0.05), (IX1, F2 - 0.3, cz + 0.05), unbreakable=True)
    for x0, x1 in ((-11.0, -8.0), (-7.8, -4.7), (-4.5, -1.4), (1.4, 4.5), (4.7, 7.8), (8.0, 11.0)):
        m.box(gl, "LabGlass", "glass_lab", (x0, 0, cz - 0.05), (x1, 3.54, cz + 0.05))
    # (the ways in: at the west and east ends, and through the middle lab's front)
    for x in (-4.6, 4.6):
        for z in (5.8, 8.1):
            m.box(gl, "DividerPost", "metal", (x - 0.1, 0, z - 0.1), (x + 0.1, 3.6, z + 0.1))
        m.box(gl, "DividerLintel", "metal", (x - 0.1, 3.6, cz + 0.1), (x + 0.1, 4.0, 8.2))
        m.box(gl, "DividerTransom", "glass_window", (x - 0.05, 4.0, cz + 0.1), (x + 0.05, F2 - 0.3, 8.2), unbreakable=True)
        m.box(gl, "LabGlass", "glass_lab", (x - 0.05, 0, cz + 0.12), (x + 0.05, 3.54, 5.68))
        m.box(gl, "LabGlass", "glass_lab", (x - 0.05, 0, 5.92), (x + 0.05, 3.54, 7.98))
        m.box(gl, "DividerWall", "stone_warm", (x - 0.1, 0, 8.2), (x + 0.1, F2 - 0.3, IZ1))
    for x in (-9.2, 0.0, 9.2):
        counter(m, gl, (x - 2.0, 12.2), (x + 2.0, 13.3))
        m.cyl(gl, "Flask", "equipment", (x - 1.2, 1.05, 12.75), 0.5, 0.7, sides=10, solid=False)
        m.dome(gl, "FlaskTop", "glass_lab", (x - 1.2, 1.75, 12.75), (0.5, 0.3, 0.5), sides=10, solid=False)
        m.strip(gl, "Readout", "screen", (x + 0.3, 1.05, 12.9), (x + 1.3, 1.7, 13.0))
    m.cyl(gl, "Tank", "equipment_dark", (-12.6, 0, 6.5), 1.3, 2.4, sides=12)
    m.dome(gl, "TankTop", "equipment_dark", (-12.6, 2.4, 6.5), (1.3, 0.5, 1.3), sides=12, solid=False)
    m.cyl(gl, "Centrifuge", "equipment", (12.3, 0, 6.5), 1.6, 1.2, sides=14)
    m.dome(gl, "CentrifugeLid", "equipment_dark", (12.3, 1.2, 6.5), (1.6, 0.4, 1.6), sides=14, solid=False)
    # Upstairs: the stair climbs east along the corridor's front wall, to just short of the
    # front door; an open floor with two glass screens, and a balcony over the door.
    up = m.group("UpperLab", b, grouped=False)
    sx0, sx1 = -10.6, -10.6 + RUN
    floor(m, up, "Floor2", "floor_tile", IX0, IX1, IZ0, IZ1, F2, 0.3, holes=[(sx0 - 0.2, sx1, IZ0, 1.0)])
    stairs(m, up, "StairUp", (sx0, 0, -0.1), (sx1, F2, -0.1), SW, sides=(False, True))
    m.rail(up, "Rail", "rail", (sx0 - 0.2, 1.0), (sx1, 1.0), F2, 1.0)
    m.rail(up, "Rail", "rail", (sx0 - 0.2, IZ0 + 0.1), (sx0 - 0.2, 1.0), F2, 1.0)
    for x in (-5.0, 6.0):
        for z in (3.9, 7.0, 10.1):
            m.box(up, "ScreenPost", "metal", (x - 0.1, F2, z - 0.1), (x + 0.1, F2 + 3.6, z + 0.1))
        m.box(up, "LabGlass", "glass_lab", (x - 0.05, F2, 4.02), (x + 0.05, F2 + 3.3, 6.88))
        m.box(up, "LabGlass", "glass_lab", (x - 0.05, F2, 7.12), (x + 0.05, F2 + 3.3, 9.98))
    for x in (-10.0, 0.5, 10.5):
        counter(m, up, (x - 1.8, 12.2), (x + 1.8, 13.3), y=F2)
        m.bev(up, "Apparatus", "equipment_dark", (x - 0.6, F2 + 1.05, 12.45), (x + 0.6, F2 + 1.7, 13.05), 0.1, solid=False)
    m.bev(up, "Balcony", "stone_warm", (0.6, F2 - 0.3, BZ0 - 2.6), (6.6, F2, BZ0 - 0.2), 0.08)
    m.rail(up, "BalconyRail", "rail", (0.66, BZ0 - 2.5), (6.54, BZ0 - 2.5), F2, 1.0)
    m.rail(up, "BalconyRail", "rail", (0.66, BZ0 - 2.5), (0.66, BZ0 - 0.2), F2, 1.0)
    m.rail(up, "BalconyRail", "rail", (6.54, BZ0 - 2.5), (6.54, BZ0 - 0.2), F2, 1.0)
    sp = m.group("Spawns", g, grouped=False)
    m.spawn_in(sp, (-9.0, 0, 9.6), (-12.4, 3.4))             # lab 1, looking at its door
    m.spawn_in(sp, (11.0, F2, 9.0), (2.0, 6.0))              # upstairs, the east end
    m.spawn_in(sp, (-8.0, 0, -7.0), (0.0, -14.0))            # the plaza
    m.spawn_in(sp, (15.4, 0, 6.0), (15.4, -4.0))             # the east walkway, looking along it to the bridge
    w = m.group("WeaponSpawns", g, grouped=False)
    m.weapon_in(w, (9.5, F2, 4.5), "plasma_pistol")
    m.weapon_in(w, (0, 0, ZT + 2.6), "burst_rifle")


def cafeteria(m, g, accent, roof_kind):
    """A dining hall two floors high with a balcony round all four sides, a serving
    counter at the west end and big windows along the back (they look out at the planet).
    The door is west of the middle; the stair to the balcony climbs along the front wall
    east of it. Its shape: a striped awning all along the front, over a terrace."""
    b = m.group("Building", g, grouped=False)
    sh = m.group("Shell", b)
    top = 11.6
    walls(m, sh, "stone", BX0, BX1, BZ0, BZ1, 0, top,
          front=[fx(-6.0, -2.8, 0, 4.2, 1.3), fx(-12.5, -8.5, 1.2, 4.2, 1.0), fx(-9.0, -5.0, F2 + 1.2, F2 + 4.4, 1.0), fx(4.0, 8.0, F2 + 1.2, F2 + 4.4, 1.0)],
          back=[fx(-12.5, -5.5, 0.8, 4.4), fx(-3.5, 3.5, 0.8, 4.4), fx(5.5, 12.5, 0.8, 4.4), fx(-8.0, -2.0, F2 + 1.0, F2 + 4.2, 1.0), fx(2.0, 8.0, F2 + 1.0, F2 + 4.2, 1.0)],
          west=[sz(9.4, 12.4, 0, 3.8, 1.0)], east=[sz(2.6, 5.8, 0, 4.0, 1.2), sz(7.0, 10.0, F2 + 1.0, F2 + 4.2, 1.0)])
    band(m, sh, accent, BX0, BX1, BZ0, BZ1, 5.75, 6.2)
    band(m, sh, "stone_warm", BX0, BX1, BZ0, BZ1, 0.0, 0.7, out=0.1, name="Plinth")
    floor(m, sh, "Floor", "floor_tile", IX0, IX1, IZ0, IZ1, 0.03, 0.03, solid=False)
    roof(m, sh, roof_kind, BX0, BX1, BZ0, BZ1, top + 0.35, holes=[(-0.9, 0.9, 5.5, 7.3)])
    # The big windows: glass you look through but cannot break or pass.
    for x0, x1 in ((-12.5, -5.5), (-3.5, 3.5), (5.5, 12.5)):
        m.box(sh, "PictureWindow", "glass_window", (x0, 0.8, BZ1 - 0.06), (x1, 4.4, BZ1 + 0.06), unbreakable=True)
        m.strip(sh, "Mullion", "metal", ((x0 + x1) / 2 - 0.05, 0.8, BZ1 - 0.12), ((x0 + x1) / 2 + 0.05, 4.4, BZ1 + 0.12))
    lit_windows(m, sh, "z", BX0 - 0.2, -1, [1.5, 5.0], F2 + 1.2, F2 + 4.0, arched=True)
    # The awning: stripes of the building's colour and cream sloping out from the front
    # wall over the terrace, on thin posts.
    aw = m.group("Awning", b)
    n = 18
    wide = 25.2 / n
    for i in range(n):
        x0 = -12.6 + i * wide
        m.wedge(aw, "Stripe", accent if i % 2 == 0 else "awning", (x0, 4.55, BZ0 - 3.8), (x0 + wide, 5.55, BZ0 - 0.2), tall="+z")
    m.strip(aw, "AwningEdge", "brass", (-12.7, 4.47, BZ0 - 3.86), (12.7, 4.55, BZ0 - 3.74))
    for x in (-12.4, -7.4, -1.4, 4.4, 9.4, 12.4):
        m.cyl(aw, "AwningPost", "metal", (x, 0, BZ0 - 3.6), 0.14, 4.5, sides=8)
    for x in (2.0, 7.0, 11.0):
        m.cyl(aw, "CafeTable", "table", (x, 0.7, BZ0 - 2.2), 1.3, 0.08, sides=14)
        m.cyl(aw, "CafeTableLeg", "metal", (x, 0, BZ0 - 2.2), 0.16, 0.7, sides=8)
    # The balcony at 5.5 m, all the way round, open in the middle. The stair climbs along
    # the front wall, east of the door.
    ba = m.group("Balcony", b, grouped=False)
    sx0, sx1 = 10.4, 10.4 - RUN       # the stair's foot (east) and head (west)
    floor(m, ba, "Balcony", "floor_wood", IX0, IX1, IZ0, 3.2, F2, holes=[(sx1, sx0 + 0.2, IZ0, 1.0)])
    floor(m, ba, "Balcony", "floor_wood", 10.0, IX1, 3.2, 9.6, F2)
    floor(m, ba, "Balcony", "floor_wood", IX0, IX1, 9.6, IZ1, F2)
    floor(m, ba, "Balcony", "floor_wood", IX0, -10.2, 3.2, 9.6, F2)
    m.rail(ba, "Rail", "rail", (-10.2, 3.2), (10.0, 3.2), F2, 1.0)
    m.rail(ba, "Rail", "rail", (-10.2, 9.6), (10.0, 9.6), F2, 1.0)
    m.rail(ba, "Rail", "rail", (-10.2, 3.2), (-10.2, 9.6), F2, 1.0)
    m.rail(ba, "Rail", "rail", (10.0, 3.2), (10.0, 9.6), F2, 1.0)
    m.rail(ba, "Rail", "rail", (sx1, 1.0), (sx0 + 0.2, 1.0), F2, 1.0)
    m.rail(ba, "Rail", "rail", (sx0 + 0.2, IZ0 + 0.1), (sx0 + 0.2, 1.0), F2, 1.0)
    stairs(m, ba, "StairUp", (sx0, 0, -0.1), (sx1, F2, -0.1), SW, sides=(False, True))
    # Long tables (benches both sides of the front row, one side of the back one, so
    # there is room to walk all round), and the serving counter at the west end.
    hall = m.group("Hall", b, grouped=False)
    for z, bench_at in ((4.6, (-1.1, 1.1)), (9.4, (-1.1,))):
        for x in (-4.8, 3.6):
            table(m, hall, (x - 2.6, z - 0.5), (x + 2.6, z + 0.5))
            for dz in bench_at:
                m.bev(hall, "BenchSeat", "table", (x - 2.6, 0.34, z + dz - 0.2), (x + 2.6, 0.44, z + dz + 0.2), 0.03, tint=(0.85, 0.85, 0.85))
                for lx in (x - 2.2, x + 2.2):
                    m.strip(hall, "BenchLeg", "metal", (lx - 0.05, 0, z + dz - 0.16), (lx + 0.05, 0.34, z + dz + 0.16))
    counter(m, hall, (-12.8, 1.6), (-11.8, 8.2))
    m.strip(hall, "MenuBoard", "screen", (IX0, 2.4, 2.2), (IX0 + 0.08, 4.0, 7.6))
    m.strip(hall, "HeatLamp", "lamp", (-12.7, 2.2, 2.0), (-11.9, 2.3, 7.8))
    for x in (-7.0, 0.0, 7.0):   # (narrow shelves to eat at, against the windows: the balcony stays clear to walk)
        m.bev(hall, "BalconyShelf", "table", (x - 1.6, F2 + 0.95, IZ1 - 0.45), (x + 1.6, F2 + 1.05, IZ1), 0.03)
    sp = m.group("Spawns", g, grouped=False)
    m.spawn_in(sp, (9.0, 0, 11.6), (0.0, 6.0))               # by the windows, looking down the hall
    m.spawn_in(sp, (-12.0, F2, 6.0), (0.0, 6.0))             # the balcony's west end
    m.spawn_in(sp, (11.0, F2, 11.5), (0.0, 11.5))            # the back balcony
    m.spawn_in(sp, (9.0, 0, -8.5), (0.0, -16.0))             # the plaza
    w = m.group("WeaponSpawns", g, grouped=False)
    m.weapon_in(w, (-0.6, 0, 7.0), "machine_pistol")         # the aisle between the tables
    m.weapon_in(w, (0, 0, ZT + 2.6), "rifle")
    m.weapon_in(w, (-6.0, F2, 11.6), "auto_shotgun")         # the back balcony


def observatory(m, g, accent, roof_kind):
    """A square hall with the dome standing on its roof terrace. Inside the dome: the
    telescope (it turns slowly, above head height); a slit in the dome opens to the sky.
    The cap on top of the dome is a power weapon's spot. Its shape: the dome."""
    b = m.group("Building", g, grouped=False)
    sh = m.group("Shell", b)
    x0, x1, z0, z1 = -13.4, 13.4, BZ0, BZ1
    ox = lambda a, c, lo, hi, arch=0.0: fx(a, c, lo, hi, arch, west=x0)
    walls(m, sh, "stone", x0, x1, z0, z1, 0, F2,
          front=[ox(-1.6, 1.6, 0, 4.2, 1.3), ox(-9.5, -6.5, 1.2, 4.4, 1.0), ox(6.5, 9.5, 1.2, 4.4, 1.0)],
          back=[ox(8.0, 11.0, 1.2, 4.4, 1.0)],
          west=[sz(3.0, 6.2, 0, 4.0, 1.2)], east=[sz(5.0, 8.2, 0, 4.0, 1.2)])
    band(m, sh, accent, x0, x1, z0, z1, 4.5, 4.95)
    band(m, sh, "stone_warm", x0, x1, z0, z1, 0.0, 0.7, out=0.1, name="Plinth")
    floor(m, sh, "Floor", "floor_tile", x0 + 0.2, x1 - 0.2, z0 + 0.2, z1 - 0.2, 0.03, 0.03, solid=False)
    door_banners(m, sh, accent, 0.0, z0, 4.6, 5.4, 2.6)
    # The terrace (the hall's roof). The stair climbs west along the back wall and comes
    # out in the terrace's back corner, west of the dome.
    T = F2 + 0.3
    foot, head = 1.1, -8.6
    # (the hole starts where the stair still has 2.4 m of headroom under the terrace)
    floor(m, sh, "Terrace", "paving", x0 - 0.2, x1 + 0.2, z0 - 0.2, z1 + 0.2, T, 0.3, holes=[(head, -4.0, 11.2, z1 - 0.2)])
    stairs(m, sh, "StairUp", (foot, 0, 12.3), (head, T, 12.3), SW, sides=(True, False))
    low_wall(m, sh, (x0 - 0.05, z0 - 0.05), (x1 + 0.05, z0 - 0.05), T, 0.9, holes=[(4.0, 7.0)])
    low_wall(m, sh, (x0 - 0.05, z1 + 0.05), (x1 + 0.05, z1 + 0.05), T, 0.9)
    low_wall(m, sh, (x0 - 0.05, z0 + 0.1), (x0 - 0.05, z1 - 0.1), T, 0.9)
    low_wall(m, sh, (x1 + 0.05, z0 + 0.1), (x1 + 0.05, z1 - 0.1), T, 0.9, holes=[(1.5, 4.5)])
    m.rail(sh, "Rail", "rail", (head, 11.2), (-4.0, 11.2), T, 1.0)
    m.rail(sh, "Rail", "rail", (-4.0, 11.2), (-4.0, z1 - 0.3), T, 1.0)
    counter(m, sh, (-12.0, 9.0), (-7.4, 10.0))
    m.cyl(sh, "OrreryBase", "equipment_dark", (-6.0, 0, 5.0), 1.6, 1.0, sides=12)
    m.block(sh, "OrreryRing", "brass", (-6.0, 1.9, 5.0), (3.0, 0.08, 3.0), shape="tube", sides=20, inner=2.7, solid=False)
    m.block(sh, "OrreryRing", "brass", (-6.0, 1.9, 5.0), (2.1, 0.08, 2.1), cols=((0.9, 0.44, 0), (-0.44, 0.9, 0), (0, 0, 1)), shape="tube", sides=18, inner=1.85, solid=False)
    for kind, base, size in (("lamp", (-6.0, 1.9, 5.0), 0.7), ("accent_teal", (-4.6, 1.95, 5.3), 0.32), ("accent_red", (-6.6, 1.95, 4.2), 0.26)):
        m.dome(sh, "OrreryBall", kind, base, (size, size / 2, size), sides=8, solid=False)
        m.dome(sh, "OrreryBall", kind, base, (size, size / 2, size), sides=8, flip=True, solid=False)
    m.cyl(sh, "OrreryStem", "brass", (-6.0, 1.0, 5.0), 0.14, 0.6, sides=6, solid=False)
    lit_windows(m, sh, "z", x1 + 0.2, 1, [0.6, 10.6], 1.4, 3.8, arched=True)
    # The dome: a twenty-sided drum on the terrace and half a ball on top of it, a real
    # shell you stand inside. One wall piece in four is glass; the slit is open from the
    # terrace to the top.
    C = (5.0, 6.0)       # the dome's middle on the terrace (x, z)
    dm = m.group("Dome", b, grouped=False)
    R, n = 6.4, 20
    H = 4.2              # the drum's height
    seg = 2 * R * math.tan(math.pi / n) + 0.06
    door_side = 15      # the wall piece facing west (toward the stair): the way in
    slit_side = 2
    for i in range(n):
        deg = i * 360.0 / n
        if i == slit_side:
            continue    # the slit: open from the terrace to the top
        px, _py, pz = polar(R, deg)
        cols = rot(deg)
        if i == door_side:
            m.block(dm, "DrumLintel", "stone", (C[0] + px, T + 3.6, C[1] + pz), (seg, 1.2, 0.4), cols=cols)
        elif i % 4 == 0:
            m.block(dm, "DrumSill", "stone", (C[0] + px, T + 0.5, C[1] + pz), (seg, 1.0, 0.4), cols=cols)
            m.block(dm, "DomeGlass", "glass_sky", (C[0] + px, T + 2.1, C[1] + pz), (seg, 2.2, 0.12), cols=cols, unbreakable=True)
            m.block(dm, "DrumLintel", "stone", (C[0] + px, T + 3.7, C[1] + pz), (seg, 1.0, 0.4), cols=cols)
        else:
            m.block(dm, "Drum", "stone", (C[0] + px, T + H / 2, C[1] + pz), (seg, H, 0.4), cols=cols)
        bx, _by, bz = polar(R + 0.24, deg)
        m.block(dm, "DrumBand", accent, (C[0] + bx, T + H - 0.35, C[1] + bz), (seg, 0.4, 0.08), cols=cols, solid=False)
    m.block(dm, "DomeRing", "brass", (C[0], T + H + 0.1, C[1]), (2 * R + 1.0, 0.24, 2 * R + 1.0), shape="tube", sides=n, inner=2 * R - 0.5,
            cols=rot(9.0), solid=False)
    m.block(dm, "DomeShell", "dome_copper", (C[0], T + H + 3.3, C[1]), (2 * R + 0.4, 6.6, 2 * R + 0.4), cols=rot(slit_side * 360.0 / n),
            shape="dome", sides=n, inner=2 * R - 0.4, arc=360.0 - 360.0 / n)
    apex = T + H + 6.6
    m.cyl(dm, "DomeCap", "brass", (C[0], apex - 0.3, C[1]), 3.4, 0.4, sides=14)
    m.weapon_in(dm, (C[0] - 0.9, apex + 0.1, C[1]), "railgun")
    # Inside: the telescope's pier, and the telescope turning on it.
    m.cyl(dm, "Pier", "equipment_dark", (C[0], T, C[1]), 1.9, 2.8, sides=12)
    m.cyl(dm, "PierCap", "brass", (C[0], T + 2.8, C[1]), 2.4, 0.25, sides=12, solid=False)
    scope = m.node("Telescope", dm, "spinner", [("transform", xform(IDENTITY, (C[0], T + 3.6, C[1]))), ("speed", "5.0")])
    tilt = ((1, 0, 0), (0, 0.5, 0.866), (0, -0.866, 0.5))   # its own y (the tube's length) tipped 60 degrees toward +z
    m.block(scope, "Tube", "telescope", (0, 1.1, 1.9), (1.4, 5.8, 1.4), cols=tilt, shape="cyl", sides=12, solid=False)
    m.block(scope, "Hood", "equipment_dark", (0, 2.5, 4.3), (1.6, 0.7, 1.6), cols=tilt, shape="cyl", sides=12, solid=False)
    m.block(scope, "Eyepiece", "brass", (0, -0.35, -0.65), (0.6, 0.9, 0.6), cols=tilt, shape="cyl", sides=8, solid=False)
    m.block(scope, "Fork", "equipment", (0, -0.2, 0), (2.4, 0.6, 0.9), shape="bevel", bevel=0.1, solid=False)
    m.block(scope, "Counterweight", "equipment_dark", (0, -0.2, -1.7), (1.0, 1.0, 1.0), cols=tilt, shape="cyl", sides=10, solid=False)
    sp = m.group("Spawns", g, grouped=False)
    m.spawn_in(sp, (9.0, 0, 2.0), (0.0, 6.0))                # the hall
    m.spawn_in(sp, (-9.0, T, 2.0), (-9.0, -12.0))            # the terrace, west of the dome, looking at the quad
    m.spawn_in(sp, (-3.4, T, 6.0), (-8.0, -10.0))            # the terrace by the dome's door, looking out over the plaza
    m.spawn_in(sp, (-8.0, 0, -7.0), (0.0, -14.0))            # the plaza
    w = m.group("WeaponSpawns", g, grouped=False)
    m.weapon_in(w, (-9.0, 0, 3.0), "battle_rifle")
    m.weapon_in(w, (0, 0, ZT + 2.6), "revolver")
    m.weapon_in(w, (-11.0, T, 7.5), "harpoon_gun")           # the terrace


BUILDINGS = {"Observatory": observatory, "Labs": labs, "LectureHall": lecture_hall, "Cafeteria": cafeteria, "Library": library}


# ---------------------------------------------------------------------------
# The event, and the bots' crossings

def event(m):
    lit = 'PackedStringArray("window_lit", "lamp")'
    m.node("Layout", ".", "layout", [
        ("layouts", 'PackedStringArray("Hub", "Ring")'), ("hold_time", "60.0"), ("windup_time", "5.0"), ("move_time", "4.0"),
        ("tick_from", "Vector3(0, %s, 0)" % fmt(CLOCK_Y)),
        ("sun_direction", "Vector3(-0.93, 0.19, 0.31)"), ("sun_color", "Color(1, 0.5, 0.26, 1)"), ("sun_energy", "1.05"),
        ("ambient_color", "Color(0.66, 0.5, 0.62, 1)"), ("ambient_energy", "0.8"),
        ("lit_kinds", lit), ("lit_glow", "2.6"),
        ("flare_kinds", 'PackedStringArray("engine")'), ("flare_gain", "3.5"),
        ("scraps", "320"), ("scrap_volume", "AABB(-58, -22, -58, 116, 52, 116)"),
    ], type_="Node")


def crossings(m, islands):
    """Ring layout: how bots get up to the quad (the grapple, off the banner mast that
    stands 18 degrees round from their island) and back down (a run off the rim on the
    island's other side, clear of its stepping stone, to the deck below). People need no
    telling."""
    marks = m.group("BotLandings", "Quad", grouped=False)
    for i, (name, deg, _a, _r) in enumerate(ISLANDS):
        ring = deg + SWING                      # where this island is in the Ring layout
        g = islands[name]
        land_up = m.node("Up" + name, marks, None, [("transform", xform(IDENTITY, polar(8.4, ring + 18.0)))], type_="Marker3D")
        m.node("ToQuad", g, "link", [("transform", xform(IDENTITY, (4.2, 0, -9.5))), ("how", "0"), ("layout", "1"),
                                     ("hook", 'NodePath("../../Quad/Rim/Planter%s/Hook%d")' % ("" if i == 0 else str(i + 1), i + 1)),
                                     ("landing", 'NodePath("../../%s")' % land_up)], type_="Marker3D")
        down = m.node("Down" + name, g, None, [("transform", xform(IDENTITY, (-3.6, 0, -10.5)))], type_="Marker3D")
        off = polar(QUAD_R - 1.4, ring - 16.0)
        m.node("From" + name, "Quad", "link", [("transform", xform(IDENTITY, off)), ("how", "1"), ("layout", "1"),
                                               ("landing", 'NodePath("../../%s")' % down)], type_="Marker3D")


def build(path):
    m = CirrusMap("Cirrus", PAL,
                  {"lines": ["ambient_light_source = 2", "ambient_light_color = Color(1, 0.9, 0.74, 1)",
                             "ambient_light_energy = 0.82", "reflected_light_source = 1", "tonemap_mode = 2",
                             "tonemap_white = 3.2", "glow_enabled = true", "glow_intensity = 0.7", "glow_bloom = 0.06"]},
                  (36.0, 236.0, (1.0, 0.88, 0.66), 1.3),
                  {"face_shade": "Vector3(0.9, 0.8, 0.66)", "kill_height": "-42.0",
                   "bounds": "Rect2(-72, -72, 144, 144)", "swing_point": "Vector3(0, 24, 0)", "winding_floors": "true"})
    quad(m)
    skyways(m)
    stones(m)
    islands = {}
    for name, deg, accent, roof_kind in ISLANDS:
        islands[name] = island(m, name, deg, accent, roof_kind, BUILDINGS[name])
    # Stepping-stone pickups (the stones never move).
    for (name, deg, _a, _r), weapon in zip(ISLANDS, ("crossbow", None, "grenade_launcher", None, "lever_action")):
        if weapon:
            m.weapon(polar(STONE_R - 0.9, deg + 36.0, 0.6), weapon)
    event(m)
    crossings(m, islands)
    m.write(path)
    write_palette(path.replace("game/maps/", "game/maps/palettes/").replace(".tscn", ".tres"))
