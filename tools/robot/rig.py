"""Skeleton, pose solving (forward kinematics plus two-bone IK for arms and legs)
and baking of animation clips.

Every bone's rest orientation is the identity, and the rest pose is standing
straight with the arms hanging down. So a bone's rotation reads naturally:
  +X pitch swings a hanging limb forward, +Y yaw turns left, +Z roll tips to the right side up.

A pose is described by a "spec": a plain dict (see solve()). Specs with the same
shape can be blended number by number, which keeps planted feet planted and lets
whole-body spins go past 180 degrees.
"""
import math
import numpy as np
from m3 import v, norm, euler, frame, quat, rx, ry

FPS = 30


class Bone:
    def __init__(self, index, name, parent, pos):
        self.index, self.name, self.parent, self.pos = index, name, parent, np.array(pos, dtype=float)


class Skeleton:
    def __init__(self, spec):
        self.bones = []
        self._by_name = {}
        for name, parent, pos in spec:
            b = Bone(len(self.bones), name, self._by_name[parent].index if parent else -1, pos)
            self.bones.append(b)
            self._by_name[name] = b

    def index(self, name):
        return self._by_name[name].index

    def bone(self, name):
        return self._by_name[name]

    def offset(self, name):
        b = self._by_name[name]
        return b.pos - (self.bones[b.parent].pos if b.parent >= 0 else 0.0)

    def names(self):
        return [b.name for b in self.bones]


# The gun is modelled barrel-forward (-Z), sights up; in the rest pose the arm hangs
# down, so the gun hangs barrel-down. This turns gun-space directions into bone space.
GUN_REST = rx(-90)

BODY = Skeleton([
    ("root", None, (0, 0, 0)),
    ("hips", "root", (0, 0.96, 0)),
    ("spine", "hips", (0, 1.06, 0)),
    ("chest", "spine", (0, 1.22, 0)),
    ("head", "chest", (0, 1.50, 0)),
    ("upper_arm_l", "chest", (-0.215, 1.40, 0)),
    ("forearm_l", "upper_arm_l", (-0.215, 1.13, 0)),
    ("hand_l", "forearm_l", (-0.215, 0.88, 0)),
    ("grapple", "forearm_l", (-0.285, 0.90, 0)),      # where the grapple rope leaves the left wrist
    ("upper_arm_r", "chest", (0.215, 1.40, 0)),
    ("forearm_r", "upper_arm_r", (0.215, 1.13, 0)),
    ("hand_r", "forearm_r", (0.215, 0.88, 0)),
    ("pistol", "hand_r", (0.215, 0.835, 0)),          # the grip, in the fist
    ("pistol_slide", "pistol", (0.215, 0.835, 0)),
    ("pistol_mag", "pistol", (0.215, 0.835, 0)),
    ("muzzle", "pistol", (0.215, 0.835 - 0.20, -0.064)),  # where shots leave the barrel
    ("thigh_l", "hips", (-0.10, 0.90, 0)),
    ("shin_l", "thigh_l", (-0.10, 0.50, 0)),
    ("foot_l", "shin_l", (-0.10, 0.10, 0)),
    ("thigh_r", "hips", (0.10, 0.90, 0)),
    ("shin_r", "thigh_r", (0.10, 0.50, 0)),
    ("foot_r", "shin_r", (0.10, 0.10, 0)),
])

MOVING_BONES = ("root", "hips", "pistol", "pistol_slide", "pistol_mag")  # bones whose position is animated

ZERO = (0.0, 0.0, 0.0)


def _two_bone(S, T, l1, l2, pole, knee):
    """Returns (upper R, lower R, end position). pole: where the elbow/knee points."""
    d = T - S
    dist = np.linalg.norm(d)
    reach = (l1 + l2) * 0.999
    if dist > reach:
        d = d / dist * reach
        dist = reach
    if dist < 1e-4:
        d, dist = v(0, -1e-4, 0), 1e-4
    dirn = d / dist
    perp = pole - dirn * np.dot(pole, dirn)
    if np.linalg.norm(perp) < 1e-5:
        alt = v(0, 0, 1) if abs(dirn[2]) < 0.9 else v(1, 0, 0)
        perp = alt - dirn * np.dot(alt, dirn)
    perp = norm(perp)
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    E = S + dirn * a + perp * h
    d1 = norm(E - S)
    d2 = norm(S + d - E)
    z = -perp if knee else perp
    Ru = frame(y=-d1, z=z)
    Rl = frame(x=Ru[:, 0], y=-d2)
    return Ru, Rl, S + d


def solve(skel, spec):
    """Turns a pose spec into local bone rotations and positions.

    spec keys (all optional; anything left out stays at rest):
      root:  {pos, rot}                       model-space placement of the whole body
      hips:  {pos, rot}                       pos is absolute, in model space
      spine, chest, head: (pitch, yaw, roll)
      arm_l, arm_r:  {fk: euler, bend: deg, hand: euler}
                  or {ik: wrist target, space: model|chest|hips, pole: dir, hand: euler in that space (optional),
                      cant: roll about the fingers (tilts a held gun), hand_local: euler}
      leg_l, leg_r:  {fk: euler, bend: deg, foot: euler}
                  or {ik: ankle target, space: model|hips, pole: dir, foot: euler in model space}
      pistol: {pos, rot}   offset and rotation in the hand, in gun space (barrel -Z, up +Y)
      slide: float         slide travel backwards, metres
      mag:   (x, y, z)     magazine offset in gun space
    Returns (rotations {bone: 3x3}, positions {bone: local xyz}).
    """
    if "_blend" in spec:
        a, b, u = spec["_blend"]
        ra, pa = solve(skel, a)
        rb, pb = solve(skel, b)
        rot = {k: _slerp_m(ra[k], rb[k], u) for k in ra}
        pos = {k: pa[k] * (1 - u) + pb[k] * u for k in pa}
        return rot, pos

    G = {}   # global rotation per bone
    Pg = {}  # global position per bone
    L = {}   # local rotation
    T = {}   # local translation

    def place(name, local_rot, local_pos=None):
        b = skel.bone(name)
        t = skel.offset(name) if local_pos is None else np.array(local_pos, dtype=float)
        if b.parent < 0:
            G[name] = local_rot
            Pg[name] = t
        else:
            pn = skel.bones[b.parent].name
            G[name] = G[pn] @ local_rot
            Pg[name] = Pg[pn] + G[pn] @ t
        L[name] = local_rot
        T[name] = t

    def place_global(name, global_rot):
        b = skel.bone(name)
        pn = skel.bones[b.parent].name
        place(name, G[pn].T @ global_rot)

    root = spec.get("root", {})
    place("root", euler(root.get("rot", ZERO)), root.get("pos", ZERO))
    hips = spec.get("hips", {})
    hips_pos = np.array(hips.get("pos", skel.bone("hips").pos), dtype=float)
    place("hips", euler(hips.get("rot", ZERO)), G["root"].T @ (hips_pos - Pg["root"]))
    place("spine", euler(spec.get("spine", ZERO)))
    place("chest", euler(spec.get("chest", ZERO)))
    place("head", euler(spec.get("head", ZERO)))

    def space(name):
        if name == "model":
            return G["root"], Pg["root"]
        return G[name], Pg[name]

    for side in ("l", "r"):
        arm = spec.get("arm_" + side, {})
        up, fo, ha = "upper_arm_" + side, "forearm_" + side, "hand_" + side
        if "ik" in arm:
            R, O = space(arm.get("space", "model"))
            target = O + R @ np.array(arm["ik"], dtype=float)
            pole = R @ np.array(arm.get("pole", (0.3 if side == "r" else -0.3, -1.0, 0.6)), dtype=float)
            S = Pg["chest"] + G["chest"] @ skel.offset(up)
            l1 = np.linalg.norm(skel.offset(fo))
            l2 = np.linalg.norm(skel.offset(ha))
            Ru, Rl, _ = _two_bone(S, target, l1, l2, pole, knee=False)
            place_global(up, Ru)
            place_global(fo, Rl)
            if "hand" in arm:
                place_global(ha, R @ euler(arm["hand"]) @ ry(arm.get("cant", 0.0)))
            else:
                place(ha, euler(arm.get("hand_local", ZERO)))
        else:
            place(up, euler(arm.get("fk", ZERO)))
            place(fo, rx(arm.get("bend", 0.0)))
            place(ha, euler(arm.get("hand", ZERO)))

        leg = spec.get("leg_" + side, {})
        th, sh, ft = "thigh_" + side, "shin_" + side, "foot_" + side
        if "ik" in leg:
            R, O = space(leg.get("space", "model"))
            target = O + R @ np.array(leg["ik"], dtype=float)
            pole = R @ np.array(leg.get("pole", (0.0, 0.0, -1.0)), dtype=float)
            S = Pg["hips"] + G["hips"] @ skel.offset(th)
            l1 = np.linalg.norm(skel.offset(sh))
            l2 = np.linalg.norm(skel.offset(ft))
            Ru, Rl, _ = _two_bone(S, target, l1, l2, pole, knee=True)
            place_global(th, Ru)
            place_global(sh, Rl)
            place_global(ft, R @ euler(leg.get("foot", ZERO)))
        else:
            place(th, euler(leg.get("fk", ZERO)))
            place(sh, rx(-leg.get("bend", 0.0)))
            place(ft, euler(leg.get("foot", ZERO)))

    if "pistol" in skel._by_name:
        gun = spec.get("pistol", {})
        place("pistol", GUN_REST @ euler(gun.get("rot", ZERO)) @ GUN_REST.T,
              skel.offset("pistol") + GUN_REST @ np.array(gun.get("pos", ZERO), dtype=float))
        place("pistol_slide", np.eye(3), GUN_REST @ v(0, 0, spec.get("slide", 0.0)))
        place("pistol_mag", np.eye(3), GUN_REST @ np.array(spec.get("mag", ZERO), dtype=float))
    for b in skel.bones:   # marker bones (muzzle, grapple) just ride along
        if b.name not in L:
            place(b.name, np.eye(3))
    return L, T


def _slerp_m(a, b, u):
    qa, qb = quat(a), quat(b)
    return _quat_to_m(_slerp_q(qa, qb, u))


def _slerp_q(qa, qb, u):
    d = float(np.dot(qa, qb))
    if d < 0:
        qb, d = -qb, -d
    if d > 0.9995:
        q = qa + (qb - qa) * u
        return q / np.linalg.norm(q)
    th = math.acos(d)
    return (qa * math.sin((1 - u) * th) + qb * math.sin(u * th)) / math.sin(th)


def _quat_to_m(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


# ---------------------------------------------------------------------------
# Blending specs

def _same_shape(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(_same_shape(a[k], b[k]) for k in a)
    if isinstance(a, str) or isinstance(b, str):
        return a == b
    if isinstance(a, (tuple, list)) and isinstance(b, (tuple, list)):
        return len(a) == len(b)
    return isinstance(a, (int, float)) and isinstance(b, (int, float))


def _mix(a, b, u):
    if isinstance(a, dict):
        return {k: _mix(a[k], b[k], u) for k in a}
    if isinstance(a, str):
        return a
    if isinstance(a, (tuple, list)):
        return tuple(x * (1 - u) + y * u for x, y in zip(a, b))
    return a * (1 - u) + b * u


def mix(a, b, u):
    """Blend two specs. Number by number when they have the same shape, otherwise
    by blending the solved poses."""
    if u <= 0:
        return a
    if u >= 1:
        return b
    keys = set(a) | set(b)
    if "_blend" not in keys and all(k in a and k in b and _same_shape(a[k], b[k]) for k in keys):
        return _mix(a, b, u)
    return {"_blend": (a, b, u)}


def ease(u, kind="smooth"):
    u = min(max(u, 0.0), 1.0)
    if kind == "linear":
        return u
    if kind == "in":
        return u * u
    if kind == "out":
        return 1 - (1 - u) * (1 - u)
    return u * u * (3 - 2 * u)


def keyed(t, keys):
    """keys: [(time, spec), ...] or [(time, spec, ease), ...] where ease shapes the
    move INTO that key. Returns the spec at time t."""
    if t <= keys[0][0]:
        return keys[0][1]
    for i in range(1, len(keys)):
        if t <= keys[i][0]:
            t0, t1 = keys[i - 1][0], keys[i][0]
            kind = keys[i][2] if len(keys[i]) > 2 else "smooth"
            return mix(keys[i - 1][1], keys[i][1], ease((t - t0) / (t1 - t0), kind))
    return keys[-1][1]


def mirror(spec):
    """Left-right mirror image of a pose (the gun stays in the right hand's bone)."""
    def flip_euler(e):
        return (e[0], -e[1], -e[2])

    def flip_pos(p):
        return (-p[0], p[1], p[2])

    out = {}
    for k, val in spec.items():
        if k in ("spine", "chest", "head"):
            out[k] = flip_euler(val)
        elif k in ("hips", "root"):
            out[k] = {kk: (flip_pos(vv) if kk == "pos" else flip_euler(vv)) for kk, vv in val.items()}
        elif k[:4] in ("arm_", "leg_"):
            other = k[:4] + ("r" if k.endswith("l") else "l")
            limb = {}
            for kk, vv in val.items():
                if kk in ("ik", "pole"):
                    limb[kk] = flip_pos(vv)
                elif kk in ("fk", "hand", "hand_local", "foot"):
                    limb[kk] = flip_euler(vv)
                elif kk == "cant":
                    limb[kk] = -vv
                else:
                    limb[kk] = vv
            out[other] = limb
        else:
            out[k] = val
    return out


def merged(base, **over):
    out = dict(base)
    out.update(over)
    return out


# ---------------------------------------------------------------------------
# Clips

class Clip:
    def __init__(self, name, duration, fn, loop=False):
        self.name, self.duration, self.fn, self.loop = name, duration, fn, loop
        self.times = []
        self.rotations = {}
        self.positions = {}

    def bake(self, skel):
        n = max(int(round(self.duration * FPS)), 1)
        self.times = [i / FPS for i in range(n + 1)]
        self.times[-1] = self.duration
        rots = {b: [] for b in skel.names()}
        poss = {b: [] for b in MOVING_BONES if b in skel._by_name}
        for i, t in enumerate(self.times):
            tt = 0.0 if (self.loop and i == n) else t
            L, T = solve(skel, self.fn(tt))
            for b in rots:
                q = quat(L[b])
                if rots[b] and np.dot(rots[b][-1], q) < 0:
                    q = -q
                rots[b].append(q)
            for b in poss:
                poss[b].append(T[b])
        self.rotations = {b: np.array(q, dtype=np.float32) for b, q in rots.items()}
        self.positions = {b: np.array(p, dtype=np.float32) for b, p in poss.items()}
        return self
