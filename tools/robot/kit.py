"""Low-poly mesh kit: flat-shaded parts built from lofted rings, plus a mesh that
collects parts, each tied to one bone and one material."""
import math
import numpy as np
from m3 import euler, norm


class Part:
    """A bag of triangles (n x 3 x 3)."""

    def __init__(self, tris):
        self.t = np.array(tris, dtype=float).reshape(-1, 3, 3)

    def move(self, x=0.0, y=0.0, z=0.0):
        return Part(self.t + np.array([x, y, z]))

    def rot(self, pitch=0.0, yaw=0.0, roll=0.0):
        m = euler((pitch, yaw, roll))
        return Part(self.t @ m.T)

    def scale(self, x=1.0, y=1.0, z=1.0):
        return Part(self.t * np.array([x, y, z]))

    def mirrored(self):
        t = self.t * np.array([-1.0, 1.0, 1.0])
        return Part(t[:, ::-1, :])

    def __add__(self, other):
        return Part(np.concatenate([self.t, other.t]))


def _tri_out(a, b, c, centre):
    n = np.cross(b - a, c - a)
    if np.dot(n, (a + b + c) / 3.0 - centre) < 0:
        return [a, c, b]
    return [a, b, c]


def loft(rings, cap_start=True, cap_end=True):
    """Skin a sequence of rings (each n points, same n) into a closed, outward-facing part."""
    rings = [np.array(r, dtype=float) for r in rings]
    tris = []
    n = len(rings[0])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        centre = (a.mean(axis=0) + b.mean(axis=0)) / 2.0
        for j in range(n):
            k = (j + 1) % n
            tris.append(_tri_out(a[j], a[k], b[k], centre))
            tris.append(_tri_out(a[j], b[k], b[j], centre))
    for ring, other, on in ((rings[0], rings[1], cap_start), (rings[-1], rings[-2], cap_end)):
        if not on:
            continue
        inside = other.mean(axis=0)
        for j in range(1, n - 1):
            tris.append(_tri_out(ring[0], ring[j], ring[j + 1], inside))
    out = [t for t in tris if np.linalg.norm(np.cross(t[1] - t[0], t[2] - t[0])) > 1e-9]
    return Part(out)


def rect(w, d, y=0.0, chamfer=0.0, cx=0.0, cz=0.0):
    """A rectangle ring in the XZ plane (w along X, d along Z), optionally with cut corners."""
    hw, hd, c = w / 2.0, d / 2.0, min(chamfer, w / 2.0 - 1e-4, d / 2.0 - 1e-4)
    if c <= 0:
        pts = [(-hw, hd), (hw, hd), (hw, -hd), (-hw, -hd)]
    else:
        pts = [(-hw + c, hd), (hw - c, hd), (hw, hd - c), (hw, -hd + c),
               (hw - c, -hd), (-hw + c, -hd), (-hw, -hd + c), (-hw, hd - c)]
    return [(x + cx, y, z + cz) for x, z in pts]


def ngon(n, r, y=0.0, rz=None, phase=0.0, cx=0.0, cz=0.0):
    """A regular n-sided ring in the XZ plane (rz gives an ellipse)."""
    rz = r if rz is None else rz
    return [(cx + r * math.cos(phase + i * math.tau / n), y, cz + rz * math.sin(phase + i * math.tau / n)) for i in range(n)]


def box(w, h, d, chamfer=0.0):
    return loft([rect(w, d, -h / 2.0, chamfer), rect(w, d, h / 2.0, chamfer)])


def prism(n, r, h, r_top=None, rz=None, phase=0.0):
    r_top = r if r_top is None else r_top
    rz_top = None if rz is None else rz * r_top / r
    return loft([ngon(n, r, -h / 2.0, rz, phase), ngon(n, r_top, h / 2.0, rz_top, phase)])


def ball(r, squash=1.0):
    """A 20-sided ball (icosahedron)."""
    p = (1 + 5 ** 0.5) / 2
    vs = [norm(np.array(x, dtype=float)) * r for x in (
        (-1, p, 0), (1, p, 0), (-1, -p, 0), (1, -p, 0), (0, -1, p), (0, 1, p),
        (0, -1, -p), (0, 1, -p), (p, 0, -1), (p, 0, 1), (-p, 0, -1), (-p, 0, 1))]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
             (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
             (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    centre = np.zeros(3)
    return Part([_tri_out(vs[a], vs[b], vs[c], centre) for a, b, c in faces]).scale(1.0, squash, 1.0)


class Tri:
    __slots__ = ("points", "normal", "material", "bone")

    def __init__(self, points, material, bone):
        self.points = points
        self.normal = norm(np.cross(points[1] - points[0], points[2] - points[0]))
        self.material = material
        self.bone = bone


class Mesh:
    def __init__(self):
        self.tris = []

    def add(self, part, material, bone):
        for t in part.t:
            self.tris.append(Tri(t, material, bone))
        return self

    def add_pair(self, part, material, bone_l):
        """Add a part on the left side (-X) and its mirror image on the right."""
        self.add(part, material, bone_l)
        self.add(part.mirrored(), material, bone_l[:-2] + "_r" if bone_l.endswith("_l") else bone_l)
        return self

    def count(self):
        return len(self.tris)
