"""The Character Creator's bodies that are not robots: people, goblins, frogs and
the rest. Each is a whole body on the robots' skeleton (see rig.BODY), modelled in
the rest pose like the robots in designs.py, so any head goes on any torso on any
legs.

Every one has the robots' own hands (hands.py), in its own colours: see hand().

They hold no guns and carry no animations: build.py writes each as a small file
of body parts (NAME.glb), and the game puts those parts on a robot's skeleton
(see RobotModel in game/player/robot/robot_model.gd).

A material's name says what the game does with it: the part before the "_" is
its kind.
  armor_*   takes the body paint (and the team colour); counts as the head's shell
  extra_*   takes the paint too, but is left out when the head and chest are measured
            for hats and glasses (ears, tails, fins)
  skin_*    takes the skin tone; counts as the head's shell
  flesh_*   takes the skin tone, left out of the measuring (ears, noses)
  hair_*    as built; counts as the head's shell
  trim_*    takes the second colour (jeans, a belly, a beak: see ROLES)
  mark_*    takes the detail colour (spots, stripes, horns); so does hair_*
  hair_*    counts as the head's shell
  eye_*     as built; where glasses go
  accent, visor   the player's colour, as on the robots
Anything else is as built.
"""
import math
import numpy as np
from kit import Mesh, Part, loft, rect, ngon, box, prism, ball
import designs
import hands
from designs import rect8, _along_z

def _linear(c):
    """A colour as you would pick it on screen (sRGB) -> the number a model file stores."""
    return tuple(round(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92, 4) for x in c)


# Colours here are as they look on screen; MATERIALS (below) holds them as a model file stores them.
_LOOKS = {
    # Skin (takes the skin tone).
    "skin_human": {"color": (0.87, 0.66, 0.52), "roughness": 0.75},
    "flesh_human": {"color": (0.87, 0.66, 0.52), "roughness": 0.75},
    "skin_goblin": {"color": (0.45, 0.62, 0.24), "roughness": 0.75},
    "flesh_goblin": {"color": (0.45, 0.62, 0.24), "roughness": 0.75},
    "skin_zombie": {"color": (0.52, 0.63, 0.50), "roughness": 0.8},
    "flesh_zombie": {"color": (0.52, 0.63, 0.50), "roughness": 0.8},
    "skin_imp": {"color": (0.78, 0.16, 0.13), "roughness": 0.7},
    "flesh_imp": {"color": (0.78, 0.16, 0.13), "roughness": 0.7},
    "skin_yeti": {"color": (0.42, 0.55, 0.72), "roughness": 0.7},
    "flesh_yeti": {"color": (0.42, 0.55, 0.72), "roughness": 0.7},
    # Paintable bodies and clothes: each its own colour until painted.
    "armor_tee": {"color": (0.93, 0.93, 0.90), "roughness": 0.85},
    "armor_tunic": {"color": (0.50, 0.33, 0.18), "roughness": 0.85},
    "armor_frog": {"color": (0.36, 0.68, 0.24), "roughness": 0.6},
    "extra_frog": {"color": (0.36, 0.68, 0.24), "roughness": 0.6},
    "armor_bone": {"color": (0.92, 0.89, 0.80), "roughness": 0.7},
    "extra_bone": {"color": (0.92, 0.89, 0.80), "roughness": 0.7},
    "armor_alien": {"color": (0.62, 0.70, 0.66), "roughness": 0.5},
    "extra_alien": {"color": (0.62, 0.70, 0.66), "roughness": 0.5},
    "armor_cat": {"color": (0.93, 0.58, 0.20), "roughness": 0.85},
    "extra_cat": {"color": (0.93, 0.58, 0.20), "roughness": 0.85},
    "armor_rex": {"color": (0.34, 0.56, 0.30), "roughness": 0.7},
    "extra_rex": {"color": (0.34, 0.56, 0.30), "roughness": 0.7},
    "armor_yeti": {"color": (0.93, 0.95, 0.98), "roughness": 0.95},
    "extra_yeti": {"color": (0.93, 0.95, 0.98), "roughness": 0.95},
    "armor_duck": {"color": (0.98, 0.84, 0.22), "roughness": 0.8},
    "extra_duck": {"color": (0.98, 0.84, 0.22), "roughness": 0.8},
    "armor_flannel": {"color": (0.66, 0.20, 0.16), "roughness": 0.9},
    "armor_suit": {"color": (0.93, 0.94, 0.96), "roughness": 0.6},
    "extra_suit": {"color": (0.93, 0.94, 0.96), "roughness": 0.6},
    "armor_snow": {"color": (0.96, 0.97, 1.0), "roughness": 0.9},
    "armor_shark": {"color": (0.36, 0.48, 0.62), "roughness": 0.45},
    "extra_shark": {"color": (0.36, 0.48, 0.62), "roughness": 0.45},
    "armor_gi": {"color": (0.13, 0.14, 0.20), "roughness": 0.9},
    "armor_robe": {"color": (0.36, 0.22, 0.60), "roughness": 0.9},
    "armor_rags": {"color": (0.42, 0.44, 0.52), "roughness": 0.9},
    "armor_cap": {"color": (0.82, 0.14, 0.12), "roughness": 0.6},
    "armor_bear": {"color": (0.50, 0.32, 0.18), "roughness": 0.95},
    "extra_bear": {"color": (0.50, 0.32, 0.18), "roughness": 0.95},
    "armor_banana": {"color": (0.98, 0.85, 0.25), "roughness": 0.6},
    "extra_banana": {"color": (0.98, 0.85, 0.25), "roughness": 0.6},
    # Hair.
    "hair_brown": {"color": (0.24, 0.15, 0.09), "roughness": 0.9},
    "hair_white": {"color": (0.92, 0.92, 0.90), "roughness": 0.9},
    "hair_black": {"color": (0.07, 0.07, 0.08), "roughness": 0.9},
    # Eyes.
    "eye_white": {"color": (0.97, 0.97, 0.95), "roughness": 0.35},
    "eye_yellow": {"color": (0.98, 0.83, 0.20), "roughness": 0.35},
    "eye_green": {"color": (0.55, 0.85, 0.30), "roughness": 0.35},
    "eye_black": {"color": (0.02, 0.02, 0.03), "metallic": 0.4, "roughness": 0.08},
    "eye_gold": {"color": (0.95, 0.70, 0.20), "metallic": 0.7, "roughness": 0.15},
    # The rest: as built.
    "black": {"color": (0.04, 0.04, 0.05), "roughness": 0.6},
    "white": {"color": (0.96, 0.96, 0.94), "roughness": 0.6},
    "pink": {"color": (0.93, 0.50, 0.55), "roughness": 0.7},
    "belly": {"color": (0.94, 0.90, 0.72), "roughness": 0.7},
    "denim": {"color": (0.20, 0.30, 0.52), "roughness": 0.9},
    "leather": {"color": (0.36, 0.22, 0.11), "roughness": 0.8},
    "rope": {"color": (0.72, 0.60, 0.38), "roughness": 0.95},
    "horn": {"color": (0.90, 0.86, 0.72), "roughness": 0.55},
    "beak": {"color": (0.96, 0.52, 0.10), "roughness": 0.55},
    "spot": {"color": (0.14, 0.26, 0.12), "roughness": 0.7},
    "stripe": {"color": (0.45, 0.24, 0.08), "roughness": 0.85},
    "gold": {"color": (1.0, 0.76, 0.28), "metallic": 0.45, "roughness": 0.3},
    "shell_pumpkin": {"color": (0.93, 0.45, 0.07), "roughness": 0.6},
    "stem": {"color": (0.30, 0.38, 0.14), "roughness": 0.8},
    "straw": {"color": (0.86, 0.72, 0.34), "roughness": 0.95},
    "burlap": {"color": (0.52, 0.42, 0.28), "roughness": 0.95},
    "wood": {"color": (0.40, 0.26, 0.14), "roughness": 0.85},
    "carrot": {"color": (0.95, 0.48, 0.10), "roughness": 0.6},
    "brain": {"color": (0.90, 0.55, 0.62), "roughness": 0.5},
    "peel": {"color": (0.97, 0.94, 0.78), "roughness": 0.7},
    "dark": {"color": (0.16, 0.13, 0.12), "roughness": 0.9},
}

MATERIALS = {k: designs.MATERIALS[k] for k in ("accent", "joint", "detail", "visor")}   # the robots' own
MATERIALS.update({k: dict(v, color=_linear(v["color"])) for k, v in _LOOKS.items()})



# ---------------------------------------------------------------------------
# Shapes, rounder than the robots' boxes.

def ring(n, rx, rz, y, cx=0.0, cz=0.0):
    """An ellipse of n points at height y, a flat side to the front and the back."""
    ph = math.pi / n if n % 4 == 0 else math.pi / 2
    return [(cx + rx * math.cos(ph + i * math.tau / n), y, cz + rz * math.sin(ph + i * math.tau / n)) for i in range(n)]


def lathe(rows, n=8, cx=0.0, cz=0.0, caps=(True, True)):
    """Rings stacked up: each row is (y, rx, rz) or (y, rx, rz, cz) or (y, rx, rz, cz, cx)."""
    rings = []
    for r in rows:
        rings.append(ring(n, r[1], r[2], r[0], cx + (r[4] if len(r) > 4 else 0.0), cz + (r[3] if len(r) > 3 else 0.0)))
    return loft(rings, caps[0], caps[1])


def blob(rx, ry=None, rz=None, n=8, rows=5):
    """A ball of stacked rings (smoother than kit.ball), centred on the origin."""
    ry = rx if ry is None else ry
    rz = rx if rz is None else rz
    rings = []
    for i in range(rows + 1):
        a = 0.2 + (math.pi - 0.4) * i / rows
        rings.append(ring(n, rx * math.sin(a), rz * math.sin(a), -ry * math.cos(a)))
    return loft(rings)


def tube(path, radii, n=6, flat=1.0, up=(0.0, 1.0, 0.0), caps=(True, True)):
    """A tube along a path of points. radii: one per point, or (start, end). flat
    squashes it across `up`."""
    pts = [np.array(p, dtype=float) for p in path]
    if len(radii) != len(pts):
        radii = [radii[0] + (radii[-1] - radii[0]) * i / max(len(pts) - 1, 1) for i in range(len(pts))]
    up = np.array(up, dtype=float)
    rings = []
    for i, p in enumerate(pts):
        d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        d = d / np.linalg.norm(d)
        ref = up if abs(np.dot(d, up)) < 0.95 else np.array([1.0, 0.0, 0.0])
        side = np.cross(d, ref)
        side /= np.linalg.norm(side)
        top = np.cross(side, d)
        r = max(radii[i], 0.0015)
        rings.append([p + (side * math.cos(a) + top * math.sin(a) * flat) * r
                      for a in (math.pi / n + j * math.tau / n for j in range(n))])
    return loft(rings, caps[0], caps[1])


def spike(base, tip, r, n=4, flat=1.0, up=(0.0, 1.0, 0.0)):
    return tube([base, tip], [r, 0.0015], n, flat, up)


def hoop(rx, rz, y, thick, n=12, cz=0.0, a0=0.0, a1=math.tau, tall=None):
    """A band round an ellipse (or part of one: angles from the right, +X, through the back, +Z)."""
    tall = thick if tall is None else tall
    out = None
    steps = max(int(round(n * (a1 - a0) / math.tau)), 1)
    for i in range(steps):
        b0 = a0 + (a1 - a0) * i / steps
        b1 = a0 + (a1 - a0) * (i + 1) / steps
        p0 = (rx * math.cos(b0), y, cz + rz * math.sin(b0))
        p1 = (rx * math.cos(b1), y, cz + rz * math.sin(b1))
        seg = tube([p0, p1], [thick / 2.0, thick / 2.0], 4, tall / thick)
        out = seg if out is None else out + seg
    return out


def disc(r, depth=0.012, n=8):
    """A flat round plate facing forward (-Z), centred on the origin."""
    return prism(n, r, depth, phase=math.pi / n).rot(pitch=90)


# ---------------------------------------------------------------------------
# Limbs every body shares. x: the left side (add_pair mirrors them).

AX = -0.215   # the arms' line
LX = -0.10    # the legs' line


def launcher(m, x=-0.275, strap="leather"):
    """The grapple launcher strapped to the left forearm (every character has one)."""
    m.add(box(0.045, 0.15, 0.065, 0.01).move(x, 0.985, 0), "detail", "forearm_l")
    m.add(prism(6, 0.019, 0.035).move(x, 0.895, 0), "accent", "forearm_l")
    for y in (0.94, 1.03):
        m.add(box(abs(x - AX) * 2 + 0.03, 0.022, 0.085, 0.01).move(AX, y, 0), strap, "forearm_l")


def hand(m, body, back=None, band=None, knuckle=None, bulk=1.0):
    """The hands every character has: the robots' own (hands.py: a palm, a trigger finger,
    three more fingers that move as one, a thumb), in this character's colours. body: the
    palm and fingers; back: the plate on the back of the hand; band: the bar across the
    knuckles; knuckle: the round joints (each left out: as the body). bulk: how thick."""
    hands.add(m, bulk, body=body, plate=back or body, trim=band or body, pin=knuckle or body)


def arm(m, upper, fore, palm, r1=0.046, r2=0.04, r3=0.034, shoulder=0.058, fist=(0.058, 0.10, 0.09), n=8,
        back=None, band=None, knuckle=None):
    """A plain round arm: shoulder ball, upper arm, elbow, forearm, and the hand (see hand():
    palm is its body; fist: the old one-piece fist's size, which sets how thick the hand is)."""
    m.add_pair(blob(shoulder, n=n, rows=4).move(AX, 1.40, 0), upper, "upper_arm_l")
    m.add_pair(lathe([(1.40, r1, r1), (1.27, r1, r1), (1.15, r2, r2)], n, AX), upper, "upper_arm_l")
    m.add_pair(blob(r2 * 1.08, n=n, rows=4).move(AX, 1.13, 0), fore, "forearm_l")
    m.add_pair(lathe([(1.12, r2, r2), (1.04, r2 * 1.1, r2 * 1.1), (0.89, r3, r3)], n, AX), fore, "forearm_l")
    hand(m, palm, back, band, knuckle, fist[0] / 0.058)


def leg(m, thigh, shin, r1=0.072, r2=0.052, r3=0.04, n=8, knee=None, calf=1.12):
    """A plain round leg, hip to ankle."""
    m.add_pair(blob(r1 * 1.02, n=n, rows=4).move(LX, 0.90, 0), thigh, "thigh_l")
    m.add_pair(lathe([(0.90, r1, r1), (0.72, r1 * 0.96, r1 * 0.96), (0.52, r2, r2)], n, LX), thigh, "thigh_l")
    m.add_pair(blob(r2 * 1.06, n=n, rows=4).move(LX, 0.50, 0), knee or shin, "shin_l")
    m.add_pair(lathe([(0.49, r2, r2), (0.36, r2 * calf, r2 * calf, 0.008), (0.12, r3, r3)], n, LX), shin, "shin_l")


def shoe(m, upper, sole="white", w=0.105, toe="", lift=0.0):
    """A shoe: the upper, a sole under it, and (toe) a cap over the toes."""
    part = _along_z(loft([rect8(w, 0.085, -0.085, 0.02, cz=0.0425), rect8(w + 0.012, 0.09, 0.07, 0.02, cz=0.045),
                          rect8(w - 0.01, 0.055, 0.185, 0.02, cz=0.0275)]))
    m.add_pair(part.move(LX, 0.012 + lift, 0), upper, "foot_l")
    m.add_pair(blob(0.045, 0.05, 0.05, rows=4).move(LX, 0.11, 0.0), upper, "foot_l")
    m.add_pair(box(w + 0.02, 0.022, 0.285, 0.02).move(LX, 0.011, -0.048), sole, "foot_l")
    if toe:
        m.add_pair(box(w + 0.006, 0.05, 0.06, 0.018).move(LX, 0.045 + lift, -0.16), toe, "foot_l")


def eyes(m, x, y, z, r=0.022, white="eye_white", pupil="black", pr=0.55, look=0.0, squash=1.0):
    """Two round eyes on the front of a head: a ball and a pupil in front of it."""
    m.add_pair(blob(r, r * squash, r * 0.6, rows=4).move(-x, y, z), white, "head")
    m.add_pair(blob(r * pr, r * pr * squash, r * 0.35, rows=3).move(-x + look, y, z - r * 0.45), pupil, "head")


# ---------------------------------------------------------------------------
def human():
    """Dude: a person. Short hair, a T-shirt with a stripe in the player's colour,
    jeans and trainers."""
    m = Mesh()
    _human_head(m)
    m.add(blob(0.118, 0.05, 0.132, rows=3).scale(1, 1, 1).move(0, 1.765, 0.004), "hair_brown", "head")
    m.add(lathe([(1.60, 0.108, 0.07, 0.07), (1.68, 0.121, 0.10, 0.045), (1.755, 0.118, 0.125, 0.012)], 8), "hair_brown", "head")
    m.add(box(0.17, 0.035, 0.03).rot(pitch=-12).move(0, 1.728, -0.128), "hair_brown", "head")   # fringe

    # T-shirt
    m.add(lathe([(1.19, 0.135, 0.098), (1.30, 0.17, 0.112), (1.42, 0.182, 0.112), (1.475, 0.13, 0.095), (1.50, 0.075, 0.07)], 8), "armor_tee", "chest")
    m.add(hoop(0.172, 0.114, 1.335, 0.012, 12, tall=0.05), "accent", "chest")
    m.add(lathe([(1.02, 0.125, 0.092), (1.21, 0.138, 0.1)], 8), "armor_tee", "spine")
    # Jeans, belt
    m.add(lathe([(0.84, 0.11, 0.085), (0.92, 0.155, 0.105), (1.05, 0.135, 0.098)], 8), "denim", "hips")
    m.add(hoop(0.14, 0.102, 1.03, 0.014, 12, tall=0.035), "leather", "hips")
    m.add(box(0.05, 0.045, 0.016).move(0, 1.03, -0.106), "gold", "hips")

    # Arms: short sleeves over bare arms
    arm(m, "skin_human", "skin_human", "skin_human")
    m.add_pair(lathe([(1.26, 0.056, 0.058), (1.36, 0.062, 0.064), (1.45, 0.058, 0.06)], 8, AX - 0.005), "armor_tee", "upper_arm_l")
    m.add_pair(hoop(0.056, 0.058, 1.265, 0.008, 8, tall=0.02).move(AX - 0.005, 0, 0), "accent", "upper_arm_l")
    launcher(m, -0.268)

    # Legs
    leg(m, "denim", "denim", 0.074, 0.056, 0.047)
    shoe(m, "accent", "white", toe="white")
    return m


def _human_head(m, skin="skin_human", flesh="flesh_human", brow="hair_brown", mouth=True):
    """A person's bare head: skull, ears, nose, eyes and brows."""
    m.add(prism(8, 0.05, 0.10).move(0, 1.47, 0), skin, "head")
    m.add(lathe([(1.50, 0.07, 0.08, -0.012), (1.545, 0.098, 0.112, -0.012), (1.62, 0.112, 0.127, -0.01),
                 (1.70, 0.113, 0.128, -0.008), (1.755, 0.092, 0.106, -0.004), (1.79, 0.05, 0.06, 0.0)], 8), skin, "head")
    m.add_pair(box(0.025, 0.055, 0.035, 0.008).move(-0.118, 1.63, 0.0), flesh, "head")
    m.add(loft([rect8(0.034, 0.02, 1.60, 0.006, cz=-0.146), rect8(0.02, 0.012, 1.655, 0.004, cz=-0.139)]), flesh, "head")
    m.add_pair(box(0.042, 0.028, 0.012).move(-0.046, 1.655, -0.133), "eye_white", "head")
    m.add_pair(box(0.017, 0.022, 0.012).move(-0.044, 1.654, -0.138), "black", "head")
    if brow:
        m.add_pair(box(0.05, 0.011, 0.012).rot(roll=-6).move(-0.047, 1.685, -0.135), brow, "head")
    if mouth:
        m.add(box(0.056, 0.01, 0.012).move(0, 1.565, -0.13), "dark", "head")


# ---------------------------------------------------------------------------
def goblin():
    """Goblin: wide head, long nose, great pointed ears, yellow eyes and two fangs;
    a leather tunic and ragged trousers, bare clawed feet."""
    m = Mesh()
    s, f = "skin_goblin", "flesh_goblin"
    m.add(prism(8, 0.05, 0.10).move(0, 1.47, 0), s, "head")
    m.add(lathe([(1.495, 0.075, 0.08, -0.01), (1.54, 0.125, 0.118, -0.012), (1.62, 0.142, 0.132, -0.012),
                 (1.69, 0.135, 0.126, -0.008), (1.74, 0.10, 0.098, -0.004), (1.765, 0.05, 0.05, 0.0)], 8), s, "head")
    # Ears: long flat blades, out and a little back
    ear = loft([rect8(0.03, 0.09, 0.0, 0.01), rect8(0.02, 0.07, 0.09, 0.008, cz=0.01), rect8(0.006, 0.012, 0.21, 0.0, cz=0.04)])
    m.add_pair(ear.rot(roll=68).move(-0.125, 1.635, 0.01), f, "head")
    m.add_pair(box(0.012, 0.012, 0.012).move(-0.215, 1.655, 0.005), "gold", "head")   # earrings
    # Nose: long and drooping
    m.add(tube([(0, 1.635, -0.13), (0, 1.615, -0.185), (0, 1.575, -0.215)], [0.03, 0.022, 0.006], 6), f, "head")
    m.add(box(0.21, 0.02, 0.03).move(0, 1.69, -0.128), f, "head")   # brow ridge
    eyes(m, 0.062, 1.655, -0.128, 0.03, "eye_yellow", "black", 0.42, 0.004, 0.8)
    m.add(box(0.13, 0.012, 0.012).move(0, 1.548, -0.124), "dark", "head")
    m.add_pair(spike((-0.04, 1.548, -0.128), (-0.043, 1.585, -0.132), 0.011, 4), "white", "head")   # fangs
    m.add(spike((0, 1.76, 0.0), (0.01, 1.83, 0.05), 0.022, 5), "hair_black", "head")   # a tuft

    # Tunic with a rope belt and a shoulder strap
    m.add(lathe([(1.19, 0.14, 0.105), (1.30, 0.165, 0.118), (1.42, 0.172, 0.112), (1.475, 0.12, 0.095), (1.50, 0.075, 0.07)], 8), "armor_tunic", "chest")
    m.add(box(0.045, 0.33, 0.02).rot(roll=-38).move(0.0, 1.345, -0.113), "leather", "chest")
    m.add(box(0.045, 0.33, 0.02).rot(roll=38).move(0.0, 1.345, 0.113), "leather", "chest")
    m.add(disc(0.028, 0.02).move(0.05, 1.385, -0.126), "accent", "chest")
    m.add(lathe([(1.02, 0.135, 0.10), (1.21, 0.145, 0.108)], 8), "armor_tunic", "spine")
    m.add(lathe([(0.84, 0.11, 0.09), (0.92, 0.158, 0.112), (1.05, 0.142, 0.104)], 8), "armor_tunic", "hips")
    m.add(hoop(0.148, 0.108, 1.04, 0.022, 12), "rope", "hips")
    m.add(box(0.11, 0.17, 0.016).move(0, 0.94, -0.116), "accent", "hips")   # loincloth flap
    for i in range(7):   # the tunic's ragged hem
        a = math.pi / 7 + i * math.tau / 7
        m.add(spike((0.15 * math.cos(a), 0.86, 0.105 * math.sin(a)), (0.17 * math.cos(a), 0.76, 0.12 * math.sin(a)), 0.04, 4, 0.4,
                    (math.cos(a), 0, math.sin(a))), "armor_tunic", "hips")

    # Arms: thin, with big hands; an arm band
    arm(m, s, s, s, 0.04, 0.034, 0.03, 0.05, (0.066, 0.11, 0.10), band="leather")
    m.add_pair(hoop(0.046, 0.046, 1.30, 0.014, 8, tall=0.03).move(AX, 0, 0), "leather", "upper_arm_l")
    launcher(m, -0.265)

    # Legs: ragged trousers to the knee, bare shins, clawed feet
    m.add_pair(blob(0.07, rows=4).move(LX, 0.90, 0), "armor_tunic", "thigh_l")
    m.add_pair(lathe([(0.90, 0.07, 0.07), (0.72, 0.068, 0.068), (0.56, 0.062, 0.062)], 8, LX), "leather", "thigh_l")
    m.add_pair(blob(0.05, rows=4).move(LX, 0.50, 0), s, "shin_l")
    m.add_pair(lathe([(0.56, 0.045, 0.045), (0.36, 0.05, 0.052, 0.008), (0.12, 0.036, 0.036)], 8, LX), s, "shin_l")
    foot = _along_z(loft([rect8(0.085, 0.07, -0.07, 0.02, cz=0.035), rect8(0.12, 0.06, 0.09, 0.02, cz=0.03),
                          rect8(0.13, 0.03, 0.17, 0.01, cz=0.015)]))
    m.add_pair(foot.move(LX, 0.008, 0), s, "foot_l")
    m.add_pair(blob(0.042, rows=4).move(LX, 0.10, 0), s, "foot_l")
    for dx in (-0.045, 0.0, 0.045):
        m.add_pair(spike((LX + dx, 0.022, -0.165), (LX + dx * 1.2, 0.012, -0.215), 0.014, 4), "horn", "foot_l")
    return m


# ---------------------------------------------------------------------------
def frog():
    """Frog: a wide flat head with eyes bulging out of the top, a pale belly, dark
    spots, long legs and wide webbed feet. Stripes down its back in the player's colour."""
    m = Mesh()
    g, x = "armor_frog", "extra_frog"
    m.add(prism(8, 0.06, 0.10).move(0, 1.47, 0), "belly", "head")
    m.add(lathe([(1.50, 0.09, 0.085, -0.01), (1.535, 0.15, 0.135, -0.022), (1.565, 0.168, 0.152, -0.03)], 10, caps=(True, False)), "belly", "head")
    m.add(lathe([(1.575, 0.17, 0.155, -0.03), (1.63, 0.158, 0.145, -0.026), (1.68, 0.12, 0.115, -0.015), (1.705, 0.06, 0.06, 0.0)], 10), g, "head")
    m.add(lathe([(1.563, 0.164, 0.148, -0.03), (1.577, 0.164, 0.148, -0.03)], 10), "dark", "head")   # the mouth, all the way round
    # Eyes on top
    m.add_pair(blob(0.056, rows=4).move(-0.088, 1.70, -0.04), x, "head")
    m.add_pair(blob(0.04, 0.04, 0.03, rows=4).move(-0.092, 1.715, -0.078), "eye_white", "head")
    m.add_pair(blob(0.026, 0.014, 0.014, rows=3).move(-0.092, 1.715, -0.102), "black", "head")
    m.add_pair(box(0.012, 0.008, 0.01).move(-0.03, 1.625, -0.172), "dark", "head")   # nostrils
    for sx, sy, sz, r in ((0.05, 1.692, 0.06, 0.03), (-0.07, 1.675, 0.085, 0.022), (0.0, 1.705, 0.0, 0.02)):
        m.add(blob(r, 0.008, r, rows=2).move(sx, sy, sz), "spot", "head")

    # Body: green back, pale belly
    m.add(lathe([(1.19, 0.135, 0.105), (1.30, 0.168, 0.125), (1.42, 0.168, 0.12), (1.475, 0.12, 0.10), (1.50, 0.08, 0.075)], 10), g, "chest")
    m.add(blob(0.125, 0.15, 0.06, 10, 5).move(0, 1.315, -0.085), "belly", "chest")
    for sx in (-0.06, 0.06):   # stripes down the back
        m.add(tube([(sx, 1.46, 0.105), (sx * 1.2, 1.34, 0.128), (sx * 1.1, 1.20, 0.112)], [0.016, 0.02, 0.016], 4, 0.4, (0, 0, 1)), "accent", "chest")
    for sx, sy, r in ((0.12, 1.40, 0.022), (-0.125, 1.31, 0.026), (-0.02, 1.25, 0.018)):
        m.add(blob(r, r, 0.008, rows=2).move(sx, sy, 0.118 if abs(sx) < 0.1 else 0.088), "spot", "chest")
    m.add(lathe([(1.02, 0.135, 0.105), (1.21, 0.14, 0.108)], 10), g, "spine")
    m.add(blob(0.115, 0.11, 0.05, 10, 4).move(0, 1.11, -0.075), "belly", "spine")
    m.add(lathe([(0.84, 0.11, 0.09), (0.92, 0.16, 0.115), (1.05, 0.14, 0.106)], 10), g, "hips")

    # Arms: thin; the hands' joints are its round pads
    arm(m, g, g, g, 0.04, 0.034, 0.028, 0.05, (0.056, 0.09, 0.085), knuckle="accent")
    launcher(m, -0.262, "dark")

    # Legs: strong thighs, thin shins, wide webbed feet
    leg(m, g, g, 0.08, 0.05, 0.034, calf=1.0)
    web = _along_z(loft([rect8(0.07, 0.05, -0.06, 0.015, cz=0.025), rect8(0.14, 0.035, 0.08, 0.012, cz=0.0175),
                         rect8(0.24, 0.014, 0.22, 0.004, cz=0.007)]))
    m.add_pair(web.move(LX - 0.01, 0.004, 0), g, "foot_l")
    m.add_pair(blob(0.04, rows=4).move(LX, 0.10, 0), g, "foot_l")
    for dx in (-0.105, 0.0, 0.105):
        m.add_pair(blob(0.024, 0.016, 0.024, rows=3).move(LX - 0.01 + dx, 0.018, -0.215), "accent", "foot_l")
    return m


# ---------------------------------------------------------------------------
def skeleton():
    """Bones: a skeleton. A skull with glowing eyes in its sockets, a rib cage with
    a heart in the player's colour, bare bones for limbs."""
    m = Mesh()
    b, x = "armor_bone", "extra_bone"
    m.add(prism(6, 0.024, 0.11).move(0, 1.465, 0.01), b, "head")
    m.add(blob(0.118, 0.105, 0.128, 10, 5).move(0, 1.685, 0.005), b, "head")
    m.add(lathe([(1.505, 0.06, 0.06, -0.035), (1.535, 0.08, 0.085, -0.03), (1.60, 0.098, 0.105, -0.018), (1.65, 0.105, 0.11, -0.01)], 8), b, "head")
    m.add_pair(blob(0.034, 0.03, 0.02, rows=3).move(-0.046, 1.66, -0.112), "black", "head")
    m.add_pair(blob(0.012, rows=3).move(-0.046, 1.66, -0.124), "visor", "head")
    m.add(prism(3, 0.02, 0.016, phase=-math.pi / 2).rot(pitch=90).move(0, 1.607, -0.118), "black", "head")
    m.add(box(0.12, 0.034, 0.012).move(0, 1.548, -0.112), "black", "head")
    for i in range(6):
        m.add(box(0.014, 0.026, 0.012).move(-0.05 + 0.02 * i, 1.55, -0.117), "white", "head")

    # Rib cage round a spine, a heart inside
    m.add(prism(6, 0.026, 0.33).move(0, 1.345, 0.05), b, "chest")
    for y, rx, rz in ((1.24, 0.105, 0.085), (1.30, 0.135, 0.10), (1.36, 0.15, 0.108), (1.42, 0.145, 0.102)):
        m.add(hoop(rx, rz, y, 0.024, 12, a0=math.pi * 0.62, a1=math.pi * 2.38), b, "chest")
    m.add(box(0.036, 0.22, 0.02).move(0, 1.35, -0.103), b, "chest")
    m.add_pair(tube([(0, 1.468, -0.07), (-0.11, 1.475, -0.04), (-0.20, 1.455, 0.0)], [0.014, 0.014, 0.014], 5), b, "chest")
    m.add(blob(0.04, 0.045, 0.035, rows=4).move(0.035, 1.35, -0.01), "accent", "chest")
    for y in (1.05, 1.11, 1.17):
        m.add(prism(6, 0.032, 0.045).move(0, y, 0.03), b, "spine")
    m.add(lathe([(0.86, 0.05, 0.045), (0.93, 0.14, 0.085), (1.01, 0.15, 0.08), (1.04, 0.09, 0.05)], 8), b, "hips")
    m.add(blob(0.05, 0.045, 0.03, rows=3).move(0, 0.95, -0.075), "black", "hips")

    # Arm bones: one above the elbow, two below
    m.add_pair(blob(0.032, rows=3).move(AX, 1.40, 0), b, "upper_arm_l")
    m.add_pair(prism(6, 0.019, 0.26).move(AX, 1.265, 0), b, "upper_arm_l")
    m.add_pair(blob(0.03, rows=3).move(AX, 1.13, 0), b, "forearm_l")
    for dz in (-0.016, 0.016):
        m.add_pair(prism(5, 0.012, 0.23).move(AX, 1.005, dz), b, "forearm_l")
    m.add_pair(blob(0.024, rows=3).move(AX, 0.885, 0), b, "forearm_l")
    hand(m, b, knuckle="dark", bulk=0.8)
    launcher(m, -0.255, "dark")

    # Leg bones
    m.add_pair(blob(0.038, rows=3).move(LX, 0.90, 0), b, "thigh_l")
    m.add_pair(prism(6, 0.023, 0.38).move(LX, 0.70, 0), b, "thigh_l")
    m.add_pair(blob(0.036, rows=3).move(LX, 0.50, 0), b, "shin_l")
    m.add_pair(prism(6, 0.018, 0.36).move(LX - 0.012, 0.30, 0), b, "shin_l")
    m.add_pair(prism(5, 0.011, 0.34).move(LX + 0.022, 0.30, 0.012), b, "shin_l")
    m.add_pair(blob(0.03, rows=3).move(LX, 0.10, 0), b, "foot_l")
    foot = _along_z(loft([rect8(0.06, 0.06, -0.06, 0.015, cz=0.03), rect8(0.075, 0.04, 0.07, 0.012, cz=0.02),
                          rect8(0.085, 0.022, 0.185, 0.006, cz=0.011)]))
    m.add_pair(foot.move(LX, 0.004, 0), b, "foot_l")
    return m


# ---------------------------------------------------------------------------
def alien():
    """Zorp: a little grey visitor. A great bulb of a head, huge black eyes, a slim
    body with a glowing gem on its chest, long fingers."""
    m = Mesh()
    a, x = "armor_alien", "extra_alien"
    m.add(prism(8, 0.03, 0.10).move(0, 1.47, 0), a, "head")
    m.add(lathe([(1.50, 0.05, 0.055, -0.01), (1.535, 0.078, 0.088, -0.012), (1.60, 0.118, 0.124, -0.006), (1.69, 0.152, 0.156, 0.008),
                 (1.765, 0.146, 0.15, 0.014), (1.815, 0.105, 0.108, 0.018), (1.838, 0.04, 0.04, 0.02)], 10), a, "head")
    eye = blob(0.058, 0.036, 0.022, 8, 4)
    m.add_pair(eye.rot(roll=24).rot(yaw=-14).move(-0.064, 1.628, -0.112), "eye_black", "head")
    m.add(box(0.03, 0.007, 0.01).move(0, 1.545, -0.098), "dark", "head")
    m.add_pair(box(0.006, 0.012, 0.01).move(-0.01, 1.582, -0.118), "dark", "head")

    m.add(lathe([(1.19, 0.095, 0.078), (1.32, 0.135, 0.092), (1.43, 0.152, 0.094), (1.475, 0.105, 0.08), (1.50, 0.06, 0.06)], 8), a, "chest")
    m.add(hoop(0.10, 0.082, 1.482, 0.022, 12), "accent", "chest")
    m.add(disc(0.034, 0.016).move(0, 1.385, -0.097), "detail", "chest")
    m.add(disc(0.022, 0.016).move(0, 1.385, -0.104), "visor", "chest")
    m.add(lathe([(1.02, 0.082, 0.068), (1.21, 0.098, 0.08)], 8), a, "spine")
    m.add(lathe([(0.84, 0.085, 0.072), (0.92, 0.128, 0.092), (1.05, 0.088, 0.072)], 8), a, "hips")
    m.add(hoop(0.105, 0.082, 1.0, 0.02, 12, tall=0.03), "accent", "hips")

    arm(m, a, a, a, 0.032, 0.027, 0.023, 0.042, (0.044, 0.07, 0.07), band="accent")
    launcher(m, -0.252, "dark")

    leg(m, a, a, 0.05, 0.036, 0.028, calf=1.0)
    foot = _along_z(loft([rect8(0.06, 0.05, -0.05, 0.015, cz=0.025), rect8(0.075, 0.04, 0.08, 0.012, cz=0.02),
                          rect8(0.05, 0.02, 0.20, 0.006, cz=0.01)]))
    m.add_pair(foot.move(LX, 0.004, 0), a, "foot_l")
    m.add_pair(blob(0.034, rows=3).move(LX, 0.10, 0), a, "foot_l")
    return m


# ---------------------------------------------------------------------------
def cat():
    """Whiskers: a ginger cat. Pointed ears, green eyes, a white muzzle and paws,
    stripes down its back, a long tail, and a collar with a bell in the player's colour."""
    m = Mesh()
    c, x = "armor_cat", "extra_cat"
    m.add(prism(8, 0.055, 0.10).move(0, 1.47, 0), c, "head")
    m.add(lathe([(1.50, 0.08, 0.08, -0.008), (1.545, 0.128, 0.116, -0.01), (1.62, 0.142, 0.13, -0.012), (1.69, 0.134, 0.124, -0.008),
                 (1.745, 0.10, 0.096, -0.004), (1.775, 0.05, 0.05, 0.0)], 10), c, "head")
    ear = loft([rect8(0.085, 0.035, 0.0, 0.01), rect8(0.01, 0.01, 0.105, 0.002, cz=-0.005)])
    m.add_pair(ear.rot(roll=14).move(-0.085, 1.735, 0.0), x, "head")
    inner = loft([rect8(0.05, 0.012, 0.0, 0.004), rect8(0.006, 0.006, 0.07, 0.001)])
    m.add_pair(inner.rot(roll=14).move(-0.086, 1.745, -0.017), "pink", "head")
    m.add_pair(spike((-0.13, 1.585, -0.02), (-0.185, 1.565, -0.01), 0.03, 4, 0.5), x, "head")   # cheek fur
    m.add(blob(0.062, 0.042, 0.04, 8, 4).move(0, 1.582, -0.118), "white", "head")
    m.add(blob(0.016, 0.012, 0.012, rows=3).move(0, 1.606, -0.154), "pink", "head")
    m.add(box(0.006, 0.022, 0.008).move(0, 1.585, -0.156), "dark", "head")
    for dy in (0.008, -0.012):
        m.add_pair(tube([(-0.04, 1.585 + dy * 0.5, -0.146), (-0.16, 1.585 + dy * 2.0, -0.118)], [0.004, 0.003], 4), "white", "head")
    m.add_pair(blob(0.028, 0.026, 0.016, rows=4).move(-0.058, 1.66, -0.124), "eye_green", "head")
    m.add_pair(blob(0.007, 0.022, 0.008, rows=3).move(-0.058, 1.66, -0.136), "black", "head")
    for z in (-0.045, 0.02, 0.08):
        m.add(hoop(0.132 - abs(z) * 0.25, 0.02, 1.70 + 0.045 * (1 - abs(z - 0.02) * 8), 0.016, 10, cz=z, a0=math.pi * 0.2, a1=math.pi * 0.8), "stripe", "head")

    m.add(lathe([(1.19, 0.125, 0.10), (1.30, 0.16, 0.115), (1.42, 0.165, 0.11), (1.475, 0.115, 0.095), (1.50, 0.075, 0.07)], 10), c, "chest")
    m.add(blob(0.10, 0.12, 0.05, 8, 4).move(0, 1.33, -0.078), "white", "chest")
    m.add(hoop(0.10, 0.088, 1.488, 0.024, 12), "accent", "chest")
    m.add(blob(0.022, rows=3).move(0, 1.462, -0.105), "gold", "chest")
    for y, w in ((1.42, 0.172), (1.34, 0.168), (1.26, 0.152)):
        m.add(hoop(w, 0.118, y, 0.014, 12, a0=math.pi * 0.2, a1=math.pi * 0.8, tall=0.028), "stripe", "chest")
    m.add(lathe([(1.02, 0.12, 0.095), (1.21, 0.13, 0.102)], 10), c, "spine")
    m.add(lathe([(0.84, 0.10, 0.085), (0.92, 0.15, 0.108), (1.05, 0.125, 0.098)], 10), c, "hips")
    tail = [(0, 0.95, 0.09), (0, 0.90, 0.21), (0, 0.97, 0.32), (0, 1.12, 0.37), (0, 1.25, 0.35)]
    m.add(tube(tail, [0.034, 0.034, 0.032, 0.03, 0.028], 6), x, "hips")
    m.add(blob(0.034, 0.045, 0.034, rows=4).move(0, 1.28, 0.345), "white", "hips")

    arm(m, c, c, "white", 0.042, 0.037, 0.032, 0.052, (0.062, 0.10, 0.095), back=c, knuckle="pink")
    launcher(m, -0.268)
    leg(m, c, c, 0.07, 0.05, 0.04)
    m.add_pair(blob(0.058, 0.045, 0.10, 8, 4).move(LX, 0.042, -0.05), "white", "foot_l")
    m.add_pair(blob(0.042, rows=3).move(LX, 0.10, 0), c, "foot_l")
    return m


# ---------------------------------------------------------------------------
def rex():
    """Rex: a small dinosaur. A long snout full of teeth, a pale belly, a thick tail,
    clawed hands and feet, and spines down its back in the player's colour."""
    m = Mesh()
    r, x = "armor_rex", "extra_rex"
    m.add(prism(8, 0.07, 0.11).move(0, 1.475, 0.01), r, "head")
    m.add(_along_z(loft([rect8(0.15, 0.12, -0.115, 0.04, cz=1.655), rect8(0.205, 0.165, -0.02, 0.055, cz=1.665),
                         rect8(0.19, 0.14, 0.11, 0.05, cz=1.665)])), r, "head")
    m.add(_along_z(loft([rect8(0.188, 0.138, 0.11, 0.05, cz=1.665), rect8(0.14, 0.095, 0.24, 0.035, cz=1.652),
                         rect8(0.11, 0.065, 0.305, 0.022, cz=1.642)])), x, "head")
    m.add(_along_z(loft([rect8(0.16, 0.05, -0.04, 0.02, cz=1.568), rect8(0.15, 0.045, 0.12, 0.02, cz=1.566),
                         rect8(0.10, 0.034, 0.26, 0.012, cz=1.572), rect8(0.08, 0.026, 0.285, 0.008, cz=1.575)])), x, "head")
    m.add(_along_z(loft([rect8(0.13, 0.03, 0.0, 0.01, cz=1.598), rect8(0.08, 0.02, 0.26, 0.006, cz=1.602)])), "dark", "head")
    for i in range(5):   # teeth
        z = -0.10 - 0.042 * i
        w = 0.092 - 0.011 * i
        m.add_pair(spike((-w, 1.612, z), (-w, 1.585, z), 0.011, 4), "white", "head")
    m.add_pair(blob(0.03, 0.03, 0.022, rows=4).rot(yaw=-55).move(-0.092, 1.695, -0.07), "eye_yellow", "head")
    m.add_pair(blob(0.008, 0.022, 0.01, rows=3).rot(yaw=-55).move(-0.104, 1.695, -0.078), "black", "head")
    m.add_pair(box(0.03, 0.022, 0.08).rot(roll=18).move(-0.092, 1.735, -0.07), x, "head")   # brow ridges
    m.add_pair(box(0.012, 0.01, 0.014).move(-0.03, 1.676, -0.29), "dark", "head")
    for z, h in ((-0.04, 0.05), (0.04, 0.06), (0.105, 0.045)):
        m.add(spike((0, 1.735, z), (0, 1.735 + h, z + 0.03), 0.03, 4, 0.35, (1, 0, 0)), "accent", "head")

    m.add(lathe([(1.19, 0.14, 0.115), (1.30, 0.175, 0.13), (1.42, 0.17, 0.12), (1.475, 0.125, 0.10), (1.50, 0.085, 0.08)], 8), r, "chest")
    for y, w in ((1.42, 0.10), (1.34, 0.115), (1.26, 0.11)):
        m.add(box(w * 2, 0.07, 0.03, 0.012).move(0, y, -0.118 - (0.008 if y < 1.4 else 0.0)), "belly", "chest")
    for y, h in ((1.44, 0.07), (1.34, 0.085), (1.24, 0.07)):
        m.add(spike((0, y, 0.115), (0, y + 0.02, 0.115 + h), 0.035, 4, 0.35, (1, 0, 0)), "accent", "chest")
    m.add(lathe([(1.02, 0.135, 0.108), (1.21, 0.145, 0.118)], 8), r, "spine")
    m.add(box(0.2, 0.07, 0.03, 0.012).move(0, 1.17, -0.108), "belly", "spine")
    m.add(box(0.19, 0.07, 0.03, 0.012).move(0, 1.09, -0.10), "belly", "spine")
    m.add(lathe([(0.84, 0.12, 0.10), (0.92, 0.165, 0.12), (1.05, 0.145, 0.11)], 8), r, "hips")
    tail = [(0, 0.97, 0.06), (0, 0.88, 0.26), (0, 0.76, 0.46), (0, 0.69, 0.64)]
    m.add(tube(tail, [0.085, 0.07, 0.045, 0.01], 8), x, "hips")
    for i in (1, 2):
        p = tail[i]
        m.add(spike((0, p[1] + 0.05, p[2]), (0, p[1] + 0.12 - 0.02 * i, p[2] + 0.04), 0.03, 4, 0.35, (1, 0, 0)), "accent", "hips")

    arm(m, r, r, r, 0.045, 0.04, 0.034, 0.056, (0.058, 0.09, 0.09), band="horn", knuckle="horn")
    launcher(m, -0.27, "dark")

    leg(m, r, r, 0.086, 0.058, 0.042)
    foot = _along_z(loft([rect8(0.09, 0.075, -0.07, 0.02, cz=0.0375), rect8(0.125, 0.06, 0.08, 0.02, cz=0.03),
                          rect8(0.135, 0.03, 0.16, 0.01, cz=0.015)]))
    m.add_pair(foot.move(LX, 0.006, 0), r, "foot_l")
    m.add_pair(blob(0.045, rows=3).move(LX, 0.10, 0), r, "foot_l")
    for dx in (-0.048, 0.0, 0.048):
        m.add_pair(spike((LX + dx, 0.022, -0.155), (LX + dx * 1.25, 0.01, -0.225), 0.016, 4), "horn", "foot_l")
    return m


# ---------------------------------------------------------------------------
def _tufts(m, material, bone, rx, rz, y, n=8, drop=0.07, out=0.02, size=0.045, cx=0.0, cz=0.0, pair=False):
    """A ring of fur (or straw) tufts hanging down from a hem."""
    for i in range(n):
        a = math.pi / n + i * math.tau / n
        base = (cx + rx * math.cos(a), y, cz + rz * math.sin(a))
        tip = (cx + (rx + out) * math.cos(a), y - drop, cz + (rz + out) * math.sin(a))
        part = spike(base, tip, size, 4, 0.45, (math.cos(a), 0.0, math.sin(a)))
        if pair:
            m.add_pair(part, material, bone)
        else:
            m.add(part, material, bone)


def yeti():
    """Yeti: a great shaggy snow beast. A blue face under a dome of white fur, small
    horns, two fangs, huge hands and feet."""
    m = Mesh()
    w, x, s, f = "armor_yeti", "extra_yeti", "skin_yeti", "flesh_yeti"
    m.add(lathe([(1.47, 0.10, 0.10), (1.53, 0.15, 0.14), (1.63, 0.165, 0.152), (1.72, 0.15, 0.14), (1.79, 0.10, 0.098), (1.815, 0.04, 0.04)], 10), w, "head")
    _tufts(m, x, "head", 0.14, 0.13, 1.545, 9, 0.075, 0.03, 0.05)
    m.add(blob(0.10, 0.082, 0.04, 8, 4).move(0, 1.628, -0.128), f, "head")
    m.add(box(0.19, 0.03, 0.04).move(0, 1.70, -0.135), x, "head")   # shaggy brow
    eyes(m, 0.045, 1.655, -0.158, 0.018, "eye_white", "black", 0.5)
    m.add(box(0.03, 0.02, 0.016).move(0, 1.622, -0.166), "dark", "head")
    m.add(box(0.10, 0.014, 0.012).move(0, 1.582, -0.16), "dark", "head")
    m.add_pair(spike((-0.036, 1.582, -0.162), (-0.04, 1.618, -0.168), 0.012, 4), "white", "head")
    m.add_pair(tube([(-0.115, 1.74, 0.0), (-0.165, 1.80, 0.0), (-0.17, 1.86, -0.01)], [0.03, 0.022, 0.004], 5), "horn", "head")

    m.add(lathe([(1.17, 0.17, 0.13), (1.30, 0.215, 0.155), (1.43, 0.22, 0.15), (1.49, 0.16, 0.12), (1.52, 0.09, 0.09)], 10), w, "chest")
    _tufts(m, x, "chest", 0.19, 0.14, 1.24, 10, 0.08, 0.02, 0.06)
    _tufts(m, x, "chest", 0.215, 0.15, 1.40, 10, 0.07, 0.015, 0.055)
    m.add(lathe([(1.0, 0.16, 0.125), (1.2, 0.175, 0.135)], 10), w, "spine")
    m.add(lathe([(0.82, 0.13, 0.11), (0.92, 0.185, 0.14), (1.05, 0.165, 0.13)], 10), w, "hips")
    _tufts(m, x, "hips", 0.17, 0.13, 0.90, 10, 0.08, 0.0, 0.06)

    arm(m, w, w, f, 0.066, 0.06, 0.05, 0.08, (0.075, 0.115, 0.105), 10, back=w)
    _tufts(m, x, "upper_arm_l", 0.06, 0.06, 1.22, 6, 0.07, 0.012, 0.045, AX, 0.0, True)
    _tufts(m, x, "forearm_l", 0.055, 0.055, 0.95, 6, 0.07, 0.012, 0.045, AX, 0.0, True)
    launcher(m, -0.295, "dark")

    leg(m, w, w, 0.092, 0.07, 0.055, 10)
    _tufts(m, x, "thigh_l", 0.075, 0.075, 0.60, 6, 0.07, 0.01, 0.05, LX, 0.0, True)
    _tufts(m, x, "shin_l", 0.06, 0.06, 0.22, 6, 0.08, 0.02, 0.05, LX, 0.0, True)
    foot = _along_z(loft([rect8(0.11, 0.08, -0.08, 0.025, cz=0.04), rect8(0.15, 0.07, 0.08, 0.025, cz=0.035),
                          rect8(0.16, 0.04, 0.17, 0.015, cz=0.02)]))
    m.add_pair(foot.move(LX - 0.01, 0.006, 0), f, "foot_l")
    for dx in (-0.055, 0.0, 0.055):
        m.add_pair(blob(0.03, 0.024, 0.035, rows=3).move(LX - 0.01 + dx, 0.03, -0.185), f, "foot_l")
    return m


# ---------------------------------------------------------------------------
def duck():
    """Quackers: a yellow duck. A flat orange bill, a tuft on its head, feathered
    wings for arms, orange legs and webbed feet, a neckerchief in the player's colour."""
    m = Mesh()
    d, x = "armor_duck", "extra_duck"
    m.add(lathe([(1.47, 0.06, 0.06), (1.53, 0.10, 0.105), (1.60, 0.126, 0.13), (1.69, 0.126, 0.13), (1.76, 0.095, 0.10), (1.79, 0.04, 0.04)], 10), d, "head")
    m.add(_along_z(loft([rect8(0.11, 0.045, 0.09, 0.02, cz=1.61), rect8(0.125, 0.032, 0.19, 0.014, cz=1.602),
                         rect8(0.10, 0.018, 0.245, 0.006, cz=1.597)])), "beak", "head")
    m.add(_along_z(loft([rect8(0.10, 0.03, 0.09, 0.012, cz=1.578), rect8(0.105, 0.02, 0.18, 0.008, cz=1.58),
                         rect8(0.085, 0.012, 0.225, 0.004, cz=1.584)])), "beak", "head")
    m.add_pair(blob(0.02, 0.024, 0.014, rows=3).move(-0.06, 1.675, -0.118), "eye_black", "head")
    m.add_pair(blob(0.007, rows=2).move(-0.054, 1.684, -0.13), "white", "head")
    for dx, h in ((-0.03, 0.06), (0.0, 0.085), (0.03, 0.06)):
        m.add(spike((dx * 0.4, 1.78, 0.0), (dx * 1.6, 1.78 + h, 0.05), 0.022, 4, 0.4, (1, 0, 0)), x, "head")

    m.add(lathe([(1.19, 0.16, 0.13), (1.30, 0.18, 0.14), (1.42, 0.165, 0.125), (1.475, 0.11, 0.095), (1.50, 0.07, 0.07)], 10), d, "chest")
    m.add(hoop(0.105, 0.092, 1.482, 0.03, 12), "accent", "chest")
    m.add(spike((0.0, 1.485, -0.095), (0.0, 1.385, -0.135), 0.06, 4, 0.3, (0, 0, 1)), "accent", "chest")
    m.add(lathe([(1.02, 0.155, 0.125), (1.21, 0.165, 0.132)], 10), d, "spine")
    m.add(lathe([(0.84, 0.12, 0.10), (0.93, 0.175, 0.135), (1.05, 0.165, 0.13)], 10), d, "hips")
    for dx in (-0.05, 0.0, 0.05):   # tail feathers
        m.add(spike((dx, 0.98, 0.11), (dx * 1.8, 1.10 - abs(dx), 0.27), 0.05, 4, 0.3, (0, 1, 0)), x, "hips")

    arm(m, d, d, d, 0.045, 0.04, 0.034, 0.056, (0.056, 0.095, 0.09), band="beak")
    for y, ln in ((1.08, 0.13), (1.01, 0.15), (0.94, 0.13)):   # wing feathers behind the forearm
        m.add_pair(spike((AX, y, 0.02), (AX, y - 0.07, 0.02 + ln), 0.04, 4, 0.3, (1, 0, 0)), x, "forearm_l")
    launcher(m, -0.27)

    m.add_pair(blob(0.078, 0.075, 0.078, 8, 4).move(LX, 0.88, 0), d, "thigh_l")
    m.add_pair(lathe([(0.86, 0.07, 0.07), (0.72, 0.055, 0.055), (0.68, 0.03, 0.03)], 8, LX), d, "thigh_l")
    m.add_pair(prism(6, 0.024, 0.22).move(LX, 0.60, 0), "beak", "thigh_l")
    m.add_pair(blob(0.03, rows=3).move(LX, 0.50, 0), "beak", "shin_l")
    m.add_pair(prism(6, 0.02, 0.38).move(LX, 0.30, 0), "beak", "shin_l")
    web = _along_z(loft([rect8(0.05, 0.045, -0.05, 0.012, cz=0.0225), rect8(0.12, 0.03, 0.08, 0.01, cz=0.015),
                         rect8(0.20, 0.012, 0.21, 0.004, cz=0.006)]))
    m.add_pair(web.move(LX - 0.005, 0.004, 0), "beak", "foot_l")
    m.add_pair(blob(0.03, rows=3).move(LX, 0.10, 0), "beak", "foot_l")
    return m


# ---------------------------------------------------------------------------
def _pumpkin(rx, ry, rz, n=16, rows=6, ribs=8, depth=0.07):
    rings = []
    for i in range(rows + 1):
        a = 0.28 + (math.pi - 0.56) * i / rows
        pts = []
        for j in range(n):
            t = j * math.tau / n
            k = 1.0 - depth * (0.5 - 0.5 * math.cos(ribs * t))
            pts.append((rx * math.sin(a) * k * math.cos(t), -ry * math.cos(a), rz * math.sin(a) * k * math.sin(t)))
        rings.append(pts)
    return loft(rings)


def jack():
    """Jack: a pumpkin-headed scarecrow. A carved face lit from inside in the
    player's colour, a flannel shirt stuffed with straw, patched sackcloth trousers."""
    m = Mesh()
    m.add(prism(8, 0.04, 0.10).move(0, 1.47, 0), "straw", "head")
    m.add(_pumpkin(0.165, 0.14, 0.155).move(0, 1.65, 0), "shell_pumpkin", "head")
    m.add(prism(6, 0.022, 0.06, r_top=0.014).rot(roll=-14).move(0.008, 1.80, 0), "stem", "head")
    tri = prism(3, 0.036, 0.03, phase=-math.pi / 2).rot(pitch=90)
    m.add_pair(tri.rot(roll=-10).move(-0.058, 1.69, -0.135), "visor", "head")
    m.add(prism(3, 0.018, 0.03, phase=-math.pi / 2).rot(pitch=90).move(0, 1.645, -0.146), "visor", "head")
    for i in range(7):   # a jagged grin
        u = (i - 3) / 3.0
        m.add(box(0.026, 0.03 if i % 2 == 0 else 0.018, 0.03).rot(roll=-22 * u).move(0.085 * u, 1.585 + 0.03 * u * u, -0.142 + 0.03 * u * u), "visor", "head")
    _tufts(m, "straw", "head", 0.07, 0.07, 1.525, 8, 0.055, 0.03, 0.035)

    f = "armor_flannel"
    m.add(lathe([(1.19, 0.135, 0.10), (1.30, 0.17, 0.115), (1.42, 0.182, 0.115), (1.475, 0.13, 0.095), (1.50, 0.075, 0.07)], 8), f, "chest")
    m.add(box(0.07, 0.07, 0.016).rot(roll=8).move(-0.07, 1.385, -0.117), "accent", "chest")
    m.add(box(0.03, 0.26, 0.016).move(0, 1.33, -0.117), "dark", "chest")
    for y in (1.26, 1.33, 1.40):
        m.add(disc(0.012, 0.02).move(0, y, -0.122), "gold", "chest")
    m.add(lathe([(1.02, 0.125, 0.092), (1.21, 0.138, 0.1)], 8), f, "spine")
    m.add(box(0.06, 0.06, 0.016).rot(roll=-12).move(0.06, 1.11, -0.098), "burlap", "spine")
    m.add(lathe([(0.84, 0.11, 0.085), (0.92, 0.155, 0.105), (1.05, 0.135, 0.098)], 8), "burlap", "hips")
    m.add(hoop(0.14, 0.102, 1.035, 0.022, 12), "rope", "hips")
    m.add(tube([(0.05, 1.03, -0.108), (0.06, 0.93, -0.12)], [0.012, 0.012], 5), "rope", "hips")

    arm(m, f, f, "burlap", 0.05, 0.044, 0.04, 0.062, band="straw")
    _tufts(m, "straw", "forearm_l", 0.036, 0.036, 0.90, 6, 0.05, 0.012, 0.03, AX, 0.0, True)
    launcher(m, -0.272, "rope")
    leg(m, "burlap", "burlap", 0.074, 0.056, 0.05)
    m.add_pair(box(0.06, 0.06, 0.016).rot(roll=10).move(LX, 0.60, -0.062), "accent", "thigh_l")
    _tufts(m, "straw", "shin_l", 0.046, 0.046, 0.15, 6, 0.045, 0.014, 0.03, LX, 0.0, True)
    shoe(m, "leather", "dark")
    return m


# ---------------------------------------------------------------------------
def astronaut():
    """Cosmo: an astronaut. A round helmet with a gold visor, a puffy suit with a
    control box on the chest and a pack on the back, gloves and boots in the player's colour."""
    m = Mesh()
    s, x = "armor_suit", "extra_suit"
    m.add(lathe([(1.465, 0.10, 0.10), (1.50, 0.13, 0.13), (1.57, 0.165, 0.165), (1.66, 0.175, 0.175), (1.75, 0.155, 0.155), (1.81, 0.10, 0.10),
                 (1.835, 0.035, 0.035)], 10), s, "head")
    m.add(blob(0.128, 0.085, 0.06, 10, 4).move(0, 1.655, -0.128), "eye_gold", "head")
    m.add(hoop(0.132, 0.132, 1.492, 0.03, 12), "detail", "head")
    m.add(prism(5, 0.008, 0.09).move(0.12, 1.83, 0.03), "detail", "head")
    m.add(blob(0.018, rows=3).move(0.12, 1.88, 0.03), "accent", "head")

    m.add(lathe([(1.17, 0.16, 0.125), (1.30, 0.195, 0.14), (1.43, 0.20, 0.135), (1.48, 0.14, 0.11), (1.50, 0.10, 0.10)], 10), s, "chest")
    m.add(box(0.15, 0.10, 0.035, 0.012).move(0, 1.335, -0.142), "detail", "chest")
    m.add(box(0.03, 0.03, 0.012).move(-0.04, 1.35, -0.162), "accent", "chest")
    m.add(box(0.03, 0.03, 0.012).move(0.0, 1.35, -0.162), "visor", "chest")
    m.add(box(0.03, 0.03, 0.012).move(0.04, 1.35, -0.162), "joint", "chest")
    m.add(box(0.11, 0.016, 0.012).move(0, 1.312, -0.162), "joint", "chest")
    m.add(box(0.27, 0.30, 0.10, 0.03).move(0, 1.34, 0.175), "detail", "chest")
    m.add(box(0.20, 0.03, 0.012).move(0, 1.42, 0.228), "accent", "chest")
    m.add(lathe([(1.02, 0.15, 0.12), (1.20, 0.16, 0.125)], 10), s, "spine")
    m.add(lathe([(0.84, 0.125, 0.105), (0.92, 0.175, 0.13), (1.05, 0.155, 0.12)], 10), s, "hips")
    m.add(hoop(0.158, 0.122, 1.03, 0.02, 12, tall=0.04), "accent", "hips")

    arm(m, s, s, "accent", 0.058, 0.052, 0.046, 0.07, (0.066, 0.105, 0.098), back=s, band="detail", knuckle="detail")
    for y, rr, bone in ((1.27, 0.06, "upper_arm_l"), (1.02, 0.056, "forearm_l"), (0.905, 0.05, "forearm_l")):
        m.add_pair(hoop(rr, rr, y, 0.016, 8, tall=0.03).move(AX, 0, 0), "detail", bone)
    launcher(m, -0.288, "detail")

    leg(m, s, s, 0.086, 0.066, 0.058, calf=1.05)
    for y, rr, bone in ((0.62, 0.078, "thigh_l"), (0.36, 0.072, "shin_l")):
        m.add_pair(hoop(rr, rr, y, 0.016, 8, tall=0.03).move(LX, 0, 0), "detail", bone)
    foot = _along_z(loft([rect8(0.13, 0.11, -0.09, 0.03, cz=0.055), rect8(0.14, 0.11, 0.08, 0.03, cz=0.055),
                          rect8(0.13, 0.07, 0.18, 0.03, cz=0.035)]))
    m.add_pair(foot.move(LX, 0.02, 0), "detail", "foot_l")
    m.add_pair(lathe([(0.10, 0.066, 0.07), (0.20, 0.064, 0.066)], 8, LX), "detail", "foot_l")
    m.add_pair(box(0.15, 0.03, 0.29, 0.03).move(LX, 0.015, -0.045), "accent", "foot_l")
    return m


# ---------------------------------------------------------------------------
def imp():
    """Imp: a little devil. Curling horns, pointed ears, yellow eyes, a toothy
    grin and a goatee; ragged trousers, hooves and a tail with a spade on the end."""
    m = Mesh()
    s, f = "skin_imp", "flesh_imp"
    m.add(prism(8, 0.045, 0.10).move(0, 1.47, 0), s, "head")
    m.add(lathe([(1.50, 0.055, 0.065, -0.02), (1.545, 0.092, 0.105, -0.015), (1.62, 0.115, 0.125, -0.01), (1.70, 0.116, 0.126, -0.008),
                 (1.755, 0.092, 0.104, -0.004), (1.785, 0.05, 0.058, 0.0)], 8), s, "head")
    m.add_pair(tube([(-0.065, 1.755, -0.02), (-0.115, 1.82, -0.02), (-0.105, 1.895, -0.06)], [0.03, 0.022, 0.004], 6), "horn", "head")
    ear = loft([rect8(0.025, 0.06, 0.0, 0.008), rect8(0.006, 0.012, 0.11, 0.0, cz=0.02)])
    m.add_pair(ear.rot(roll=55).move(-0.11, 1.64, 0.01), f, "head")
    m.add(loft([rect8(0.036, 0.02, 1.60, 0.006, cz=-0.146), rect8(0.02, 0.012, 1.65, 0.004, cz=-0.138)]), f, "head")
    m.add_pair(blob(0.03, 0.02, 0.014, rows=3).rot(roll=-18).move(-0.05, 1.662, -0.13), "eye_yellow", "head")
    m.add_pair(blob(0.006, 0.016, 0.008, rows=3).move(-0.048, 1.66, -0.141), "black", "head")
    m.add_pair(box(0.062, 0.014, 0.014).rot(roll=-24).move(-0.05, 1.692, -0.134), "dark", "head")
    m.add(box(0.10, 0.026, 0.012).move(0, 1.562, -0.122), "dark", "head")
    for i in range(5):
        m.add(box(0.014, 0.014, 0.012).move(-0.04 + 0.02 * i, 1.568, -0.127), "white", "head")
    m.add(spike((0, 1.525, -0.10), (0, 1.455, -0.125), 0.026, 4), "hair_black", "head")

    m.add(lathe([(1.19, 0.125, 0.098), (1.30, 0.162, 0.112), (1.42, 0.176, 0.112), (1.475, 0.125, 0.095), (1.50, 0.075, 0.07)], 8), s, "chest")
    r = "armor_rags"
    m.add(box(0.045, 0.33, 0.02).rot(roll=-38).move(0.0, 1.345, -0.112), r, "chest")
    m.add(box(0.045, 0.33, 0.02).rot(roll=38).move(0.0, 1.345, -0.112), r, "chest")
    m.add(box(0.045, 0.33, 0.02).rot(roll=-38).move(0.0, 1.345, 0.112), r, "chest")
    m.add(box(0.045, 0.33, 0.02).rot(roll=38).move(0.0, 1.345, 0.112), r, "chest")
    m.add(disc(0.036, 0.024).move(0, 1.345, -0.12), "accent", "chest")
    m.add(lathe([(1.02, 0.118, 0.09), (1.21, 0.13, 0.098)], 8), s, "spine")
    m.add(lathe([(0.84, 0.11, 0.088), (0.92, 0.156, 0.108), (1.06, 0.14, 0.102)], 8), r, "hips")
    m.add(hoop(0.146, 0.106, 1.04, 0.022, 12, tall=0.04), "leather", "hips")
    m.add(box(0.05, 0.05, 0.016).move(0, 1.04, -0.11), "gold", "hips")
    tail = [(0, 0.96, 0.09), (0.02, 0.82, 0.20), (0.05, 0.72, 0.34), (0.06, 0.80, 0.47), (0.05, 0.95, 0.52)]
    m.add(tube(tail, [0.022, 0.02, 0.016, 0.013, 0.011], 5), f, "hips")
    m.add(spike((0.05, 0.94, 0.52), (0.045, 1.06, 0.54), 0.05, 4, 0.3, (1, 0, 0)), f, "hips")

    arm(m, s, s, s, 0.042, 0.036, 0.031, 0.054, (0.058, 0.095, 0.09), band="black", knuckle="black")
    m.add_pair(hoop(0.04, 0.04, 0.93, 0.014, 8, tall=0.04).move(AX, 0, 0), r, "forearm_l")
    launcher(m, -0.266, "dark")

    m.add_pair(blob(0.074, rows=4).move(LX, 0.90, 0), r, "thigh_l")
    m.add_pair(lathe([(0.90, 0.074, 0.074), (0.72, 0.07, 0.07), (0.54, 0.062, 0.062)], 8, LX), r, "thigh_l")
    _tufts(m, r, "thigh_l", 0.058, 0.058, 0.56, 6, 0.07, 0.006, 0.045, LX, 0.0, True)
    m.add_pair(blob(0.048, rows=4).move(LX, 0.50, 0), s, "shin_l")
    m.add_pair(lathe([(0.52, 0.044, 0.044), (0.36, 0.05, 0.052, 0.01), (0.14, 0.032, 0.032)], 8, LX), s, "shin_l")
    hoof = _along_z(loft([rect8(0.08, 0.10, -0.05, 0.02, cz=0.05), rect8(0.09, 0.09, 0.05, 0.02, cz=0.045),
                          rect8(0.075, 0.05, 0.11, 0.015, cz=0.025)]))
    m.add_pair(hoof.move(LX, 0.0, 0), "dark", "foot_l")
    m.add_pair(blob(0.04, rows=3).move(LX, 0.12, 0), s, "foot_l")
    return m


# ---------------------------------------------------------------------------
def snowman():
    """Frosty: a snowman. Coal eyes and a carrot nose, three balls of snow with
    coal buttons, stick arms in mittens, and a scarf in the player's colour."""
    m = Mesh()
    w = "armor_snow"
    m.add(lathe([(1.485, 0.07, 0.07), (1.53, 0.115, 0.115), (1.60, 0.14, 0.14), (1.68, 0.142, 0.142), (1.75, 0.118, 0.118), (1.795, 0.06, 0.06)], 10), w, "head")
    m.add_pair(blob(0.02, rows=3).move(-0.05, 1.69, -0.126), "black", "head")
    m.add(spike((0, 1.645, -0.13), (0, 1.63, -0.27), 0.026, 6), "carrot", "head")
    for i in range(5):
        u = (i - 2) / 2.0
        m.add(blob(0.012, rows=2).move(0.065 * u, 1.575 + 0.022 * u * u, -0.128 + 0.012 * u * u), "black", "head")

    m.add(lathe([(1.17, 0.13, 0.12), (1.24, 0.19, 0.17), (1.34, 0.21, 0.185), (1.44, 0.185, 0.165), (1.50, 0.11, 0.10)], 10), w, "chest")
    for y, z in ((1.27, -0.18), (1.34, -0.187), (1.41, -0.176)):
        m.add(blob(0.018, rows=3).move(0, y, z), "black", "chest")
    m.add(hoop(0.125, 0.118, 1.495, 0.04, 12, tall=0.05), "accent", "chest")
    m.add(tube([(0.07, 1.49, -0.115), (0.085, 1.42, -0.175), (0.085, 1.32, -0.19)], [0.03, 0.03, 0.03], 4, 0.35, (0, 0, 1)), "accent", "chest")
    m.add(lathe([(1.0, 0.20, 0.175), (1.10, 0.215, 0.19), (1.20, 0.19, 0.17)], 10), w, "spine")
    m.add(lathe([(0.80, 0.13, 0.12), (0.88, 0.20, 0.18), (1.0, 0.215, 0.19)], 10), w, "hips")

    m.add_pair(blob(0.05, rows=3).move(AX, 1.40, 0), w, "upper_arm_l")
    m.add_pair(prism(5, 0.017, 0.27).move(AX, 1.265, 0), "wood", "upper_arm_l")
    m.add_pair(blob(0.022, rows=3).move(AX, 1.13, 0), "wood", "forearm_l")
    m.add_pair(prism(5, 0.015, 0.24).move(AX, 1.01, 0), "wood", "forearm_l")
    m.add_pair(spike((AX, 1.06, 0.0), (AX - 0.01, 0.99, 0.07), 0.01, 4), "wood", "forearm_l")
    hand(m, "accent", band="white", bulk=1.15)
    m.add_pair(hoop(0.036, 0.04, 0.892, 0.014, 8, tall=0.03).move(AX, 0, 0), "white", "forearm_l")
    launcher(m, -0.26, "dark")

    m.add_pair(lathe([(0.92, 0.078, 0.078), (0.72, 0.076, 0.076), (0.52, 0.07, 0.07)], 10, LX), w, "thigh_l")
    m.add_pair(blob(0.072, rows=4).move(LX, 0.50, 0), w, "shin_l")
    m.add_pair(lathe([(0.50, 0.07, 0.07), (0.30, 0.068, 0.068), (0.14, 0.06, 0.06)], 10, LX), w, "shin_l")
    shoe(m, "black", "dark", 0.12)
    return m


# ---------------------------------------------------------------------------
def shark():
    """Chomp: a shark on two legs. A pointed snout over rows of teeth, a white
    belly, a fin on its back and its arms, and a tail fin."""
    m = Mesh()
    g, x = "armor_shark", "extra_shark"
    m.add(prism(8, 0.075, 0.11).move(0, 1.475, 0.01), g, "head")
    m.add(_along_z(loft([rect8(0.16, 0.13, -0.115, 0.05, cz=1.66), rect8(0.215, 0.185, -0.01, 0.07, cz=1.665),
                         rect8(0.20, 0.16, 0.10, 0.06, cz=1.668)])), g, "head")
    m.add(_along_z(loft([rect8(0.198, 0.158, 0.10, 0.06, cz=1.668), rect8(0.12, 0.085, 0.24, 0.035, cz=1.685),
                         rect8(0.03, 0.02, 0.32, 0.008, cz=1.695)])), x, "head")
    m.add(_along_z(loft([rect8(0.18, 0.05, -0.05, 0.02, cz=1.558), rect8(0.17, 0.045, 0.09, 0.02, cz=1.558),
                         rect8(0.10, 0.03, 0.205, 0.012, cz=1.57)])), "white", "head")
    m.add(_along_z(loft([rect8(0.15, 0.04, -0.02, 0.01, cz=1.592), rect8(0.09, 0.03, 0.20, 0.008, cz=1.60)])), "dark", "head")
    for i in range(5):
        z = -0.075 - 0.032 * i
        wd = 0.098 - 0.011 * i
        m.add_pair(spike((-wd, 1.612, z), (-wd, 1.588, z), 0.012, 3), "white", "head")
        m.add_pair(spike((-wd + 0.012, 1.578, z - 0.016), (-wd + 0.012, 1.60, z - 0.016), 0.01, 3), "white", "head")
    m.add_pair(blob(0.016, rows=3).move(-0.104, 1.69, -0.07), "eye_black", "head")
    for i in range(3):   # gills
        m.add_pair(box(0.01, 0.06, 0.012).rot(pitch=14).move(-0.098 + 0.004 * i, 1.63, 0.03 + 0.028 * i), "dark", "head")

    m.add(lathe([(1.19, 0.14, 0.115), (1.30, 0.175, 0.13), (1.42, 0.17, 0.12), (1.475, 0.125, 0.10), (1.50, 0.085, 0.08)], 8), g, "chest")
    m.add(blob(0.12, 0.15, 0.05, 8, 4).move(0, 1.32, -0.092), "white", "chest")
    fin = loft([rect8(0.03, 0.17, 0.0, 0.005), rect8(0.02, 0.10, 0.10, 0.004, cz=0.035), rect8(0.006, 0.02, 0.20, 0.0, cz=0.08)])
    m.add(fin.rot(pitch=62).move(0, 1.36, 0.10), x, "chest")
    m.add(lathe([(1.02, 0.135, 0.108), (1.21, 0.145, 0.118)], 8), g, "spine")
    m.add(blob(0.11, 0.11, 0.045, 8, 4).move(0, 1.11, -0.078), "white", "spine")
    m.add(lathe([(0.84, 0.12, 0.10), (0.92, 0.16, 0.12), (1.05, 0.145, 0.11)], 8), g, "hips")
    m.add(tube([(0, 0.97, 0.07), (0, 0.90, 0.24), (0, 0.86, 0.38)], [0.075, 0.05, 0.026], 6), x, "hips")
    m.add(spike((0, 0.86, 0.36), (0, 1.06, 0.50), 0.06, 4, 0.25, (1, 0, 0)), x, "hips")
    m.add(spike((0, 0.86, 0.36), (0, 0.72, 0.46), 0.045, 4, 0.25, (1, 0, 0)), x, "hips")

    arm(m, g, g, g, 0.046, 0.04, 0.034, 0.058, band="white")
    m.add_pair(spike((AX, 1.06, 0.02), (AX, 0.96, 0.14), 0.045, 4, 0.25, (1, 0, 0)), x, "forearm_l")
    launcher(m, -0.27, "dark")
    leg(m, g, g, 0.08, 0.056, 0.042)
    flip = _along_z(loft([rect8(0.08, 0.07, -0.07, 0.02, cz=0.035), rect8(0.13, 0.05, 0.08, 0.015, cz=0.025),
                          rect8(0.17, 0.016, 0.21, 0.005, cz=0.008)]))
    m.add_pair(flip.move(LX - 0.005, 0.004, 0), g, "foot_l")
    m.add_pair(blob(0.042, rows=3).move(LX, 0.10, 0), g, "foot_l")
    return m


# ---------------------------------------------------------------------------
def ninja():
    """Ninja: wrapped head to toe, only the eyes showing. A headband with tails
    and a sash in the player's colour, bound forearms and shins, split-toe boots."""
    m = Mesh()
    g = "armor_gi"
    m.add(prism(8, 0.052, 0.10).move(0, 1.47, 0), g, "head")
    m.add(lathe([(1.50, 0.072, 0.082, -0.012), (1.545, 0.10, 0.114, -0.012), (1.62, 0.114, 0.129, -0.01),
                 (1.70, 0.115, 0.13, -0.008), (1.755, 0.094, 0.108, -0.004), (1.79, 0.05, 0.06, 0.0)], 8), g, "head")
    m.add(box(0.17, 0.042, 0.016, 0.006).move(0, 1.655, -0.133), "flesh_human", "head")
    m.add_pair(box(0.04, 0.024, 0.012).move(-0.045, 1.654, -0.139), "eye_white", "head")
    m.add_pair(box(0.016, 0.02, 0.012).move(-0.043, 1.653, -0.143), "black", "head")
    m.add(hoop(0.118, 0.132, 1.70, 0.012, 12, cz=-0.008, tall=0.035), "accent", "head")
    for dx, drop in ((-0.02, 0.16), (0.03, 0.12)):
        m.add(tube([(dx, 1.70, 0.125), (dx * 2.5, 1.70 - drop * 0.4, 0.185), (dx * 4, 1.70 - drop, 0.21)], [0.02, 0.022, 0.016], 4, 0.3, (0, 0, 1)), "accent", "head")

    m.add(lathe([(1.19, 0.135, 0.098), (1.30, 0.168, 0.112), (1.42, 0.18, 0.112), (1.475, 0.128, 0.095), (1.50, 0.075, 0.07)], 8), g, "chest")
    m.add(box(0.035, 0.30, 0.016).rot(roll=-26).move(-0.045, 1.37, -0.113), "dark", "chest")
    m.add(box(0.035, 0.30, 0.016).rot(roll=26).move(0.045, 1.37, -0.115), "dark", "chest")
    m.add(lathe([(1.02, 0.125, 0.092), (1.21, 0.138, 0.1)], 8), g, "spine")
    m.add(lathe([(0.84, 0.11, 0.085), (0.92, 0.155, 0.105), (1.05, 0.135, 0.098)], 8), g, "hips")
    m.add(hoop(0.142, 0.104, 1.04, 0.016, 12, tall=0.06), "accent", "hips")
    m.add(box(0.05, 0.06, 0.03).move(-0.05, 1.04, -0.112), "accent", "hips")
    for dx in (-0.065, -0.035):
        m.add(box(0.026, 0.15, 0.014).rot(roll=dx * 150).move(dx, 0.955, -0.114), "accent", "hips")

    arm(m, g, g, "skin_human", 0.046, 0.04, 0.034, back=g, band="dark")
    for y in (1.05, 1.0, 0.95, 0.90):
        m.add_pair(hoop(0.04, 0.04, y, 0.01, 8, tall=0.03).move(AX, 0, 0), "dark", "forearm_l")
    launcher(m, -0.268, "dark")
    leg(m, g, g, 0.08, 0.06, 0.044)
    for y in (0.34, 0.28, 0.22, 0.16):
        m.add_pair(hoop(0.05 - (0.34 - y) * 0.03, 0.05 - (0.34 - y) * 0.03, y, 0.01, 8, tall=0.035).move(LX, 0, 0.004), "dark", "shin_l")
    shoe(m, "black", "dark", 0.095)
    m.add_pair(box(0.008, 0.03, 0.06).move(LX + 0.012, 0.045, -0.17), "dark", "foot_l")
    return m


# ---------------------------------------------------------------------------
def zombie():
    """Zombie: a person, some time after. Green skin, a bit of brain showing, one
    eye too big, a torn shirt with a rib or two on view, one shoe."""
    m = Mesh()
    s, f = "skin_zombie", "flesh_zombie"
    _human_head(m, s, f, "hair_black", False)
    m.add(blob(0.075, 0.04, 0.085, 8, 3).move(0.02, 1.775, 0.0), "brain", "head")
    m.add(lathe([(1.60, 0.108, 0.07, 0.07), (1.68, 0.121, 0.10, 0.045), (1.745, 0.116, 0.122, 0.014)], 8), "hair_black", "head")
    m.add(blob(0.034, 0.034, 0.016, rows=3).move(0.048, 1.66, -0.132), "eye_white", "head")
    m.add(blob(0.01, 0.01, 0.008, rows=2).move(0.052, 1.662, -0.146), "black", "head")
    m.add(box(0.08, 0.03, 0.012).rot(roll=6).move(0.005, 1.562, -0.13), "dark", "head")
    for i in range(4):
        m.add(box(0.012, 0.016, 0.012).move(-0.022 + 0.018 * i + (0.004 if i == 2 else 0), 1.568 + 0.003 * i, -0.135), "white", "head")

    r = "armor_rags"
    m.add(lathe([(1.19, 0.135, 0.098), (1.30, 0.17, 0.112), (1.42, 0.182, 0.112), (1.475, 0.13, 0.095), (1.50, 0.075, 0.07)], 8), r, "chest")
    m.add(box(0.10, 0.12, 0.016).move(0.07, 1.28, -0.112), "dark", "chest")   # a hole in the shirt, ribs behind it
    for i in range(3):
        m.add(box(0.085, 0.018, 0.016).move(0.07, 1.245 + 0.035 * i, -0.117), "white", "chest")
    m.add(lathe([(1.03, 0.126, 0.093), (1.21, 0.138, 0.1)], 8), r, "spine")
    _tufts(m, r, "spine", 0.125, 0.092, 1.05, 8, 0.07, 0.0, 0.05)
    m.add(lathe([(0.84, 0.11, 0.085), (0.92, 0.152, 0.103), (1.05, 0.13, 0.095)], 8), "burlap", "hips")

    arm(m, s, s, s)
    m.add(lathe([(1.22, 0.056, 0.058), (1.36, 0.062, 0.064), (1.45, 0.058, 0.06)], 8, AX - 0.005), r, "upper_arm_l")
    _tufts(m, r, "upper_arm_l", 0.052, 0.054, 1.235, 6, 0.05, 0.0, 0.035, AX - 0.005)
    m.add(lathe([(1.36, 0.062, 0.064), (1.45, 0.058, 0.06)], 8, -(AX - 0.005)), r, "upper_arm_r")
    _tufts(m, r, "upper_arm_r", 0.058, 0.06, 1.37, 6, 0.045, 0.0, 0.035, -(AX - 0.005))
    launcher(m, -0.268, "dark")

    m.add_pair(blob(0.074, rows=4).move(LX, 0.90, 0), "burlap", "thigh_l")
    m.add_pair(lathe([(0.90, 0.074, 0.074), (0.72, 0.07, 0.07), (0.52, 0.056, 0.056)], 8, LX), "burlap", "thigh_l")
    m.add(blob(0.058, rows=4).move(LX, 0.50, 0), "burlap", "shin_l")
    m.add(lathe([(0.49, 0.056, 0.056), (0.36, 0.06, 0.06, 0.008), (0.12, 0.047, 0.047)], 8, LX), "burlap", "shin_l")
    m.add(blob(0.05, rows=4).move(-LX, 0.50, 0), s, "shin_r")
    m.add(lathe([(0.47, 0.042, 0.042), (0.36, 0.048, 0.05, 0.008), (0.12, 0.036, 0.036)], 8, -LX), s, "shin_r")
    _tufts(m, "burlap", "shin_r", 0.05, 0.05, 0.50, 6, 0.07, 0.0, 0.04, -LX)
    # One shoe, one bare foot
    part = _along_z(loft([rect8(0.105, 0.085, -0.085, 0.02, cz=0.0425), rect8(0.117, 0.09, 0.07, 0.02, cz=0.045),
                          rect8(0.095, 0.055, 0.185, 0.02, cz=0.0275)]))
    m.add(part.move(LX, 0.012, 0), "leather", "foot_l")
    m.add(blob(0.045, 0.05, 0.05, rows=4).move(LX, 0.11, 0.0), "leather", "foot_l")
    m.add(box(0.125, 0.022, 0.285, 0.02).move(LX, 0.011, -0.048), "dark", "foot_l")
    bare = _along_z(loft([rect8(0.08, 0.07, -0.07, 0.02, cz=0.035), rect8(0.105, 0.055, 0.09, 0.02, cz=0.0275),
                          rect8(0.11, 0.03, 0.18, 0.012, cz=0.015)]))
    m.add(bare.move(-LX, 0.006, 0), s, "foot_r")
    m.add(blob(0.04, rows=4).move(-LX, 0.10, 0), s, "foot_r")
    return m


# ---------------------------------------------------------------------------
def wizard():
    """Wizard: an old one. A long white beard and bushy brows, a robe to the
    ankles with wide sleeves, a rope belt, a star on the chest, curly-toed shoes."""
    m = Mesh()
    _human_head(m, brow="", mouth=False)
    h = "hair_white"
    m.add(lathe([(1.52, 0.10, 0.05, 0.09), (1.60, 0.12, 0.075, 0.07), (1.69, 0.122, 0.10, 0.045), (1.75, 0.105, 0.105, 0.022)], 8), h, "head")
    m.add(loft([rect8(0.17, 0.05, 1.60, 0.02, cz=-0.118), rect8(0.16, 0.07, 1.53, 0.025, cz=-0.128),
                rect8(0.10, 0.05, 1.40, 0.02, cz=-0.142), rect8(0.02, 0.012, 1.30, 0.004, cz=-0.15)]), h, "head")
    m.add_pair(tube([(-0.008, 1.59, -0.145), (-0.06, 1.578, -0.14), (-0.10, 1.60, -0.12)], [0.018, 0.016, 0.005], 5), h, "head")
    m.add_pair(box(0.062, 0.022, 0.022).rot(roll=-10).move(-0.05, 1.69, -0.136), h, "head")

    r = "armor_robe"
    m.add(lathe([(1.19, 0.14, 0.105), (1.30, 0.172, 0.118), (1.42, 0.182, 0.115), (1.475, 0.13, 0.098), (1.50, 0.08, 0.075)], 8), r, "chest")
    m.add(hoop(0.10, 0.085, 1.485, 0.022, 12, tall=0.03), "accent", "chest")
    star = None
    for i in range(5):
        p = spike((0, 0, 0), (0.05 * math.sin(i * math.tau / 5), 0.05 * math.cos(i * math.tau / 5), 0), 0.02, 4, 0.3, (0, 0, 1))
        star = p if star is None else star + p
    m.add(star.move(-0.07, 1.385, -0.118), "gold", "chest")
    m.add(lathe([(1.02, 0.135, 0.10), (1.21, 0.145, 0.108)], 8), r, "spine")
    m.add(lathe([(0.84, 0.13, 0.10), (0.92, 0.165, 0.115), (1.05, 0.142, 0.104)], 8), r, "hips")
    m.add(lathe([(0.97, 0.166, 0.118), (0.80, 0.19, 0.14)], 8, caps=(False, False)), r, "hips")
    m.add(hoop(0.148, 0.108, 1.04, 0.022, 12), "rope", "hips")
    for dx, ln in ((0.045, 0.20), (0.075, 0.14)):
        m.add(tube([(dx, 1.04, -0.112), (dx + 0.01, 1.04 - ln, -0.132)], [0.011, 0.011], 5), "rope", "hips")
        m.add(blob(0.018, rows=3).move(dx + 0.01, 1.03 - ln, -0.132), "rope", "hips")

    # Wide sleeves, flaring to the wrist
    m.add_pair(blob(0.062, rows=4).move(AX, 1.40, 0), r, "upper_arm_l")
    m.add_pair(lathe([(1.40, 0.05, 0.05), (1.15, 0.052, 0.056)], 8, AX), r, "upper_arm_l")
    m.add_pair(blob(0.056, rows=4).move(AX, 1.13, 0), r, "forearm_l")
    m.add_pair(lathe([(1.12, 0.052, 0.056), (0.93, 0.064, 0.085, 0.012)], 8, AX), r, "forearm_l")
    m.add_pair(lathe([(0.945, 0.066, 0.087, 0.012), (0.925, 0.066, 0.087, 0.012)], 8, AX), "accent", "forearm_l")
    hand(m, "skin_human")
    launcher(m, -0.285)

    # The robe's skirt: a split panel down each leg
    m.add_pair(lathe([(0.86, 0.095, 0.105), (0.50, 0.102, 0.115)], 8, LX - 0.005, caps=(False, True)), r, "thigh_l")
    m.add_pair(lathe([(0.52, 0.098, 0.11), (0.15, 0.112, 0.125)], 8, LX - 0.005, caps=(True, True)), r, "shin_l")
    m.add_pair(lathe([(0.17, 0.114, 0.127), (0.14, 0.114, 0.127)], 8, LX - 0.005), "accent", "shin_l")
    toe = _along_z(loft([rect8(0.09, 0.07, -0.07, 0.02, cz=0.035), rect8(0.10, 0.065, 0.07, 0.02, cz=0.0325),
                         rect8(0.05, 0.04, 0.19, 0.012, cz=0.02)]))
    m.add_pair(toe.move(LX, 0.006, 0), "leather", "foot_l")
    m.add_pair(tube([(LX, 0.03, -0.18), (LX, 0.06, -0.225), (LX, 0.10, -0.215)], [0.02, 0.014, 0.004], 5), "leather", "foot_l")
    m.add_pair(blob(0.04, rows=3).move(LX, 0.10, 0), "leather", "foot_l")
    return m


# ---------------------------------------------------------------------------
def bear():
    """Teddy: a brown bear. Round ears, a pale muzzle and belly, stout limbs, paw
    pads, a stub of a tail, and a bow tie in the player's colour."""
    m = Mesh()
    b, x = "armor_bear", "extra_bear"
    m.add(lathe([(1.47, 0.08, 0.08), (1.53, 0.13, 0.12), (1.61, 0.152, 0.138, -0.008), (1.70, 0.145, 0.132, -0.006), (1.76, 0.11, 0.10), (1.795, 0.05, 0.05)], 10), b, "head")
    m.add_pair(blob(0.05, 0.05, 0.03, 8, 4).move(-0.115, 1.775, 0.0), x, "head")
    m.add_pair(blob(0.028, 0.028, 0.012, rows=3).move(-0.115, 1.775, -0.024), "belly", "head")
    m.add(blob(0.07, 0.052, 0.05, 8, 4).move(0, 1.59, -0.125), "belly", "head")
    m.add(blob(0.024, 0.018, 0.016, rows=3).move(0, 1.612, -0.172), "black", "head")
    m.add(box(0.006, 0.03, 0.008).move(0, 1.585, -0.172), "dark", "head")
    m.add_pair(blob(0.016, rows=3).move(-0.058, 1.672, -0.128), "eye_black", "head")

    m.add(lathe([(1.18, 0.16, 0.13), (1.30, 0.19, 0.145), (1.42, 0.185, 0.13), (1.475, 0.125, 0.10), (1.50, 0.08, 0.08)], 10), b, "chest")
    m.add(blob(0.125, 0.14, 0.05, 8, 4).move(0, 1.31, -0.105), "belly", "chest")
    for side in (-1, 1):
        m.add(spike((0, 1.478, -0.10), (side * 0.07, 1.478, -0.115), 0.04, 4, 0.5, (0, 0, 1)), "accent", "chest")
    m.add(blob(0.018, rows=3).move(0, 1.478, -0.106), "accent", "chest")
    m.add(lathe([(1.0, 0.155, 0.128), (1.2, 0.165, 0.135)], 10), b, "spine")
    m.add(blob(0.12, 0.10, 0.045, 8, 4).move(0, 1.11, -0.10), "belly", "spine")
    m.add(lathe([(0.83, 0.125, 0.105), (0.92, 0.175, 0.135), (1.05, 0.16, 0.13)], 10), b, "hips")
    m.add(blob(0.045, rows=3).move(0, 0.95, 0.135), x, "hips")

    arm(m, b, b, b, 0.056, 0.05, 0.044, 0.068, (0.07, 0.105, 0.10), 10, knuckle="belly")
    launcher(m, -0.282)
    leg(m, b, b, 0.088, 0.066, 0.055, 10)
    m.add_pair(blob(0.07, 0.05, 0.105, 8, 4).move(LX, 0.046, -0.045), b, "foot_l")
    m.add_pair(blob(0.05, rows=3).move(LX, 0.11, 0), b, "foot_l")
    for dx in (-0.035, 0.0, 0.035):
        m.add_pair(blob(0.016, 0.012, 0.016, rows=2).move(LX + dx, 0.06, -0.142), "belly", "foot_l")
    return m


# ---------------------------------------------------------------------------
def mushroom():
    """Shroom: a toadstool on legs. A wide spotted cap, a little face on the stalk,
    a frill round its shoulders, stubby boots."""
    m = Mesh()
    c = "armor_cap"
    m.add(lathe([(1.47, 0.085, 0.085), (1.55, 0.105, 0.105), (1.66, 0.105, 0.105)], 10, caps=(True, False)), "belly", "head")
    m.add(lathe([(1.64, 0.20, 0.20), (1.70, 0.185, 0.185), (1.77, 0.13, 0.13), (1.81, 0.05, 0.05)], 12), c, "head")
    m.add(lathe([(1.625, 0.10, 0.10), (1.642, 0.198, 0.198)], 12, caps=(False, False)), "peel", "head")
    for a, y, rr in ((0.3, 1.72, 0.03), (1.5, 1.70, 0.035), (2.6, 1.745, 0.026), (3.7, 1.70, 0.034), (4.9, 1.725, 0.03), (0.0, 1.795, 0.03)):
        rad = 0.19 if y < 1.71 else (0.165 if y < 1.74 else (0.14 if y < 1.78 else 0.0))
        m.add(blob(rr, 0.02, rr, rows=2).move(rad * math.cos(a), y + 0.004, rad * math.sin(a)), "white", "head")
    eyes(m, 0.04, 1.59, -0.098, 0.016, "eye_black", "white", 0.3, 0.004)
    m.add(box(0.04, 0.008, 0.01).move(0, 1.545, -0.103), "dark", "head")
    m.add_pair(blob(0.014, 0.008, 0.006, rows=2).move(-0.062, 1.56, -0.088), "pink", "head")

    m.add(lathe([(1.19, 0.14, 0.12), (1.30, 0.16, 0.13), (1.42, 0.15, 0.12), (1.475, 0.11, 0.095), (1.50, 0.08, 0.08)], 10), "belly", "chest")
    m.add(lathe([(1.485, 0.085, 0.085), (1.44, 0.175, 0.15)], 12, caps=(False, False)), "peel", "chest")
    m.add(hoop(0.172, 0.148, 1.442, 0.012, 12), "accent", "chest")
    m.add(lathe([(1.02, 0.14, 0.12), (1.21, 0.145, 0.122)], 10), "belly", "spine")
    m.add(lathe([(0.84, 0.11, 0.095), (0.92, 0.155, 0.125), (1.05, 0.145, 0.122)], 10), "belly", "hips")

    arm(m, "belly", "belly", c, 0.04, 0.036, 0.032, 0.05, (0.062, 0.095, 0.09), band="white")
    launcher(m, -0.265)
    leg(m, "belly", "belly", 0.068, 0.052, 0.045)
    shoe(m, c, "dark", 0.11)
    return m


# ---------------------------------------------------------------------------
def banana():
    """Peel: a banana. A curved tip for a head with a face on it, the skin peeled
    down round its waist, thin black limbs, white gloves and trainers."""
    m = Mesh()
    b, x = "armor_banana", "extra_banana"
    m.add(lathe([(1.47, 0.115, 0.105), (1.56, 0.118, 0.108, -0.004), (1.66, 0.105, 0.098, -0.012), (1.75, 0.075, 0.07, -0.03),
                 (1.82, 0.04, 0.04, -0.055)], 8), b, "head")
    m.add(tube([(0, 1.815, -0.055), (0, 1.86, -0.08), (0, 1.88, -0.11)], [0.03, 0.022, 0.018], 6), "wood", "head")
    eyes(m, 0.042, 1.64, -0.106, 0.022, "eye_white", "black", 0.5, 0.0, 1.3)
    m.add(hoop(0.05, 0.03, 1.575, 0.01, 10, cz=-0.082, a0=math.pi * 1.15, a1=math.pi * 1.85), "dark", "head")

    m.add(lathe([(1.17, 0.125, 0.115), (1.30, 0.135, 0.122), (1.42, 0.13, 0.118), (1.50, 0.115, 0.105)], 8), b, "chest")
    m.add(lathe([(1.0, 0.11, 0.10), (1.19, 0.125, 0.115)], 8), b, "spine")
    m.add(lathe([(0.84, 0.09, 0.08), (0.92, 0.105, 0.095), (1.03, 0.112, 0.10)], 8), "peel", "hips")
    for i in range(4):   # the peel, hanging open
        a = math.pi / 4 + i * math.tau / 4
        cs, sn = math.cos(a), math.sin(a)
        path = [(0.10 * cs, 1.05, 0.09 * sn), (0.20 * cs, 1.02, 0.18 * sn), (0.25 * cs, 0.88, 0.23 * sn), (0.24 * cs, 0.72, 0.22 * sn)]
        m.add(tube(path, [0.085, 0.09, 0.075, 0.02], 4, 0.18, (cs, 0.4, sn)), x, "hips")
        inner = [(p[0] * 0.95, p[1] - 0.012, p[2] * 0.95) for p in path]
        m.add(tube(inner, [0.075, 0.08, 0.065, 0.015], 4, 0.14, (cs, 0.4, sn)), "peel", "hips")

    m.add_pair(blob(0.04, rows=3).move(AX, 1.40, 0), "black", "upper_arm_l")
    m.add_pair(prism(6, 0.022, 0.27).move(AX, 1.265, 0), "black", "upper_arm_l")
    m.add_pair(blob(0.026, rows=3).move(AX, 1.13, 0), "black", "forearm_l")
    m.add_pair(prism(6, 0.02, 0.22).move(AX, 1.01, 0), "black", "forearm_l")
    m.add_pair(hoop(0.034, 0.036, 0.90, 0.016, 8, tall=0.035).move(AX, 0, 0), "white", "forearm_l")
    hand(m, "white", band="black", bulk=1.07)
    launcher(m, -0.258, "dark")

    m.add_pair(blob(0.04, rows=3).move(LX, 0.90, 0), "black", "thigh_l")
    m.add_pair(prism(6, 0.026, 0.40).move(LX, 0.70, 0), "black", "thigh_l")
    m.add_pair(blob(0.03, rows=3).move(LX, 0.50, 0), "black", "shin_l")
    m.add_pair(prism(6, 0.023, 0.38).move(LX, 0.30, 0), "black", "shin_l")
    shoe(m, "white", "accent", toe="accent")
    return m


## Which of a creature's materials take the creator's second colour ("trim") and its
## detail colour ("mark"): {creature: {material: role}}. The pieces are modelled under
## their plain names above (several creatures share "belly", "white", "leather", and
## it is not the same part on each); the kit is written with the role in front
## ("trim_denim"), which is what the game goes by. A role ending in "!" leaves the
## head's pieces of that material alone (a banana's black limbs, not its pupils).
ROLES = {
    "human": {"denim": "trim"},
    "goblin": {"leather": "trim"},
    "frog": {"belly": "trim", "spot": "mark"},
    "cat": {"white": "trim", "stripe": "mark"},
    "rex": {"belly": "trim", "horn": "mark"},
    "yeti": {"horn": "mark"},
    "duck": {"beak": "trim"},
    "jack": {"burlap": "trim", "straw": "mark"},
    "astronaut": {"detail": "trim"},
    "imp": {"leather": "trim", "horn": "mark"},
    "snowman": {"black": "trim"},
    "shark": {"white": "trim"},
    "ninja": {"dark": "trim"},
    "zombie": {"burlap": "trim"},
    "wizard": {"leather": "trim", "rope": "trim"},
    "bear": {"belly": "trim"},
    "mushroom": {"belly": "trim", "white": "mark"},
    "banana": {"black": "trim!"},
}
for _roles in ROLES.values():
    for _name, _role in _roles.items():
        MATERIALS["%s_%s" % (_role.rstrip("!"), _name)] = MATERIALS[_name]


def _with_roles(name, build):
    def made():
        mesh = build()
        roles = ROLES.get(name, {})
        for t in mesh.tris:
            role = roles.get(t.material)
            if role and not (role.endswith("!") and t.bone == "head"):
                t.material = "%s_%s" % (role.rstrip("!"), t.material)
        return mesh
    return made


KITS = {"human": human, "goblin": goblin, "frog": frog, "skeleton": skeleton, "alien": alien, "cat": cat, "rex": rex, "yeti": yeti,
        "duck": duck, "jack": jack, "astronaut": astronaut, "imp": imp, "snowman": snowman, "shark": shark,
        "ninja": ninja, "zombie": zombie, "wizard": wizard, "bear": bear, "mushroom": mushroom, "banana": banana}
KITS = {k: _with_roles(k, f) for k, f in KITS.items()}
