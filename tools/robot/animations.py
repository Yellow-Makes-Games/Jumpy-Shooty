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


# Each robot has a habit of its own when it stands still: a version of the idle, three
# breaths long, with one small thing in it. They go by the torso ("idle_<torso>"), so a
# character put together in the Character Creator stands the way its torso does; a
# torso with none stands in the plain idle. A habit never turns the chest or moves it
# sideways (the gun is held from the chest, and must not wander off its aim: _steady
# keeps it there while the hips move); it may raise or lower it a little. And it never
# looks like doing something: no reaching, no ducking. tests/robot_test.gd checks the first.

QUIRK_PERIOD = 9.0


def _snap(t, start, rise, hold, fall):
    """0, up to 1 and back to 0: there in `rise` seconds with a little overshoot, held,
    then eased back over `fall`."""
    u = t - start
    if u <= 0.0 or u >= rise + hold + fall:
        return 0.0
    if u < rise:
        w = u / rise - 1.0
        return 1.0 + 2.70158 * w ** 3 + 1.70158 * w ** 2
    if u < rise + hold:
        return 1.0
    return 1.0 - ease((u - rise - hold) / fall)


def _turned(spec, bone, pitch=0.0, yaw=0.0, roll=0.0):
    r = spec[bone]
    spec[bone] = (r[0] + pitch, r[1] + yaw, r[2] + roll)


def _ease(t, start, rise, hold, fall):
    """0, up to 1 and back to 0, eased both ways (no overshoot): for slow moves."""
    u = t - start
    if u <= 0.0 or u >= rise + hold + fall:
        return 0.0
    if u < rise:
        return ease(u / rise)
    if u < rise + hold:
        return 1.0
    return 1.0 - ease((u - rise - hold) / fall)


def _steady(spec, t, lift=0.0):
    """Keeps the chest where the plain idle has it at time t (raised by `lift`), whatever
    this spec does with the hips: the spine and chest take up the difference and the
    hips are put where that leaves them. The gun is held from the chest, so a habit can
    shift its weight about underneath without the aim wandering."""
    plain = idle(t)
    o_spine, o_chest = BODY.offset("spine"), BODY.offset("chest")
    gh = euler(plain["hips"]["rot"])
    gs = gh @ euler(plain["spine"])
    gc = gs @ euler(plain["chest"])
    at = np.array(plain["hips"]["pos"]) + gh @ o_spine + gs @ o_chest + np.array([0.0, lift, 0.0])
    hips = euler(spec["hips"]["rot"])
    mid = hips @ _slerp_m(np.eye(3), hips.T @ gc, 0.5)
    spec["spine"] = _euler_of(hips.T @ mid)
    spec["chest"] = _euler_of(mid.T @ gc)
    spec["hips"]["pos"] = tuple(float(x) for x in at - hips @ o_spine - mid @ o_chest)
    return spec


def _hips(spec, pitch=0.0, yaw=0.0, roll=0.0):
    r = spec["hips"]["rot"]
    spec["hips"]["rot"] = (r[0] + pitch, r[1] + yaw, r[2] + roll)


def idle_needle(t):
    """Needle is curious: it cocks its head like a bird, and a while later takes a quick
    second look to the side and tips its head the other way."""
    spec = idle(t)
    a = _snap(t, 2.2, 0.16, 1.0, 0.26)
    b = _snap(t, 6.0, 0.14, 0.4, 0.2)
    c = _snap(t, 6.7, 0.15, 0.75, 0.28)
    _turned(spec, "head", pitch=-3.0 * a + 2.0 * b - 2.0 * c, yaw=-5.0 * a + 15.0 * b + 4.0 * c, roll=15.0 * a - 13.0 * c)
    return spec


def idle_vanguard(t):
    """Vanguard stands ready: it rocks up onto its toes and settles, like a soldier
    keeping loose, then a smaller one."""
    spec = idle(t)
    a = _snap(t, 2.0, 0.22, 0.5, 0.45)
    b = _snap(t, 6.2, 0.2, 0.25, 0.4) * 0.55
    up = a + b
    spec["leg_l"] = foot(-0.13, 0.0, -0.20, pitch=-16.0 * up, yaw=6.0, pole=(-0.15, 0.0, -1.0))
    spec["leg_r"] = foot(0.14, 0.0, -0.02, pitch=-16.0 * up, yaw=-14.0, pole=(0.3, 0.0, -1.0))
    _turned(spec, "head", pitch=3.0 * up)
    return _steady(spec, t, 0.022 * up)


def idle_kestrel(t):
    """Kestrel is restless: two quick bounces on its talons, and later a sharp, bird-like
    snap of the head to one side."""
    spec = idle(t)
    hop = _snap(t, 1.6, 0.09, 0.02, 0.13) + _snap(t, 1.9, 0.09, 0.02, 0.16) * 0.7
    look = _snap(t, 5.2, 0.09, 0.7, 0.14)
    spec["leg_l"] = foot(-0.13, 0.0, -0.20, pitch=-11.0 * hop, yaw=6.0, pole=(-0.15, 0.0, -1.0))
    spec["leg_r"] = foot(0.14, 0.0, -0.02, pitch=-11.0 * hop, yaw=-14.0, pole=(0.3, 0.0, -1.0))
    _turned(spec, "head", pitch=2.0 * look, yaw=-34.0 * look, roll=-6.0 * look)
    return _steady(spec, t, 0.016 * hop)


def idle_bulwark(t):
    """Bulwark is heavy: it sags slowly into its knees, then hitches itself back up."""
    spec = idle(t)
    sag = ease((t - 1.0) / 3.2) if t < 4.4 else 0.0
    up = _snap(t, 4.4, 0.2, 0.0, 0.01) if t < 4.6 else 1.0
    low = sag if t < 4.4 else max(1.0 - up, 0.0) if t < 4.6 else 0.0
    _hips(spec, pitch=-3.0 * low)
    _turned(spec, "head", pitch=-7.0 * low + 4.0 * _snap(t, 4.45, 0.16, 0.1, 0.5))
    return _steady(spec, t, -0.03 * low + 0.008 * _snap(t, 4.45, 0.16, 0.0, 0.4))


def idle_rivet(t):
    """Rivet is impatient: it taps the toe of its front boot, three times, then twice."""
    spec = idle(t)
    tap = sum(_snap(t, t0, 0.07, 0.0, 0.1) for t0 in (2.0, 2.3, 2.6, 6.4, 6.7))
    spec["leg_l"] = foot(-0.13, 0.034 * tap, -0.20, pitch=11.0 * tap, yaw=6.0, pole=(-0.15, 0.0, -1.0))
    glance = _ease(t, 1.8, 0.4, 1.0, 0.5) + _ease(t, 6.2, 0.4, 0.6, 0.5)
    _turned(spec, "head", pitch=-5.0 * glance, yaw=7.0 * glance)
    return spec


def idle_specter(t):
    """Specter keeps still: one slow look over its shoulder, and back."""
    spec = idle(t)
    look = _ease(t, 2.4, 1.0, 1.3, 1.1)
    _turned(spec, "head", pitch=3.0 * look, yaw=46.0 * look, roll=4.0 * look)
    _hips(spec, yaw=5.0 * look)
    return _steady(spec, t)


def idle_orbit(t):
    """Orbit floats: its weight drifts slowly from side to side and its head tips with it."""
    spec = idle(t)
    drift = math.sin(TAU * t / 4.5)
    slow = math.sin(TAU * t / 9.0)
    _hips(spec, yaw=3.0 * slow, roll=3.5 * drift)
    _turned(spec, "head", yaw=-4.0 * slow, roll=-5.0 * drift)
    return _steady(spec, t, 0.006 * math.cos(TAU * t / 4.5))


def idle_templar(t):
    """Templar stands tall: it draws itself up, lifts its chin and squares its hips to
    the front, holds it, and settles."""
    spec = idle(t)
    tall = _ease(t, 2.2, 0.5, 1.7, 0.9)
    _hips(spec, pitch=1.5 * tall, yaw=5.0 * tall)
    _turned(spec, "head", pitch=8.0 * tall)
    return _steady(spec, t, 0.014 * tall)


# The Character Creator's other torsos (creatures.py), each by its body's id.

def _stand(spec, heels=0.0, tap_l=0.0, tap_r=0.0):
    """The idle's feet, with both heels raised (degrees: up on the toes) or a toe tapped (0..1)."""
    spec["leg_l"] = foot(-0.13, 0.034 * tap_l, -0.20, pitch=11.0 * tap_l - heels, yaw=6.0, pole=(-0.15, 0.0, -1.0))
    spec["leg_r"] = foot(0.14, 0.034 * tap_r, -0.02, pitch=11.0 * tap_r - heels, yaw=-14.0, pole=(0.3, 0.0, -1.0))


def idle_human(t):
    """Dude rolls his neck: over to one side, then the other."""
    spec = idle(t)
    a, b = _ease(t, 2.0, 0.6, 0.5, 0.6), _ease(t, 4.2, 0.6, 0.5, 0.6)
    _turned(spec, "head", pitch=-2.0 * (a + b), roll=11.0 * (a - b))
    _hips(spec, roll=2.5 * (a - b))
    return _steady(spec, t)


def idle_goblin(t):
    """Goblin is twitchy: it ducks a little and darts a look one way, then the other."""
    spec = idle(t)
    a, b = _snap(t, 2.0, 0.08, 0.35, 0.12), _snap(t, 2.7, 0.08, 0.3, 0.14)
    _turned(spec, "head", pitch=-3.0 * (a + b), yaw=-28.0 * a + 24.0 * b)
    return _steady(spec, t, -0.012 * min(a + b, 1.0))


def idle_frog(t):
    """Frog bobs: two slow dips into its knees, looking up, as if about to hop."""
    spec = idle(t)
    dip = _ease(t, 2.0, 0.35, 0.1, 0.45) + _ease(t, 3.3, 0.35, 0.1, 0.45)
    _turned(spec, "head", pitch=5.0 * dip)
    return _steady(spec, t, -0.028 * dip)


def idle_skeleton(t):
    """Bones rattles: a quick shiver of the skull, and later it tips to one side."""
    spec = idle(t)
    shiver = math.sin(TAU * (t - 2.0) / 0.16) * _ease(t, 2.0, 0.1, 0.45, 0.2)
    tip = _snap(t, 5.5, 0.16, 0.9, 0.3)
    _turned(spec, "head", yaw=3.0 * shiver, roll=6.0 * shiver + 13.0 * tip)
    return spec


def idle_alien(t):
    """Zorp studies things: a long, slow tilt of the head, then a slow look across."""
    spec = idle(t)
    tilt = _ease(t, 1.6, 1.0, 1.1, 1.0)
    scan = math.sin(TAU * (t - 5.2) / 3.2) if 5.2 <= t <= 8.4 else 0.0
    _turned(spec, "head", pitch=2.0 * tilt, yaw=12.0 * scan, roll=21.0 * tilt)
    return spec


def idle_cat(t):
    """Whiskers tilts its head, and later flicks it twice, like shaking off a fly."""
    spec = idle(t)
    tilt = _snap(t, 2.0, 0.18, 1.0, 0.3)
    flick = _snap(t, 6.0, 0.06, 0.0, 0.1) + _snap(t, 6.3, 0.06, 0.0, 0.1)
    _turned(spec, "head", roll=14.0 * tilt - 7.0 * flick, yaw=4.0 * flick)
    return spec


def idle_rex(t):
    """Rex sniffs: three short dips of the snout, then lifts its head to look."""
    spec = idle(t)
    sniff = sum(_snap(t, t0, 0.12, 0.0, 0.2) for t0 in (2.0, 2.45, 2.9))
    look = _ease(t, 3.5, 0.5, 0.9, 0.7)
    _turned(spec, "head", pitch=-9.0 * sniff + 10.0 * look)
    return spec


def idle_yeti(t):
    """Yeti is big and slow: its weight sways from foot to foot and its head lolls after it."""
    spec = idle(t)
    sway = math.sin(TAU * t / 4.5)
    late = math.sin(TAU * (t - 0.35) / 4.5)
    _hips(spec, roll=4.0 * sway)
    _turned(spec, "head", pitch=-5.0 * _ease(t, 5.0, 0.9, 0.8, 0.9), roll=-4.0 * late)
    return _steady(spec, t)


def idle_duck(t):
    """Quackers waddles on the spot for a moment, its head bobbing."""
    spec = idle(t)
    on = _ease(t, 1.8, 0.3, 1.9, 0.4)
    side = math.sin(TAU * (t - 1.8) / 0.75) * on
    _hips(spec, roll=5.0 * side)
    _turned(spec, "head", pitch=4.0 * abs(side), roll=-4.0 * side)
    return _steady(spec, t)


def idle_jack(t):
    """Jack's head is loose: it lolls slowly over to one side, then snaps upright."""
    spec = idle(t)
    loll = ease((t - 1.5) / 1.8) if t < 3.9 else max(1.0 - _snap(t, 3.9, 0.14, 0.0, 0.01), 0.0) if t < 4.04 else 0.0
    _turned(spec, "head", pitch=-4.0 * loll, roll=24.0 * loll)
    return spec


def idle_astronaut(t):
    """Cosmo is light on its feet: it drifts up onto its toes, looking up, and sinks back."""
    spec = idle(t)
    up = _ease(t, 1.8, 1.2, 0.9, 1.4)
    _stand(spec, heels=14.0 * up)
    _turned(spec, "head", pitch=10.0 * up)
    return _steady(spec, t, 0.02 * up)


def idle_imp(t):
    """Imp fidgets: it taps one foot, the other, the first again, then sneaks a look each way."""
    spec = idle(t)
    _stand(spec, tap_l=_snap(t, 2.0, 0.07, 0.0, 0.1) + _snap(t, 2.5, 0.07, 0.0, 0.1), tap_r=_snap(t, 2.25, 0.07, 0.0, 0.1))
    a, b = _snap(t, 5.4, 0.1, 0.5, 0.14), _snap(t, 6.3, 0.1, 0.3, 0.16)
    _turned(spec, "head", pitch=-4.0 * (a + b), yaw=-30.0 * a + 20.0 * b)
    return spec


def idle_snowman(t):
    """Frosty rocks gently from side to side, the way a snowman would."""
    spec = idle(t)
    rock = math.sin(TAU * t / 3.0)
    _hips(spec, roll=4.0 * rock)
    _turned(spec, "head", roll=-3.0 * math.sin(TAU * (t - 0.2) / 3.0))
    return _steady(spec, t)


def idle_shark(t):
    """Chomp hunts: its head sweeps slowly from side to side."""
    spec = idle(t)
    sweep = math.sin(TAU * t / 4.5)
    _turned(spec, "head", pitch=-2.0 * abs(sweep), yaw=24.0 * sweep)
    return spec


def idle_ninja(t):
    """Ninja sinks a little lower and checks each side with a sharp turn of the head."""
    spec = idle(t)
    low = _ease(t, 1.5, 0.5, 2.3, 0.6)
    a, b = _snap(t, 2.4, 0.08, 0.5, 0.12), _snap(t, 3.3, 0.08, 0.4, 0.12)
    _turned(spec, "head", yaw=38.0 * a - 38.0 * b)
    return _steady(spec, t, -0.022 * low)


def idle_zombie(t):
    """Zombie's head sinks slowly onto its chest, then jerks back up; it sways as it stands."""
    spec = idle(t)
    droop = ease((t - 1.2) / 2.2) if t < 3.8 else max(1.0 - _snap(t, 3.8, 0.16, 0.0, 0.01), 0.0) if t < 3.96 else 0.0
    sway = math.sin(TAU * t / 4.5)
    _hips(spec, roll=3.0 * sway)
    _turned(spec, "head", pitch=-15.0 * droop, roll=7.0 * droop - 2.0 * sway)
    return _steady(spec, t)


def idle_wizard(t):
    """Wizard nods to himself, twice, slowly, then lifts his head as if a thought had come."""
    spec = idle(t)
    nod = _ease(t, 2.0, 0.35, 0.1, 0.4) + _ease(t, 3.0, 0.35, 0.1, 0.4)
    thought = _ease(t, 5.6, 0.5, 0.9, 0.7)
    _turned(spec, "head", pitch=-8.0 * nod + 6.0 * thought, roll=4.0 * thought)
    return spec


def idle_bear(t):
    """Teddy lumbers on the spot: a slow sway, and a big tilt of the head each way."""
    spec = idle(t)
    sway = math.sin(TAU * t / 4.5)
    a, b = _ease(t, 2.0, 0.5, 0.9, 0.6), _ease(t, 5.4, 0.5, 0.9, 0.6)
    _hips(spec, roll=3.5 * sway)
    _turned(spec, "head", roll=12.0 * (a - b))
    return _steady(spec, t)


def idle_mushroom(t):
    """Shroom is cheerful: two little bounces on its toes, head tipped to one side."""
    spec = idle(t)
    hop = _snap(t, 2.0, 0.14, 0.02, 0.2) + _snap(t, 2.45, 0.14, 0.02, 0.22) * 0.8
    tilt = _ease(t, 1.8, 0.3, 1.2, 0.5)
    _stand(spec, heels=11.0 * hop)
    _turned(spec, "head", roll=10.0 * tilt)
    return _steady(spec, t, 0.016 * hop)


def idle_banana(t):
    """Peel wobbles: a loose shimmy from side to side, its top going the other way."""
    spec = idle(t)
    on = _ease(t, 2.0, 0.4, 2.2, 0.6)
    side = math.sin(TAU * (t - 2.0) / 1.1) * on
    _hips(spec, roll=5.0 * side)
    _turned(spec, "head", roll=-6.0 * side)
    return _steady(spec, t)


IDLES = {"needle": idle_needle, "vanguard": idle_vanguard, "kestrel": idle_kestrel, "bulwark": idle_bulwark,
         "rivet": idle_rivet, "specter": idle_specter, "orbit": idle_orbit, "templar": idle_templar,
         "human": idle_human, "goblin": idle_goblin, "frog": idle_frog, "skeleton": idle_skeleton, "alien": idle_alien,
         "cat": idle_cat, "rex": idle_rex, "yeti": idle_yeti, "duck": idle_duck, "jack": idle_jack,
         "astronaut": idle_astronaut, "imp": idle_imp, "snowman": idle_snowman, "shark": idle_shark, "ninja": idle_ninja,
         "zombie": idle_zombie, "wizard": idle_wizard, "bear": idle_bear, "mushroom": idle_mushroom,
         "banana": idle_banana}   # torso -> its idle


def _bounce(p):
    """How high the hips ride through a running cycle (two steps), -1 to 1 or so: they
    drop quickly as each foot takes the weight and hang a moment at the top of each stride."""
    a = 2 * TAU * (p - 0.14)
    return (math.cos(a) + 0.28 * math.sin(2 * a)) / 1.1


def _run(t, period, lean, bob, stance, front, back, lift, sprint):
    p = (t / period) % 1.0
    c = math.cos(TAU * p)
    s = math.sin(TAU * p)
    nod = _bounce(p - 0.05)   # the head follows the hips a moment late
    spec = {
        # The hips swing with the legs and the chest swings back against them, so the
        # shoulders (and the gun) stay square while the body under them works.
        "hips": {"pos": (0.012 * s, 0.885 - bob * _bounce(p), 0.0), "rot": (lean, -9.0 * c, 3.5 * s)},
        "spine": (-lean * 0.3, 5.0 * c, -1.75 * s), "chest": (-lean * 0.2, 6.0 * c, -1.75 * s),
        "head": (-lean * 0.4 + 1.6 * nod, -2.0 * c, 0.0),
        "leg_l": stride(p, -0.085, stance, front, back, lift, push=-46.0),
        "leg_r": stride(p + 0.5, 0.085, stance, front, back, lift, push=-46.0),
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
    return _run(t, RUN_PERIOD, -11.0, 0.032, 0.30, -0.36, 0.42, 0.33, False)


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
    """Creeping: the hips sink onto each foot as it takes the weight and swing with the
    steps, and the chest swings back against them, so the gun stays level."""
    p = (t / CROUCH_PERIOD) % 1.0
    c = math.cos(TAU * p)
    s = math.sin(TAU * p)
    spec = _low(0.50 - 0.014 * _bounce(p + 0.04))
    spec["hips"]["pos"] = (0.014 * s, spec["hips"]["pos"][1], 0.04)
    spec["hips"]["rot"] = (-26.0, -8.0 * c, 2.5 * s)
    spec["spine"] = (LOW_SPINE[0], 5.0 * c, -1.25 * s)
    spec["chest"] = (LOW_CHEST[0], 3.0 * c, -1.25 * s)
    spec["head"] = (LOW_HEAD[0] + 1.2 * _bounce(p - 0.02), 0.0, 0.0)
    spec["leg_l"] = stride(p, -0.105, 0.5, -0.30, 0.30, 0.15, push=-34.0, pole=(-0.2, 0.0, -1.0))
    spec["leg_r"] = stride(p + 0.5, 0.105, 0.5, -0.30, 0.30, 0.15, push=-34.0, pole=(0.2, 0.0, -1.0))
    return spec


def slide(t):
    """Sliding on one hip, a leg out in front. It is not still: the ground chatters up
    through the hips, the front foot skips, and the head rides it out a beat behind."""
    s = math.sin(TAU * t / 0.8)
    chatter = math.sin(TAU * t / 0.2)          # (four to the loop)
    late = math.sin(TAU * (t - 0.05) / 0.2)
    return {
        "hips": {"pos": (0.03, 0.27 + 0.004 * s + 0.003 * chatter, 0.12), "rot": (34.0 + 0.8 * chatter, 0.0, 6.0 + 1.0 * s)},
        "spine": (-22.0 - 0.5 * chatter, 0.0, -4.0 - 0.5 * s), "chest": (-14.0, 0.0, -2.0 - 0.5 * s), "head": (4.0 - 1.0 * late, 0.0, 0.0),
        "leg_l": foot(-0.11, 0.05 + 0.012 * max(chatter, 0.0), -0.80, pitch=22.0 + 3.0 * chatter, pole=(-0.1, 1.0, -0.3)),
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


LAND_TIME = 0.34   # how long a landing shows (RobotAnimator lays it over the base pose, fading out)


def land(t):
    """A landing, laid over the base pose for a moment: the knees soak it up at once,
    the head drops a beat after the hips, and the body comes back up a little past
    standing (up on its toes) before it settles."""
    def at(hips_y, lean, head, toes, z=0.03):
        return {
            "hips": {"pos": (0.0, hips_y, z), "rot": (lean, 0.0, 0.0)},
            "spine": (lean * 0.27, 0.0, 0.0), "chest": (lean * 0.18, 0.0, 0.0), "head": (head, 0.0, 0.0),
            "leg_l": foot(-0.14, 0.0, -0.18, pitch=toes, pole=(-0.3, 0.0, -1.0)),
            "leg_r": foot(0.14, 0.0, 0.0, pitch=toes, pole=(0.3, 0.0, -1.0)),
            "arm_r": AIM_R, "arm_l": AIM_L,
        }
    return keyed(t, [(0.0, at(0.70, -18.0, 14.0, 0.0)), (0.06, at(0.66, -22.0, 20.0, 0.0)), (0.11, at(0.67, -22.0, 26.0, 0.0)),
                     (0.24, at(0.95, -3.0, 6.0, -12.0, 0.0)), (LAND_TIME, at(0.925, -2.0, 2.0, 0.0, 0.0))])


# ---------------------------------------------------------------------------
# Walls

WALL_PERIOD = 0.42     # matches 10.5 m/s


def wall_run_l(t):
    """Running along a wall on the left: feet on the wall, body leaning away, left hand trailing on it."""
    p = (t / WALL_PERIOD) % 1.0
    c = math.cos(TAU * p)
    return {
        "hips": {"pos": (0.10, 0.90 - 0.022 * _bounce(p), 0.0), "rot": (-10.0, -8.0 * c, -24.0 + 2.0 * math.sin(TAU * p))},
        "spine": (3.0, 5.0 * c, 9.0), "chest": (3.0, 6.0 * c, 7.0), "head": (3.0 + 1.4 * _bounce(p - 0.05), -3.0 * c, 8.0),
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
    spent = merged(push, hips={"pos": (0.0, 0.96, 0.0), "rot": (-4.0, 0.0, -11.0)},   # the kicking leg lets go and trails
                   leg_l={"ik": (-0.40, 0.42, 0.10), "space": "model", "pole": (0.3, 0.5, -1.0), "foot": (-20.0, 0.0, -35.0)})
    return keyed(t, [(0.0, coil), (0.09, push, "out"), (0.3, spent)])


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
                 spine=(-2.0, 3.0, 2.0), chest=(-2.0, 3.0, 2.0), head=(8.0, 0.0, 0.0),   # (the chest and head come round last)
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
    over = merged(press, hips={"pos": (0.0, 0.94, 0.0), "rot": (-29.0, 0.0, 0.0)}, head=(23.0, 0.0, 0.0))   # tips a little past, then settles
    return keyed(t, [(0.0, hang), (0.24, pull), (0.42, over, "out"), (0.5, press)])


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
        "hips": {"pos": (0.0, 0.60, 0.20), "rot": (-80.0, 0.0, 1.5 * s)},
        "spine": (6.0, 0.0, -0.75 * s), "chest": (8.0, 0.0, -0.75 * s), "head": (52.0, 0.0, 0.0),
        "leg_l": fk_leg(-12.0 + 6.0 * s, 12.0 - 5.0 * s, foot_pitch=-55.0), "leg_r": fk_leg(-2.0 - 6.0 * s, 30.0 + 5.0 * s, foot_pitch=-55.0),
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


# A flip turns once in 0.45 s: it speeds up over the first 0.10 s, turns steadily, and
# slows over the last 0.11 s to spot the landing. These are how far it has turned at
# the ends of those two, for the speed to be the same either side of each key.
SPIN_IN = 52.2
SPIN_OUT = 57.4


def flip_front(t):
    return keyed(t, [
        (0.0, _tuck(0.0, 0.96, 0.0, thigh=30.0, knee=40.0, spine=-4.0, chest=-4.0, head=0.0, arm=40.0, elbow=80.0)),
        (0.10, _tuck(-SPIN_IN, 0.96, 0.0), "in"),
        (0.34, _tuck(-360.0 + SPIN_OUT, 0.96, 0.0), "linear"),
        (0.45, _tuck(-360.0, 0.96, 0.0, thigh=28.0, knee=36.0, spine=-2.0, chest=-2.0, head=4.0, arm=40.0, elbow=80.0), "out"),
    ])


def flip_back(t):
    return keyed(t, [
        (0.0, _tuck(0.0, 0.96, 0.0, thigh=34.0, knee=44.0, spine=6.0, chest=6.0, head=-10.0, arm=70.0, elbow=60.0)),
        (0.10, _tuck(SPIN_IN, 0.96, 0.0, head=-8.0), "in"),
        (0.34, _tuck(360.0 - SPIN_OUT, 0.96, 0.0, head=-8.0), "linear"),
        (0.45, _tuck(360.0, 0.96, 0.0, thigh=28.0, knee=36.0, spine=-2.0, chest=-2.0, head=4.0, arm=40.0, elbow=80.0), "out"),
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
        (0.10, _aerial(SPIN_IN, 38.0, 30.0, 70.0), "in"),
        (0.34, _aerial(360.0 - SPIN_OUT, 38.0, 30.0, 70.0), "linear"),
        (0.45, _aerial(360.0, 6.0, 36.0, 20.0), "out"),
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
    r, l = limp(124.0, 46.0, 54.0)
    bounce = merged(flat, hips={"pos": (0.0, 0.15, -0.30), "rot": (-87.0, 12.0, 8.0)}, head=(-14.0, 32.0, 0.0), arm_r=r, arm_l=l,
                    leg_l=fk_leg(-9.0, 36.0, roll=-8.0, foot_pitch=-50.0))   # the frame hits the floor, comes up off it once, and lies still
    return keyed(t, [(0.0, stand), (0.10, jolt, "out"), (0.45, knees, "in"), (0.85, fall, "in"), (0.96, flat, "in"),
                     (1.05, bounce, "out"), (1.16, flat, "in"), (1.3, flat)])


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
        Clip("land", LAND_TIME, land, fps=60),
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
    ] + [Clip("idle_" + torso, QUIRK_PERIOD, fn, loop=True, fps=24, lean=True) for torso, fn in IDLES.items()] + view_clips() + hand_clips()


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
