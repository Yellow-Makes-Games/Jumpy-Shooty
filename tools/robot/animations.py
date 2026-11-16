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
from m3 import euler
import numpy as np
from rig import Clip, keyed, mix, mirror, merged, ease

TAU = math.tau

# ---------------------------------------------------------------------------
# Building blocks

# Gun up in both hands, relative to the chest. The game pitches this with the aim.
AIM_R = {"ik": (0.045, 0.25, -0.44), "space": "chest", "pole": (0.7, -1.0, 0.3), "hand": (90.0, 0.0, 0.0)}
AIM_L = {"ik": (-0.02, 0.232, -0.425), "space": "chest", "pole": (-0.7, -1.0, 0.3), "hand": (90.0, -25.0, 0.0)}
# Gun in one hand (the left arm is busy: wall, rope, ground)
AIM_R_ONE = {"ik": (0.14, 0.24, -0.46), "space": "chest", "pole": (0.7, -1.0, 0.3), "hand": (90.0, 0.0, 0.0)}

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
    """Arms and gun only; the game lays this over whatever the body is doing."""
    return _reload(t,
                   _arm("r", AIM_R["ik"], AIM_R["hand"]), _arm("l", AIM_L["ik"], AIM_L["hand"]),
                   _arm("r", (0.07, 0.21, -0.37), (118.0, 14.0, 0.0), 38.0),
                   _arm("l", (0.015, 0.105, -0.34), (100.0, -20.0, 0.0)),
                   _arm("l", (-0.19, -0.22, -0.10), (40.0, 0.0, 0.0)),
                   _arm("l", (0.035, 0.275, -0.405), (90.0, -50.0, 0.0), -60.0))


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
    ] + view_clips()


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


FP_R = fp_arm_r(0.185, -0.165, -0.43)
FP_L = fp_arm_l(0.12, -0.182, -0.415)
FP_L_AWAY = fp_arm_l(-0.30, -0.48, -0.12, hand=(60.0, 0.0, 0.0))


def fp_idle(t):
    return {"arm_r": FP_R, "arm_l": FP_L}


def fp_one_hand(t):
    """Gun in the right hand only (the left arm is on the rope)."""
    return {"arm_r": fp_arm_r(0.20, -0.165, -0.43), "arm_l": FP_L_AWAY}


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
    return _reload(t, FP_R, FP_L,
                   fp_arm_r(0.17, -0.145, -0.39, hand=(114.0, 14.0, 0.0), cant=38.0),
                   fp_arm_l(0.125, -0.235, -0.365, hand=(100.0, -20.0, 0.0)),
                   fp_arm_l(-0.04, -0.50, -0.20, hand=(80.0, 0.0, 0.0)),
                   fp_arm_l(0.155, -0.115, -0.405, hand=(90.0, -50.0, 0.0), cant=-60.0))


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
    ]
