"""Writes an arena map scene (game/maps/*.tscn) from a short Python description.

Used to make the first version of the Rail Yard, Lost Temple and Neon Arcade maps
(tools/arena/build_arena_maps.py). The scenes it writes are ordinary map scenes: one
group per object (so a click in the editor picks the whole train or staircase),
MapBlocks inside, MapSpawns, MapWeaponSpawns and Label3D signs. After this, edit them
in Godot. Running the builder again overwrites them, so only do that before hand edits.

Coordinates are metres in the map's frame: x east, y up, z south. Inside a group,
positions are in the group's own frame (a group can be moved and turned about y).
"""
import math

SCRIPTS = {
    "root": "res://game/arena/map_root.gd",
    "block": "res://game/arena/map_block.gd",
    "spawn": "res://game/arena/map_spawn.gd",
    "weapon": "res://game/arena/map_weapon_spawn.gd",
}

IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def fmt(v):
    v = round(float(v), 4)
    if v == int(v):
        return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")


def vec(v):
    return "Vector3(%s)" % ", ".join(fmt(x) for x in v)


def color(c):
    c = list(c) + [1] * (4 - len(c))
    return "Color(%s)" % ", ".join(fmt(x) for x in c)


def xform(cols, origin):
    X, Y, Z = cols
    rows = []
    for i in range(3):
        rows += [X[i], Y[i], Z[i]]
    return "Transform3D(%s)" % ", ".join(fmt(v) for v in rows + list(origin))


def yaw_cols(yaw):
    """Basis turned left (counter-clockwise seen from above) by `yaw` radians."""
    c, s = math.cos(yaw), math.sin(yaw)
    return ((c, 0, -s), (0, 1, 0), (s, 0, c))


def norm(v):
    l = math.sqrt(sum(x * x for x in v)) or 1.0
    return tuple(x / l for x in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def facing(at, toward):
    """Yaw of a node at `at` whose front (-z) looks toward the point `toward` (x, z)."""
    dx, dz = toward[0] - at[0], toward[-1] - at[2]
    # front = -Z = (dx, dz) normalised, so Z = (-dx, -dz): yaw = atan2(Z.x, Z.z)
    return math.atan2(-dx, -dz)


class Node:
    __slots__ = ("name", "type", "parent", "props", "script", "group")

    def __init__(self, name, type_, parent, props, script, group):
        self.name, self.type, self.parent = name, type_, parent
        self.props, self.script, self.group = props, script, group


class Map:
    def __init__(self, root_name, palette_res, env, sun, settings):
        """env: Environment settings (list of "key = value" lines) and sky colours (dict).
        sun: (elevation degrees, azimuth degrees from north toward east, colour, energy).
        settings: MapRoot properties as text (bounds, kill_height, swing_point, face_shade)."""
        self.root = root_name
        self.palette = palette_res
        self.env = env
        self.sun = sun
        self.settings = settings
        self.nodes = []
        self.names = {}
        self.spawn_count = 0
        self.weapon_count = 0
        for g in ("Spawns", "WeaponSpawns", "Signs"):
            self._add(g, "Node3D", ".", [], None, False)

    # -- nodes -------------------------------------------------------------
    def _add(self, name, type_, parent, props, script, group):
        key = (parent, name)
        n = self.names.get(key, 0) + 1
        self.names[key] = n
        if n > 1:
            name = "%s%d" % (name, n)
        self.nodes.append(Node(name, type_, parent, props, script, group))
        return name if parent == "." else parent + "/" + name

    def group(self, name, parent=".", at=None, yaw=0.0, grouped=True):
        """A plain Node3D. grouped: one click in the editor selects all of it."""
        props = []
        if at is not None or yaw:
            props.append(("transform", xform(yaw_cols(yaw), at or (0, 0, 0))))
        return self._add(name, "Node3D", parent, props, None, grouped)

    def folder(self, name, parent="."):
        """A plain Node3D that only sorts the scene tree (its children are the objects)."""
        return self.group(name, parent, grouped=False)

    def block(self, parent, name, kind, center, size, cols=IDENTITY, solid=True, drawn=True,
              shape="box", tint=None, sides=None, inner=None, unbreakable=False):
        props = [("transform", xform(cols, center))]
        if shape != "box":
            props.append(("shape", {"cyl": "1", "tube": "2"}[shape]))
        props.append(("size", vec(size)))
        props.append(("kind", '"%s"' % kind))
        if not solid:
            props.append(("solid", "false"))
        if not drawn:
            props.append(("drawn", "false"))
        if unbreakable:
            props.append(("breakable", "2"))   # MapBlock.Breakable.NO
        if tint:
            props.append(("tint", color(tint)))
        if sides:
            props.append(("sides", str(sides)))
        if inner:
            props.append(("inner", fmt(inner)))
        return self._add(name, "Node3D", parent, props, "block", False)

    def box(self, parent, name, kind, lo, hi, **kw):
        """An axis-lined box from corner `lo` (x, y, z) to corner `hi`."""
        c = tuple((a + b) * 0.5 for a, b in zip(lo, hi))
        s = tuple(abs(b - a) for a, b in zip(lo, hi))
        return self.block(parent, name, kind, c, s, **kw)

    def cyl(self, parent, name, kind, base, diameter, height, sides=12, **kw):
        """An upright cylinder standing on `base` (x, y, z)."""
        c = (base[0], base[1] + height * 0.5, base[2])
        return self.block(parent, name, kind, c, (diameter, height, diameter), shape="cyl", sides=sides, **kw)

    def lying_cyl(self, parent, name, kind, center, diameter, length, axis="x", sides=12, **kw):
        """A cylinder lying along x or z (a log, a tank, a fallen column)."""
        if axis == "x":
            cols = ((0, -1, 0), (1, 0, 0), (0, 0, 1))   # its own y (the length) along world x
        else:
            cols = ((1, 0, 0), (0, 0, 1), (0, -1, 0))   # its own y along world z
        return self.block(parent, name, kind, center, (diameter, length, diameter), cols=cols, shape="cyl", sides=sides, **kw)

    def slab(self, parent, name, kind, a, b, width, thick=0.4, **kw):
        """A sloped slab whose top runs from point `a` to point `b` (each x, y, z), `width` wide."""
        d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        Z = norm(d)
        Y = norm(cross(Z, norm(cross((0, 1, 0), Z))))   # up, square to the slope
        if Y[1] < 0:
            Y = tuple(-v for v in Y)
        X = cross(Y, Z)
        L = math.sqrt(sum(v * v for v in d))
        mid = tuple((p + q) * 0.5 - y * thick * 0.5 for p, q, y in zip(a, b, Y))
        return self.block(parent, name, kind, mid, (width, thick, L), cols=(X, Y, Z), **kw)

    def stairs(self, parent, name, a, b, width, kind="stair", side=None, rise=0.25, base=None, fill=False, cheeks=(True, True),
               cheek_stop=0.0):
        """A staircase from `a` (bottom of the first step) to `b` (top landing edge): an invisible
        solid ramp to walk (and for the bots' navigation mesh) under drawn steps you see.
        `side`: a kind for the cheeks along both sides. `base`: how low the step boxes reach.
        `fill`: solid invisible boxes under the ramp, so nobody walks in under a big stair.
        `cheeks`: which of the two cheeks to make (north or west one, south or east one): leave
        out the one against a wall, or it lies in the wall's face and flickers. `cheek_stop`:
        how far short of the top landing edge the cheeks end (when a railing or a beam's face
        is in line with that edge)."""
        g = self.group(name, parent)
        self.slab(g, "Ramp", kind, a, b, width, thick=0.3, drawn=False, unbreakable=True)
        lo, hi = (a, b) if a[1] < b[1] else (b, a)
        n = max(1, int(math.ceil((hi[1] - lo[1]) / rise - 1e-6)))
        floor_y = lo[1] if base is None else base
        dx, dz = hi[0] - lo[0], hi[2] - lo[2]
        along_x = abs(dx) >= abs(dz)
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            top = lo[1] + (hi[1] - lo[1]) * t1
            p0 = (lo[0] + dx * t0, lo[2] + dz * t0)
            p1 = (lo[0] + dx * t1, lo[2] + dz * t1)
            if along_x:
                x0, x1 = sorted((p0[0], p1[0]))
                z0, z1 = lo[2] - width / 2, lo[2] + width / 2
            else:
                z0, z1 = sorted((p0[1], p1[1]))
                x0, x1 = lo[0] - width / 2, lo[0] + width / 2
            self.box(g, "Step", kind, (x0, floor_y, z0), (x1, top, z1), solid=False)
            if fill and top - rise - 0.1 > floor_y + 0.2:
                self.box(g, "Fill", kind, (x0, floor_y, z0), (x1, top - rise - 0.1, z1), drawn=False, unbreakable=True)
            if side:
                if along_x:
                    c0, c1 = (max(x0, hi[0] + cheek_stop), x1) if dx < 0 else (x0, min(x1, hi[0] - cheek_stop))
                    for zz, on in zip((z0 - 0.15, z1 + 0.15), cheeks):
                        if on:
                            self.box(g, "Side", side, (c0, floor_y, zz - 0.15), (c1, top + 0.35, zz + 0.15), solid=False)
                else:
                    c0, c1 = (max(z0, hi[2] + cheek_stop), z1) if dz < 0 else (z0, min(z1, hi[2] - cheek_stop))
                    for xx, on in zip((x0 - 0.15, x1 + 0.15), cheeks):
                        if on:
                            self.box(g, "Side", side, (xx - 0.15, floor_y, c0), (xx + 0.15, top + 0.35, c1), solid=False)
        return g

    def wall(self, parent, name, kind, a, b, y0, y1, thick, holes=(), **kw):
        """A straight wall along x or z from (x, z) `a` to `b`, from height y0 to y1, with
        openings: holes are (from, to, bottom, top) in metres along the wall from its west or north end."""
        along_x = abs(b[0] - a[0]) >= abs(b[1] - a[1])
        length = abs(b[0] - a[0]) if along_x else abs(b[1] - a[1])
        start = min(a[0], b[0]) if along_x else min(a[1], b[1])
        line = a[1] if along_x else a[0]

        def piece(u0, u1, v0, v1, label):
            if u1 - u0 < 0.01 or v1 - v0 < 0.01:
                return
            if along_x:
                lo, hi = (start + u0, v0, line - thick / 2), (start + u1, v1, line + thick / 2)
            else:
                lo, hi = (line - thick / 2, v0, start + u0), (line + thick / 2, v1, start + u1)
            self.box(parent, label, kind, lo, hi, **kw)

        holes = sorted(holes)
        u = 0.0
        for (h0, h1, hb, ht) in holes:
            piece(u, h0, y0, y1, name)
            piece(h0, h1, y0, hb, name + "Sill")
            piece(h0, h1, ht, y1, name + "Lintel")
            u = h1
        piece(u, length, y0, y1, name)

    def rail(self, parent, name, kind, a, b, y, height=1.1, thick=0.12, holes=(), **kw):
        """A railing (a low wall) along x or z with gaps: holes are (from, to) along it."""
        self.wall(parent, name, kind, a, b, y, y + height, thick, [(h0, h1, y, y + height) for h0, h1 in holes], **kw)

    # -- details: drawn only, never solid --------------------------------------
    # Two surfaces of different colours in one plane flicker, so a detail always stands
    # proud of the face it is on (paint on a floor is 2 cm thick), and two details that
    # overlap stand out by different amounts. tests/map_flicker_test.gd checks it.
    def strip(self, parent, name, kind, lo, hi, **kw):
        """A drawn-only box from corner `lo` to corner `hi`: paint, trim, a lamp, a rod."""
        return self.box(parent, name, kind, lo, hi, solid=False, **kw)

    def on_wall(self, parent, name, kind, axis, face, out, u0, u1, y0, y1, depth=0.1, lift=0.0, **kw):
        """A drawn-only piece on a wall. `axis` "x": the wall runs along x and `face` is its
        z; "z": it runs along z and `face` is its x. `out` (+1 or -1) is the way the wall
        faces. The piece covers u0..u1 along the wall and y0..y1, and stands `depth` proud
        (starting `lift` off the face: on top of another piece). Its back lies against the
        wall and never goes into it, so on a wall that breaks it never holds the wall up."""
        a = face + out * lift
        b = face + out * (lift + depth)
        if axis == "x":
            return self.strip(parent, name, kind, (u0, y0, min(a, b)), (u1, y1, max(a, b)), **kw)
        return self.strip(parent, name, kind, (min(a, b), y0, u0), (max(a, b), y1, u1), **kw)

    def rod(self, parent, name, kind, a, b, thick=0.08, wide=None, **kw):
        """A drawn-only bar from point `a` to point `b` at any angle: a brace, a cable, a rung."""
        d = tuple(q - p for p, q in zip(a, b))
        L = math.sqrt(sum(v * v for v in d))
        Z = norm(d)
        ref = (0, 1, 0) if abs(Z[1]) < 0.95 else (1, 0, 0)
        X = norm(cross(ref, Z))
        Y = cross(Z, X)
        mid = tuple((p + q) * 0.5 for p, q in zip(a, b))
        return self.block(parent, name, kind, mid, (wide or thick, thick, L), cols=(X, Y, Z), solid=False, **kw)

    def pipe(self, parent, name, kind, a, b, diameter=0.2, sides=8, inner=None, **kw):
        """A drawn-only round bar (or, with `inner`, a hoop or a hollow pipe) from `a` to `b`."""
        d = tuple(q - p for p, q in zip(a, b))
        L = math.sqrt(sum(v * v for v in d))
        Y = norm(d)
        ref = (1, 0, 0) if abs(Y[0]) < 0.95 else (0, 0, 1)
        Z = norm(cross(ref, Y))
        X = cross(Y, Z)
        mid = tuple((p + q) * 0.5 for p, q in zip(a, b))
        return self.block(parent, name, kind, mid, (diameter, L, diameter), cols=(X, Y, Z), solid=False,
                          shape="tube" if inner else "cyl", sides=sides, inner=inner, **kw)

    # -- players and pickups -------------------------------------------------
    def spawn(self, pos, toward=(0, 0)):
        self.spawn_count += 1
        props = [("transform", xform(yaw_cols(facing(pos, toward)), pos))]
        self._add("Spawn%d" % self.spawn_count, "Marker3D", "Spawns", props, "spawn", False)

    def weapon(self, pos, weapon):
        self.weapon_count += 1
        props = [("transform", xform(IDENTITY, pos)), ("weapon", '"%s"' % weapon)]
        self._add("%s%d" % (weapon.title().replace("_", ""), self.weapon_count), "Marker3D", "WeaponSpawns", props, "weapon", False)

    def sign(self, text, pos, yaw=0.0, size=96, col=(1, 1, 1, 1), parent="Signs", pixel=0.01, outline=True, flat=False,
             one_sided=False):
        """A Label3D; it reads from its +z side (yaw turns it). flat: it lies on a floor, read
        from above (its top toward -z before yaw), and takes the map's light like paint.
        one_sided: not drawn from behind (for a sign on a board or a wall)."""
        cols = yaw_cols(yaw)
        if flat:
            X, _, Z = cols
            cols = (X, tuple(-v for v in Z), (0, 1, 0))
        props = [("transform", xform(cols, pos)), ("pixel_size", fmt(pixel)), ("modulate", color(col))]
        if flat:
            props.append(("shaded", "true"))
        if flat or one_sided:
            props.append(("double_sided", "false"))
        if outline:
            props += [("outline_size", "14"), ("outline_modulate", "Color(0.05, 0.05, 0.08, 1)")]
        props += [("text", '"%s"' % text.replace('"', "'")), ("font_size", str(size))]
        self._add("Sign_" + "".join(ch for ch in text.title() if ch.isalnum())[:24], "Label3D", parent, props, None, False)

    # -- writing -------------------------------------------------------------
    def write(self, path):
        ids = {}
        out = ["[gd_scene format=3]", ""]
        for i, (k, p) in enumerate(SCRIPTS.items()):
            ids[k] = "%d_%s" % (i + 1, k)
            out.append('[ext_resource type="Script" path="%s" id="%s"]' % (p, ids[k]))
        out.append('[ext_resource type="Resource" path="%s" id="pal"]' % self.palette)
        out.append("")
        sky = self.env["sky"]
        out.append('[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_1"]')
        for k in ("sky_top_color", "sky_horizon_color", "ground_bottom_color", "ground_horizon_color"):
            out.append("%s = %s" % (k, color(sky[k])))
        out.append("")
        out.append('[sub_resource type="Sky" id="Sky_1"]')
        out.append('sky_material = SubResource("ProceduralSkyMaterial_1")')
        out.append("")
        out.append('[sub_resource type="Environment" id="Environment_1"]')
        out.append("background_mode = 2")
        out.append('sky = SubResource("Sky_1")')
        out += self.env["lines"]
        out.append("")
        out.append('[node name="%s" type="Node3D"]' % self.root)
        out.append('script = ExtResource("%s")' % ids["root"])
        out.append('palette = ExtResource("pal")')
        for k, v in self.settings.items():
            out.append("%s = %s" % (k, v))
        out.append("")
        out.append('[node name="Environment" type="WorldEnvironment" parent="."]')
        out.append('environment = SubResource("Environment_1")')
        out.append("")
        elev, azim, col, energy = self.sun
        e, az = math.radians(elev), math.radians(azim)
        to_sun = (math.sin(az) * math.cos(e), math.sin(e), -math.cos(az) * math.cos(e))
        Z = norm(to_sun)                 # the light shines along -Z
        X = norm(cross((0, 1, 0), Z))
        Y = cross(Z, X)
        out.append('[node name="Sun" type="DirectionalLight3D" parent="."]')
        out.append("transform = %s" % xform((X, Y, Z), (0, 0, 0)))
        out.append("light_color = %s" % color(col))
        out.append("light_energy = %s" % fmt(energy))
        out.append("shadow_enabled = true")
        out.append("directional_shadow_max_distance = 180.0")
        out.append("")
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
        print("wrote %s: %d nodes, %d spawns, %d weapon pickups" % (path, len(self.nodes), self.spawn_count, self.weapon_count))


def palette(path, colors, glow=None, breakable=None, roughness=0.85, surface=None):
    """Writes a MapPalette resource (game/maps/palettes/*.tres)."""
    out = ['[gd_resource type="Resource" script_class="MapPalette" format=3]', "",
           '[ext_resource type="Script" path="res://game/arena/map_palette.gd" id="1_pal"]', "", "[resource]",
           'script = ExtResource("1_pal")']

    def dict_lines(name, typ, d, conv):
        lines = ['"%s": %s' % (k, conv(d[k])) for k in sorted(d)]
        return "%s = Dictionary[String, %s]({\n%s\n})" % (name, typ, ",\n".join(lines))

    out.append(dict_lines("colors", "Color", colors, color))
    if glow:
        out.append(dict_lines("glow", "float", glow, lambda v: fmt(float(v)) if float(v) != int(v) else "%s.0" % int(v)))
    if surface:
        out.append(dict_lines("surface", "String", surface, lambda v: '"%s"' % v))
    if roughness != 0.85:
        out.append("roughness = %s" % fmt(roughness))
    if breakable:
        out.append(dict_lines("breakable", "float", breakable, lambda v: "%s.0" % int(v) if float(v) == int(v) else fmt(v)))
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")
