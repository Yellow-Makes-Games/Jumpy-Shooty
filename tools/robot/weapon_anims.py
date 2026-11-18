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

LONG = ("shotgun", "rifle", "sniper", "break_action", "smg", "burst_rifle", "lmg", "lever_action",
        "bolt_action", "railgun", "rocket_launcher", "grenade_launcher",
        "auto_shotgun", "slug_shotgun", "air_cannon", "minigun", "battle_rifle", "laser_rifle", "nail_gun",
        "crossbow", "anti_materiel", "harpoon_gun", "mortar", "plasma_cannon")
# Sidearms held like the pistol: they keep its poses but have their own reloads.
SIDEARMS = ("revolver", "machine_pistol", "derringer", "flare_gun", "plasma_pistol")

# How each long gun is held, reloaded and worked after a shot.
#   hold: whose hold it copies; reload: mag (drop the magazine, with "handle": charge or
#   bolt after), shell (a shell at a time into the tube, looped), break (tip the barrels
#   open), cover (lift the top cover, swap the box), gate (a round into the side gate,
#   looped), top (a round in through the open bolt, looped), cell (swap the power cell),
#   rocket (a new rocket in at the back), drum (a grenade into the drum, looped);
#   fire: pump, bolt, lever, vent (the railgun's sleeve snaps back).
SPEC = {
    "shotgun": {"hold": "shotgun", "reload": "shell", "fire": "pump"},
    "rifle": {"hold": "rifle", "reload": "mag", "handle": "charge", "handle_at": (-0.06, 0.07, -0.13)},
    "sniper": {"hold": "sniper", "reload": "mag", "handle": "bolt", "fire": "bolt", "bolt": (-0.088, 0.06, -0.02)},
    "break_action": {"hold": "shotgun", "reload": "break"},
    "smg": {"hold": "rifle", "reload": "mag", "handle": "charge", "handle_at": (-0.03, 0.07, -0.10), "mag_hold": (0.0, -0.10, -0.085)},
    "burst_rifle": {"hold": "rifle", "reload": "mag", "handle": "charge", "handle_at": (-0.034, 0.075, 0.02), "mag_hold": (0.0, -0.08, -0.10)},
    "lmg": {"hold": "rifle", "reload": "cover", "mag_hold": (0.0, -0.05, -0.12)},
    "lever_action": {"hold": "rifle", "reload": "gate", "fire": "lever"},
    "bolt_action": {"hold": "sniper", "reload": "top", "fire": "bolt", "bolt": (-0.08, 0.06, -0.01)},
    "railgun": {"hold": "sniper", "reload": "cell", "fire": "vent", "mag_hold": (0.0, -0.005, 0.105)},
    "rocket_launcher": {"hold": "rocket_launcher", "reload": "rocket"},
    "grenade_launcher": {"hold": "shotgun", "reload": "drum"},
    # The third batch (each copies a hold and a way of reloading from the guns above)
    "auto_shotgun": {"hold": "shotgun", "reload": "mag", "handle": "charge", "handle_at": (-0.032, 0.07, -0.10),
                     "mag_hold": (0.0, -0.07, -0.12)},
    "slug_shotgun": {"hold": "shotgun", "reload": "shell", "fire": "pump"},
    "air_cannon": {"hold": "shotgun", "reload": "cell", "mag_hold": (0.0, 0.0, -0.16)},
    "minigun": {"hold": "rifle", "reload": "cover", "mag_hold": (0.0, -0.05, -0.12)},
    "battle_rifle": {"hold": "rifle", "reload": "mag", "handle": "charge", "handle_at": (-0.035, 0.07, -0.12)},
    "laser_rifle": {"hold": "rifle", "reload": "cell", "mag_hold": (0.0, -0.005, 0.105)},
    "nail_gun": {"hold": "rifle", "reload": "mag", "mag_hold": (0.0, -0.035, -0.17)},
    "crossbow": {"hold": "rifle", "reload": "top"},
    "anti_materiel": {"hold": "sniper", "reload": "mag", "handle": "bolt", "fire": "bolt", "bolt": (-0.092, 0.065, -0.02),
                      "mag_hold": (0.0, -0.03, -0.12)},
    "harpoon_gun": {"hold": "rifle", "reload": "rocket", "grab": (0.0, 0.065, -0.45)},
    "mortar": {"hold": "rocket_launcher", "reload": "rocket", "grab": (0.0, 0.115, -0.45)},
    "plasma_cannon": {"hold": "shotgun", "reload": "cell", "mag_hold": (0.0, -0.005, 0.11)},
}

# Third person, model space (the robot stands at the origin, facing -Z): where the
# right fist holds the grip, and how far the chest turns to the right.
HOLD = {
    "shotgun": {"grip": (0.10, 1.42, -0.27), "twist": -32.0},
    "rifle": {"grip": (0.10, 1.42, -0.30), "twist": -30.0},
    "sniper": {"grip": (0.10, 1.43, -0.27), "twist": -32.0},
    "rocket_launcher": {"grip": (0.10, 1.36, -0.25), "twist": -26.0},
}
# First person, relative to the camera.
FP_HOLD = {
    "shotgun": {"grip": (0.170, -0.275, -0.34), "twist": -24.0},
    "rifle": {"grip": (0.170, -0.265, -0.35), "twist": -22.0},
    "sniper": {"grip": (0.175, -0.272, -0.34), "twist": -24.0},
    "rocket_launcher": {"grip": (0.175, -0.31, -0.33), "twist": -20.0},
}
for _g in LONG:
    HOLD.setdefault(_g, HOLD[SPEC[_g]["hold"]])
    FP_HOLD.setdefault(_g, FP_HOLD[SPEC[_g]["hold"]])
# First person only: the shoulders sit lower and further forward than the body's, so the
# arms come up into view from below instead of across it (only the arms are drawn).
FP_HIPS = (0.0, 0.86, -0.09)
EYE_Y = A.EYE[1]

# Reload lengths match WeaponData (the shotgun's is one shell; it loops).
RELOAD = {"shotgun": 0.5, "rifle": 1.9, "sniper": 2.4, "break_action": 1.7, "smg": 1.6, "burst_rifle": 2.0,
          "lmg": 3.6, "lever_action": 0.45, "bolt_action": 0.5, "railgun": 2.6, "rocket_launcher": 1.5,
          "grenade_launcher": 0.55, "revolver": 2.0, "machine_pistol": 1.4,
          "derringer": 1.4, "flare_gun": 1.1, "plasma_pistol": 2.0, "auto_shotgun": 2.6, "slug_shotgun": 0.55,
          "air_cannon": 1.8, "minigun": 4.5, "battle_rifle": 2.1, "laser_rifle": 2.5, "nail_gun": 2.0, "crossbow": 1.3,
          "anti_materiel": 3.2, "harpoon_gun": 1.2, "mortar": 1.8, "plasma_cannon": 2.4}
FIRE = {"shotgun": 0.6, "sniper": 1.1, "lever_action": 0.66, "bolt_action": 0.95, "railgun": 0.5,
        "slug_shotgun": 0.7, "anti_materiel": 1.8}
LOOPED = ("shotgun", "lever_action", "bolt_action", "grenade_launcher", "slug_shotgun")   # a round at a time
# The left hand under a fore-end: palm up, the fingers across under the gun and up its
# right side (the fist's turn, relative to the gun's). A gun held by an upright handle
# (weapons.SUPPORT: "upright") is held as the forearm comes, like a second grip.
CUPPED = (-90.0, 0.0, 90.0)
UPRIGHT = (0.0, 0.0, 0.0)      # ...the left fist turned as the right one is on the grip, the wrist behind the handle
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
    out["hand"] = UPRIGHT if s.get("upright") else CUPPED
    if s.get("upright"):
        out["fingers"] = "foregrip"
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
    spec = SPEC[gun]
    style = spec["reload"]
    if style == "shell":
        return _shotgun_reload(rest, tilt)
    if style in NEW_RELOADS:
        return NEW_RELOADS[style](gun, fp, rest, tilt, away)
    mag_hold = spec.get("mag_hold", (0.0, -0.09, -0.10))   # the left fist on the magazine
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
    if spec.get("handle") == "charge":
        handle = spec["handle_at"]
        k(1.32, rest, on_gun(handle, "pistol_slide"))
        k(1.44, rest, on_gun(handle, "pistol_slide"), "out", slide=0.075)
        k(1.52, rest, on_gun(handle, "pistol_slide"), "in")
        k(1.74, rest, support(gun))
        k(1.90, rest, support(gun))
    elif spec.get("handle") is None:
        k(1.32, rest, support(gun))
        k(1.45, rest, support(gun))
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
    return _scaled(keys, RELOAD[gun])


def _scaled(keys, length):
    """Keys stretched (or squeezed) to `length` seconds."""
    k = length / keys[-1][0]
    keys = [(key[0] * k,) + tuple(key[1:]) for key in keys]
    return lambda t: keyed(t, keys)


def _hinge(rot, pivot):
    """mag / mag_rot that turn the magazine-bone part by `rot` (pitch, yaw, roll) about `pivot` (gun space)."""
    p = np.array(pivot, dtype=float)
    off = p - euler(rot) @ p
    return {"mag_rot": tuple(float(x) for x in rot), "mag": tuple(float(x) for x in off)}


def _break_reload(gun, fp, rest, tilt, away):
    """Break-action: thumb the lever, tip the barrels down on their hinge (the left hand
    on the fore-end pushes them), two shells into the breech, snap it shut."""
    hinge = (0.0, 0.045, -0.13)
    fore = SUPPORT[gun]["grip"]
    breech = (0.0, 0.066, -0.14)
    lift = held(gun, fp, offset=(-0.01, 0.04, 0.05), hand=(104.0, 10.0, 0.0), cant=18.0)
    shut = _hinge((0.0, 0.0, 0.0), hinge)
    opened = _hinge((-34.0, 0.0, 0.0), hinge)
    keys = [(0.0, dict(rest, **shut))]
    for t, base, left, opn, ease in [
        (0.18, lift, on_gun(fore, "pistol_mag"), False, "smooth"),
        (0.36, lift, on_gun(fore, "pistol_mag"), True, "out"),
        (0.62, tilt, away, True, "in"),
        (0.92, tilt, on_gun(breech), True, "out"),
        (1.02, tilt, on_gun(_add(breech, (0.0, -0.01, 0.02))), True, "in"),
        (1.22, lift, on_gun(fore, "pistol_mag"), True, "smooth"),
        (1.38, lift, on_gun(fore, "pistol_mag"), False, "in"),
        (1.70, rest, on_gun(fore, "pistol_mag"), False, "smooth"),
    ]:
        spec = dict(base, arm_l=left)
        spec.update(opened if opn else shut)
        keys.append((t, spec, ease))
    return _scaled(keys, RELOAD[gun])


def _cover_reload(gun, fp, rest, tilt, away):
    """LMG: lift the top cover, drop the empty box, hang a new one and slam the cover."""
    cover = {"slide_pivot": (0.095, 0.16)}
    lid = (0.0, 0.10, -0.02)
    box_at = SPEC[gun]["mag_hold"]

    def k(t, base, left, ease="smooth", pitch=0.0, **more):
        spec = dict(base, arm_l=left, slide_pitch=pitch, **cover)
        spec.update(more)
        return (t, spec, ease)
    keys = [
        k(0.0, rest, support(gun)),
        k(0.30, tilt, on_gun(lid, "pistol_slide")),
        k(0.55, tilt, on_gun(lid, "pistol_slide"), "out", pitch=-62.0),
        k(0.80, tilt, on_gun(box_at, "pistol_mag"), pitch=-62.0),
        k(0.95, tilt, on_gun(box_at, "pistol_mag"), pitch=-62.0, mag=(0.0, -0.04, 0.0)),
        k(1.30, tilt, away, "in", pitch=-62.0, mag=(0.0, -0.8, 0.05)),
        k(1.90, tilt, on_gun(box_at, "pistol_mag"), "linear", pitch=-62.0, mag=(0.0, -0.25, 0.05)),
        k(2.25, tilt, on_gun(box_at, "pistol_mag"), "out", pitch=-62.0, mag=(0.0, 0.0, 0.0)),
        k(2.55, tilt, on_gun(lid, "pistol_slide"), pitch=-62.0),
        k(2.85, tilt, on_gun(lid, "pistol_slide"), "in", pitch=0.0),
        k(3.05, rest, on_gun(lid, "pistol_slide")),
        k(3.35, rest, support(gun)),
        k(3.60, rest, support(gun)),
    ]
    return _scaled(keys, RELOAD[gun])


def _gate_reload(gun, fp, rest, tilt, away):
    """Lever-action: a round from the belt, pushed into the loading gate. Loops."""
    rnd = (0.0, 0.055, -0.04)
    start_off = (-0.06, -0.28, 0.06)
    gate_off = (-0.03, -0.01, -0.02)
    side = held(gun, fp, offset=(-0.02, 0.02, 0.04), hand=(96.0, 18.0, 0.0), cant=-24.0)
    keys = [
        (0.0, dict(side, arm_l=on_gun(rnd, "pistol_mag"), mag=start_off)),
        (0.20, dict(side, arm_l=on_gun(rnd, "pistol_mag"), mag=gate_off), "out"),
        (0.30, dict(side, arm_l=on_gun(rnd, "pistol_mag"), mag=(0.0, 0.0, 0.0)), "in"),
        (0.45, dict(side, arm_l=on_gun(_add(rnd, start_off))), "smooth"),
    ]
    return _scaled(keys, RELOAD[gun])


def _top_reload(gun, fp, rest, tilt, away):
    """Bolt-action: bolt open, a round pressed down into the action from above. Loops."""
    bolt_open = {"slide_turn": -70.0, "slide": 0.09}
    top = (0.0, 0.09, -0.06)
    above = _add(top, (-0.03, 0.10, 0.04))
    work = dict(tilt, **bolt_open)
    keys = [
        (0.0, dict(work, arm_l=on_gun(above))),
        (0.22, dict(work, arm_l=on_gun(top)), "out"),
        (0.30, dict(work, arm_l=on_gun(_add(top, (0.0, -0.02, 0.0)))), "in"),
        (0.50, dict(work, arm_l=on_gun(above)), "smooth"),
    ]
    return _scaled(keys, RELOAD[gun])


def _cell_reload(gun, fp, rest, tilt, away):
    """Railgun: pop the spent power cell out of the back, slot in a fresh one."""
    cell = SPEC[gun]["mag_hold"]

    def k(t, base, left, ease="smooth", **more):
        return (t, dict(base, arm_l=left, **more), ease)
    keys = [
        k(0.0, rest, support(gun)),
        k(0.35, tilt, on_gun(cell, "pistol_mag")),
        k(0.55, tilt, on_gun(cell, "pistol_mag"), "out", mag=(0.0, -0.03, 0.03)),
        k(0.85, tilt, away, "in", mag=(0.0, -0.8, 0.1)),
        k(1.45, tilt, on_gun(cell, "pistol_mag"), "linear", mag=(0.0, -0.22, 0.08)),
        k(1.80, tilt, on_gun(cell, "pistol_mag"), "out", mag=(0.0, 0.0, 0.0)),
        k(1.95, tilt, on_gun(cell, "pistol_mag"), "in"),
        k(2.30, rest, support(gun)),
        k(2.60, rest, support(gun)),
    ]
    return _scaled(keys, RELOAD[gun])


def _rocket_reload(gun, fp, rest, tilt, away):
    """Rocket launcher: a new rocket from the hip, up behind the shoulder and slid into the back of the tube."""
    grab = SPEC[gun].get("grab", (0.0, 0.115, -0.36))   # a point on the rocket's body
    low = (-0.04, -0.36, 0.10)
    behind = (0.0, -0.02, 0.22)
    lift = held(gun, fp, offset=(0.0, 0.02, 0.0), hand=(96.0, 6.0, 0.0), cant=12.0)

    def k(t, base, left, ease="smooth", **more):
        return (t, dict(base, arm_l=left, **more), ease)
    keys = [
        k(0.0, rest, away, mag=low),
        k(0.30, lift, on_gun(grab, "pistol_mag"), "out", mag=low),
        k(0.70, lift, on_gun(grab, "pistol_mag"), "smooth", mag=behind),
        k(1.05, lift, on_gun(grab, "pistol_mag"), "in", mag=(0.0, 0.0, 0.0)),
        k(1.25, rest, support(gun), "smooth"),
        k(1.50, rest, support(gun)),
    ]
    return _scaled(keys, RELOAD[gun])


def _drum_reload(gun, fp, rest, tilt, away):
    """Grenade launcher: a grenade pushed into the front of the drum, which turns one chamber. Loops."""
    face = (0.03, 0.07, -0.27)
    start = _add(face, (-0.08, -0.26, 0.10))
    keys = [
        (0.0, dict(tilt, arm_l=on_gun(start), mag_rot=(0.0, 0.0, 0.0))),
        (0.24, dict(tilt, arm_l=on_gun(face), mag_rot=(0.0, 0.0, 0.0)), "out"),
        (0.32, dict(tilt, arm_l=on_gun(_add(face, (0.0, 0.0, 0.03))), mag_rot=(0.0, 0.0, 0.0)), "in"),
        (0.44, dict(tilt, arm_l=on_gun(face), mag_rot=(0.0, 0.0, 60.0)), "out"),
        (0.55, dict(tilt, arm_l=on_gun(start), mag_rot=(0.0, 0.0, 60.0)), "smooth"),
    ]
    for i, key in enumerate(keys):   # the drum turns about its own axis, not the grip
        spec = dict(key[1])
        spec.update(_hinge(spec["mag_rot"], (0.0, 0.07, 0.0)))
        keys[i] = (key[0], spec) + tuple(key[2:])
    return lambda t: keyed(t, keys)


NEW_RELOADS = {"break": _break_reload, "cover": _cover_reload, "gate": _gate_reload, "top": _top_reload,
               "cell": _cell_reload, "rocket": _rocket_reload, "drum": _drum_reload}


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
    style = SPEC[gun].get("fire")
    if style == "pump":
        return lambda t: keyed(t, [
            (0.0, rest), (0.10, rest),
            (0.24, dict(dip, slide=0.08), "out"),
            (0.38, dict(rest, slide=0.0), "in"),
            (0.60, rest),
        ])
    if style == "lever":
        pin = {"slide_pivot": (-0.012, 0.065)}
        flick = held(gun, fp, offset=(0.0, -0.01, 0.015), hand=(84.0, 0.0, 0.0), cant=-4.0)
        return lambda t: keyed(t, [
            (0.0, dict(rest, slide_pitch=0.0, **pin)), (0.08, dict(rest, slide_pitch=0.0, **pin)),
            (0.22, dict(flick, slide_pitch=48.0, **pin), "out"),
            (0.38, dict(rest, slide_pitch=0.0, **pin), "in"),
            (0.66, dict(rest, slide_pitch=0.0, **pin)),
        ])
    if style == "vent":
        return lambda t: keyed(t, [
            (0.0, dict(rest, slide=0.0)), (0.04, dict(dip, slide=0.06), "out"),
            (0.36, dict(rest, slide=0.0), "smooth"), (0.5, rest),
        ])
    bolt = SPEC[gun].get("bolt", (-0.088, 0.06, -0.02))
    work = held(gun, fp, offset=(0.0, 0.0, 0.02), hand=(92.0, -4.0, 0.0), cant=14.0)

    def at_bolt(**more):
        return dict(work, arm_l=on_gun(bolt, "pistol_slide"), **more)
    keys = [
        (0.0, rest), (0.12, rest),
        (0.32, at_bolt()),
        (0.42, at_bolt(slide_turn=-70.0), "out"),
        (0.56, at_bolt(slide_turn=-70.0, slide=0.09), "out"),
        (0.70, at_bolt(slide_turn=-70.0), "in"),
        (0.78, at_bolt(), "in"),
        (0.98, rest),
        (1.10, rest),
    ]
    return _scaled(keys, FIRE[gun]) if gun != "sniper" else (lambda t: keyed(t, keys))


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
            Clip("reload_" + gun, RELOAD[gun], reload_clip(gun, False), loop=gun in LOOPED),
            Clip("respawn_" + gun, 0.6, respawn(gun)),
        ]
        if gun in FIRE:
            out.append(Clip("fire_" + gun, FIRE[gun], fire_clip(gun, False)))
    out += [Clip("reload_" + g, RELOAD[g], sidearm_reload(g, False)) for g in SIDEARMS]
    out += akimbo_body_clips()
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
    out.append(Clip("fp_reload_" + gun, RELOAD[gun], reload_clip(gun, True), loop=gun in LOOPED))
    if gun in FIRE:
        out.append(Clip("fp_fire_" + gun, FIRE[gun], fire_clip(gun, True)))
    return out


def arms_clips():
    out = []
    for gun in LONG:
        out += fp_clips_for(gun)
    out += [Clip("fp_reload_" + g, RELOAD[g], sidearm_reload(g, True)) for g in SIDEARMS]
    out += akimbo_arms_clips()
    return out


# ---------------------------------------------------------------------------
# Sidearms (held like the pistol, with the pistol's poses)

def sidearm_reload(gun, fp):
    if gun == "revolver":
        return _revolver_reload(fp)
    base = A.fp_reload if fp else A.reload
    k = 1.3 / RELOAD[gun]
    return lambda t: base(t * k)


def _revolver_reload(fp):
    """Revolver: tip it, swing the cylinder out to the left, knock out the empties,
    push in a speed loader, flick the cylinder shut."""
    if fp:
        rest_r, rest_l = A.FP_R, A.FP_L
        tilt_r = A.fp_arm_r(0.16, -0.14, -0.38, hand=(118.0, 14.0, 0.0), cant=42.0)
        up_r = A.fp_arm_r(0.15, -0.10, -0.36, hand=(140.0, 10.0, 0.0), cant=30.0)
        away = A.fp_arm_l(-0.04, -0.50, -0.20, hand=(80.0, 0.0, 0.0))
    else:
        rest_r = A._arm("r", A.AIM_R["ik"], A.AIM_R["hand"])
        rest_l = A._arm("l", A.AIM_L["ik"], A.AIM_L["hand"])
        tilt_r = A._arm("r", (0.07, 0.22, -0.37), (120.0, 14.0, 0.0), 42.0)
        up_r = A._arm("r", (0.07, 0.27, -0.33), (145.0, 10.0, 0.0), 30.0)
        away = A._arm("l", (-0.19, -0.22, -0.10), (40.0, 0.0, 0.0))
    cyl = (0.0, 0.046, -0.06)
    shut = _hinge((0.0, 0.0, 0.0), (-0.02, 0.02, 0.0))
    swung = _hinge((0.0, 0.0, 80.0), (-0.02, 0.02, 0.0))

    def k(t, r, l, opn, ease="smooth"):
        spec = {"arm_r": r, "arm_l": l, "slide": 0.0}
        spec.update(swung if opn else shut)
        return (t, spec, ease)
    keys = [
        k(0.0, rest_r, rest_l, False),
        k(0.20, tilt_r, on_gun(cyl, "pistol_mag"), False),
        k(0.36, tilt_r, on_gun(cyl, "pistol_mag"), True, "out"),
        k(0.55, up_r, on_gun(cyl, "pistol_mag"), True, "in"),    # muzzle up: the empties drop out
        k(0.70, tilt_r, away, True),
        k(1.10, tilt_r, on_gun(_add(cyl, (0.0, 0.0, 0.10)), "pistol_mag"), True, "out"),
        k(1.28, tilt_r, on_gun(cyl, "pistol_mag"), True, "in"),
        k(1.45, tilt_r, on_gun(cyl, "pistol_mag"), False, "in"),
        k(1.70, rest_r, rest_l, False),
        k(2.0, rest_r, rest_l, False),
    ]
    return lambda t: keyed(t, keys)


# ---------------------------------------------------------------------------
# Akimbo: a pistol in each fist. The left gun rides on its own bones ("pistol_l"...),
# so every pose here sets both arms out front, mirror images of each other. Shots
# alternate between the guns; the game kicks whichever arm fired (no fire clip).

AKIMBO = "akimbo"
AKIMBO_RELOAD = 2.0   # WeaponData.akimbo().reload_time


def _mirror_arm(arm):
    """The left arm as the mirror image of a right-arm spec."""
    out = dict(arm)
    out["ik"] = (-arm["ik"][0], arm["ik"][1], arm["ik"][2])
    out["pole"] = (-arm["pole"][0], arm["pole"][1], arm["pole"][2])
    if "hand" in arm:
        out["hand"] = (arm["hand"][0], -arm["hand"][1], -arm["hand"][2])
    out["cant"] = -arm.get("cant", 0.0)
    return out


def _pair(right_arm, **more):
    spec = {"arm_r": right_arm, "arm_l": _mirror_arm(right_arm),
            "slide": 0.0, "mag": (0.0, 0.0, 0.0), "slide_l": 0.0, "mag_l": (0.0, 0.0, 0.0),
            "fingers_l": "gun"}   # the left hand has a gun of its own
    spec.update(more)
    return spec


def _ak_arm(fp, pos, hand=(90.0, 0.0, 0.0), cant=0.0):
    return A.fp_arm_r(*pos, hand=hand, cant=cant) if fp else A._arm("r", pos, hand, cant)


# Where the right fist holds its gun: third person in chest space, first person from the camera.
AK_AIM = {False: ((0.125, 0.25, -0.445), (90.0, 5.0, 0.0), -8.0),
          True: ((0.155, -0.16, -0.42), (90.0, 4.0, 0.0), -6.0)}


def akimbo_rest(fp, offset=(0.0, 0.0, 0.0), hand=None, cant=None, **more):
    pos, h, c = AK_AIM[fp]
    return _pair(_ak_arm(fp, _add(pos, offset), hand if hand is not None else h, c if cant is None else cant), **more)


def akimbo_reload(fp):
    """Both guns tip up and the empty magazines drop out (the slides locked back),
    the fists drop to the hips and push both guns down onto fresh magazines on the
    belt, then up again: the slides slam home together."""
    rest = akimbo_rest(fp)
    if fp:
        tilt_arm = _ak_arm(fp, (0.16, -0.19, -0.34), (122.0, 20.0, 0.0), 22.0)
        low_arm = _ak_arm(fp, (0.20, -0.56, -0.22), (40.0, 0.0, 0.0), -10.0)
        push_arm = _ak_arm(fp, (0.20, -0.60, -0.20), (40.0, 0.0, 0.0), -10.0)
    else:
        tilt_arm = _ak_arm(fp, (0.11, 0.21, -0.36), (122.0, 12.0, 0.0), 30.0)
        low_arm = _ak_arm(fp, (0.20, -0.20, -0.16), (40.0, 0.0, 0.0), -10.0)
        push_arm = _ak_arm(fp, (0.20, -0.24, -0.15), (40.0, 0.0, 0.0), -10.0)
    back = 0.04            # a slide locked back on an empty gun
    out_mag = (0.0, -0.03, 0.0)
    gone = (0.0, -0.75, 0.05)
    belt = (0.0, -0.10, 0.0)   # the fresh magazine, waiting in its pouch under the grip

    def k(t, arm, slide, mag, ease="smooth"):
        return (t, _pair(arm, slide=slide, slide_l=slide, mag=mag, mag_l=mag), ease)
    keys = [
        (0.0, rest),
        k(0.20, tilt_arm, back, (0.0, 0.0, 0.0)),
        k(0.26, tilt_arm, back, out_mag, "out"),
        k(0.46, tilt_arm, back, gone, "in"),
        k(0.84, low_arm, back, gone),
        k(0.86, low_arm, back, belt, "linear"),
        k(1.02, push_arm, back, (0.0, 0.0, 0.0), "out"),
        k(1.12, low_arm, back, (0.0, 0.0, 0.0), "in"),
        k(1.50, tilt_arm, back, (0.0, 0.0, 0.0)),
        k(1.58, tilt_arm, 0.0, (0.0, 0.0, 0.0), "out"),
        k(1.80, AK_REST_ARM[fp], 0.0, (0.0, 0.0, 0.0)),
        k(2.00, AK_REST_ARM[fp], 0.0, (0.0, 0.0, 0.0)),
    ]
    return _scaled(keys, AKIMBO_RELOAD)


AK_REST_ARM = {fp: akimbo_rest(fp)["arm_r"] for fp in (False, True)}


def akimbo_body_clips():
    return [
        Clip("aim_akimbo", 1 / 30, lambda t: akimbo_rest(False)),
        Clip("reload_akimbo", AKIMBO_RELOAD, akimbo_reload(False)),
    ]


def akimbo_arms_clips():
    idle = akimbo_rest(True)
    down = akimbo_rest(True, offset=(0.02, -0.25, 0.18), hand=(60.0, 10.0, 0.0))
    sprint = akimbo_rest(True, offset=(0.045, -0.13, 0.12), hand=(125.0, 18.0, 0.0), cant=-18.0)
    one = dict(akimbo_rest(True, offset=(0.02, 0.0, 0.0)), arm_l=A.FP_L_AWAY)
    wall_r = dict(akimbo_rest(True, offset=(0.02, 0.0, 0.0), cant=-16.0))
    wall_r["arm_l"] = AK_REST_ARM_L_FP
    dive = akimbo_rest(True, offset=(-0.02, 0.045, -0.08))
    return [
        Clip("fp_idle_akimbo", 1 / 30, lambda t: idle),
        Clip("fp_sprint_akimbo", 1 / 30, lambda t: sprint),
        Clip("fp_one_hand_akimbo", 1 / 30, lambda t: one),
        Clip("fp_wall_r_akimbo", 1 / 30, lambda t: wall_r),
        Clip("fp_dive_akimbo", 1 / 30, lambda t: dive),
        Clip("fp_raise_akimbo", 0.4, lambda t: keyed(t, [(0.0, down), (0.1, down), (0.4, idle, "out")])),
        Clip("fp_reload_akimbo", AKIMBO_RELOAD, akimbo_reload(True)),
    ]


AK_REST_ARM_L_FP = akimbo_rest(True)["arm_l"]
