"""Animation clips for the long guns: the shotgun, the assault rifle and the sniper rifle.
(The pistol's are in animations.py; it is the default, so its clips have plain names.)

Each long gun has its own version of every clip in which the hands hold the gun,
named "<clip>_<gun>" ("aim_rifle", "fp_reload_sniper"). The game uses that version
when the player holds that gun, and the plain clip otherwise. The body clips (run,
slide, flips...) are shared: the game lays the gun's "aim" over the arms.

How a long gun is held: the right fist on the grip, the stock tucked in by the right
shoulder, and the left fist on the gun's support point (weapons.SUPPORT), solved by
the rig's "grip" so it stays on the gun whatever the gun does: on the shotgun it
rides the pump. The chest turns a little to the right (a bladed stance) to bring the
left shoulder forward, since a robot's arms are not long enough to reach a rifle's
handguard square-on. The game turns the chest by the aim clip's twist too.

New clips per gun:
  body:  aim (gun up), carry (sprinting: gun across the chest), reload, fire (the
         shotgun's pump, the sniper's bolt), respawn
  arms:  fp_idle, fp_one_hand, fp_sprint, fp_slide, fp_wall_l, fp_wall_r, fp_dive,
         fp_tuck, fp_mantle, fp_raise, fp_reload, fp_fire (shotgun, sniper)
The shotgun reloads a shell at a time: its reload clips are one shell, looped.
"""
import numpy as np
from m3 import euler
from rig import Clip, FIST, keyed, merged
import animations as A
from weapons import SUPPORT

LONG = ("shotgun", "rifle", "sniper")

# Third person, model space (the robot stands at the origin, facing -Z): where the
# right fist holds the grip, and how far the chest turns to the right.
HOLD = {
    "shotgun": {"grip": (0.10, 1.42, -0.27), "twist": -32.0},
    "rifle": {"grip": (0.10, 1.42, -0.30), "twist": -30.0},
    "sniper": {"grip": (0.10, 1.43, -0.27), "twist": -32.0},
}
# First person, relative to the camera.
FP_HOLD = {
    "shotgun": {"grip": (0.170, -0.275, -0.34), "twist": -24.0},
    "rifle": {"grip": (0.170, -0.265, -0.35), "twist": -22.0},
    "sniper": {"grip": (0.175, -0.272, -0.34), "twist": -24.0},
}
# First person only: the shoulders sit lower and further forward than the body's, so the
# arms come up into view from below instead of across it (only the arms are drawn).
FP_HIPS = (0.0, 0.86, -0.09)
EYE_Y = A.EYE[1]

# Reload lengths match WeaponData (the shotgun's is one shell; it loops).
RELOAD = {"shotgun": 0.5, "rifle": 1.9, "sniper": 2.4}
FIRE = {"shotgun": 0.6, "sniper": 1.1}
POLE_R = (0.7, -1.0, 0.1)
POLE_L = (-0.6, -1.0, 0.2)


def right(grip, hand=(90.0, 0.0, 0.0), cant=0.0):
    """The right arm with its fist on the grip at `grip` (model space). hand: the fist's
    turn ((90, 0, 0) points the gun straight ahead); cant rolls the gun about its barrel."""
    wrist = np.array(grip, dtype=float) + euler(hand) @ np.array([0.0, FIST, 0.0])
    return {"ik": tuple(float(x) for x in wrist), "space": "model", "pole": POLE_R, "hand": hand, "cant": cant}


def fp_right(x, y, z, hand=(90.0, 0.0, 0.0), cant=0.0):
    return right((x, y + EYE_Y, z), hand, cant)


def support(gun, **extra):
    """The left fist on the gun's support point (the pump, the handguard)."""
    s = SUPPORT[gun]
    out = {"grip": s["grip"], "on": s.get("on", "pistol"), "pole": POLE_L}
    out.update(extra)
    return out


def on_gun(point, on="pistol", **extra):
    out = {"grip": point, "on": on, "pole": POLE_L}
    out.update(extra)
    return out


def _add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def _base(gun, fp):
    h = (FP_HOLD if fp else HOLD)[gun]
    grip = _add(h["grip"], (0.0, EYE_Y, 0.0)) if fp else h["grip"]
    return grip, h["twist"]


def _pose(twist, arm_r, arm_l, **more):
    spec = {"chest": (0.0, twist, 0.0), "arm_r": arm_r, "arm_l": arm_l,
            "slide": 0.0, "slide_turn": 0.0, "slide_axis": 0.06, "mag": (0.0, 0.0, 0.0), "mag_rot": (0.0, 0.0, 0.0)}
    spec.update(more)
    return spec


def held(gun, fp=False, offset=(0.0, 0.0, 0.0), hand=(90.0, 0.0, 0.0), cant=0.0, left=None, **more):
    """The gun up in both hands (or in the right only, when `left` is given)."""
    grip, twist = _base(gun, fp)
    if fp:
        more.setdefault("hips", {"pos": FP_HIPS, "rot": (0.0, 0.0, 0.0)})
    return _pose(twist, right(_add(grip, offset), hand, cant), left if left is not None else support(gun), **more)


# ---------------------------------------------------------------------------
# Body (third person)

def aim(gun):
    return lambda t: held(gun)


def carry(gun):
    """Sprinting: the gun across the chest, muzzle up and to the left."""
    def fn(t):
        spec = _pose(0.0, right((0.13, 1.16, -0.25), hand=(122.0, 38.0, 0.0), cant=-20.0), support(gun))
        return spec
    return fn


def _away_body():
    return {"ik": (-0.20, 0.98, -0.08), "space": "model", "pole": (-0.6, -0.3, 1.0), "hand": (30.0, 0.0, 0.0)}


def _away_fp():
    return {"ik": (-0.06, EYE_Y - 0.55, -0.16), "space": "model", "pole": (-0.6, -0.3, 1.0), "hand": (30.0, 0.0, 0.0)}


def reload_clip(gun, fp):
    away = _away_fp() if fp else _away_body()
    rest = held(gun, fp)
    tilt = held(gun, fp, offset=(-0.02, 0.02, 0.04), hand=(98.0, 12.0, 0.0), cant=32.0)
    if gun == "shotgun":
        return _shotgun_reload(rest, tilt)
    mag_hold = (0.0, -0.09, -0.10)          # the left fist on the magazine
    start = dict(tilt)
    keys = [(0.0, rest)]

    def k(t, base, left, ease="smooth", **more):
        spec = dict(base)
        spec["arm_l"] = left
        spec.update(more)
        keys.append((t, spec, ease))

    k(0.18, tilt, on_gun(mag_hold, "pistol_mag"))
    k(0.30, tilt, on_gun(mag_hold, "pistol_mag"), mag=(0.0, -0.03, 0.01))
    k(0.48, tilt, away, "in", mag=(0.0, -0.75, 0.06))
    k(0.80, tilt, on_gun(mag_hold, "pistol_mag"), "linear", mag=(0.0, -0.20, 0.06))
    k(1.02, tilt, on_gun(mag_hold, "pistol_mag"), "out", mag=(0.0, -0.04, 0.01))
    k(1.12, tilt, on_gun(mag_hold, "pistol_mag"), "in")
    if gun == "rifle":
        handle = (-0.06, 0.07, -0.13)
        k(1.32, rest, on_gun(handle, "pistol_slide"))
        k(1.44, rest, on_gun(handle, "pistol_slide"), "out", slide=0.075)
        k(1.52, rest, on_gun(handle, "pistol_slide"), "in")
        k(1.74, rest, support(gun))
        k(1.90, rest, support(gun))
    else:
        bolt = (-0.088, 0.06, -0.02)
        k(1.40, rest, on_gun(bolt, "pistol_slide"))
        k(1.55, rest, on_gun(bolt, "pistol_slide"), "out", slide_turn=-70.0)
        k(1.75, rest, on_gun(bolt, "pistol_slide"), "out", slide_turn=-70.0, slide=0.09)
        k(1.92, rest, on_gun(bolt, "pistol_slide"), "in", slide_turn=-70.0)
        k(2.02, rest, on_gun(bolt, "pistol_slide"), "in")
        k(2.24, rest, support(gun))
        k(2.40, rest, support(gun))
    del start
    return lambda t: keyed(t, keys)


def _shotgun_reload(rest, tilt):
    """One shell: from the belt, up under the gun, pushed into the loading port. Loops."""
    shell = (0.0, 0.05, -0.045)              # the middle of the shell, at rest (inside the receiver)
    start_off = (-0.05, -0.30, 0.06)         # where a new shell comes from (gun space)
    start_pt = _add(shell, start_off)
    port_off = (0.0, -0.055, 0.005)
    keys = [
        (0.0, dict(tilt, arm_l=on_gun(shell, "pistol_mag"), mag=start_off)),
        (0.20, dict(tilt, arm_l=on_gun(shell, "pistol_mag"), mag=port_off), "out"),
        (0.30, dict(tilt, arm_l=on_gun(shell, "pistol_mag"), mag=(0.0, 0.0, 0.0)), "in"),
        (0.36, dict(tilt, arm_l=on_gun(_add(shell, (0.0, -0.05, 0.0)))), "out"),
        (0.50, dict(tilt, arm_l=on_gun(start_pt)), "smooth"),
    ]
    return lambda t: keyed(t, keys)


def fire_clip(gun, fp):
    rest = held(gun, fp)
    dip = held(gun, fp, offset=(0.0, -0.015, 0.02), hand=(86.0, 3.0, 0.0), cant=-6.0)
    if gun == "shotgun":
        return lambda t: keyed(t, [
            (0.0, rest), (0.10, rest),
            (0.24, dict(dip, slide=0.08), "out"),
            (0.38, dict(rest, slide=0.0), "in"),
            (0.60, rest),
        ])
    bolt = (-0.088, 0.06, -0.02)
    work = held(gun, fp, offset=(0.0, 0.0, 0.02), hand=(92.0, -4.0, 0.0), cant=14.0)

    def at_bolt(**more):
        return dict(work, arm_l=on_gun(bolt, "pistol_slide"), **more)
    return lambda t: keyed(t, [
        (0.0, rest), (0.12, rest),
        (0.32, at_bolt()),
        (0.42, at_bolt(slide_turn=-70.0), "out"),
        (0.56, at_bolt(slide_turn=-70.0, slide=0.09), "out"),
        (0.70, at_bolt(slide_turn=-70.0), "in"),
        (0.78, at_bolt(), "in"),
        (0.98, rest),
        (1.10, rest),
    ])


def respawn(gun):
    """Boot-up: kneeling with the head down, then up to ready, gun in both hands."""
    idle = A.idle(0.0)
    ready = merged(idle, chest=(idle["chest"][0], idle["chest"][1] + HOLD[gun]["twist"], 0.0),
                   arm_r=held(gun)["arm_r"], arm_l=support(gun))
    kneel = merged(A.crouch_idle(0.0), chest=A.LOW_CHEST, head=(-28.0, 0.0, 0.0),
                   arm_r=right((0.12, 0.80, -0.30), hand=(30.0, 10.0, 0.0)), arm_l=support(gun))
    return lambda t: keyed(t, [(0.0, kneel), (0.15, kneel), (0.6, ready, "out")])


def body_clips():
    out = []
    for gun in LONG:
        out += [
            Clip("aim_" + gun, 1 / 30, aim(gun)),
            Clip("carry_" + gun, 1 / 30, carry(gun)),
            Clip("reload_" + gun, RELOAD[gun], reload_clip(gun, False), loop=gun == "shotgun"),
            Clip("respawn_" + gun, 0.6, respawn(gun)),
        ]
        if gun in FIRE:
            out.append(Clip("fire_" + gun, FIRE[gun], fire_clip(gun, False)))
    return out


# ---------------------------------------------------------------------------
# First-person arms

def fp_clips_for(gun):
    def fp(offset=(0.0, 0.0, 0.0), **kw):
        return held(gun, True, offset=offset, **kw)

    away_l = A.FP_L_AWAY
    one = dict(offset=(0.025, -0.03, 0.01), cant=-8.0, left=away_l)
    idle = fp()
    clips = {
        "fp_idle": lambda t: idle,
        "fp_one_hand": lambda t: fp(**one),
        "fp_sprint": lambda t: fp(offset=(-0.05, -0.06, 0.02), hand=(80.0, 32.0, 0.0), cant=-30.0),
        "fp_slide": lambda t: fp(offset=(0.02, 0.0, 0.0), cant=-20.0, left=A.fp_slide(0)["arm_l"]),
        "fp_wall_l": lambda t: fp(offset=(0.03, -0.01, 0.0), cant=10.0, left=A.fp_wall_l(0)["arm_l"]),
        "fp_wall_r": lambda t: fp(offset=(0.01, -0.01, 0.01), cant=-14.0),
        "fp_dive": lambda t: fp(offset=(-0.02, 0.03, -0.04)),
        "fp_tuck": lambda t: fp(offset=(-0.01, -0.10, 0.07), hand=(100.0, 12.0, 0.0)),
    }
    reach = fp(offset=(0.08, -0.12, 0.03), hand=(70.0, -8.0, 0.0), cant=-30.0, left=A.fp_mantle(0)["arm_l"])
    push = fp(offset=(0.10, -0.26, 0.08), hand=(64.0, -8.0, 0.0), cant=-35.0, left=A.fp_mantle(0.45)["arm_l"])
    clips["fp_mantle"] = lambda t: keyed(t, [(0.0, reach), (0.08, reach), (0.34, push, "in"), (0.45, push)])
    down = fp(offset=(0.0, -0.20, 0.08), hand=(62.0, 18.0, 0.0))
    clips["fp_raise"] = lambda t: keyed(t, [(0.0, down), (0.1, down), (0.4, idle, "out")])
    out = []
    for name, fn in clips.items():
        length = {"fp_mantle": 0.45, "fp_raise": 0.4}.get(name, 1 / 30)
        out.append(Clip("%s_%s" % (name, gun), length, fn))
    out.append(Clip("fp_reload_" + gun, RELOAD[gun], reload_clip(gun, True), loop=gun == "shotgun"))
    if gun in FIRE:
        out.append(Clip("fp_fire_" + gun, FIRE[gun], fire_clip(gun, True)))
    return out


def arms_clips():
    out = []
    for gun in LONG:
        out += fp_clips_for(gun)
    return out
