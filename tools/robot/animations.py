"""The robot's animation clips, described as poses over time (see rig.solve for
what a pose spec can hold). build.py bakes them into robot.glb.

How the game uses them (game/player/robot/robot_animator.gd):
  - one "base" clip per movement state, cross-faded;
  - the arms then blend to the "aim" pose (gun up, two hands) wherever the robot
    can shoot, and the whole upper body pitches with the player's aim;
  - "reload", "land" and "respawn" are laid over the top for a moment.
Looping clips must return the same pose at t = 0 and t = duration.
"""
import math
from m3 import euler, norm, rx, ry, rz, v
import numpy as np
from rig import BODY, FIST, GUN_REST, HANDS, ZERO, Clip, _slerp_m, keyed, mix, mirror, merged, ease, solve

TAU = math.tau

# ---------------------------------------------------------------------------
# Building blocks

# Gun up in both hands, relative to the chest. The game pitches this with the aim.
# Relaxed: elbows bent, the gun at the right of the chest and a little below the chin,
# tipped a touch inward (cant: + rolls a gun's top to the left), the left hand cupped under it. (The first-person arms hold it
# the same way: FP_R, below.)
AIM_R = {"ik": (0.09, 0.12, -0.32), "space": "chest", "pole": (0.7, -1.0, 0.3), "hand": (90.0, 3.0, 0.0), "cant": 6.0}
def _euler_of(m):
    """The (pitch, yaw, roll) that m3.euler turns back into the rotation m."""
    return (-math.degrees(math.asin(max(-1.0, min(1.0, m[1][2])))), math.degrees(math.atan2(m[0][2], m[2][2])),
            math.degrees(math.atan2(m[1][0], m[1][1])))


CHEST0 = (0.0, 1.22, 0.0)   # where the chest is in the model with the body standing at rest


def _frames(spec, space="chest"):
    """Where a pose puts the gun and the left hand, in the chest's own space or the model's
    (whichever the arms' "ik" is in): {"gun": (turn, place), "hand_l": (turn, wrist), "fist_l": place}."""
    L, T = solve(BODY, spec)
    G, P = {}, {}
    for b in BODY.bones:
        if b.parent < 0:
            G[b.name], P[b.name] = L[b.name], T[b.name]
        else:
            pn = BODY.bones[b.parent].name
            G[b.name] = G[pn] @ L[b.name]
            P[b.name] = P[pn] + G[pn] @ T[b.name]
    back = G["chest"].T if space == "chest" else np.eye(3)
    origin = P["chest"] if space == "chest" else np.zeros(3)

    def seen(bone):
        return back @ G[bone], back @ (P[bone] - origin)
    hand = seen("hand_l")
    return {"gun": seen("pistol"), "hand_l": hand, "fist_l": hand[1] + hand[0] @ v(0.0, -FIST, 0.0)}


# The left hand on a pistol: wrapped round the right hand from the left and below. Its palm
# is against the left of the grip, over the right hand's fingertips, its fingers lie
# across the front of the right hand's under the trigger guard, and its wrist is lower
# and further out than the right one, so the hand cups the grip from underneath.
WRAP_AT = (-0.002, -0.048, -0.016)   # where the left hand's own grip is, in gun space (x right, y up, z back)
WRAP_TURN = (26.0, 0.0, 12.0)        # the hand's turn from the right hand's: the wrist dropped, rolled, swung out to the left


def wrap_l(arm_r, pole=(-0.5, -1.0, 0.3), body=None):
    """The left arm with its hand wrapped round the right hand on a pistol's grip, for the
    right arm `arm_r` (an "ik" arm) and the rest of the pose `body` (where the shoulders
    are). In the same space as the right arm, so the two blend with other arm poses number
    by number. The arm has to reach: see FP_BODY."""
    space = arm_r.get("space", "chest")
    gun_turn, gun_at = _frames(dict(body or {}, arm_r=arm_r), space)["gun"]
    turn = gun_turn @ rz(WRAP_TURN[2]) @ rx(WRAP_TURN[0]) @ ry(WRAP_TURN[1])
    wrist = gun_at + gun_turn @ GUN_REST @ v(*WRAP_AT) + turn @ v(0.0, FIST, 0.0)
    return {"ik": tuple(float(x) for x in wrist), "space": space, "pole": pole, "hand": _euler_of(turn), "cant": 0.0,
            "fingers": "wrap"}


AIM_L = wrap_l(AIM_R)
# Gun in one hand (the left arm is busy: wall, rope, ground)
AIM_R_ONE = {"ik": (0.19, 0.10, -0.40), "space": "chest", "pole": (0.7, -1.0, 0.3), "hand": (90.0, 2.0, 0.0), "cant": 10.0}

# Crouched torso: hunched forward so the head sits at crouch height (1.1 m body).
LOW_SPINE = (-12.0, 0.0, 0.0)
LOW_CHEST = (-8.0, 0.0, 0.0)
LOW_HEAD = (38.0, 0.0, 0.0)


def lerp(a, b, u):
    return a + (b - a) * u


def foot(x, y, z, pitch=0.0, yaw=0.0, roll=0.0, pole=(0.0, 0.0, -1.0), space="model"):
    """A leg placed by the ball of its foot (x, y, z; y = 0 is the ground), so a
    planted foot can roll up onto its toes without sliding."""
    r = euler((pitch, yaw, roll))
    ankle = np.array([x, y, z]) - r @ np.array([0.0, -0.10, -0.12])
    return {"ik": (float(ankle[0]), float(ankle[1]), float(ankle[2])), "space": space,
            "pole": pole, "foot": (pitch, yaw, roll)}


def fk_arm(pitch, roll=0.0, bend=0.0, yaw=0.0, hand=(0.0, 0.0, 0.0)):
    return {"fk": (pitch, yaw, roll), "bend": bend, "hand": hand}


def fk_leg(pitch, bend=0.0, roll=0.0, yaw=0.0, foot_pitch=0.0):
    return {"fk": (pitch, yaw, roll), "bend": bend, "foot": (foot_pitch, 0.0, 0.0)}


def stride(u, x, stance=0.3, front=-0.38, back=0.42, lift=0.32, push=-40.0, pole=(0.0, 0.0, -1.0), roll=0.0, y0=0.0):
    """One leg through a running cycle. u = 0 is the moment this foot lands."""
    u = u % 1.0
    if u < stance:
        w = u / stance
        z = lerp(front, back, w)
        y = 0.0
        pitch = 8.0 * (1 - w / 0.3) if w < 0.3 else push * ((w - 0.3) / 0.7) ** 2
    else:
        w = (u - stance) / (1 - stance)
        z = lerp(back, front, ease(w))
        y = lift * math.sin(math.pi * w ** 0.7)
        if w < 0.25:
            pitch = lerp(push, push - 30.0, w / 0.25)
        elif w < 0.8:
            pitch = lerp(push - 30.0, 0.0, (w - 0.25) / 0.55)
        else:
            pitch = lerp(0.0, 8.0, (w - 0.8) / 0.2)
    return foot(x, y + y0, z, pitch, roll=roll, pole=pole)


# ---------------------------------------------------------------------------
# Standing, running

def aim(t):
    return {"arm_r": AIM_R, "arm_l": AIM_L}


def idle(t):
    s = math.sin(TAU * t / 3.0)
    c = math.cos(TAU * t / 3.0)
    return {
        "hips": {"pos": (0.0, 0.925 + 0.006 * s, 0.0), "rot": (-2.0, -8.0, 0.0)},
        "spine": (-1.0 + 0.6 * s, 3.0, 0.0), "chest": (-1.0 + 0.6 * c, 5.0, 0.0), "head": (2.0 - 0.5 * c, 0.0, 0.0),
        "leg_l": foot(-0.13, 0.0, -0.20, yaw=6.0, pole=(-0.15, 0.0, -1.0)),
        "leg_r": foot(0.14, 0.0, -0.02, yaw=-14.0, pole=(0.3, 0.0, -1.0)),
        "arm_r": AIM_R, "arm_l": AIM_L,
    }


def _run(t, period, lean, bob, stance, front, back, lift, sprint):
    p = (t / period) % 1.0
    c = math.cos(TAU * p)
    s = math.sin(TAU * p)
    spec = {
        "hips": {"pos": (0.0, 0.885 - bob * math.cos(2 * TAU * (p - 0.14)), 0.0), "rot": (lean, -7.0 * c, 3.0 * s)},
        "spine": (-lean * 0.35, 4.0 * c, -1.5 * s), "chest": (-lean * 0.25, 5.0 * c, -1.5 * s),
        "head": (-lean * 0.3, -2.0 * c, 0.0),
        "leg_l": stride(p, -0.10, stance, front, back, lift),
        "leg_r": stride(p + 0.5, 0.10, stance, front, back, lift),
    }
    if sprint:
        spec["arm_r"] = fk_arm(-8.0 + 48.0 * c, roll=10.0, bend=95.0 + 10.0 * c, hand=(0.0, 0.0, 0.0))
        spec["arm_l"] = fk_arm(-8.0 - 48.0 * c, roll=-10.0, bend=95.0 - 10.0 * c)
    else:
        spec["arm_r"] = AIM_R
        spec["arm_l"] = AIM_L
    return spec


RUN_PERIOD = 0.46      # two steps; matches 8 m/s
SPRINT_PERIOD = 0.40   # matches 11.5 m/s


def run(t):
    return _run(t, RUN_PERIOD, -9.0, 0.028, 0.30, -0.36, 0.42, 0.30, False)


def sprint(t):
    return _run(t, SPRINT_PERIOD, -20.0, 0.034, 0.26, -0.40, 0.52, 0.40, True)


# ---------------------------------------------------------------------------
# Crouch and slide (the body is 1.1 m tall in these)

def _low(hips_y, hips_pitch=-26.0):
    return {"hips": {"pos": (0.0, hips_y, 0.04), "rot": (hips_pitch, 0.0, 0.0)},
            "spine": LOW_SPINE, "chest": LOW_CHEST, "head": LOW_HEAD,
            "arm_r": AIM_R, "arm_l": AIM_L}


def crouch_idle(t):
    s = math.sin(TAU * t / 3.0)
    spec = _low(0.47 + 0.005 * s)
    spec["leg_l"] = foot(-0.13, 0.0, -0.22, pole=(-0.25, 0.0, -1.0))
    spec["leg_r"] = foot(0.13, 0.0, 0.20, pitch=-42.0, pole=(0.3, 0.0, -1.0))
    return spec


CROUCH_PERIOD = 0.7    # matches 4 m/s


def crouch_walk(t):
    p = (t / CROUCH_PERIOD) % 1.0
    c = math.cos(TAU * p)
    spec = _low(0.50 - 0.012 * math.cos(2 * TAU * (p - 0.1)))
    spec["hips"]["rot"] = (-26.0, -6.0 * c, 0.0)
    spec["spine"] = (LOW_SPINE[0], 6.0 * c, 0.0)
    spec["leg_l"] = stride(p, -0.12, 0.5, -0.30, 0.30, 0.13, push=-30.0, pole=(-0.2, 0.0, -1.0))
    spec["leg_r"] = stride(p + 0.5, 0.12, 0.5, -0.30, 0.30, 0.13, push=-30.0, pole=(0.2, 0.0, -1.0))
    return spec


def slide(t):
    s = math.sin(TAU * t / 0.8)
    return {
        "hips": {"pos": (0.03, 0.27 + 0.004 * s, 0.12), "rot": (34.0, 0.0, 6.0)},
        "spine": (-22.0, 0.0, -4.0), "chest": (-14.0, 0.0, -2.0), "head": (4.0, 0.0, 0.0),
        "leg_l": foot(-0.11, 0.05, -0.80, pitch=22.0, pole=(-0.1, 1.0, -0.3)),
        "leg_r": foot(0.17, 0.0, -0.17, pitch=0.0, pole=(0.5, 1.0, -0.4)),
        "arm_r": AIM_R_ONE,
        "arm_l": {"ik": (-0.36, 0.09, 0.34), "space": "model", "pole": (-0.6, 0.3, 1.0), "hand": (0.0, 0.0, 70.0)},
    }


# ---------------------------------------------------------------------------
# In the air

def air(t):
    """A strip, not a movie: t = 0 rising fast, 0.5 at the top, 1 falling fast."""
    rising = {
        "hips": {"pos": (0.0, 0.96, 0.0), "rot": (-6.0, 0.0, 0.0)},
        "spine": (2.0, 0.0, 0.0), "chest": (2.0, 0.0, 0.0), "head": (2.0, 0.0, 0.0),
        "leg_l": fk_leg(58.0, 88.0, foot_pitch=-25.0), "leg_r": fk_leg(-16.0, 14.0, foot_pitch=-38.0),
        "arm_r": AIM_R, "arm_l": AIM_L,
    }
    top = merged(rising, hips={"pos": (0.0, 0.96, 0.0), "rot": (-3.0, 0.0, 0.0)},
                 leg_l=fk_leg(42.0, 70.0, foot_pitch=-15.0), leg_r=fk_leg(14.0, 52.0, foot_pitch=-20.0))
    falling = merged(rising, hips={"pos": (0.0, 0.96, 0.0), "rot": (-4.0, 0.0, 0.0)},
                     leg_l=fk_leg(26.0, 30.0, roll=-5.0, foot_pitch=4.0), leg_r=fk_leg(6.0, 24.0, roll=5.0, foot_pitch=4.0))
    return keyed(t, [(0.0, rising), (0.5, top), (1.0, falling)])


def air_tuck(t):
    """Legs pulled up in the air. The feet rise; the head stays where it was."""
    s = math.sin(TAU * t / 0.8)
    spec = _low(0.50, -16.0)
    spec["leg_l"] = fk_leg(98.0 + 2.0 * s, 118.0, roll=-6.0, foot_pitch=-10.0)
    spec["leg_r"] = fk_leg(88.0 - 2.0 * s, 112.0, roll=6.0, foot_pitch=-10.0)
    spec["head"] = (28.0, 0.0, 0.0)
    return spec


def land(t):
    """The bottom of a landing: knees soak it up. Laid over the base pose briefly."""
    return {
        "hips": {"pos": (0.0, 0.66, 0.03), "rot": (-22.0, 0.0, 0.0)},
        "spine": (-6.0, 0.0, 0.0), "chest": (-4.0, 0.0, 0.0), "head": (24.0, 0.0, 0.0),
        "leg_l": foot(-0.14, 0.0, -0.18, pole=(-0.3, 0.0, -1.0)),
        "leg_r": foot(0.14, 0.0, 0.0, pole=(0.3, 0.0, -1.0)),
        "arm_r": AIM_R, "arm_l": AIM_L,
    }


# ---------------------------------------------------------------------------
# Walls

WALL_PERIOD = 0.42     # matches 10.5 m/s


def wall_run_l(t):
    """Running along a wall on the left: feet on the wall, body leaning away, left hand trailing on it."""
    p = (t / WALL_PERIOD) % 1.0
    c = math.cos(TAU * p)
    return {
        "hips": {"pos": (0.10, 0.90 - 0.02 * math.cos(2 * TAU * (p - 0.14)), 0.0), "rot": (-10.0, -6.0 * c, -24.0)},
        "spine": (3.0, 4.0 * c, 9.0), "chest": (3.0, 5.0 * c, 7.0), "head": (3.0, 0.0, 8.0),
        "leg_l": stride(p, -0.33, 0.30, -0.36, 0.42, 0.28, roll=-30.0, y0=0.10, pole=(0.25, 0.3, -1.0)),
        "leg_r": stride(p + 0.5, -0.20, 0.30, -0.36, 0.42, 0.28, roll=-30.0, y0=0.0, pole=(0.25, 0.3, -1.0)),
        "arm_r": AIM_R_ONE,
        "arm_l": {"ik": (-0.50, 1.20, -0.16), "space": "model", "pole": (-0.2, -1.0, 0.6), "hand": (15.0, 0.0, -75.0)},
    }


def wall_run_r(t):
    spec = mirror(wall_run_l(t))
    spec["arm_r"] = AIM_R_ONE
    spec["arm_l"] = fk_arm(15.0, roll=-55.0, bend=35.0)   # out for balance
    return spec


def wall_jump_l(t):
    """Kicking off a wall on the left. Legs and hips only; laid over the air pose."""
    coil = {"hips": {"pos": (0.0, 0.96, 0.0), "rot": (-4.0, 0.0, -14.0)}, "spine": (0.0, 0.0, 6.0),
            "leg_l": {"ik": (-0.30, 0.52, 0.02), "space": "model", "pole": (0.3, 0.5, -1.0), "foot": (0.0, 0.0, -50.0)},
            "leg_r": fk_leg(55.0, 85.0, foot_pitch=-20.0)}
    push = merged(coil, hips={"pos": (0.0, 0.96, 0.0), "rot": (-4.0, 0.0, -20.0)},
                  leg_l={"ik": (-0.52, 0.36, 0.06), "space": "model", "pole": (0.3, 0.5, -1.0), "foot": (0.0, 0.0, -60.0)})
    return keyed(t, [(0.0, coil), (0.09, push, "out"), (0.3, push)])


def wall_jump_r(t):
    return mirror(wall_jump_l(t))


# ---------------------------------------------------------------------------
# Vault and ledge climb

def vault(t):
    """Over a low obstacle: left hand plants on it, legs swing through to the side."""
    def hand(y, z):
        return {"ik": (-0.20, y, z), "space": "model", "pole": (-0.6, -0.3, 1.0), "hand": (80.0, 0.0, 0.0), "cant": 90.0}
    plant = {"hips": {"pos": (0.0, 0.92, 0.0), "rot": (-24.0, -14.0, -10.0)},
             "spine": (-6.0, 6.0, 4.0), "chest": (-4.0, 6.0, 4.0), "head": (22.0, 0.0, 0.0),
             "leg_l": fk_leg(72.0, 100.0, roll=8.0), "leg_r": fk_leg(88.0, 96.0, roll=14.0),
             "arm_l": hand(0.72, -0.42), "arm_r": fk_arm(35.0, roll=30.0, bend=70.0)}
    over = merged(plant, hips={"pos": (0.0, 0.94, 0.0), "rot": (-12.0, -18.0, -14.0)},
                  leg_l=fk_leg(92.0, 62.0, roll=10.0), leg_r=fk_leg(100.0, 50.0, roll=16.0), arm_l=hand(0.70, -0.10))
    out = merged(plant, hips={"pos": (0.0, 0.95, 0.0), "rot": (-6.0, 0.0, 0.0)},
                 leg_l=fk_leg(40.0, 30.0, roll=0.0), leg_r=fk_leg(22.0, 34.0, roll=0.0), arm_l=hand(0.80, 0.25))
    return keyed(t, [(0.0, plant), (0.14, over), (0.32, out)])


def climb(t):
    """Up a ledge: hang, pull, get a knee over, push up."""
    def hands(y, z, bend_pole):
        return ({"ik": (-0.19, y, z), "space": "model", "pole": (-0.7, bend_pole, 0.5), "hand": (150.0, 0.0, 0.0), "cant": 90.0},
                {"ik": (0.19, y, z), "space": "model", "pole": (0.7, bend_pole, 0.5), "hand": (150.0, 0.0, 0.0), "cant": -90.0})
    l0, r0 = hands(1.88, -0.30, -0.4)
    hang = {"hips": {"pos": (0.0, 0.96, 0.02), "rot": (6.0, 0.0, 0.0)}, "spine": (0.0, 0.0, 0.0), "chest": (-4.0, 0.0, 0.0),
            "head": (-22.0, 0.0, 0.0), "leg_l": fk_leg(12.0, 22.0), "leg_r": fk_leg(26.0, 40.0), "arm_l": l0, "arm_r": r0}
    l1, r1 = hands(1.36, -0.30, -1.0)
    pull = merged(hang, hips={"pos": (0.0, 0.96, 0.02), "rot": (-6.0, 0.0, 0.0)}, head=(-8.0, 0.0, 0.0),
                  leg_l=fk_leg(20.0, 40.0), leg_r=fk_leg(86.0, 104.0), arm_l=l1, arm_r=r1)
    l2, r2 = hands(0.92, -0.22, -1.0)
    press = merged(hang, hips={"pos": (0.0, 0.94, 0.0), "rot": (-24.0, 0.0, 0.0)}, head=(18.0, 0.0, 0.0),
                   leg_l=fk_leg(8.0, 30.0), leg_r=fk_leg(100.0, 86.0), arm_l=l2, arm_r=r2)
    return keyed(t, [(0.0, hang), (0.24, pull), (0.5, press)])


# ---------------------------------------------------------------------------
# Grapple, dive, roll, flips

def grapple(t):
    """Swinging on the rope. The game aims the left arm at the anchor."""
    s = math.sin(TAU * t / 1.2)
    return {
        "hips": {"pos": (0.0, 0.96, 0.0), "rot": (9.0 + 2.0 * s, 0.0, 6.0)},
        "spine": (-3.0, 0.0, -3.0), "chest": (-3.0, 0.0, -3.0), "head": (-2.0, 0.0, 0.0),
        "leg_l": fk_leg(20.0 + 4.0 * s, 34.0, foot_pitch=-25.0), "leg_r": fk_leg(-8.0 - 4.0 * s, 52.0, foot_pitch=-35.0),
        "arm_r": AIM_R_ONE, "arm_l": fk_arm(165.0, roll=-12.0, bend=8.0),
    }


def dive(t):
    """A flat forward lunge, gun leading."""
    s = math.sin(TAU * t / 0.6)
    return {
        "hips": {"pos": (0.0, 0.60, 0.20), "rot": (-80.0, 0.0, 0.0)},
        "spine": (6.0, 0.0, 0.0), "chest": (8.0, 0.0, 0.0), "head": (52.0, 0.0, 0.0),
        "leg_l": fk_leg(-12.0 + 3.0 * s, 12.0, foot_pitch=-55.0), "leg_r": fk_leg(-2.0 - 3.0 * s, 30.0, foot_pitch=-55.0),
        "arm_r": fk_arm(158.0, roll=6.0, bend=8.0), "arm_l": fk_arm(150.0, roll=-10.0, bend=20.0),
    }


def _prone(sway=0.0, kick_l=0.0, kick_r=0.0, lift=0.0):
    """Flat on the front, chest up, gun out in front in both hands. kick_l/kick_r
    (0..1) draw a knee up and out to the side along the floor, for crawling."""
    def leg(kick, side):
        if kick <= 0.0:
            return fk_leg(-6.0, 6.0, roll=side * 5.0, foot_pitch=-62.0)
        return foot(side * (0.12 + 0.38 * kick), 0.05, 1.26 - 0.56 * kick, pitch=-75.0 + 15.0 * kick,
                    pole=(side * 1.0, 0.15, -0.3 * kick))
    return {
        "hips": {"pos": (0.0, 0.21 + lift, 0.36), "rot": (-86.0, 0.0, sway)},
        "spine": (12.0, 0.0, -sway * 0.5), "chest": (14.0, 0.0, -sway * 0.5), "head": (50.0, 0.0, 0.0),
        "leg_l": leg(kick_l, -1.0), "leg_r": leg(kick_r, 1.0),
        "arm_r": AIM_R, "arm_l": AIM_L,
    }


def belly_slide(t):
    """Keep holding dive as you land: sliding on the front, gun out ahead. The game
    raises the arms to the aim."""
    s = math.sin(TAU * t / 0.8)
    return _prone(sway=2.5 * s, lift=0.004 * s)


CRAWL_PERIOD = 0.9


def belly_crawl(t):
    """Crawling once a belly slide runs out: knees drawn up in turn."""
    p = (t / CRAWL_PERIOD) % 1.0
    k = 0.5 - 0.5 * math.cos(TAU * p)
    return _prone(sway=6.0 * math.sin(TAU * p), kick_l=max(k, 0.02), kick_r=max(1.0 - k, 0.02))


def _tuck(pitch, y, z, thigh=108.0, knee=126.0, spine=-24.0, chest=-18.0, head=-18.0, arm=55.0, elbow=115.0, roll=0.0):
    return {
        "hips": {"pos": (0.0, y, z), "rot": (pitch, 0.0, roll)},
        "spine": (spine, 0.0, 0.0), "chest": (chest, 0.0, 0.0), "head": (head, 0.0, 0.0),
        "leg_l": fk_leg(thigh, knee, roll=-6.0, foot_pitch=-20.0), "leg_r": fk_leg(thigh - 6.0, knee - 4.0, roll=6.0, foot_pitch=-20.0),
        "arm_r": fk_arm(arm, roll=14.0, bend=elbow), "arm_l": fk_arm(arm, roll=-14.0, bend=elbow),
    }


def roll(t):
    """Landing roll after a dive: over the shoulders and back onto the feet."""
    return keyed(t, [
        (0.0, _tuck(-82.0, 0.56, 0.16, thigh=60.0, knee=80.0, spine=-6.0, chest=-4.0, head=10.0, arm=120.0, elbow=40.0)),
        (0.12, _tuck(-165.0, 0.60, 0.06, spine=-42.0, chest=-36.0, head=-35.0), "linear"),
        (0.33, _tuck(-300.0, 0.50, 0.0, spine=-42.0, chest=-36.0, head=-30.0), "linear"),
        (0.45, _tuck(-360.0, 0.62, 0.02, thigh=78.0, knee=104.0, spine=-12.0, chest=-8.0, head=14.0, arm=45.0, elbow=95.0), "linear"),
    ])


def flip_front(t):
    return keyed(t, [
        (0.0, _tuck(0.0, 0.96, 0.0, thigh=30.0, knee=40.0, spine=-4.0, chest=-4.0, head=0.0, arm=40.0, elbow=80.0)),
        (0.10, _tuck(-70.0, 0.96, 0.0), "linear"),
        (0.34, _tuck(-295.0, 0.96, 0.0), "linear"),
        (0.45, _tuck(-360.0, 0.96, 0.0, thigh=28.0, knee=36.0, spine=-2.0, chest=-2.0, head=4.0, arm=40.0, elbow=80.0), "linear"),
    ])


def flip_back(t):
    return keyed(t, [
        (0.0, _tuck(0.0, 0.96, 0.0, thigh=34.0, knee=44.0, spine=6.0, chest=6.0, head=-10.0, arm=70.0, elbow=60.0)),
        (0.10, _tuck(65.0, 0.96, 0.0, head=-8.0), "linear"),
        (0.34, _tuck(295.0, 0.96, 0.0, head=-8.0), "linear"),
        (0.45, _tuck(360.0, 0.96, 0.0, thigh=28.0, knee=36.0, spine=-2.0, chest=-2.0, head=4.0, arm=40.0, elbow=80.0), "linear"),
    ])


def _aerial(roll_deg, spread, tuck, arms):
    return {
        "hips": {"pos": (0.0, 0.96, 0.0), "rot": (-4.0, 0.0, roll_deg)},
        "spine": (-4.0, 0.0, 0.0), "chest": (-4.0, 0.0, 0.0), "head": (0.0, 0.0, 0.0),
        "leg_l": fk_leg(tuck * 0.5, tuck, roll=-spread, foot_pitch=-30.0), "leg_r": fk_leg(tuck * 0.5, tuck, roll=spread, foot_pitch=-30.0),
        "arm_r": fk_arm(10.0, roll=arms, bend=25.0), "arm_l": fk_arm(10.0, roll=-arms, bend=25.0),
    }


def flip_left(t):
    """Side flip to the left: a no-hands cartwheel, legs apart."""
    return keyed(t, [
        (0.0, _aerial(0.0, 6.0, 40.0, 20.0)),
        (0.10, _aerial(70.0, 38.0, 30.0, 70.0), "linear"),
        (0.34, _aerial(295.0, 38.0, 30.0, 70.0), "linear"),
        (0.45, _aerial(360.0, 6.0, 36.0, 20.0), "linear"),
    ])


def flip_right(t):
    return mirror(flip_left(t))


# ---------------------------------------------------------------------------
# Reload, death, respawn

def _arm(side, pos, hand, cant=0.0, space="chest"):
    return {"ik": pos, "space": space, "pole": (0.7 if side == "r" else -0.7, -1.0, 0.3), "hand": hand, "cant": cant}


def reload(t):
    """Arms and gun (the game lays this over whatever the body is doing), and a turn of
    the chest and spine that the game adds to the body's own."""
    return _pistol_reload(t, _arm("r", AIM_R["ik"], AIM_R["hand"], AIM_R["cant"]), AIM_L, False)


def death(t):
    """Power cut: a jolt, the knees go, and the frame pitches forward onto the floor."""
    def limp(pitch, roll, bend):
        return fk_arm(pitch, roll=roll, bend=bend), fk_arm(pitch, roll=-roll, bend=bend)
    r, l = limp(0.0, 8.0, 20.0)
    stand = {"hips": {"pos": (0.0, 0.93, 0.0), "rot": (-2.0, 0.0, 0.0)}, "spine": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0),
             "head": (0.0, 0.0, 0.0), "leg_l": fk_leg(8.0, 14.0), "leg_r": fk_leg(-2.0, 10.0), "arm_r": r, "arm_l": l}
    r, l = limp(-25.0, 38.0, 35.0)
    jolt = merged(stand, hips={"pos": (0.0, 0.92, 0.06), "rot": (10.0, 0.0, 0.0)}, spine=(10.0, 0.0, 0.0), chest=(8.0, 0.0, 0.0),
                  head=(18.0, 0.0, 0.0), arm_r=r, arm_l=l)
    r, l = limp(12.0, 10.0, 16.0)
    knees = merged(stand, hips={"pos": (0.0, 0.47, 0.02), "rot": (-10.0, 0.0, 5.0)}, spine=(-24.0, 0.0, 0.0), chest=(-20.0, 0.0, 0.0),
                   head=(-34.0, 0.0, 6.0), leg_l=fk_leg(40.0, 128.0, foot_pitch=-55.0), leg_r=fk_leg(34.0, 124.0, foot_pitch=-55.0),
                   arm_r=r, arm_l=l)
    r, l = limp(120.0, 42.0, 45.0)
    fall = merged(stand, hips={"pos": (0.0, 0.20, -0.26), "rot": (-80.0, 10.0, 8.0)}, spine=(-4.0, 0.0, 0.0), chest=(0.0, 0.0, 0.0),
                  head=(-12.0, 28.0, 0.0), leg_l=fk_leg(-4.0, 30.0, roll=-8.0, foot_pitch=-50.0),
                  leg_r=fk_leg(-8.0, 14.0, roll=10.0, foot_pitch=-50.0), arm_r=r, arm_l=l)
    r, l = limp(128.0, 48.0, 50.0)
    flat = merged(fall, hips={"pos": (0.0, 0.11, -0.30), "rot": (-90.0, 12.0, 8.0)}, head=(-6.0, 34.0, 0.0), arm_r=r, arm_l=l)
    return keyed(t, [(0.0, stand), (0.10, jolt, "out"), (0.45, knees, "in"), (0.85, fall, "in"), (0.98, flat, "out"), (1.3, flat)])


def respawn(t):
    """Boot-up: kneeling with the head down, then up to ready."""
    kneel = crouch_idle(0.0)
    kneel = merged(kneel, head=(-28.0, 0.0, 0.0), arm_r=fk_arm(18.0, roll=8.0, bend=30.0), arm_l=fk_arm(18.0, roll=-8.0, bend=30.0))
    return keyed(t, [(0.0, kneel), (0.15, kneel), (0.6, idle(0.0), "out")])


def body_clips():
    return [
        Clip("aim", 1 / 30, aim),
        Clip("idle", 3.0, idle, loop=True),
        Clip("run", RUN_PERIOD, run, loop=True),
        Clip("sprint", SPRINT_PERIOD, sprint, loop=True),
        Clip("crouch_idle", 3.0, crouch_idle, loop=True),
        Clip("crouch_walk", CROUCH_PERIOD, crouch_walk, loop=True),
        Clip("slide", 0.8, slide, loop=True),
        Clip("air", 1.0, air),
        Clip("air_tuck", 0.8, air_tuck, loop=True),
        Clip("land", 1 / 30, land),
        Clip("wall_run_l", WALL_PERIOD, wall_run_l, loop=True),
        Clip("wall_run_r", WALL_PERIOD, wall_run_r, loop=True),
        Clip("wall_jump_l", 0.3, wall_jump_l),
        Clip("wall_jump_r", 0.3, wall_jump_r),
        Clip("vault", 0.32, vault),
        Clip("climb", 0.5, climb),
        Clip("grapple", 1.2, grapple, loop=True),
        Clip("dive", 0.6, dive, loop=True),
        Clip("roll", 0.45, roll),
        Clip("belly_slide", 0.8, belly_slide, loop=True),
        Clip("belly_crawl", CRAWL_PERIOD, belly_crawl, loop=True),
        Clip("flip_front", 0.45, flip_front),
        Clip("flip_back", 0.45, flip_back),
        Clip("flip_left", 0.45, flip_left),
        Clip("flip_right", 0.45, flip_right),
        Clip("reload", 1.3, reload),
        Clip("death", 1.3, death),
        Clip("respawn", 0.6, respawn),
    ] + view_clips() + hand_clips()


# ---------------------------------------------------------------------------
# The body as you see it in first person ("view_" clips). The game keeps the neck
# just under and behind the camera whatever the pose (RobotAnimator.place_for_view),
# and the camera stays level, so these are made to be looked at from the eyes: the
# pelvis tips back to bring the legs up into the lower part of the view, and moves
# that spin the whole body in third person become leg sweeps here. Only the legs
# and torso are drawn; the arms are ViewModel's.

def _seen(lean, left, right, roll=0.0, turn=0.0, spread=6.0, curl=0.75, feet=-20.0):
    """lean: pelvis tipped back (degrees). left/right: (thigh, knee) for each leg.
    roll: the whole body wheeled about the line of sight (side flips). curl: how much
    of the lean the spine takes back, so the chest stays under the camera."""
    return {
        "root": {"pos": (0.0, 0.0, 0.0), "rot": (0.0, 0.0, roll)},
        "hips": {"pos": (0.0, 0.96, 0.0), "rot": (lean, turn, 0.0)},
        "spine": (-lean * curl * 0.5, 0.0, 0.0), "chest": (-lean * curl * 0.5, 0.0, 0.0), "head": (0.0, 0.0, 0.0),
        "leg_l": fk_leg(left[0], left[1], roll=-spread, foot_pitch=feet),
        "leg_r": fk_leg(right[0], right[1], roll=spread, foot_pitch=feet),
        "arm_r": fk_arm(40.0, roll=14.0, bend=80.0), "arm_l": fk_arm(40.0, roll=-14.0, bend=80.0),
    }


SEEN_HANG = _seen(4.0, (30.0, 40.0), (20.0, 34.0))


def view_slide(t):
    """Sliding: lying back, the lead leg stretched out ahead, the other knee up."""
    s = math.sin(TAU * t / 0.8)
    return _seen(52.0 + 1.0 * s, (42.0, 14.0), (74.0 + 1.5 * s, 92.0), turn=-6.0, feet=10.0)


def view_air_tuck(t):
    """Legs pulled up in the air: knees high in front."""
    s = math.sin(TAU * t / 0.8)
    return _seen(34.0, (104.0 + 2.0 * s, 112.0), (96.0 - 2.0 * s, 108.0))


def view_flip_back(t):
    """Backflip: the knees drive up and the feet kick up in front, then tuck in and drop away under you."""
    return keyed(t, [
        (0.0, SEEN_HANG),
        (0.10, _seen(46.0, (96.0, 112.0), (88.0, 106.0)), "out"),
        (0.21, _seen(68.0, (98.0, 58.0), (92.0, 52.0)), "linear"),
        (0.33, _seen(26.0, (112.0, 140.0), (106.0, 136.0)), "linear"),
        (0.45, SEEN_HANG, "out"),
    ])


def view_flip_front(t):
    """Front flip: the legs whip back out of sight, come through tucked under you, and swing down in front to land."""
    return keyed(t, [
        (0.0, SEEN_HANG),
        (0.10, _seen(-18.0, (-24.0, 84.0), (-30.0, 78.0)), "out"),
        (0.23, _seen(26.0, (114.0, 140.0), (108.0, 136.0)), "linear"),
        (0.34, _seen(64.0, (96.0, 54.0), (90.0, 48.0)), "linear"),
        (0.45, SEEN_HANG, "out"),
    ])


def view_flip_left(t):
    """Side flip to the left: the tucked legs wheel around the edge of the view, out to the right, over the top and back in from the left."""
    return keyed(t, [
        (0.0, SEEN_HANG),
        (0.10, _seen(36.0, (80.0, 104.0), (70.0, 96.0), roll=70.0, spread=14.0, curl=1.0), "linear"),
        (0.34, _seen(36.0, (80.0, 104.0), (70.0, 96.0), roll=295.0, spread=14.0, curl=1.0), "linear"),
        (0.45, merged(SEEN_HANG, root={"pos": (0.0, 0.0, 0.0), "rot": (0.0, 0.0, 360.0)}), "linear"),
    ])


def view_flip_right(t):
    return mirror(view_flip_left(t))


def view_roll(t):
    """Landing roll after a dive: the legs come through tucked under you and swing down to plant."""
    return keyed(t, [
        (0.0, _seen(-50.0, (-8.0, 20.0), (-2.0, 30.0))),
        (0.14, _seen(22.0, (118.0, 142.0), (112.0, 138.0)), "linear"),
        (0.30, _seen(58.0, (100.0, 66.0), (94.0, 60.0)), "linear"),
        (0.45, _seen(16.0, (84.0, 112.0), (70.0, 104.0)), "out"),
    ])


def hand_clips():
    """Each hand pose (rig.HANDS) as a clip one frame long, both hands held that way:
    the game blends a hand to one where the other clips cannot know how it is held (a
    blade's handle in the fist: game/player/robot/hands.gd)."""
    def held(how):
        return lambda t: {"fingers_l": how, "fingers_r": how}
    return [Clip("hand_" + how, 1 / 30, held(how)) for how in HANDS]


def view_clips():
    return [
        Clip("view_slide", 0.8, view_slide, loop=True),
        Clip("view_air_tuck", 0.8, view_air_tuck, loop=True),
        Clip("view_roll", 0.45, view_roll),
        Clip("view_flip_front", 0.45, view_flip_front),
        Clip("view_flip_back", 0.45, view_flip_back),
        Clip("view_flip_left", 0.45, view_flip_left),
        Clip("view_flip_right", 0.45, view_flip_right),
    ]


# ---------------------------------------------------------------------------
# First-person arms. Same skeleton, standing straight; the camera sits at EYE and
# only the arms and gun are drawn. Positions here are relative to the camera.

EYE = (0.0, 1.60, 0.0)


def cam(x, y, z):
    """A point given relative to the camera, as a chest-space point."""
    return (x, y + EYE[1] - 1.22, z)


def fp_arm_r(x, y, z, hand=(90.0, 0.0, 0.0), cant=0.0):
    return {"ik": cam(x, y, z), "space": "chest", "pole": (0.8, -1.0, 0.3), "hand": hand, "cant": cant}


def fp_arm_l(x, y, z, hand=(90.0, -28.0, 0.0), cant=0.0):
    return {"ik": cam(x, y, z), "space": "chest", "pole": (-0.8, -1.0, 0.3), "hand": hand, "cant": cant}


# The same relaxed hold as the body's (AIM_R): low and off to the right of the view,
# pointing in toward the crosshair, not held up in front of your face.
# Only the arms are drawn, so the shoulders go where both hands can reach a gun held that
# far out to the right: the chest turned to the right and brought forward (the right
# shoulder stays about where it was, the left comes round to the front). Arms held this
# way are given in the model's space (in_view), which the turned chest does not move.
FP_BODY = {"hips": {"pos": (0.04, 0.96, -0.09), "rot": (0.0, 0.0, 0.0)}, "chest": (0.0, -30.0, 0.0)}


def in_view(arm):
    """An arm given relative to the camera (fp_arm_r, fp_arm_l), in the model's space."""
    return dict(arm, ik=tuple(a + b for a, b in zip(arm["ik"], CHEST0)), space="model")


FP_R = in_view(fp_arm_r(0.262, -0.222, -0.40, hand=(90.0, 4.0, 0.0), cant=6.0))
FP_L = wrap_l(FP_R, pole=(-0.8, -1.0, 0.3), body=FP_BODY)
FP_L_AWAY = fp_arm_l(-0.30, -0.48, -0.12, hand=(60.0, 0.0, 0.0))


def fp_idle(t):
    return dict(FP_BODY, arm_r=FP_R, arm_l=FP_L)


def fp_one_hand(t):
    """Gun in the right hand only (the left arm is on the rope)."""
    return {"arm_r": fp_arm_r(0.27, -0.222, -0.40, hand=(90.0, 4.0, 0.0), cant=10.0), "arm_l": FP_L_AWAY}


def fp_sprint(t):
    return {"arm_r": fp_arm_r(0.21, -0.26, -0.31, hand=(128.0, 22.0, 0.0), cant=-18.0),
            "arm_l": fp_arm_l(-0.20, -0.36, -0.24, hand=(75.0, 0.0, 0.0))}


def fp_slide(t):
    """Gun in the right hand; the left trails out to the side, clear of the legs you can see below."""
    return {"arm_r": fp_arm_r(0.19, -0.16, -0.43, cant=-20.0),
            "arm_l": fp_arm_l(-0.50, -0.46, -0.10, hand=(50.0, 0.0, 20.0))}


def fp_wall_l(t):
    return {"arm_r": fp_arm_r(0.20, -0.165, -0.43, cant=10.0),
            "arm_l": fp_arm_l(-0.44, -0.16, -0.30, hand=(72.0, 0.0, 0.0), cant=180.0)}


def fp_wall_r(t):
    return {"arm_r": fp_arm_r(0.20, -0.17, -0.42, cant=-16.0), "arm_l": fp_arm_l(0.135, -0.188, -0.405)}


def fp_dive(t):
    return {"arm_r": fp_arm_r(0.13, -0.125, -0.50), "arm_l": fp_arm_l(0.065, -0.142, -0.485)}


def fp_tuck(t):
    return {"arm_r": fp_arm_r(0.15, -0.31, -0.26, hand=(104.0, 16.0, 0.0)),
            "arm_l": fp_arm_l(-0.12, -0.38, -0.22, hand=(80.0, 0.0, 0.0))}


def fp_mantle(t):
    """Hands reach for the edge and push it down past the camera."""
    reach = {"arm_r": fp_arm_r(0.22, -0.13, -0.44, cant=-28.0),
             "arm_l": fp_arm_l(-0.19, -0.12, -0.47, hand=(95.0, 0.0, 0.0), cant=90.0)}
    push = {"arm_r": fp_arm_r(0.24, -0.47, -0.28, cant=-35.0),
            "arm_l": fp_arm_l(-0.21, -0.48, -0.30, hand=(110.0, 0.0, 0.0), cant=90.0)}
    return keyed(t, [(0.0, reach), (0.08, reach), (0.34, push, "in"), (0.45, push)])


def fp_raise(t):
    """Bringing the gun up (after a respawn)."""
    down = {"arm_r": fp_arm_r(0.17, -0.42, -0.24, hand=(60.0, 10.0, 0.0)),
            "arm_l": fp_arm_l(-0.02, -0.44, -0.22, hand=(60.0, -10.0, 0.0))}
    return keyed(t, [(0.0, down), (0.1, down), (0.4, fp_idle(0), "out")])


def _reload(t, rest_r, rest_l, tilt_r, at_mag, away, at_slide):
    """Shared shape of a reload (1.3 s): tip the gun, drop the magazine, bring a new
    one up from the hip, seat it, rack the slide, back on target."""
    rest = {"arm_r": rest_r, "arm_l": rest_l, "mag": (0.0, 0.0, 0.0), "slide": 0.0}
    tilt = {"arm_r": tilt_r, "arm_l": at_mag, "mag": (0.0, 0.0, 0.0), "slide": 0.0}
    drop = {"arm_r": tilt_r, "arm_l": away, "mag": (0.0, -0.75, 0.05), "slide": 0.0}
    fetch = {"arm_r": tilt_r, "arm_l": away, "mag": (0.0, -0.40, 0.06), "slide": 0.0}
    insert = {"arm_r": tilt_r, "arm_l": at_mag, "mag": (0.0, -0.05, 0.012), "slide": 0.0}
    seated = {"arm_r": tilt_r, "arm_l": at_mag, "mag": (0.0, 0.0, 0.0), "slide": 0.0}
    grab = {"arm_r": rest_r, "arm_l": at_slide, "mag": (0.0, 0.0, 0.0), "slide": 0.0}
    rack = {"arm_r": rest_r, "arm_l": at_slide, "mag": (0.0, 0.0, 0.0), "slide": 0.04}
    return keyed(t, [(0.0, rest), (0.16, tilt), (0.24, tilt), (0.42, drop, "in"), (0.56, fetch, "linear"),
                     (0.76, insert, "out"), (0.84, seated, "in"), (0.98, grab), (1.06, rack, "out"),
                     (1.12, grab, "in"), (1.30, rest)])


def fp_reload(t):
    return _pistol_reload(t, FP_R, FP_L, True)


# ---------------------------------------------------------------------------
# The pistol's reload (1.3 s): a flick of the wrist throws the spent cell out sideways
# and drops the vent open, the left hand brings a new cell up from the hip, tosses it
# and slaps it home with the flat of the palm, the vent snaps shut, and the right hand
# opens to let the gun spin once forward round the trigger finger, closing on the grip
# as it comes round, its slide snapping shut as it lands. The game's side of it (the
# spent cell that flies off, the glow, hiding the cell between the throw and the new one)
# is timed to these keys in game/combat/reload_fx.gd.

PISTOL_VENT_PIVOT = (0.027, 0.086)          # the vent's hinge: (up, forward) of the grip
PISTOL_SPIN_PIVOT = (0.0, 0.006, -0.024)    # the trigger finger in the guard, in gun space: the gun spins round it
CELL_MIDDLE = v(0.0, -0.045, 0.02)          # the middle of the cell seated in the grip (gun space)
CELL_OUT = norm(v(0.0, -0.97, 0.24))        # the way out of the grip (gun space)
CELL_HALF = 0.055                           # from the cell's middle to its base
PALM_L = v(-0.020, -0.031, 0.029)           # the middle of the left palm's face, from its wrist (hands.py)


def _at(t, keys):
    """A number keyed over time: keys [(time, value), ...] or [(time, value, ease), ...]."""
    if t <= keys[0][0]:
        return keys[0][1]
    for i in range(1, len(keys)):
        if t <= keys[i][0]:
            u = ease((t - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0]), keys[i][2] if len(keys[i]) > 2 else "smooth")
            return keys[i - 1][1] + (keys[i][1] - keys[i - 1][1]) * u
    return keys[-1][1]


def _hand_at(t, keys):
    """A hand's pose keyed over time: keys [(time, name in rig.HANDS), ...] (or with an ease)."""
    return tuple(_at(t, [(k[0], HANDS[k[1]][i]) + tuple(k[2:]) for k in keys]) for i in range(8))


def _moved(arm, by, hand=None, cant=None):
    """An arm's pose with its wrist moved `by` (and the hand turned)."""
    return {"ik": tuple(a + b for a, b in zip(arm["ik"], by)), "space": arm.get("space", "chest"), "pole": arm["pole"],
            "hand": hand if hand is not None else arm["hand"], "cant": cant if cant is not None else arm.get("cant", 0.0)}


def _pistol_reload(t, rest_r, rest_l, fp):
    rest_r = _moved(rest_r, ZERO)
    rest_l = _moved(rest_l, ZERO)
    rest_cant = rest_r["cant"]
    space = rest_r["space"]
    body = FP_BODY if fp else {}
    # --- The right arm. In first person the gun comes up and in toward the middle of the view.
    # Each move starts a touch the other way and runs a little past where it settles, and the
    # gun never sits dead still: it rocks back from the flick, then rises to meet the tossed cell.
    if fp:
        dip = _moved(rest_r, (0.006, -0.012, 0.0), cant=rest_cant + 8.0)
        flick = _moved(rest_r, (-0.04, 0.09, 0.0), (110.0, 14.0, 0.0), -94.0)
        settle = _moved(rest_r, (-0.05, 0.072, 0.015), (99.0, 10.0, 0.0), -70.0)
        offer = _moved(rest_r, (-0.07, 0.11, 0.03), (106.0, 14.0, 0.0), -84.0)
        ready = _moved(rest_r, (-0.076, 0.12, 0.03), (109.0, 15.0, 0.0), -89.0)
        wait = _moved(rest_r, (-0.07, 0.102, 0.03), (104.0, 14.0, 0.0), -82.0)
        knock = _moved(rest_r, (-0.03, 0.112, 0.03), (103.0, 9.0, 0.0), -74.0)
        spin = _moved(rest_r, (-0.06, 0.12, 0.0), (90.0, 5.0, 0.0), 4.0)
        top = _moved(rest_r, (-0.06, 0.134, 0.0), (86.0, 5.0, 0.0), 4.0)
        catch = _moved(rest_r, (-0.02, -0.018, 0.0), (94.0, 4.0, 0.0), rest_cant)
        over = _moved(rest_r, (0.0, 0.008, 0.0))
    else:
        dip = _moved(rest_r, (0.006, -0.012, 0.0), cant=rest_cant + 8.0)
        flick = _moved(rest_r, (0.05, 0.06, 0.03), (110.0, 12.0, 0.0), -94.0)
        settle = _moved(rest_r, (0.035, 0.04, 0.04), (99.0, 8.0, 0.0), -70.0)
        offer = _moved(rest_r, (0.0, 0.05, 0.05), (106.0, 12.0, 0.0), -84.0)
        ready = _moved(rest_r, (-0.006, 0.06, 0.05), (109.0, 13.0, 0.0), -89.0)
        wait = _moved(rest_r, (0.0, 0.042, 0.05), (104.0, 12.0, 0.0), -82.0)
        knock = _moved(rest_r, (0.04, 0.052, 0.05), (103.0, 7.0, 0.0), -74.0)
        spin = _moved(rest_r, (0.01, 0.08, 0.02), (90.0, 3.0, 0.0), 4.0)
        top = _moved(rest_r, (0.01, 0.094, 0.02), (86.0, 3.0, 0.0), 4.0)
        catch = _moved(rest_r, (0.0, -0.028, 0.0), (94.0, 3.0, 0.0), rest_cant)
        over = _moved(rest_r, (0.0, 0.008, 0.0))
    arm_r = keyed(t, [(0.0, rest_r), (0.04, dip), (0.11, flick, "out"), (0.20, settle), (0.32, offer), (0.47, ready),
                      (0.585, wait), (0.63, knock, "out"),
                      (0.72, offer), (0.82, spin), (0.94, top), (1.06, spin), (1.13, catch, "in"), (1.21, over, "out"),
                      (1.28, rest_r), (1.30, rest_r)])
    # --- The left arm: to the hip for a new cell, up with it, the toss (the hand follows it up,
    # opening), back for the slap, the slap, off the gun with the knock, clear of the spin, back under.
    if fp:
        hip = fp_arm_l(-0.02, -0.52, -0.16, hand=(40.0, 0.0, 0.0))
        lift = fp_arm_l(-0.03, -0.37, -0.33, hand=(64.0, -30.0, 0.0))
        toss = fp_arm_l(0.0, -0.255, -0.36, hand=(104.0, -40.0, 0.0))
        clear = fp_arm_l(-0.07, -0.32, -0.29, hand=(80.0, -30.0, 0.0))
    else:
        hip = _arm("l", (-0.21, -0.30, -0.05), (30.0, 0.0, 0.0))
        lift = _arm("l", (-0.11, -0.08, -0.26), (64.0, -30.0, 0.0))
        toss = _arm("l", (-0.08, 0.035, -0.30), (104.0, -40.0, 0.0))
        clear = _arm("l", (-0.14, -0.04, -0.23), (80.0, -30.0, 0.0))
    hip, lift, toss, clear = [_moved(in_view(a) if fp else a, ZERO) for a in (hip, lift, toss, clear)]
    # The slap is worked out from where the gun is waiting: the flat of the palm on the
    # cell's base, facing up the grip, the fingers along the gun.
    gun_turn, gun_at = _frames(dict(body, arm_r=wait, arm_l=toss), space)["gun"]
    aim = gun_turn @ GUN_REST
    into = -(aim @ CELL_OUT)
    base = gun_at + aim @ (CELL_MIDDLE + CELL_OUT * (CELL_HALF + 0.004))
    along = aim @ v(0.0, 0.25, -1.0)
    along = norm(along - into * float(np.dot(along, into)))
    palm = np.column_stack([into, -along, np.cross(into, -along)])

    def struck(back_off, pole=(-0.5, -1.0, 0.3)):
        wrist = base - into * back_off - palm @ PALM_L
        return {"ik": tuple(float(x) for x in wrist), "space": space, "pole": pole, "hand": _euler_of(palm), "cant": 0.0}
    arm_l = keyed(t, [(0.0, rest_l), (0.10, rest_l), (0.27, hip, "in"), (0.38, lift, "in"), (0.44, toss, "out"),
                      (0.50, _moved(toss, (0.0, 0.03, -0.01))), (0.565, struck(0.11)), (0.62, struck(0.0), "in"),
                      (0.68, struck(0.05), "out"), (0.80, clear), (0.96, _moved(clear, (-0.025, -0.035, 0.03))),
                      (1.10, _moved(clear, (-0.01, -0.01, 0.0))), (1.26, rest_l), (1.30, rest_l)])
    spec = dict(body)
    spec.update({"arm_r": arm_r, "arm_l": arm_l,
            # The right hand lets go for the spin, all but the trigger finger, and closes as the grip comes round.
            "fingers_r": _hand_at(t, [(0.0, "gun"), (0.70, "gun"), (0.79, "trigger", "out"), (1.02, "trigger"), (1.11, "gun", "in")]),
            "fingers_l": _hand_at(t, [(0.0, "wrap"), (0.08, "wrap"), (0.2, "relaxed"), (0.27, "open"), (0.31, "pinch", "in"),
                                      (0.43, "pinch"), (0.49, "open", "out"), (0.56, "flat"), (0.64, "flat"), (0.76, "relaxed"),
                                      (1.10, "relaxed"), (1.26, "wrap")]),
            "vent": _at(t, [(0.0, 0.0), (0.05, 0.0), (0.10, -38.0, "out"), (0.16, -32.0), (0.66, -32.0), (0.71, 0.0, "in")]),
            "vent_pivot": PISTOL_VENT_PIVOT,
            "slide": _at(t, [(0.0, 0.0), (0.07, 0.0), (0.10, 0.04, "out"), (1.10, 0.04), (1.16, 0.0, "in")])})
    if not fp:
        # The body goes with it: the right shoulder goes into the flick, the left comes
        # round behind the slap, and the chest leans back a touch through the spin.
        spec["chest"] = (_at(t, [(0.0, 0.0), (0.12, 3.0, "out"), (0.62, 2.0), (0.84, -4.0), (1.10, -3.0), (1.3, 0.0)]),
                         _at(t, [(0.0, 0.0), (0.12, 9.0, "out"), (0.44, 5.0), (0.63, -11.0, "in"), (0.84, -2.0), (1.3, 0.0)]),
                         _at(t, [(0.0, 0.0), (0.12, -7.0, "out"), (0.5, -4.0), (0.66, 3.0), (0.9, 0.0), (1.3, 0.0)]))
        spec["spine"] = (0.0, _at(t, [(0.0, 0.0), (0.12, 4.0, "out"), (0.44, 2.0), (0.63, -5.0, "in"), (0.84, 0.0), (1.3, 0.0)]), 0.0)
    # --- The gun in the hand: once round the trigger finger, muzzle going down and forward first,
    # slowing as it comes back up into the palm.
    turn = _at(t, [(0.0, 0.0), (0.77, 0.0), (0.84, -70.0, "in"), (1.0, -300.0, "linear"), (1.09, -360.0, "out"), (1.3, -360.0)])
    if turn != 0.0 and turn != -360.0:
        pivot = v(*PISTOL_SPIN_PIVOT)
        spec["pistol"] = {"pos": tuple(pivot - rx(turn) @ pivot), "rot": (turn, 0.0, 0.0)}
    # --- The cell: thrown out of the grip, then the new one in the left hand, tossed, and home.
    if t < 0.07 or t >= 0.62:
        return spec
    if t < 0.14:   # out, the way the grip points (the game's own flying cell takes over from here)
        spec["mag"] = tuple(CELL_OUT * _at(t, [(0.07, 0.0), (0.14, 0.2, "linear")]))
        return spec
    now = _frames(spec, space)
    gun_turn, gun_at = now["gun"]
    aim = gun_turn @ GUN_REST
    seated = gun_at + aim @ CELL_MIDDLE

    def in_hand(frames):
        """The cell held across the fingers, its top toward the thumb: (its middle, its turn in gun space)."""
        hand_turn = frames["hand_l"][0]
        top = hand_turn @ v(0.0, 0.0, -1.0)
        flat = hand_turn @ v(1.0, 0.0, 0.0)
        world = np.column_stack([flat, top, np.cross(flat, top)])
        own = np.column_stack([v(1.0, 0.0, 0.0), -CELL_OUT, np.cross(v(1.0, 0.0, 0.0), -CELL_OUT)])
        return frames["fist_l"] + hand_turn @ v(0.012, 0.0, 0.0), aim.T @ world @ own.T
    if t < 0.44:   # in the hand (hidden by the game until the hand is on its way up)
        middle, turn_m = in_hand(now)
    else:          # tossed: up in an arc from where the hand let go, turning over once, into the grip
        u = (t - 0.44) / (0.62 - 0.44)
        let_go, held = in_hand(_frames(merged(spec, arm_l=toss), space))
        middle = let_go + (seated - let_go) * ease(u, "in") + v(0.0, 0.085, 0.0) * 4.0 * u * (1.0 - u) * (1.0 - u) * 1.6
        turn_m = rx(-360.0 * min(u / 0.85, 1.0)) @ _slerp_m(held, np.eye(3), ease(min(u / 0.7, 1.0)))
    spec["mag_rot"] = _euler_of(turn_m)
    spec["mag"] = tuple(aim.T @ (middle - gun_at) - turn_m @ CELL_MIDDLE)
    return spec


def arms_clips():
    return [
        Clip("fp_idle", 1 / 30, fp_idle),
        Clip("fp_one_hand", 1 / 30, fp_one_hand),
        Clip("fp_sprint", 1 / 30, fp_sprint),
        Clip("fp_slide", 1 / 30, fp_slide),
        Clip("fp_wall_l", 1 / 30, fp_wall_l),
        Clip("fp_wall_r", 1 / 30, fp_wall_r),
        Clip("fp_dive", 1 / 30, fp_dive),
        Clip("fp_tuck", 1 / 30, fp_tuck),
        Clip("fp_mantle", 0.45, fp_mantle),
        Clip("fp_raise", 0.4, fp_raise),
        Clip("fp_reload", 1.3, fp_reload),
    ] + hand_clips()
