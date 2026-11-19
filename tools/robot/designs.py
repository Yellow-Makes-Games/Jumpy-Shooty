"""The robot's shape. Parts are modelled in the rest pose (standing, arms down,
facing -Z) and each is tied to one bone, so the robot moves as rigid segments.

Materials (the game recolours "accent" and "visor" per player):
  armor   the main shell          accent  player-colour panels
  joint   dark joints and hands   visor   the glowing face
  detail  mid-grey trim
  steel, mail, cloth, cross   the Templar's plate, chain mail, white surcoat and red cross
The guns are in weapons.py: every robot holds all of them, and the game shows one.
"""
import math
import numpy as np
from kit import Mesh, Part, loft, rect, ngon, box, prism, ball, bead, face
import hands
import weapons

# Colours are written the way the game's own code writes them (sRGB) and turned into what
# a model file holds (linear) below. Surfaces are satin: only the glowing parts shine.
_LOOKS = {
    "armor": {"color": (0.90, 0.91, 0.93), "metallic": 0.05, "roughness": 0.72},
    "accent": {"color": (0.95, 0.35, 0.25), "metallic": 0.05, "roughness": 0.65},
    "joint": {"color": (0.38, 0.40, 0.43), "metallic": 0.15, "roughness": 0.72},
    "detail": {"color": (0.63, 0.65, 0.68), "metallic": 0.2, "roughness": 0.65},
    "visor": {"color": (0.25, 0.25, 0.27), "metallic": 0.0, "roughness": 0.3, "emission": (0.95, 0.35, 0.25)},
    # The Templar's own surfaces (the game leaves any kind but accent and visor as built).
    "steel": {"color": (0.83, 0.84, 0.86), "metallic": 0.75, "roughness": 0.32},
    "mail": {"color": (0.665, 0.673, 0.688), "metallic": 0.6, "roughness": 0.6},
    "cloth": {"color": (0.969, 0.959, 0.936), "metallic": 0.0, "roughness": 0.9},
    "cross": {"color": (0.854, 0.272, 0.293), "metallic": 0.0, "roughness": 0.8},
}
MATERIALS = {k: dict(v, color=weapons._lin(*v["color"])) for k, v in _LOOKS.items()}
MATERIALS.update(weapons.materials())   # "<gun>.<kind>": each gun's own surfaces (see weapons.py)


def _along_z(rings_part):
    """Turn a part built upwards (+Y) so that it runs forwards (-Z)."""
    return rings_part.rot(pitch=-90)


def vanguard():
    """Design A: an athletic armoured frame. Broad shoulders, narrow waist, a helmet
    with one wide visor band."""
    m = Mesh()
    # Head
    m.add(prism(6, 0.055, 0.10).move(0, 1.47, 0), "joint", "head")
    m.add(loft([rect(0.18, 0.20, 1.485, 0.045, cz=-0.01), rect(0.24, 0.26, 1.57, 0.06, cz=-0.015),
                rect(0.24, 0.26, 1.70, 0.06, cz=-0.015), rect(0.16, 0.18, 1.785, 0.045, cz=0.0)]), "armor", "head")
    m.add(loft([rect(0.225, 0.06, 1.585, 0.02, cz=-0.13), rect(0.225, 0.06, 1.67, 0.02, cz=-0.13)]), "visor", "head")
    m.add(loft([rect(0.03, 0.20, 1.775, 0.0, cz=0.01), rect(0.03, 0.13, 1.82, 0.0, cz=0.045)]), "accent", "head")
    m.add_pair(prism(6, 0.045, 0.03).rot(roll=90).move(-0.125, 1.63, 0.0), "detail", "head")

    # Torso: chest tapers to the waist
    m.add(loft([rect(0.26, 0.18, 1.19, 0.045), rect(0.41, 0.25, 1.33, 0.06, cz=-0.005),
                rect(0.40, 0.24, 1.45, 0.06), rect(0.25, 0.16, 1.50, 0.045)]), "armor", "chest")
    m.add(loft([rect(0.20, 0.03, 1.29, 0.03, cz=-0.128), rect(0.27, 0.03, 1.44, 0.04, cz=-0.128)]), "accent", "chest")
    m.add(box(0.08, 0.04, 0.02).move(0, 1.375, -0.15), "visor", "chest")
    m.add(loft([rect(0.24, 0.08, 1.26, 0.02, cz=0.145), rect(0.27, 0.10, 1.45, 0.03, cz=0.15)]), "detail", "chest")
    m.add(loft([rect(0.20, 0.15, 1.03, 0.04), rect(0.24, 0.17, 1.21, 0.04)]), "joint", "spine")
    m.add(loft([rect(0.22, 0.16, 0.84, 0.04), rect(0.33, 0.21, 0.94, 0.055), rect(0.27, 0.18, 1.06, 0.045)]), "armor", "hips")
    m.add(box(0.11, 0.075, 0.02).move(0, 0.955, -0.105), "accent", "hips")

    # Arms (left, mirrored to the right)
    m.add_pair(ball(0.068).move(-0.215, 1.40, 0), "joint", "upper_arm_l")
    m.add_pair(loft([rect(0.14, 0.17, 1.37, 0.04, cx=-0.25), rect(0.16, 0.19, 1.44, 0.045, cx=-0.255),
                     rect(0.10, 0.13, 1.495, 0.03, cx=-0.24)]), "accent", "upper_arm_l")
    m.add_pair(loft([rect(0.10, 0.105, 1.36, 0.025, cx=-0.22), rect(0.085, 0.09, 1.17, 0.022, cx=-0.215)]), "armor", "upper_arm_l")
    m.add_pair(ball(0.052).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect(0.085, 0.095, 1.10, 0.022, cx=-0.215), rect(0.12, 0.135, 0.99, 0.03, cx=-0.215),
                     rect(0.10, 0.11, 0.90, 0.025, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(box(0.125, 0.032, 0.14, 0.03).move(-0.215, 0.95, 0), "accent", "forearm_l")
    hands.add(m, 1.0)
    # Grapple launcher on the outside of the left forearm
    m.add(box(0.05, 0.16, 0.07, 0.012).move(-0.295, 0.985, 0), "detail", "forearm_l")
    m.add(prism(6, 0.02, 0.035).move(-0.295, 0.895, 0), "accent", "forearm_l")

    # Legs
    m.add_pair(ball(0.07).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([rect(0.14, 0.155, 0.875, 0.035, cx=-0.11), rect(0.14, 0.155, 0.71, 0.035, cx=-0.11),
                     rect(0.105, 0.115, 0.545, 0.028, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.057).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(box(0.095, 0.10, 0.035, 0.025).move(-0.10, 0.50, -0.06), "accent", "shin_l")
    m.add_pair(loft([rect(0.10, 0.11, 0.455, 0.028, cx=-0.10), rect(0.135, 0.16, 0.33, 0.035, cx=-0.10, cz=0.012),
                     rect(0.095, 0.105, 0.14, 0.025, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(ball(0.047).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect(0.11, 0.085, -0.085, 0.018, cz=0.0425), rect(0.125, 0.09, 0.07, 0.018, cz=0.045),
                          rect(0.10, 0.045, 0.185, 0.012, cz=0.0225)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    weapons.add_all(m)
    return m


def brick():
    """Design B: a chunky, friendly bot. Big square head with a screen face, small
    upper limbs, oversized gauntlets and boots."""
    m = Mesh()
    # Head: a big box with a dark screen and two glowing eyes
    m.add(prism(8, 0.07, 0.07).move(0, 1.465, 0), "joint", "head")
    m.add(loft([rect(0.29, 0.25, 1.49, 0.05, cz=-0.01), rect(0.31, 0.27, 1.54, 0.05, cz=-0.01),
                rect(0.31, 0.27, 1.73, 0.05, cz=-0.01), rect(0.27, 0.23, 1.775, 0.05, cz=-0.01)]), "armor", "head")
    m.add(box(0.245, 0.02, 0.15, 0.025).rot(pitch=90).move(0, 1.635, -0.146), "joint", "head")
    m.add_pair(box(0.05, 0.065, 0.02).move(-0.058, 1.645, -0.156), "visor", "head")
    m.add_pair(box(0.03, 0.09, 0.10, 0.01).move(-0.165, 1.63, 0.0), "accent", "head")
    m.add(prism(6, 0.012, 0.09).move(0.09, 1.82, 0.03), "detail", "head")
    m.add(ball(0.028).move(0.09, 1.875, 0.03), "accent", "head")

    # Torso: one big block
    m.add(loft([rect(0.36, 0.24, 1.13, 0.05), rect(0.43, 0.28, 1.25, 0.06), rect(0.43, 0.28, 1.42, 0.06),
                rect(0.34, 0.22, 1.47, 0.05)]), "armor", "chest")
    m.add(box(0.22, 0.02, 0.15, 0.03).rot(pitch=90).move(0, 1.32, -0.145), "accent", "chest")
    m.add(box(0.09, 0.045, 0.02).move(0, 1.33, -0.158), "visor", "chest")
    m.add(loft([rect(0.26, 0.10, 1.20, 0.03, cz=0.17), rect(0.26, 0.10, 1.42, 0.03, cz=0.17)]), "detail", "chest")
    m.add(loft([rect(0.26, 0.18, 1.02, 0.05), rect(0.28, 0.19, 1.14, 0.05)]), "joint", "spine")
    m.add(loft([rect(0.28, 0.19, 0.84, 0.05), rect(0.36, 0.24, 0.90, 0.06), rect(0.36, 0.24, 1.03, 0.06)]), "armor", "hips")
    m.add(box(0.37, 0.045, 0.25, 0.06).move(0, 1.0, 0), "accent", "hips")

    # Arms: ball shoulders, thin upper arms, huge gauntlets and mitts
    m.add_pair(ball(0.085).move(-0.235, 1.40, 0), "accent", "upper_arm_l")
    m.add_pair(prism(6, 0.042, 0.24).move(-0.215, 1.25, 0), "joint", "upper_arm_l")
    m.add_pair(ball(0.05).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect(0.10, 0.10, 1.10, 0.03, cx=-0.215), rect(0.16, 0.17, 1.02, 0.04, cx=-0.22),
                     rect(0.16, 0.17, 0.90, 0.04, cx=-0.22)]), "armor", "forearm_l")
    m.add_pair(box(0.165, 0.035, 0.175, 0.04).move(-0.22, 0.915, 0), "accent", "forearm_l")
    hands.add(m, 1.35)
    m.add(box(0.05, 0.13, 0.08, 0.012).move(-0.32, 0.975, 0), "detail", "forearm_l")
    m.add(prism(6, 0.022, 0.035).move(-0.32, 0.895, 0), "accent", "forearm_l")

    # Legs: thin thighs, big boots
    m.add_pair(ball(0.075).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(prism(6, 0.06, 0.36).move(-0.10, 0.70, 0), "joint", "thigh_l")
    m.add_pair(loft([rect(0.13, 0.14, 0.80, 0.03, cx=-0.105), rect(0.12, 0.13, 0.62, 0.03, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.07).move(-0.10, 0.50, 0), "accent", "shin_l")
    m.add_pair(loft([rect(0.12, 0.13, 0.47, 0.03, cx=-0.10), rect(0.17, 0.19, 0.38, 0.045, cx=-0.105),
                     rect(0.17, 0.19, 0.12, 0.045, cx=-0.105)]), "armor", "shin_l")
    foot = _along_z(loft([rect(0.17, 0.12, -0.10, 0.03, cz=0.06), rect(0.18, 0.12, 0.10, 0.03, cz=0.06),
                          rect(0.16, 0.08, 0.20, 0.03, cz=0.04)]))
    m.add_pair(foot.move(-0.105, 0, 0), "armor", "foot_l")
    m.add_pair(box(0.185, 0.03, 0.31, 0.03).move(-0.105, 0.015, -0.05), "joint", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
# Joints. A limb's two halves are stiff pieces that turn about the joint's own point
# (the bone's place in rig.BODY), so whatever fills a joint has to be centred there: a
# dark core (kit.bead) that both halves reach. Each half ends in a sleeve, a little
# wider than the core and stopping just short of the joint's point, its open end faced
# dark. Straight, a slim band of core shows between the two sleeves; bent, the sleeves
# slide over the core, and nothing opens up.

SEAM = 0.009           # a sleeve's rim, from the joint's point


def _oct(rx, rz, y, cx=0.0, cz=0.0):
    """An eight-sided ring (half-widths rx, rz) with its points in rect8's order, so
    the two loft together."""
    return rect(2 * rx, 2 * rz, y, min(rx, rz) * 0.59, cx, cz)


def _sleeve(m, rings, bone, joints, material="armor", pair=True):
    """A limb's piece, lofted through `rings`. joints: {0 or -1: the joint's point} for
    each end (the first ring, the last) that is a sleeve's open rim."""
    part = loft(rings, cap_start=0 not in joints, cap_end=-1 not in joints)
    add = m.add_pair if pair else m.add
    add(part, material, bone)
    for end, point in joints.items():
        add(face(rings[end], point), "joint", bone)


def _hinge(m, r, at, bone, wide=1.2):
    """An elbow's or knee's core: a bead lying across the limb, its ends just proud of
    the sleeves, with the pin through it."""
    m.add_pair(bead(r, squash=wide).rot(roll=90).move(*at), "joint", bone)
    m.add_pair(prism(6, r * 0.26, r * 1.88 * wide + 0.008).rot(roll=90).move(*at), "detail", bone)


def needle():
    """Design C: a slim, sleek frame. Round sensor head with one big eye, thin
    struts between socketed joints, blade-like forearms and shins."""
    m = Mesh()
    # Head: a pod with one eye and an antenna
    m.add(bead(0.046, 6).move(0, 1.50, 0), "joint", "head")   # the neck's core, half in the head and half in the chest
    m.add(loft([ngon(8, 0.06, 1.50, 0.07, cz=-0.01), ngon(8, 0.115, 1.56, 0.135, cz=-0.015),
                ngon(8, 0.125, 1.65, 0.145, cz=-0.015), ngon(8, 0.105, 1.73, 0.12, cz=-0.01),
                ngon(8, 0.05, 1.78, 0.06, cz=0.0)]), "armor", "head")
    m.add(prism(8, 0.062, 0.03).rot(pitch=90).move(0, 1.635, -0.152), "joint", "head")
    m.add(prism(8, 0.045, 0.03).rot(pitch=90).move(0, 1.635, -0.162), "visor", "head")
    m.add(prism(5, 0.008, 0.16).rot(pitch=-12).move(0.06, 1.83, 0.06), "detail", "head")
    m.add(ball(0.02).move(0.06, 1.91, 0.077), "accent", "head")
    m.add(loft([ngon(8, 0.126, 1.69, 0.146, cz=-0.015), ngon(8, 0.118, 1.715, 0.136, cz=-0.012)]), "accent", "head")

    # Torso: a small core on a thin spine
    m.add(loft([ngon(8, 0.07, 1.17, 0.06), ngon(8, 0.15, 1.30, 0.10), ngon(8, 0.185, 1.43, 0.115),
                ngon(8, 0.10, 1.50, 0.08)]), "armor", "chest")
    m.add(prism(6, 0.04, 0.03).rot(pitch=90).move(0, 1.37, -0.108), "visor", "chest")
    m.add(loft([ngon(8, 0.186, 1.415, 0.116), ngon(8, 0.17, 1.455, 0.11)]), "accent", "chest")
    m.add(loft([ngon(8, 0.058, 1.155, 0.05), ngon(8, 0.058, 1.18, 0.05)]), "joint", "chest")   # the socket the spine runs up into
    m.add(loft([ngon(6, 0.038, 1.02), ngon(6, 0.034, 1.21)]), "joint", "spine")
    m.add(bead(0.054).move(0, 1.06, 0), "joint", "spine")
    m.add(loft([ngon(8, 0.08, 0.85, 0.07), ngon(8, 0.15, 0.93, 0.10), ngon(8, 0.08, 1.03, 0.07)]), "armor", "hips")

    # Arms: a strut from the ball at the shoulder to a sleeve at the elbow, then a blade
    ax = -0.215
    elbow, wrist = (ax, 1.13, 0), (ax, 0.88, 0)
    m.add_pair(ball(0.058).move(ax, 1.40, 0), "accent", "upper_arm_l")
    m.add_pair(loft([ngon(6, 0.027, 1.16, cx=ax), ngon(6, 0.031, 1.38, cx=ax)]), "joint", "upper_arm_l")
    # The arm's own sleeve under the shoulder. It leaves the ball as a neck no wider than
    # the strut and only widens once it is clear of the ball's underside (1.351), so it
    # does not cut through the ball's faces; it is short, to leave the strut showing
    # between it and the elbow's sleeve.
    m.add_pair(loft([_oct(0.033, 0.033, 1.366, cx=ax), _oct(0.033, 0.033, 1.336, cx=ax), _oct(0.037, 0.040, 1.318, cx=ax),
                     _oct(0.037, 0.040, 1.303, cx=ax), _oct(0.029, 0.029, 1.276, cx=ax)]), "armor", "upper_arm_l")
    _sleeve(m, [_oct(0.029, 0.029, 1.225, cx=ax), _oct(0.041, 0.044, 1.185, cx=ax), _oct(0.043, 0.046, 1.13 + SEAM, cx=ax)],
            "upper_arm_l", {-1: elbow})
    _hinge(m, 0.038, elbow, "forearm_l")
    _sleeve(m, [_oct(0.043, 0.046, 1.13 - SEAM, cx=ax), rect8(0.058, 0.064, 1.075, 0.017, cx=ax),
                rect8(0.075, 0.095, 0.99, 0.02, cx=ax), rect8(0.052, 0.060, 0.918, 0.015, cx=ax),
                rect8(0.060, 0.066, 0.88 + SEAM, 0.017, cx=ax)], "forearm_l", {0: elbow, -1: wrist})
    m.add_pair(bead(0.027, 6).move(*wrist), "joint", "hand_l")   # the wrist's core
    hands.add(m, 0.8)
    m.add(box(0.035, 0.13, 0.05, 0.008).move(-0.268, 0.985, 0), "detail", "forearm_l")
    m.add(prism(6, 0.016, 0.03).move(-0.268, 0.905, 0), "accent", "forearm_l")

    # Legs: the same, with a slim fairing down the front of the thigh
    lx = -0.10
    knee, ankle = (lx, 0.50, 0), (lx, 0.10, 0)
    m.add_pair(ball(0.058).move(lx, 0.90, 0), "accent", "thigh_l")
    m.add_pair(loft([ngon(6, 0.032, 0.53, cx=lx), ngon(6, 0.036, 0.87, cx=lx)]), "joint", "thigh_l")
    m.add_pair(loft([rect8(0.044, 0.022, 0.845, 0.008, cx=lx, cz=-0.046), rect8(0.074, 0.034, 0.80, 0.012, cx=lx, cz=-0.046),
                     rect8(0.076, 0.036, 0.70, 0.012, cx=lx, cz=-0.045), rect8(0.056, 0.026, 0.60, 0.009, cx=lx, cz=-0.04)]),
               "armor", "thigh_l")
    _sleeve(m, [_oct(0.034, 0.034, 0.605, cx=lx), _oct(0.045, 0.048, 0.565, cx=lx), _oct(0.047, 0.050, 0.50 + SEAM, cx=lx)],
            "thigh_l", {-1: knee})
    _hinge(m, 0.042, knee, "shin_l")
    _sleeve(m, [_oct(0.047, 0.050, 0.50 - SEAM, cx=lx), rect8(0.062, 0.072, 0.44, 0.017, cx=lx),
                rect8(0.08, 0.12, 0.33, 0.02, cx=lx, cz=0.012), rect8(0.046, 0.052, 0.14, 0.012, cx=lx),
                rect8(0.058, 0.064, 0.10 + SEAM + 0.004, 0.016, cx=lx)], "shin_l", {0: knee, -1: ankle})
    m.add_pair(bead(0.034, 6).move(*ankle), "joint", "foot_l")   # the ankle's core
    foot = _along_z(loft([rect(0.07, 0.06, -0.06, 0.012, cz=0.03), rect(0.08, 0.065, 0.06, 0.012, cz=0.0325),
                          rect(0.05, 0.03, 0.19, 0.008, cz=0.015)]))
    m.add_pair(foot.move(lx, 0, 0), "armor", "foot_l")
    _sleeve(m, [_oct(0.036, 0.046, 0.05, cx=lx, cz=-0.004), _oct(0.039, 0.043, 0.10 - SEAM - 0.006, cx=lx)],
            "foot_l", {-1: ankle})   # the foot's own sleeve, round the ankle
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
# The second wave of robots (Kestrel, Bulwark, Rivet, Specter, Orbit), and their helpers.

def rect8(w, d, y=0.0, chamfer=0.0, cx=0.0, cz=0.0):
    """rect, but always 8 points, so rings with and without cut corners loft together."""
    return rect(w, d, y, max(chamfer, 0.002), cx, cz)


def _ring(r, thick, depth, n=12, phase=0.0):
    """A flat ring in the XY plane (facing -Z) made of n chunky segments."""
    seg = 2 * r * math.sin(math.pi / n) * 1.08
    parts = None
    for i in range(n):
        a = phase + i * math.tau / n
        p = box(seg, thick, depth).rot(roll=math.degrees(a) + 90).move(r * math.cos(a), r * math.sin(a), 0)
        parts = p if parts is None else parts + p
    return parts


def _arms_common(m, launcher_x=-0.29, launcher_y=0.985):
    """Wrists, hands and the grapple launcher on the left forearm (every robot has one)."""
    m.add(box(0.045, 0.15, 0.065, 0.01).move(launcher_x, launcher_y, 0), "detail", "forearm_l")
    m.add(prism(6, 0.019, 0.035).move(launcher_x, launcher_y - 0.09, 0), "accent", "forearm_l")


# ---------------------------------------------------------------------------
def kestrel():
    """Scout: a raptor-like racer. Wedge helmet with a slit visor and swept-back
    crest fins, twin back thrusters, talon feet with heel spurs."""
    m = Mesh()
    # Head: a forward-pointing wedge
    m.add(prism(6, 0.045, 0.10).move(0, 1.47, 0), "joint", "head")
    m.add(loft([rect8(0.14, 0.17, 1.49, 0.04, cz=0.01), rect8(0.20, 0.27, 1.56, 0.05, cz=-0.025),
                rect8(0.20, 0.30, 1.655, 0.05, cz=-0.02), rect8(0.13, 0.24, 1.745, 0.04, cz=0.02)]), "armor", "head")
    m.add(loft([rect8(0.06, 0.06, 1.54, 0.01, cz=-0.17), rect8(0.10, 0.04, 1.60, 0.012, cz=-0.175)]), "armor", "head")  # beak
    m.add(loft([rect8(0.205, 0.03, 1.605, 0.01, cz=-0.158), rect8(0.17, 0.03, 1.64, 0.01, cz=-0.153)]), "visor", "head")
    fin = loft([rect8(0.016, 0.05, 0.0, 0.0, cz=0.03), rect8(0.012, 0.20, 0.06, 0.0, cz=0.13), rect8(0.006, 0.10, 0.13, 0.0, cz=0.20)])
    m.add_pair(fin.rot(roll=14).move(-0.07, 1.70, 0), "accent", "head")
    m.add_pair(prism(6, 0.035, 0.02).rot(roll=90).move(-0.105, 1.62, 0.03), "detail", "head")

    # Torso: a deep V chest, slim waist
    m.add(loft([rect8(0.20, 0.15, 1.19, 0.04), rect8(0.36, 0.22, 1.35, 0.06, cz=-0.01),
                rect8(0.37, 0.22, 1.45, 0.06), rect8(0.22, 0.15, 1.50, 0.04)]), "armor", "chest")
    m.add_pair(box(0.13, 0.035, 0.02).rot(roll=-32).move(-0.06, 1.34, -0.125), "accent", "chest")
    m.add(box(0.05, 0.05, 0.02).rot(roll=45).move(0, 1.40, -0.123), "visor", "chest")
    # Thruster pack on the back
    m.add(loft([rect8(0.24, 0.06, 1.27, 0.02, cz=0.125), rect8(0.27, 0.07, 1.45, 0.02, cz=0.125)]), "detail", "chest")
    for x in (-0.09, 0.09):
        m.add(prism(8, 0.058, 0.26, r_top=0.048).move(x, 1.33, 0.215), "armor", "chest")
        m.add(prism(8, 0.06, 0.03).move(x, 1.40, 0.215), "accent", "chest")
        m.add(prism(8, 0.046, 0.06, r_top=0.058).move(x, 1.17, 0.215), "joint", "chest")
        m.add(prism(8, 0.036, 0.02).move(x, 1.137, 0.215), "visor", "chest")
        m.add(loft([rect8(0.012, 0.06, 1.40, 0.0, cz=0.27), rect8(0.012, 0.10, 1.47, 0.0, cz=0.29),
                    rect8(0.008, 0.03, 1.53, 0.0, cz=0.31)]).move(x, 0, 0), "accent", "chest")
    m.add(prism(6, 0.045, 0.19).move(0, 1.11, 0), "joint", "spine")
    m.add(loft([rect8(0.18, 0.14, 0.85, 0.035), rect8(0.28, 0.19, 0.94, 0.05), rect8(0.20, 0.15, 1.05, 0.04)]), "armor", "hips")
    m.add(loft([rect8(0.10, 0.02, 0.96, 0.0, cz=-0.098), rect8(0.04, 0.02, 0.88, 0.0, cz=-0.08)]), "accent", "hips")

    # Arms: slim with swept shoulder blades and forearm fins
    m.add_pair(ball(0.058).move(-0.215, 1.40, 0), "joint", "upper_arm_l")
    m.add_pair(loft([rect8(0.10, 0.16, 1.37, 0.03, cx=-0.24, cz=0.01), rect8(0.12, 0.20, 1.445, 0.035, cx=-0.245, cz=0.03),
                     rect8(0.06, 0.16, 1.49, 0.02, cx=-0.235, cz=0.06)]), "accent", "upper_arm_l")
    m.add_pair(loft([rect8(0.08, 0.085, 1.36, 0.02, cx=-0.217), rect8(0.065, 0.07, 1.17, 0.018, cx=-0.215)]), "armor", "upper_arm_l")
    m.add_pair(ball(0.045).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect8(0.07, 0.075, 1.10, 0.018, cx=-0.215), rect8(0.095, 0.11, 0.99, 0.025, cx=-0.215),
                     rect8(0.075, 0.08, 0.90, 0.02, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(loft([rect8(0.012, 0.03, 0.93, 0.0, cx=-0.215, cz=0.05), rect8(0.012, 0.06, 1.05, 0.0, cx=-0.215, cz=0.075),
                     rect8(0.008, 0.02, 1.15, 0.0, cx=-0.215, cz=0.10)]), "accent", "forearm_l")
    hands.add(m, 0.88)
    _arms_common(m, -0.275)

    # Legs: lean thighs, swept-back calves, talon feet
    m.add_pair(ball(0.062).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([rect8(0.12, 0.14, 0.87, 0.03, cx=-0.11), rect8(0.12, 0.14, 0.72, 0.03, cx=-0.11),
                     rect8(0.085, 0.10, 0.55, 0.022, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.05).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(loft([rect8(0.06, 0.02, 0.56, 0.0, cx=-0.10, cz=-0.05), rect8(0.08, 0.05, 0.49, 0.01, cx=-0.10, cz=-0.08),
                     rect8(0.05, 0.02, 0.42, 0.0, cx=-0.10, cz=-0.06)]), "accent", "shin_l")  # knee spike
    m.add_pair(loft([rect8(0.08, 0.10, 0.46, 0.022, cx=-0.10), rect8(0.11, 0.17, 0.32, 0.03, cx=-0.10, cz=0.035),
                     rect8(0.07, 0.08, 0.14, 0.02, cx=-0.10, cz=0.0)]), "armor", "shin_l")
    m.add_pair(ball(0.04).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect8(0.09, 0.07, -0.07, 0.015, cz=0.035), rect8(0.10, 0.07, 0.07, 0.015, cz=0.035),
                          rect8(0.05, 0.025, 0.21, 0.006, cz=0.012)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    spur = loft([rect8(0.03, 0.04, 0.10, 0.0, cz=0.06), rect8(0.02, 0.03, 0.05, 0.0, cz=0.12), rect8(0.006, 0.01, 0.01, 0.0, cz=0.15)])
    m.add_pair(spur.move(-0.10, 0, 0), "accent", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
def bulwark():
    """Heavy: a walking tank. Low head tucked into a high collar with a brow and
    three eyes, barrel chest with a grille, big round pauldrons, piston legs."""
    m = Mesh()
    # Head: low and wide, sunk into the collar
    m.add(prism(8, 0.06, 0.08).move(0, 1.47, 0), "joint", "head")
    m.add(loft([ngon(8, 0.10, 1.49, 0.10, phase=math.pi / 8), ngon(8, 0.13, 1.54, 0.13, phase=math.pi / 8),
                ngon(8, 0.13, 1.63, 0.13, phase=math.pi / 8), ngon(8, 0.09, 1.69, 0.09, phase=math.pi / 8)]), "armor", "head")
    m.add(loft([rect8(0.24, 0.07, 1.625, 0.015, cz=-0.11), rect8(0.25, 0.08, 1.665, 0.02, cz=-0.105)]), "accent", "head")  # brow
    m.add(box(0.19, 0.05, 0.02).move(0, 1.585, -0.12), "joint", "head")
    for x in (-0.06, 0.0, 0.06):
        m.add(prism(6, 0.017, 0.02).rot(pitch=90).move(x, 1.585, -0.132), "visor", "head")

    # Torso: barrel chest with a high collar
    m.add(loft([rect8(0.32, 0.22, 1.17, 0.05), rect8(0.48, 0.31, 1.30, 0.08, cz=-0.01), rect8(0.48, 0.31, 1.44, 0.08),
                rect8(0.40, 0.28, 1.50, 0.07)]), "armor", "chest")
    m.add(loft([rect8(0.38, 0.27, 1.49, 0.07, cz=0.02), rect8(0.36, 0.26, 1.58, 0.07, cz=0.03)], cap_end=False), "detail", "chest")
    m.add(loft([rect8(0.25, 0.02, 1.27, 0.02, cz=-0.16), rect8(0.30, 0.02, 1.43, 0.02, cz=-0.16)]), "accent", "chest")
    for i in range(4):
        m.add(box(0.20, 0.016, 0.02).move(0, 1.30 + 0.033 * i, -0.172), "joint", "chest")
    m.add(loft([rect8(0.30, 0.10, 1.22, 0.03, cz=0.17), rect8(0.34, 0.12, 1.47, 0.03, cz=0.17)]), "detail", "chest")
    m.add_pair(prism(6, 0.03, 0.18).move(-0.10, 1.53, 0.21), "joint", "chest")  # exhaust stacks
    m.add(loft([rect8(0.26, 0.19, 1.02, 0.05), rect8(0.30, 0.21, 1.18, 0.05)]), "joint", "spine")
    m.add(loft([rect8(0.27, 0.20, 0.82, 0.05), rect8(0.38, 0.25, 0.92, 0.07), rect8(0.32, 0.22, 1.05, 0.06)]), "armor", "hips")
    m.add_pair(box(0.10, 0.12, 0.17, 0.02).rot(roll=12).move(-0.20, 0.88, 0), "accent", "hips")  # side plates

    # Arms: dome pauldrons, thick limbs, heavy gauntlets
    m.add_pair(ball(0.075).move(-0.22, 1.40, 0), "joint", "upper_arm_l")
    m.add_pair(loft([ngon(8, 0.09, 1.30, 0.11, cx=-0.27), ngon(8, 0.125, 1.39, 0.145, cx=-0.285),
                     ngon(8, 0.10, 1.48, 0.12, cx=-0.27), ngon(8, 0.04, 1.52, 0.05, cx=-0.25)]), "accent", "upper_arm_l")
    m.add_pair(loft([rect8(0.11, 0.115, 1.30, 0.03, cx=-0.215), rect8(0.095, 0.10, 1.17, 0.025, cx=-0.215)]), "armor", "upper_arm_l")
    m.add_pair(ball(0.058).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect8(0.10, 0.11, 1.10, 0.025, cx=-0.215), rect8(0.15, 0.16, 1.01, 0.04, cx=-0.215),
                     rect8(0.14, 0.15, 0.90, 0.035, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(box(0.155, 0.03, 0.165, 0.035).move(-0.215, 1.03, 0), "detail", "forearm_l")
    hands.add(m, 1.25)
    _arms_common(m, -0.315)

    # Legs: thick thighs, knee guards, piston shins, wide feet
    m.add_pair(ball(0.075).move(-0.105, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([rect8(0.16, 0.17, 0.87, 0.04, cx=-0.115), rect8(0.16, 0.17, 0.70, 0.04, cx=-0.115),
                     rect8(0.12, 0.13, 0.55, 0.03, cx=-0.105)]), "armor", "thigh_l")
    m.add_pair(ball(0.062).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(loft([rect8(0.12, 0.03, 0.57, 0.01, cx=-0.10, cz=-0.075), rect8(0.13, 0.04, 0.46, 0.012, cx=-0.10, cz=-0.08)]), "accent", "shin_l")
    m.add_pair(loft([rect8(0.12, 0.13, 0.45, 0.03, cx=-0.10), rect8(0.15, 0.17, 0.32, 0.04, cx=-0.10),
                     rect8(0.14, 0.15, 0.15, 0.035, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(prism(6, 0.02, 0.26).move(-0.10, 0.31, 0.10), "detail", "shin_l")  # piston behind the calf
    m.add_pair(ball(0.05).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect8(0.15, 0.10, -0.09, 0.025, cz=0.05), rect8(0.16, 0.10, 0.08, 0.025, cz=0.05),
                          rect8(0.15, 0.06, 0.19, 0.02, cz=0.03)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    m.add_pair(box(0.165, 0.025, 0.29, 0.02).move(-0.10, 0.0125, -0.045), "joint", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
def rivet():
    """Worker: a site robot. Hard hat, one camera-lens eye with ear guards, hazard
    stripes, a tank backpack with exhaust pipes, knee pads and work boots."""
    m = Mesh()
    # Head: a rounded box under a hard hat
    m.add(prism(6, 0.05, 0.10).move(0, 1.47, 0), "joint", "head")
    m.add(loft([rect8(0.18, 0.18, 1.49, 0.05), rect8(0.22, 0.22, 1.54, 0.06), rect8(0.22, 0.22, 1.68, 0.06)]), "armor", "head")
    m.add(loft([ngon(10, 0.17, 1.675, 0.175, cz=-0.02), ngon(10, 0.17, 1.695, 0.175, cz=-0.02)]), "accent", "head")  # brim
    m.add(loft([ngon(10, 0.13, 1.69, 0.13), ngon(10, 0.125, 1.76, 0.125), ngon(10, 0.085, 1.81, 0.085),
                ngon(10, 0.02, 1.825, 0.02)]), "accent", "head")
    m.add(box(0.03, 0.025, 0.24).move(0, 1.80, 0.0), "detail", "head")  # hat ridge
    m.add(prism(8, 0.065, 0.04).rot(pitch=90).move(0, 1.605, -0.125), "detail", "head")  # lens barrel
    m.add(prism(8, 0.05, 0.03).rot(pitch=90).move(0, 1.605, -0.148), "joint", "head")
    m.add(prism(8, 0.035, 0.02).rot(pitch=90).move(0, 1.605, -0.162), "visor", "head")
    m.add_pair(prism(8, 0.045, 0.05).rot(roll=90).move(-0.13, 1.60, 0.01), "joint", "head")  # ear guards

    # Torso: boxy, with a hazard-striped band and a tank backpack
    m.add(loft([rect8(0.30, 0.20, 1.18, 0.04), rect8(0.42, 0.26, 1.28, 0.05), rect8(0.42, 0.26, 1.44, 0.05),
                rect8(0.30, 0.20, 1.50, 0.04)]), "armor", "chest")
    m.add(box(0.38, 0.065, 0.02).move(0, 1.30, -0.131), "joint", "chest")
    for i in range(6):
        m.add(box(0.03, 0.075, 0.02).rot(roll=-35).move(-0.15 + 0.06 * i, 1.30, -0.139), "accent", "chest")
    m.add(box(0.11, 0.045, 0.015).move(0, 1.40, -0.133), "visor", "chest")  # status light
    m.add(prism(10, 0.10, 0.28).rot(roll=90).move(0, 1.40, 0.19), "detail", "chest")  # tank
    m.add(box(0.24, 0.20, 0.06, 0.02).move(0, 1.32, 0.15), "joint", "chest")
    m.add_pair(prism(6, 0.022, 0.24).move(-0.09, 1.51, 0.20), "joint", "chest")  # exhausts
    m.add_pair(prism(6, 0.03, 0.03).move(-0.09, 1.635, 0.20), "accent", "chest")
    m.add(loft([rect8(0.22, 0.16, 1.03, 0.04), rect8(0.26, 0.18, 1.19, 0.04)]), "joint", "spine")
    m.add(loft([rect8(0.24, 0.17, 0.84, 0.04), rect8(0.34, 0.22, 0.93, 0.05), rect8(0.28, 0.19, 1.05, 0.045)]), "armor", "hips")
    m.add(box(0.35, 0.05, 0.23, 0.03).move(0, 0.985, 0), "joint", "hips")  # tool belt
    m.add_pair(box(0.06, 0.08, 0.07, 0.01).move(-0.15, 0.94, -0.09), "detail", "hips")  # pouches
    m.add(box(0.07, 0.045, 0.02).move(0, 0.985, -0.122), "accent", "hips")

    # Arms: rounded shoulders, work gloves
    m.add_pair(ball(0.065).move(-0.215, 1.40, 0), "joint", "upper_arm_l")
    m.add_pair(loft([ngon(8, 0.07, 1.35, 0.08, cx=-0.24), ngon(8, 0.09, 1.42, 0.10, cx=-0.245),
                     ngon(8, 0.05, 1.49, 0.06, cx=-0.235)]), "armor", "upper_arm_l")
    m.add_pair(prism(6, 0.04, 0.22).move(-0.215, 1.24, 0), "joint", "upper_arm_l")
    m.add_pair(ball(0.05).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect8(0.085, 0.09, 1.10, 0.02, cx=-0.215), rect8(0.11, 0.12, 1.00, 0.028, cx=-0.215),
                     rect8(0.10, 0.11, 0.91, 0.025, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(box(0.12, 0.05, 0.13, 0.025).move(-0.215, 0.905, 0), "accent", "forearm_l")  # glove cuff
    hands.add(m, 1.1)
    _arms_common(m, -0.29)

    # Legs: knee pads and chunky work boots with toe caps
    m.add_pair(ball(0.068).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([rect8(0.13, 0.14, 0.86, 0.03, cx=-0.105), rect8(0.13, 0.14, 0.70, 0.03, cx=-0.105),
                     rect8(0.10, 0.11, 0.55, 0.025, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.055).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(box(0.11, 0.11, 0.04, 0.02).move(-0.10, 0.50, -0.065), "accent", "shin_l")
    m.add_pair(loft([rect8(0.10, 0.11, 0.45, 0.025, cx=-0.10), rect8(0.12, 0.14, 0.33, 0.03, cx=-0.10),
                     rect8(0.11, 0.12, 0.22, 0.03, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(loft([rect8(0.14, 0.16, 0.10, 0.035, cx=-0.10, cz=-0.01), rect8(0.14, 0.16, 0.24, 0.035, cx=-0.10)]), "detail", "shin_l")
    foot = _along_z(loft([rect8(0.15, 0.10, -0.09, 0.025, cz=0.05), rect8(0.15, 0.10, 0.10, 0.025, cz=0.05),
                          rect8(0.14, 0.08, 0.19, 0.03, cz=0.04)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    m.add_pair(box(0.155, 0.065, 0.07, 0.02).move(-0.10, 0.04, -0.15), "accent", "foot_l")  # toe cap
    m.add_pair(box(0.16, 0.025, 0.29, 0.02).move(-0.10, 0.0125, -0.04), "joint", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
def specter():
    """Stealth: an angular hooded frame. A dark face behind a V visor, a scarf
    trailing off the collar, blade fins along the forearms and calves."""
    m = Mesh()
    # Head: a hood with a pointed peak and a dark face plate
    m.add(prism(6, 0.035, 0.10).move(0, 1.47, 0), "joint", "head")
    m.add(loft([ngon(6, 0.085, 1.49, 0.10, phase=math.pi / 2, cz=0.01), ngon(6, 0.125, 1.56, 0.14, phase=math.pi / 2),
                ngon(6, 0.13, 1.66, 0.15, phase=math.pi / 2, cz=0.0), ngon(6, 0.07, 1.76, 0.10, phase=math.pi / 2, cz=0.03),
                ngon(6, 0.01, 1.81, 0.02, phase=math.pi / 2, cz=0.07)]), "armor", "head")
    m.add(loft([rect8(0.17, 0.02, 1.53, 0.0, cz=-0.128), rect8(0.20, 0.02, 1.60, 0.0, cz=-0.14), rect8(0.18, 0.02, 1.67, 0.0, cz=-0.135)]), "joint", "head")
    m.add_pair(box(0.085, 0.022, 0.02).rot(roll=-20).move(-0.038, 1.615, -0.152), "visor", "head")

    # Torso: angular chest, crossed straps, a collar scarf with a tail
    m.add(loft([rect8(0.18, 0.14, 1.19, 0.03), rect8(0.33, 0.20, 1.34, 0.05), rect8(0.35, 0.21, 1.45, 0.05),
                rect8(0.20, 0.14, 1.50, 0.03)]), "armor", "chest")
    m.add(loft([ngon(8, 0.13, 1.44, 0.12), ngon(8, 0.15, 1.49, 0.13), ngon(8, 0.11, 1.54, 0.10)]), "accent", "chest")
    tail = loft([rect8(0.10, 0.02, 1.47, 0.0, cz=0.13), rect8(0.12, 0.02, 1.30, 0.0, cz=0.20),
                 rect8(0.11, 0.02, 1.12, 0.0, cz=0.28), rect8(0.05, 0.02, 0.98, 0.0, cz=0.34)])
    m.add(tail.rot(yaw=12).move(0.03, 0, 0), "accent", "chest")
    m.add_pair(box(0.03, 0.30, 0.02).rot(roll=-30).move(0, 1.33, -0.112), "joint", "chest")
    m.add(prism(6, 0.04, 0.20).move(0, 1.11, 0), "joint", "spine")
    m.add(loft([rect8(0.17, 0.13, 0.85, 0.03), rect8(0.27, 0.18, 0.93, 0.05), rect8(0.18, 0.13, 1.04, 0.035)]), "armor", "hips")
    m.add(box(0.29, 0.035, 0.19, 0.02).move(0, 0.985, 0), "accent", "hips")
    m.add_pair(loft([rect8(0.03, 0.15, 0.0, 0.01), rect8(0.02, 0.13, -0.15, 0.01)]).rot(roll=-10).move(-0.16, 0.95, 0), "detail", "hips")

    # Arms: thin, with long blade fins sweeping back past the elbow
    m.add_pair(ball(0.055).move(-0.215, 1.40, 0), "joint", "upper_arm_l")
    m.add_pair(loft([rect8(0.08, 0.13, 1.36, 0.02, cx=-0.235), rect8(0.10, 0.15, 1.44, 0.03, cx=-0.245),
                     rect8(0.03, 0.10, 1.50, 0.0, cx=-0.23)]), "armor", "upper_arm_l")
    m.add_pair(prism(6, 0.032, 0.24).move(-0.215, 1.25, 0), "joint", "upper_arm_l")
    m.add_pair(ball(0.042).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect8(0.055, 0.06, 1.10, 0.015, cx=-0.215), rect8(0.08, 0.09, 0.99, 0.02, cx=-0.215),
                     rect8(0.06, 0.065, 0.90, 0.015, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(loft([rect8(0.01, 0.03, 0.92, 0.0, cx=-0.215, cz=0.04), rect8(0.01, 0.05, 1.08, 0.0, cx=-0.215, cz=0.06),
                     rect8(0.006, 0.01, 1.22, 0.0, cx=-0.215, cz=0.09)]), "accent", "forearm_l")
    hands.add(m, 0.8)
    _arms_common(m, -0.265)

    # Legs: slender, pointed knees, calf fins, pointed feet
    m.add_pair(ball(0.055).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([rect8(0.10, 0.12, 0.86, 0.025, cx=-0.105), rect8(0.10, 0.12, 0.70, 0.025, cx=-0.105),
                     rect8(0.07, 0.08, 0.55, 0.02, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.045).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(loft([rect8(0.05, 0.02, 0.60, 0.0, cx=-0.10, cz=-0.04), rect8(0.07, 0.05, 0.50, 0.01, cx=-0.10, cz=-0.065),
                     rect8(0.05, 0.02, 0.42, 0.0, cx=-0.10, cz=-0.045)]), "detail", "shin_l")
    m.add_pair(loft([rect8(0.065, 0.075, 0.46, 0.015, cx=-0.10), rect8(0.09, 0.12, 0.32, 0.02, cx=-0.10, cz=0.01),
                     rect8(0.05, 0.06, 0.13, 0.012, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(loft([rect8(0.01, 0.03, 0.18, 0.0, cx=-0.10, cz=0.04), rect8(0.01, 0.05, 0.32, 0.0, cx=-0.10, cz=0.08),
                     rect8(0.006, 0.01, 0.45, 0.0, cx=-0.10, cz=0.12)]), "accent", "shin_l")
    m.add_pair(ball(0.035).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect8(0.07, 0.06, -0.06, 0.012, cz=0.03), rect8(0.08, 0.06, 0.07, 0.012, cz=0.03),
                          rect8(0.01, 0.01, 0.22, 0.0, cz=0.008)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
def orbit():
    """Gyro: a glowing core orb for a head inside two gimbal rings, a glowing
    chest core, ring shoulders and tapered hover-style legs."""
    m = Mesh()
    # Head: the orb (player-colour glow) inside a vertical ring and a tilted halo
    m.add(prism(8, 0.04, 0.08).move(0, 1.48, 0), "joint", "head")
    m.add(loft([ngon(8, 0.07, 1.505, 0.07), ngon(8, 0.05, 1.53, 0.05)]), "detail", "head")
    m.add(ball(0.088).move(0, 1.635, 0), "visor", "head")
    m.add(_ring(0.125, 0.026, 0.035, n=14).rot(yaw=90).move(0, 1.635, 0), "armor", "head")
    m.add(_ring(0.15, 0.022, 0.03, n=16).rot(pitch=90).rot(roll=18).move(0, 1.64, 0), "accent", "head")
    m.add_pair(prism(6, 0.022, 0.04).rot(roll=90).move(-0.135, 1.635, 0), "joint", "head")

    # Torso: an inverted triangle around a glowing core
    m.add(loft([rect8(0.12, 0.12, 1.17, 0.03), rect8(0.30, 0.20, 1.31, 0.06), rect8(0.42, 0.22, 1.44, 0.06),
                rect8(0.30, 0.16, 1.50, 0.05)]), "armor", "chest")
    m.add(_ring(0.07, 0.022, 0.03, n=10).move(0, 1.37, -0.115), "accent", "chest")
    m.add(ball(0.052).scale(1, 1, 0.6).move(0, 1.37, -0.10), "visor", "chest")
    m.add(prism(8, 0.085, 0.08, r_top=0.065).rot(pitch=-90).move(0, 1.37, 0.12), "detail", "chest")  # rear reactor
    m.add(prism(8, 0.05, 0.02).rot(pitch=90).move(0, 1.37, 0.165), "visor", "chest")
    m.add(prism(8, 0.045, 0.22, r_top=0.06).move(0, 1.10, 0), "joint", "spine")
    for y in (1.04, 1.10, 1.16):
        m.add(prism(8, 0.07, 0.02).move(0, y, 0), "detail", "spine")
    m.add(loft([ngon(8, 0.06, 0.85, 0.06), ngon(8, 0.15, 0.92, 0.11), ngon(8, 0.12, 1.02, 0.09)]), "armor", "hips")

    # Arms: ringed shoulders, tapered limbs
    m.add_pair(ball(0.06).move(-0.215, 1.40, 0), "accent", "upper_arm_l")
    m.add_pair(_ring(0.08, 0.02, 0.03, n=10).rot(yaw=90).move(-0.225, 1.40, 0), "armor", "upper_arm_l")
    m.add_pair(loft([ngon(6, 0.035, 1.34, 0.035, cx=-0.215), ngon(6, 0.045, 1.24, 0.045, cx=-0.215),
                     ngon(6, 0.03, 1.16, 0.03, cx=-0.215)]), "armor", "upper_arm_l")
    m.add_pair(ball(0.045).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([ngon(8, 0.035, 1.10, 0.035, cx=-0.215), ngon(8, 0.06, 1.00, 0.06, cx=-0.215),
                     ngon(8, 0.045, 0.90, 0.045, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(prism(8, 0.062, 0.02).move(-0.215, 1.00, 0), "accent", "forearm_l")
    hands.add(m, 0.88)
    _arms_common(m, -0.28)

    # Legs: tapered, ringed knees, small glowing soles
    m.add_pair(ball(0.06).move(-0.10, 0.90, 0), "joint", "thigh_l")
    m.add_pair(loft([ngon(8, 0.07, 0.86, 0.07, cx=-0.10), ngon(8, 0.075, 0.72, 0.075, cx=-0.10),
                     ngon(8, 0.045, 0.56, 0.045, cx=-0.10)]), "armor", "thigh_l")
    m.add_pair(ball(0.05).move(-0.10, 0.50, 0), "accent", "shin_l")
    m.add_pair(loft([ngon(8, 0.045, 0.46, 0.045, cx=-0.10), ngon(8, 0.07, 0.34, 0.075, cx=-0.10),
                     ngon(8, 0.04, 0.14, 0.04, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(prism(8, 0.074, 0.02).move(-0.10, 0.32, 0), "accent", "shin_l")
    m.add_pair(ball(0.037).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect8(0.08, 0.07, -0.07, 0.02, cz=0.04), rect8(0.09, 0.07, 0.06, 0.02, cz=0.04),
                          rect8(0.06, 0.035, 0.17, 0.012, cz=0.025)]))
    m.add_pair(foot.move(-0.10, 0.012, 0), "armor", "foot_l")
    m.add_pair(box(0.07, 0.012, 0.20, 0.02).move(-0.10, 0.006, -0.03), "visor", "foot_l")
    weapons.add_all(m)
    return m


# ---------------------------------------------------------------------------
def templar():
    """Knight: a crusader. Flat-topped great helm with an eye slit behind a cross of
    trim, a white surcoat with a red cross over chain mail, plate at the shoulders,
    elbows and knees, a split surcoat skirt and steel sabatons. The cross stays red; the player colour is on the
    helm's cross, the belt, the shoulder bands and the hems."""
    m = Mesh()
    # Head: the great helm, flat-fronted with chamfered sides and a flat top
    m.add(prism(8, 0.055, 0.10).move(0, 1.47, 0), "mail", "head")
    m.add(loft([rect8(0.26, 0.28, 1.485, 0.05), rect8(0.25, 0.27, 1.53, 0.05), rect8(0.245, 0.265, 1.76, 0.05),
                rect8(0.225, 0.245, 1.785, 0.045), rect8(0.19, 0.21, 1.80, 0.04)]), "steel", "head")
    m.add(loft([rect8(0.265, 0.285, 1.485, 0.05), rect8(0.265, 0.285, 1.51, 0.05)]), "detail", "head")  # lower rim
    m.add(loft([rect8(0.25, 0.27, 1.735, 0.05), rect8(0.25, 0.27, 1.755, 0.05)]), "detail", "head")  # crown band
    m.add_pair(box(0.058, 0.018, 0.02).move(-0.043, 1.645, -0.136), "visor", "head")  # eye slit
    m.add(box(0.15, 0.024, 0.02).move(0, 1.668, -0.139), "accent", "head")  # brow bar of the cross
    m.add(box(0.028, 0.17, 0.02).move(0, 1.585, -0.139), "accent", "head")  # nasal bar
    for i in range(3):
        for j in range(2):
            m.add(box(0.012, 0.012, 0.02).move(0.038 + 0.022 * j, 1.545 + 0.025 * i, -0.137), "joint", "head")  # breaths
            m.add(box(0.012, 0.012, 0.02).move(-0.038 - 0.022 * j, 1.545 + 0.025 * i, -0.137), "joint", "head")

    # Torso: mail collar under the helm, the surcoat over the chest with a red cross front and back
    m.add(loft([rect8(0.32, 0.24, 1.43, 0.06), rect8(0.26, 0.21, 1.49, 0.05), rect8(0.17, 0.16, 1.53, 0.04)],
               cap_end=False), "mail", "chest")
    m.add(loft([rect8(0.30, 0.22, 1.17, 0.05), rect8(0.40, 0.25, 1.30, 0.06), rect8(0.40, 0.25, 1.45, 0.06),
                rect8(0.27, 0.18, 1.50, 0.04)]), "cloth", "chest")
    for side in (-1, 1):
        bar = loft([rect8(0.06, 0.02, 1.19, 0.0, cz=0.112 * side), rect8(0.06, 0.02, 1.30, 0.0, cz=0.128 * side),
                    rect8(0.06, 0.02, 1.455, 0.0, cz=0.128 * side)])
        m.add(bar, "cross", "chest")
        m.add(box(0.24, 0.06, 0.02).move(0, 1.37, 0.128 * side), "cross", "chest")
    m.add(loft([rect8(0.28, 0.20, 1.02, 0.05), rect8(0.31, 0.225, 1.19, 0.05)]), "cloth", "spine")
    m.add(loft([rect8(0.06, 0.02, 1.03, 0.0, cz=-0.105), rect8(0.06, 0.02, 1.18, 0.0, cz=-0.115)]), "cross", "spine")
    m.add(loft([rect8(0.06, 0.02, 1.03, 0.0, cz=0.105), rect8(0.06, 0.02, 1.18, 0.0, cz=0.115)]), "cross", "spine")
    m.add(loft([rect8(0.27, 0.19, 0.84, 0.05), rect8(0.35, 0.235, 0.93, 0.06), rect8(0.31, 0.21, 1.05, 0.05)]), "cloth", "hips")
    m.add(box(0.36, 0.045, 0.25, 0.05).move(0, 0.985, 0), "accent", "hips")  # sword belt
    m.add(box(0.05, 0.05, 0.02).move(0, 0.985, -0.128), "steel", "hips")  # buckle
    # The surcoat skirt: a short hoop on the hips, then a split panel down each thigh
    m.add(loft([rect8(0.36, 0.25, 0.96, 0.06), rect8(0.40, 0.29, 0.78, 0.07)], cap_start=False), "cloth", "hips")

    # Arms: mail sleeves, round steel shoulder plates, elbow cops, plated gauntlets
    m.add_pair(ball(0.068).move(-0.215, 1.40, 0), "mail", "upper_arm_l")
    m.add_pair(loft([ngon(10, 0.075, 1.33, 0.085, cx=-0.245), ngon(10, 0.10, 1.40, 0.11, cx=-0.255),
                     ngon(10, 0.085, 1.47, 0.095, cx=-0.245), ngon(10, 0.04, 1.51, 0.05, cx=-0.235)]), "steel", "upper_arm_l")
    m.add_pair(loft([ngon(10, 0.101, 1.385, 0.111, cx=-0.255), ngon(10, 0.101, 1.40, 0.111, cx=-0.255)]), "accent", "upper_arm_l")
    m.add_pair(loft([rect8(0.10, 0.105, 1.35, 0.03, cx=-0.217), rect8(0.09, 0.095, 1.17, 0.028, cx=-0.215)]), "mail", "upper_arm_l")
    m.add_pair(ball(0.058).move(-0.215, 1.13, 0.0), "steel", "forearm_l")  # elbow cop
    m.add_pair(loft([rect8(0.085, 0.09, 1.10, 0.025, cx=-0.215), rect8(0.09, 0.095, 0.99, 0.026, cx=-0.215)]), "mail", "forearm_l")
    m.add_pair(loft([rect8(0.13, 0.14, 1.01, 0.035, cx=-0.215), rect8(0.10, 0.11, 0.90, 0.028, cx=-0.215)]), "steel", "forearm_l")  # gauntlet cuff
    hands.add(m, 1.05, body="steel", plate="steel", trim="joint")   # gauntlets
    _arms_common(m, -0.30)

    # Legs: mail chausses, a knee plate, steel sabatons
    m.add_pair(ball(0.07).move(-0.10, 0.90, 0), "mail", "thigh_l")
    m.add_pair(loft([rect8(0.14, 0.15, 0.87, 0.035, cx=-0.11), rect8(0.13, 0.145, 0.70, 0.035, cx=-0.11),
                     rect8(0.10, 0.11, 0.55, 0.028, cx=-0.10)]), "mail", "thigh_l")
    m.add_pair(loft([rect8(0.17, 0.18, 0.82, 0.04, cx=-0.11), rect8(0.19, 0.20, 0.59, 0.05, cx=-0.113)], cap_start=False),
               "cloth", "thigh_l")  # the skirt's split panel
    m.add_pair(loft([rect8(0.195, 0.205, 0.605, 0.05, cx=-0.113), rect8(0.195, 0.205, 0.585, 0.05, cx=-0.113)]), "accent", "thigh_l")
    m.add_pair(ball(0.055).move(-0.10, 0.50, 0), "mail", "shin_l")
    m.add_pair(loft([rect8(0.10, 0.02, 0.58, 0.0, cx=-0.10, cz=-0.06), rect8(0.12, 0.05, 0.50, 0.012, cx=-0.10, cz=-0.075),
                     rect8(0.09, 0.02, 0.43, 0.0, cx=-0.10, cz=-0.06)]), "steel", "shin_l")  # poleyn
    m.add_pair(loft([rect8(0.10, 0.11, 0.46, 0.025, cx=-0.10), rect8(0.12, 0.14, 0.33, 0.03, cx=-0.10, cz=0.01),
                     rect8(0.095, 0.105, 0.15, 0.025, cx=-0.10)]), "mail", "shin_l")
    m.add_pair(ball(0.047).move(-0.10, 0.10, 0), "mail", "foot_l")
    foot = _along_z(loft([rect8(0.12, 0.09, -0.085, 0.02, cz=0.045), rect8(0.13, 0.095, 0.07, 0.022, cz=0.047),
                          rect8(0.09, 0.05, 0.19, 0.015, cz=0.025), rect8(0.04, 0.025, 0.225, 0.006, cz=0.012)]))
    m.add_pair(foot.move(-0.10, 0, 0), "steel", "foot_l")
    m.add_pair(box(0.135, 0.02, 0.28, 0.02).move(-0.10, 0.01, -0.04), "joint", "foot_l")
    weapons.add_all(m)
    return m


ARM_BONES = ("upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
             "index_l", "index_l2", "fingers_l", "fingers_l2", "thumb_l", "thumb_l2",
             "index_r", "index_r2", "fingers_r", "fingers_r2", "thumb_r", "thumb_r2",
             "pistol", "pistol_slide", "pistol_mag", "pistol_vent", "pistol_l", "pistol_l_slide", "pistol_l_mag", "pistol_l_vent")  # what the first-person view shows (every gun rides on the gun bones)

DESIGNS = {"vanguard": vanguard, "brick": brick, "needle": needle, "kestrel": kestrel, "bulwark": bulwark,
           "rivet": rivet, "specter": specter, "orbit": orbit, "templar": templar}
PLAYABLE = ("needle", "vanguard", "kestrel", "bulwark", "rivet", "specter", "orbit", "templar")
# First-person arms only: thin a design's forearms and hands by this factor, so bulky
# gauntlets held up to the camera do not fill the view or push through each other.
FP_SLIM = {"vanguard": 0.74, "bulwark": 0.68, "rivet": 0.8, "templar": 0.78}
  # the characters build.py writes for the game (see game/player/robot/characters.gd)
