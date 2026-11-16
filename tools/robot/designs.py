"""The robot's shape. Parts are modelled in the rest pose (standing, arms down,
facing -Z) and each is tied to one bone, so the robot moves as rigid segments.

Materials (the game recolours "accent" and "visor" per player):
  armor   the main shell          accent  player-colour panels
  joint   dark joints and hands   visor   the glowing face
  gun     the pistol              detail  mid-grey trim
"""
import numpy as np
from kit import Mesh, Part, loft, rect, ngon, box, prism, ball
from rig import BODY, GUN_REST

MATERIALS = {
    "armor": {"color": (0.90, 0.91, 0.93), "metallic": 0.1, "roughness": 0.55},
    "accent": {"color": (0.95, 0.35, 0.25), "metallic": 0.1, "roughness": 0.5},
    "joint": {"color": (0.12, 0.13, 0.15), "metallic": 0.3, "roughness": 0.6},
    "detail": {"color": (0.36, 0.38, 0.42), "metallic": 0.3, "roughness": 0.5},
    "visor": {"color": (0.05, 0.05, 0.06), "metallic": 0.0, "roughness": 0.3, "emission": (0.95, 0.35, 0.25)},
    "gun": {"color": (0.17, 0.18, 0.21), "metallic": 0.6, "roughness": 0.4},
}


def in_gun_space(part, bone="pistol"):
    """Place a part modelled in gun space (barrel -Z, sights +Y, origin in the grip)."""
    o = BODY.bone(bone).pos if bone in ("pistol", "pistol_slide", "pistol_mag") else BODY.bone("pistol").pos
    return Part(part.t @ GUN_REST.T + o)


def pistol(mesh):
    """A chunky sidearm, about 26 cm long."""
    grip = box(0.036, 0.115, 0.05, 0.008).rot(pitch=-14).move(0, -0.035, 0.018)
    frame = loft([rect(0.036, 0.19, 0.022, 0.006, cz=-0.06), rect(0.036, 0.20, 0.05, 0.006, cz=-0.06)])
    guard = box(0.014, 0.012, 0.065).move(0, -0.012, -0.045) + box(0.014, 0.04, 0.012).move(0, 0.004, -0.078)
    under = box(0.03, 0.022, 0.07).move(0, 0.012, -0.12)   # rail block under the barrel
    mesh.add(in_gun_space(grip + frame + guard), "gun", "pistol")
    mesh.add(in_gun_space(under), "detail", "pistol")
    slide = loft([rect(0.042, 0.235, 0.05, 0.008, cz=-0.06), rect(0.042, 0.235, 0.078, 0.012, cz=-0.06),
                  rect(0.03, 0.235, 0.09, 0.006, cz=-0.06)])
    mesh.add(in_gun_space(slide), "gun", "pistol_slide")
    stripe = box(0.044, 0.008, 0.10).move(0, 0.066, -0.02)
    mesh.add(in_gun_space(stripe), "accent", "pistol_slide")
    barrel = prism(6, 0.011, 0.02).rot(pitch=90).move(0, 0.064, -0.185)
    mesh.add(in_gun_space(barrel), "detail", "pistol")
    mag = box(0.026, 0.11, 0.034).rot(pitch=-14).move(0, -0.045, 0.02)
    mesh.add(in_gun_space(mag), "detail", "pistol_mag")


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
    m.add_pair(box(0.06, 0.10, 0.095, 0.015).move(-0.215, 0.835, 0), "joint", "hand_l")
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
    pistol(m)
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
    m.add_pair(box(0.085, 0.11, 0.13, 0.025).move(-0.215, 0.83, 0), "joint", "hand_l")
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
    pistol(m)
    return m


def needle():
    """Design C: a slim, sleek frame. Round sensor head with one big eye, thin
    struts with ball joints, blade-like forearms and shins."""
    m = Mesh()
    # Head: a pod with one eye and an antenna
    m.add(prism(6, 0.03, 0.10).move(0, 1.47, 0), "joint", "head")
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
    m.add(prism(6, 0.04, 0.20).move(0, 1.11, 0), "joint", "spine")
    m.add(ball(0.055).move(0, 1.06, 0), "joint", "spine")
    m.add(loft([ngon(8, 0.08, 0.85, 0.07), ngon(8, 0.15, 0.93, 0.10), ngon(8, 0.08, 1.03, 0.07)]), "armor", "hips")

    # Arms: struts and blades
    m.add_pair(ball(0.058).move(-0.215, 1.40, 0), "accent", "upper_arm_l")
    m.add_pair(prism(6, 0.03, 0.27).move(-0.215, 1.265, 0), "joint", "upper_arm_l")
    m.add_pair(ball(0.042).move(-0.215, 1.13, 0), "joint", "forearm_l")
    m.add_pair(loft([rect(0.05, 0.055, 1.10, 0.015, cx=-0.215), rect(0.075, 0.095, 0.99, 0.02, cx=-0.215),
                     rect(0.05, 0.06, 0.90, 0.015, cx=-0.215)]), "armor", "forearm_l")
    m.add_pair(box(0.045, 0.09, 0.075, 0.012).move(-0.215, 0.835, 0), "joint", "hand_l")
    m.add(box(0.035, 0.13, 0.05, 0.008).move(-0.268, 0.985, 0), "detail", "forearm_l")
    m.add(prism(6, 0.016, 0.03).move(-0.268, 0.905, 0), "accent", "forearm_l")

    # Legs
    m.add_pair(ball(0.058).move(-0.10, 0.90, 0), "accent", "thigh_l")
    m.add_pair(prism(6, 0.036, 0.40).move(-0.10, 0.70, 0), "joint", "thigh_l")
    m.add_pair(loft([rect(0.075, 0.03, 0.84, 0.01, cx=-0.10, cz=-0.05), rect(0.065, 0.03, 0.58, 0.01, cx=-0.10, cz=-0.045)]), "armor", "thigh_l")
    m.add_pair(ball(0.046).move(-0.10, 0.50, 0), "joint", "shin_l")
    m.add_pair(loft([rect(0.06, 0.07, 0.46, 0.015, cx=-0.10), rect(0.08, 0.12, 0.33, 0.02, cx=-0.10, cz=0.012),
                     rect(0.045, 0.05, 0.12, 0.012, cx=-0.10)]), "armor", "shin_l")
    m.add_pair(ball(0.036).move(-0.10, 0.10, 0), "joint", "foot_l")
    foot = _along_z(loft([rect(0.07, 0.06, -0.06, 0.012, cz=0.03), rect(0.08, 0.065, 0.06, 0.012, cz=0.0325),
                          rect(0.05, 0.03, 0.19, 0.008, cz=0.015)]))
    m.add_pair(foot.move(-0.10, 0, 0), "armor", "foot_l")
    pistol(m)
    return m


ARM_BONES = ("upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
             "pistol", "pistol_slide", "pistol_mag")  # what the first-person view shows

DESIGNS = {"vanguard": vanguard, "brick": brick, "needle": needle}
CHOSEN = "needle"
