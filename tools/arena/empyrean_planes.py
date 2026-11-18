"""Empyrean Tower, the last step of tools/arena/empyrean.py: no two faces in one plane.

Where two drawn blocks of different kinds have faces in the same plane, facing the same
way and overlapping (a ramp's landing level with the floor it lands on, a bridge's deck
with the floor at its ends, a carpet on a strip of light, two rings on one ceiling), the
graphics card cannot tell which is in front and the two colours flicker as you move.
With fifteen thousand blocks written by four generators there are hundreds of these, so
rather than chase each one, `settle(m)` finds every such pair in the finished map and
moves one face of one of the two a few millimetres:

 - a drawn-only block against a solid one: the drawn-only one grows outward (it is
   decoration laid on the structure, and is meant to be what shows);
 - two drawn-only blocks: the one made later grows outward (it was laid over the other);
 - two solid blocks: the one made later shrinks inward (the floor was there first; the
   bridge, balcony or landing gives way).

5 to 11 mm, a different amount for each block so two that are moved do not meet again;
it runs again until there are none left. Nothing anyone can see or feel moves: only
which of the two faces is in front is settled, once.

tests/empyrean_test.gd checks the built map the same way."""
import math
import re

GAP = 0.003          # faces nearer than this to one plane count as in it (metres)
OVERLAP = 0.01       # ...when they share at least this much area (square metres)
KEEP = ("glass_stained",)        # kinds whose blocks are never moved (the panes that break have to stay square to the map, to the millimetre)
ROUND = ("1", "2", "3", "6")     # cylinder, tube, cone, dome: only their flat ends are faces
_NUM = re.compile(r"-?\d+\.?\d*(?:e-?\d+)?")


def _floats(text):
    return [float(v) for v in _NUM.findall(text[text.index("(") + 1:] if "(" in text else text)]


def _local(node):
    """A node's own transform: (basis columns X, Y, Z; origin)."""
    for k, v in node.props:
        if k == "transform":
            f = _floats(v)
            return ((f[0], f[3], f[6]), (f[1], f[4], f[7]), (f[2], f[5], f[8])), (f[9], f[10], f[11])
    return ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0, 0, 0)


def _apply(basis, origin, v):
    return tuple(origin[i] + basis[0][i] * v[0] + basis[1][i] * v[1] + basis[2][i] * v[2] for i in range(3))


def _turn(basis, v):
    return tuple(basis[0][i] * v[0] + basis[1][i] * v[1] + basis[2][i] * v[2] for i in range(3))


def _compose(parent, child):
    pb, po = parent
    cb, co = child
    return tuple(_turn(pb, c) for c in cb), _apply(pb, po, co)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _unit(v):
    n = math.sqrt(_dot(v, v)) or 1.0
    return (v[0] / n, v[1] / n, v[2] / n)


def _prop(node, key, default=None):
    for k, v in node.props:
        if k == key:
            return v
    return default


def _set(node, key, value):
    node.props[:] = [(k, value if k == key else v) for k, v in node.props]


def _blocks(m):
    """Every drawn block: [index, node, world (basis, origin), size, shape, kind, solid, top]."""
    world = {".": (((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0, 0, 0))}
    out = []
    for i, node in enumerate(m.nodes):
        xf = _compose(world[node.parent], _local(node))
        world[node.name if node.parent == "." else node.parent + "/" + node.name] = xf
        if node.script not in ("block", "hazard") or _prop(node, "drawn") == "false":
            continue
        out.append([i, node, xf, _floats(_prop(node, "size")), _prop(node, "shape", "0"), _prop(node, "kind"),
                    _prop(node, "solid") != "false", float(_prop(node, "top", "0"))])
    return out


def _faces(blocks):
    """normal (rounded) -> [(plane's distance, centre, u, v, half u, half v, block, axis, sign)]."""
    faces = {}
    for b in blocks:
        _i, _node, (basis, origin), size, shape, _kind, _solid, top = b
        rnd = shape in ROUND
        for axis in range(3):
            if rnd and axis != 1:
                continue
            for sign in (-1.0, 1.0):
                if shape == "6" or (shape == "3" and sign > 0 and top <= 0.01):
                    continue        # a dome has no flat top, nor has a cone that comes to a point
                n = _unit(tuple(c * sign for c in basis[axis]))
                c = tuple(origin[k] + basis[axis][k] * size[axis] * 0.5 * sign for k in range(3))
                a1, a2 = (axis + 1) % 3, (axis + 2) % 3
                shrink = 0.7 if rnd else 1.0
                key = (round(n[0] * 300), round(n[1] * 300), round(n[2] * 300))
                faces.setdefault(key, []).append((_dot(n, c), c, _unit(basis[a1]), _unit(basis[a2]), size[a1] * 0.5 * shrink, size[a2] * 0.5 * shrink, b, axis, sign))
    return faces


def _covers(A, B):
    """Does face B, seen along face A's two edges, reach over A? (Asked both ways round,
    this is exactly whether two rectangles in one plane overlap.)"""
    lo = [1e9, 1e9]
    hi = [-1e9, -1e9]
    for su in (-1, 1):
        for sv in (-1, 1):
            p = tuple(B[1][k] + B[2][k] * B[4] * su + B[3][k] * B[5] * sv - A[1][k] for k in range(3))
            q = (_dot(p, A[2]), _dot(p, A[3]))
            for k in range(2):
                lo[k] = min(lo[k], q[k])
                hi[k] = max(hi[k], q[k])
    w = min(hi[0], A[4]) - max(lo[0], -A[4])
    h = min(hi[1], A[5]) - max(lo[1], -A[5])
    return w > 0.03 and h > 0.03 and w * h > OVERLAP


def clashes(m):
    """Every pair of faces of different kinds in one plane, facing one way, that overlap: [(face, face)]."""
    found = []
    for group in _faces(_blocks(m)).values():
        group.sort(key=lambda f: f[0])
        for i, A in enumerate(group):
            j = i + 1
            while j < len(group) and group[j][0] - A[0] < GAP:
                B = group[j]
                j += 1
                if A[6][5] == B[6][5] or A[6] is B[6]:
                    continue
                if _covers(A, B) and _covers(B, A):
                    found.append((A, B))
    return found


def _move(face, by):
    """Moves one face of a block along its own axis by `by` metres (out if positive)."""
    block, axis, sign = face[6], face[7], face[8]
    node = block[1]
    size = block[3]
    size[axis] += by
    _set(node, "size", "Vector3(%s)" % ", ".join(_fmt(v) for v in size))
    basis, origin = _local(node)
    origin = tuple(origin[k] + basis[axis][k] * sign * by * 0.5 for k in range(3))
    rows = []
    for k in range(3):
        rows += [basis[0][k], basis[1][k], basis[2][k]]
    text = "Transform3D(%s)" % ", ".join(_fmt(v) for v in rows + list(origin))
    if _prop(node, "transform") is None:
        node.props.insert(0, ("transform", text))
    else:
        _set(node, "transform", text)


def _fmt(v):
    v = round(float(v), 4)
    return str(int(v)) if v == int(v) else ("%.4f" % v).rstrip("0").rstrip(".")


def settle(m, passes=12):
    """Moves faces until no two of different kinds share a plane. Returns how many it moved."""
    moved = 0
    for turn in range(passes):
        pairs = clashes(m)
        if not pairs:
            return moved
        done = set()
        for A, B in pairs:
            a, b = A[6], B[6]
            if a[6] != b[6]:
                face, out = (B if a[6] else A), True          # the drawn-only one grows
            else:
                face, out = (B if b[0] > a[0] else A), not a[6]    # the later one: grows if both are drawn only, shrinks if both solid
            if face[6][5] in KEEP:          # (never this one: move the other instead)
                face = A if face is B else B
                out = not face[6][6]
            key = (face[6][0], face[7], face[8])
            if key in done:
                continue
            done.add(key)
            by = 0.005 + 0.0011 * ((face[6][0] + turn * 3) % 6)
            if not out and face[6][3][face[7]] - by < 0.02:
                out = True          # (too thin to shrink)
            _move(face, by if out else -by)
            moved += 1
    left = clashes(m)
    if left:
        A, B = left[0]
        raise SystemExit("%d faces still share a plane, e.g. %s and %s" % (len(left), A[6][1].name, B[6][1].name))
    return moved
