"""Lays out a race course as a Godot map scene (game/maps/*.tscn).

Used to make the first version of the race maps: tools/race/build_race_maps.py
describes each course as a run of sections (gaps, wall runs, a chimney, grapple
beams...) and this file turns them into MapBlocks, checkpoints, hazards, movers
and the bots' route, grouped one object per group like the other maps.

The scenes it writes are ordinary map scenes: after this, edit them in Godot.
Running the builder again overwrites them, so only do that before hand edits.

Frame: a cursor walks the course. It sits on the floor at the far edge of what
has been built so far, facing the way racers run (F); R is to its right. Section
code places things in (f, y, r): metres forward from the cursor, up from the
cursor's floor, and right.
"""
import math

ACTIONS = ["RUN", "JUMP", "LONG_JUMP", "DIVE_JUMP", "FLIP_DIVE", "SLIDE", "CRAWL", "WALL_RUN",
           "WALL_JUMP", "CHIMNEY", "GRAPPLE", "WAIT_GROUND", "WAIT_CLEAR", "WALK", "BOOST_JUMP", "BOOST_UP",
           "FLOAT_JUMP"]
HEADINGS = [(1, 0, 0), (0, 0, 1), (-1, 0, 0), (0, 0, -1)]   # turning right steps forward through these


def fmt(v):
    v = round(float(v), 4)
    if v == int(v):
        return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")


def vec(v):
    return "Vector3(%s)" % ", ".join(fmt(x) for x in v)


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def mul(a, s):
    return tuple(x * s for x in a)


class Node:
    def __init__(self, name, type_, parent, props=None, script=None, group=False):
        self.name, self.type, self.parent = name, type_, parent
        self.props = props or []
        self.script = script
        self.group = group


class Course:
    def __init__(self, root_name, palette, env, sun, start, heading=0, width=8.0):
        self.root = root_name
        self.palette = palette
        self.env = env      # dict of Environment settings (text lines)
        self.sun = sun      # (transform rows tuple, color, energy)
        self.nodes = []
        self.names = {}
        self.pos = tuple(start)
        self.h = heading
        self.W = width
        self.min_y = start[1]
        self.max_y = start[1]
        self.gate_count = 0
        self.points = []
        self.extent = [start[0], start[2], start[0], start[2]]
        self.kill_margin = 8.0
        self.settings = {}
        self.add_node("Course", "Node3D", ".")
        self.add_node("Checkpoints", "Node3D", ".")
        self.add_node("BotRoute", "Node3D", ".")
        self.add_node("Spawns", "Node3D", ".")
        self.add_node("Scenery", "Node3D", ".")
        self.add_node("Signs", "Node3D", ".")

    # -- frame -------------------------------------------------------------
    @property
    def F(self):
        return HEADINGS[self.h % 4]

    @property
    def R(self):
        f = self.F
        return (-f[2], 0, f[0])

    def w(self, f, y=0.0, r=0.0):
        p = add(self.pos, mul(self.F, f))
        p = add(p, mul(self.R, r))
        return (p[0], p[1] + y, p[2])

    def local_vec(self, f, y, r):
        """A course-frame offset as a world offset."""
        return add(add(mul(self.F, f), mul(self.R, r)), (0, y, 0))

    def basis(self, pitch=0.0, yaw=0.0):
        """Columns X, Y, Z of a node facing forward (its -z along F), pitched nose-up by `pitch`
        radians and turned left by `yaw` radians."""
        F = self.F
        R = self.R
        if yaw:
            c, s = math.cos(yaw), math.sin(yaw)
            F, R = (F[0] * c - R[0] * s, 0, F[2] * c - R[2] * s), (R[0] * c + F[0] * s, 0, R[2] * c + F[2] * s)
        up = (0, 1, 0)
        Z = mul(F, -1)
        c, s = math.cos(pitch), math.sin(pitch)
        Y = add(mul(up, c), mul(F, -s))
        Z = add(mul(up, -s), mul(F, -c))
        return R, Y, Z

    @staticmethod
    def xform(cols, origin):
        X, Y, Z = cols
        rows = []
        for i in range(3):
            rows += [X[i], Y[i], Z[i]]
        return "Transform3D(%s)" % ", ".join(fmt(v) for v in rows + list(origin))

    def advance(self, f, dy=0.0):
        self.pos = add(self.w(f), (0, dy, 0))
        self._track(self.pos)

    def turn(self, right):
        self.h = (self.h + (1 if right else -1)) % 4

    def _track(self, p):
        self.min_y = min(self.min_y, p[1])
        self.max_y = max(self.max_y, p[1])
        self.extent = [min(self.extent[0], p[0]), min(self.extent[1], p[2]), max(self.extent[2], p[0]), max(self.extent[3], p[2])]

    # -- nodes -------------------------------------------------------------
    def unique(self, parent, name):
        key = (parent, name)
        n = self.names.get(key, 0) + 1
        self.names[key] = n
        return name if n == 1 else "%s%d" % (name, n)

    def add_node(self, name, type_, parent, props=None, script=None, group=False):
        name = self.unique(parent, name)
        self.nodes.append(Node(name, type_, parent, props, script, group))
        return name if parent == "." else parent + "/" + name

    def group(self, name, parent="Course", grouped=True, at=None, cols=None):
        props = []
        if at is not None:
            props.append(("transform", self.xform(cols or self.basis(), at)))
        return self.add_node(name, "Node3D", parent, props, group=grouped)

    def block(self, parent, name, center, size, kind, *, cols=None, solid=True, drawn=True, hazard=False,
              shape="box", tint=None, sides=None, local=False):
        """A block. `center` is a world point unless `local` (then it is the node's own position
        inside a mover, and `cols` its basis). `size` is (across, height, along) in the course frame."""
        cols = cols or self.basis()
        props = [("transform", self.xform(cols, center))]
        if shape != "box":
            props.append(("shape", {"cyl": "1", "tube": "2"}[shape]))
        props.append(("size", vec(size)))
        props.append(("kind", '"%s"' % kind))
        if not solid:
            props.append(("solid", "false"))
        if not drawn:
            props.append(("drawn", "false"))
        if tint:
            props.append(("tint", "Color(%s)" % ", ".join(fmt(x) for x in tint)))
        if sides:
            props.append(("sides", str(sides)))
        return self.add_node(name, "Node3D", parent, props, script="hazard" if hazard else "block")

    def world_block(self, parent, name, center, size, kind, **kw):
        """A block lined up with the world axes: `size` is (x, y, z) in metres (scenery)."""
        return self.block(parent, name, center, size, kind, cols=((1, 0, 0), (0, 1, 0), (0, 0, 1)), **kw)

    def box(self, parent, name, f0, f1, r0, r1, y0, y1, kind, **kw):
        """A block spanning f0..f1, r0..r1, y0..y1 in the course frame."""
        c = self.w((f0 + f1) * 0.5, (y0 + y1) * 0.5, (r0 + r1) * 0.5)
        return self.block(parent, name, c, (abs(r1 - r0), abs(y1 - y0), abs(f1 - f0)), kind, **kw)

    def deck(self, parent, f0, f1, kind, top=0.0, thick=1.0, width=None, r=0.0, name="Deck", **kw):
        w = width or self.W
        for f in (f0, f1):
            self._track(self.w(f, top, r))
        return self.box(parent, name, f0, f1, r - w / 2, r + w / 2, top - thick, top, kind, **kw)

    def ramp(self, parent, f0, y0, f1, y1, kind, width=None, thick=0.6, r=0.0, name="Ramp"):
        w = width or self.W
        L = math.hypot(f1 - f0, y1 - y0)
        a = math.atan2(y1 - y0, f1 - f0)
        cols = self.basis(pitch=a)
        mid = self.w((f0 + f1) * 0.5, (y0 + y1) * 0.5, r)
        c = add(mid, mul(cols[1], -thick / 2))
        return self.block(parent, name, c, (w, thick, L), kind, cols=cols)

    def mover(self, parent, name, at_f, at_y, at_r, travel=(0, 0, 0), period=4.0, spin=0.0, phase=0.0, hold=0.0):
        """A MapMover at a course point. travel is (f, y, r) in the course frame."""
        t = (travel[2], travel[1], -travel[0])   # its own frame: x = right, y = up, z = back
        props = [("transform", self.xform(self.basis(), self.w(at_f, at_y, at_r)))]
        if any(t):
            props.append(("travel", vec(t)))
        props.append(("period", fmt(period)))
        if spin:
            props.append(("spin", fmt(spin)))
        if phase:
            props.append(("phase", fmt(phase % 1.0)))
        if hold:
            props.append(("hold", fmt(hold)))
        return self.add_node(name, "Node3D", parent, props, script="mover", group=True)

    def mblock(self, parent, name, f, y, r, size, kind, **kw):
        """A block inside a mover, at (f, y, r) from the mover (course frame)."""
        X = (1, 0, 0)
        cols = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
        return self.block(parent, name, (r, y, -f), size, kind, cols=cols, local=True, **kw)

    # -- race things ---------------------------------------------------------
    def point(self, f, y, r, action="RUN", aim=None, radius=1.0, boost=False):
        props = [("transform", self.xform(self.basis(), self.w(f, y, r)))]
        props.append(("action", str(ACTIONS.index(action))))
        if aim is not None:
            props.append(("aim", vec(self.local_vec(*aim))))
        if radius != 1.2:
            props.append(("radius", fmt(radius)))
        if boost:
            props.append(("boost", "true"))
        self.points.append(self.w(f, y, r))
        return self.add_node("P%02d_%s" % (len(self.points), action.lower()), "Marker3D", "BotRoute", props, script="route")

    def gate(self, f, finish=False, opening=None, r=0.0):
        """A checkpoint across the course `f` metres ahead, with a route point just past it."""
        self.gate_count += 1
        w = opening or (self.W + 4.4, 6.0)   # posts stand clear of rails and parapets
        props = [("transform", self.xform(self.basis(), self.w(f, 0, r))), ("number", str(self.gate_count))]
        if finish:
            props.append(("finish", "true"))
        props.append(("opening", "Vector2(%s, %s)" % (fmt(w[0]), fmt(w[1]))))
        self.add_node("Finish" if finish else "Checkpoint%d" % self.gate_count, "Marker3D", "Checkpoints", props, script="checkpoint")
        if not finish:
            self.point(f + 4.0, 0, r, "RUN", radius=1.6)

    def spawns(self, f, count=5, gap=1.7, rows=1):
        for row in range(rows):
            for i in range(count):
                r = (i - (count - 1) / 2) * gap
                props = [("transform", self.xform(self.basis(), self.w(f - row * 2.5, 0, r)))]
                self.add_node("Start%d" % (row * count + i + 1), "Marker3D", "Spawns", props, script="spawn")

    def sign(self, f, y, r, text, size=96, color=(1, 1, 1, 1), parent="Signs", yaw=0.0):
        cols = self.basis(yaw=yaw)   # a Label3D reads from its +z side: back toward the racers coming
        props = [("transform", self.xform(cols, self.w(f, y, r))), ("pixel_size", "0.01"),
                 ("modulate", "Color(%s)" % ", ".join(fmt(c) for c in color)),
                 ("outline_size", "16"), ("outline_modulate", "Color(0.05, 0.05, 0.08, 1)"),
                 ("text", '"%s"' % text), ("font_size", str(size))]
        self.add_node("Sign_" + "".join(ch for ch in text.title() if ch.isalnum())[:24], "Label3D", parent, props)

    # -- writing -------------------------------------------------------------
    def write(self, path, palette_res):
        scripts = {"root": "res://game/arena/map_root.gd", "block": "res://game/arena/map_block.gd",
                   "hazard": "res://game/arena/map_hazard.gd", "mover": "res://game/arena/map_mover.gd",
                   "route": "res://game/arena/map_route_point.gd", "checkpoint": "res://game/arena/map_checkpoint.gd",
                   "spawn": "res://game/arena/map_spawn.gd"}
        ids = {}
        out = ["[gd_scene format=3]", ""]
        for i, (k, p) in enumerate(scripts.items()):
            ids[k] = "%d_%s" % (i + 1, k)
            out.append('[ext_resource type="Script" path="%s" id="%s"]' % (p, ids[k]))
        out.append('[ext_resource type="Resource" path="%s" id="pal"]' % palette_res)
        out.append("")
        out += self.env
        out.append("")
        x0, z0, x1, z1 = self.extent
        pad = 40
        out.append('[node name="%s" type="Node3D"]' % self.root)
        out.append('script = ExtResource("%s")' % ids["root"])
        out.append('palette = ExtResource("pal")')
        for k, v in self.settings.items():
            out.append("%s = %s" % (k, v))
        out.append("kill_height = %s" % fmt(self.min_y - self.kill_margin))
        out.append("bounds = Rect2(%s, %s, %s, %s)" % (fmt(x0 - pad), fmt(z0 - pad), fmt(x1 - x0 + 2 * pad), fmt(z1 - z0 + 2 * pad)))
        out.append("swing_point = %s" % vec(self.settings_swing if hasattr(self, "settings_swing") else (0, 10, 0)))
        out.append("")
        out.append('[node name="Environment" type="WorldEnvironment" parent="."]')
        out.append('environment = SubResource("Environment_1")')
        out.append("")
        rows, color, energy = self.sun
        out.append('[node name="Sun" type="DirectionalLight3D" parent="."]')
        out.append("transform = Transform3D(%s, 0, 0, 0)" % ", ".join(fmt(v) for v in rows))
        out.append("light_color = Color(%s, 1)" % ", ".join(fmt(c) for c in color))
        out.append("light_energy = %s" % fmt(energy))
        out.append("shadow_enabled = true")
        out.append("directional_shadow_max_distance = 220.0")
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
