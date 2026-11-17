"""The guns. Each is modelled in gun space (barrel -Z, sights +Y, origin where the
right fist closes on the grip) and tied to the three gun bones:

  pistol        the gun itself (the bone is called "pistol" for history; every gun uses it)
  pistol_slide  the part that moves when the gun is worked: the pistol's slide, the
                shotgun's pump, the rifle's charging handle, the sniper's bolt
  pistol_mag    the magazine (the shotgun's: one shell, kept out of sight inside the
                receiver until a reload brings it out)

Every robot carries every gun in its model file; the game shows only the one the
player picked. A gun's triangles use materials named "<gun>.<kind>" (kinds: gun,
detail, accent, lens), so the game can tell which surfaces belong to which gun.
"""
from kit import Part, loft, rect, box, prism, ball
from rig import BODY, GUN_REST

IDS = ("pistol", "shotgun", "rifle", "sniper", "revolver", "machine_pistol", "break_action", "smg",
       "burst_rifle", "lmg", "lever_action", "bolt_action", "railgun", "rocket_launcher", "grenade_launcher")

# Where the left fist holds each gun (gun space), and on which bone: the shotgun's
# hand rides on the pump. The pistol is held in both hands round the grip instead.
SUPPORT = {
    "shotgun": {"grip": (0.0, 0.020, -0.30), "on": "pistol_slide"},
    "rifle": {"grip": (0.0, 0.010, -0.235)},
    "sniper": {"grip": (0.0, 0.012, -0.30)},
    "break_action": {"grip": (0.0, 0.022, -0.30), "on": "pistol_mag"},   # the fore-end swings down with the barrels
    "smg": {"grip": (0.0, -0.045, -0.215)},            # the vertical foregrip
    "burst_rifle": {"grip": (0.0, 0.012, -0.25)},
    "lmg": {"grip": (0.0, 0.0, -0.27)},
    "lever_action": {"grip": (0.0, 0.022, -0.28)},
    "bolt_action": {"grip": (0.0, 0.016, -0.29)},
    "railgun": {"grip": (0.0, 0.005, -0.27)},
    "rocket_launcher": {"grip": (0.0, -0.02, -0.24)},  # the front handle under the tube
    "grenade_launcher": {"grip": (0.0, 0.025, -0.28)},
}

KINDS = {
    "gun": {"color": (0.17, 0.18, 0.21), "metallic": 0.6, "roughness": 0.4},
    "detail": {"color": (0.36, 0.38, 0.42), "metallic": 0.3, "roughness": 0.5},
    "accent": {"color": (0.95, 0.35, 0.25), "metallic": 0.1, "roughness": 0.5},
    "lens": {"color": (0.05, 0.10, 0.14), "metallic": 0.2, "roughness": 0.15, "emission": (0.10, 0.45, 0.60)},
    "polymer": {"color": (0.27, 0.28, 0.30), "metallic": 0.05, "roughness": 0.75},
    "wood": {"color": (0.42, 0.25, 0.13), "metallic": 0.0, "roughness": 0.7},
}


def materials():
    return {"%s.%s" % (g, k): dict(m) for g in IDS for k, m in KINDS.items()}


def _place(part):
    o = BODY.bone("pistol").pos
    return Part(part.t @ GUN_REST.T + o)


def _sec(w, h, fwd, y=0.0, x=0.0, ch=0.0):
    """A rectangle across the barrel line: w wide, h tall, `fwd` metres in front of the grip."""
    return rect(w, h, fwd, ch, cx=x, cz=y)


def _run(secs):
    """Loft rings made by _sec into a part running forwards (-Z)."""
    return loft(secs).rot(pitch=-90)


def _tube(r, back, front, y, sides=8, x=0.0):
    """A round bar along the barrel line from `back` to `front` metres ahead of the grip."""
    return prism(sides, r, front - back, phase=0.39).rot(pitch=-90).move(x, y, -(back + front) / 2.0)


def _add(mesh, gun, kind, bone, part):
    mesh.add(_place(part), "%s.%s" % (gun, kind), bone)


# ---------------------------------------------------------------------------

def pistol(mesh):
    """A chunky sidearm, about 26 cm long."""
    g = "pistol"
    grip = box(0.036, 0.115, 0.05, 0.008).rot(pitch=-14).move(0, -0.035, 0.018)
    frame = loft([rect(0.036, 0.19, 0.022, 0.006, cz=-0.06), rect(0.036, 0.20, 0.05, 0.006, cz=-0.06)])
    guard = box(0.014, 0.012, 0.065).move(0, -0.012, -0.045) + box(0.014, 0.04, 0.012).move(0, 0.004, -0.078)
    under = box(0.03, 0.022, 0.07).move(0, 0.012, -0.12)   # rail block under the barrel
    _add(mesh, g, "gun", "pistol", grip + frame + guard)
    _add(mesh, g, "detail", "pistol", under)
    slide = loft([rect(0.042, 0.235, 0.05, 0.008, cz=-0.06), rect(0.042, 0.235, 0.078, 0.012, cz=-0.06),
                  rect(0.03, 0.235, 0.09, 0.006, cz=-0.06)])
    _add(mesh, g, "gun", "pistol_slide", slide)
    _add(mesh, g, "accent", "pistol_slide", box(0.044, 0.008, 0.10).move(0, 0.066, -0.02))
    _add(mesh, g, "detail", "pistol", prism(6, 0.011, 0.02).rot(pitch=90).move(0, 0.064, -0.185))
    _add(mesh, g, "detail", "pistol_mag", box(0.026, 0.11, 0.034).rot(pitch=-14).move(0, -0.045, 0.02))


def shotgun(mesh):
    """Pump-action, about 80 cm: a short stock, a thick barrel over a magazine tube,
    and a ribbed pump in the player's colour that racks back after every shot."""
    g = "shotgun"
    grip = box(0.038, 0.12, 0.052, 0.009).rot(pitch=-20).move(0, -0.035, 0.022)
    guard = box(0.014, 0.012, 0.07).move(0, -0.014, -0.045) + box(0.014, 0.045, 0.012).move(0, 0.002, -0.08)
    receiver = _run([_sec(0.052, 0.07, -0.05, 0.058, ch=0.012), _sec(0.052, 0.07, 0.17, 0.058, ch=0.012),
                     _sec(0.046, 0.05, 0.19, 0.06, ch=0.01)])
    stock = _run([_sec(0.046, 0.06, -0.04, 0.05, ch=0.01), _sec(0.04, 0.05, -0.12, 0.035, ch=0.01),
                  _sec(0.046, 0.10, -0.21, 0.02, ch=0.012), _sec(0.046, 0.105, -0.23, 0.02, ch=0.012)])
    _add(mesh, g, "gun", "pistol", grip + guard + receiver)
    _add(mesh, g, "polymer", "pistol", stock)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.05, 0.11, -0.232, 0.02, ch=0.012), _sec(0.05, 0.11, -0.25, 0.02, ch=0.012)]))
    _add(mesh, g, "detail", "pistol", _tube(0.017, 0.17, 0.58, 0.072, 8) + _tube(0.012, 0.17, 0.50, 0.036, 8))
    _add(mesh, g, "gun", "pistol", _tube(0.02, 0.555, 0.60, 0.072, 8) + box(0.008, 0.012, 0.012).move(0, 0.094, -0.585))
    _add(mesh, g, "gun", "pistol", _tube(0.014, 0.50, 0.52, 0.036, 8))   # magazine tube cap
    pump = _run([_sec(0.046, 0.044, 0.21, 0.036, ch=0.012), _sec(0.056, 0.054, 0.24, 0.036, ch=0.015),
                 _sec(0.056, 0.054, 0.36, 0.036, ch=0.015), _sec(0.046, 0.044, 0.39, 0.036, ch=0.012)])
    _add(mesh, g, "polymer", "pistol_slide", pump)
    ribs = Part([])
    for i in range(4):
        ribs = ribs + _run([_sec(0.059, 0.057, 0.26 + i * 0.03, 0.036, ch=0.016), _sec(0.059, 0.057, 0.272 + i * 0.03, 0.036, ch=0.016)])
    _add(mesh, g, "accent", "pistol_slide", ribs)
    # One shell, for reloads: hidden inside the receiver until a reload brings it out.
    _add(mesh, g, "accent", "pistol_mag", _tube(0.011, 0.02, 0.07, 0.05, 6))
    _add(mesh, g, "detail", "pistol_mag", _tube(0.0115, 0.0, 0.02, 0.05, 6))


def rifle(mesh):
    """Assault rifle, about 80 cm: fixed stock, a curved magazine, a long handguard with
    accent stripes, a red-dot sight, and a charging handle on the left side."""
    g = "rifle"
    grip = box(0.034, 0.11, 0.048, 0.008).rot(pitch=-18).move(0, -0.034, 0.02)
    guard = box(0.012, 0.012, 0.065).move(0, -0.012, -0.042) + box(0.012, 0.04, 0.012).move(0, 0.002, -0.076)
    lower = _run([_sec(0.044, 0.035, -0.06, 0.035, ch=0.008), _sec(0.044, 0.035, 0.13, 0.035, ch=0.008)])
    upper = _run([_sec(0.046, 0.04, -0.06, 0.07, ch=0.008), _sec(0.046, 0.04, 0.18, 0.07, ch=0.008)])
    magwell = _run([_sec(0.04, 0.04, 0.04, 0.005, ch=0.006), _sec(0.04, 0.04, 0.12, 0.005, ch=0.006)])
    stock = _run([_sec(0.04, 0.05, -0.05, 0.045, ch=0.01), _sec(0.032, 0.04, -0.10, 0.045, ch=0.008),
                  _sec(0.04, 0.10, -0.20, 0.025, ch=0.012), _sec(0.04, 0.10, -0.215, 0.025, ch=0.012)])
    _add(mesh, g, "gun", "pistol", grip + guard + lower + upper + magwell)
    _add(mesh, g, "polymer", "pistol", stock)
    hand = _run([_sec(0.05, 0.052, 0.17, 0.052, ch=0.014), _sec(0.05, 0.052, 0.43, 0.052, ch=0.014)])
    _add(mesh, g, "polymer", "pistol", hand)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.053, 0.014, 0.22, 0.058), _sec(0.053, 0.014, 0.38, 0.058)]))
    _add(mesh, g, "detail", "pistol", _tube(0.011, 0.43, 0.52, 0.052, 6) + _tube(0.017, 0.52, 0.565, 0.052, 6))
    rail = box(0.022, 0.01, 0.30).move(0, 0.095, -0.12)
    sight = _run([_sec(0.034, 0.04, 0.02, 0.118, ch=0.008), _sec(0.034, 0.042, 0.09, 0.119, ch=0.008)])
    _add(mesh, g, "detail", "pistol", rail + sight)
    _add(mesh, g, "lens", "pistol", _run([_sec(0.024, 0.028, 0.0905, 0.121), _sec(0.024, 0.028, 0.093, 0.121)]))
    _add(mesh, g, "gun", "pistol", box(0.008, 0.03, 0.012).move(0, 0.092, -0.40))   # front sight post
    # Curved magazine
    mag = loft([rect(0.03, 0.075, 0.0, 0.008, cz=-0.08), rect(0.03, 0.075, -0.07, 0.008, cz=-0.09),
                rect(0.03, 0.07, -0.15, 0.008, cz=-0.11), rect(0.03, 0.068, -0.19, 0.008, cz=-0.125)])
    _add(mesh, g, "detail", "pistol_mag", mag)
    _add(mesh, g, "accent", "pistol_mag", rect_box(0.032, 0.012, 0.072, -0.185, -0.125))
    # Charging handle on the left of the receiver: pulled back on a reload.
    _add(mesh, g, "gun", "pistol_slide", box(0.03, 0.018, 0.035, 0.005).move(-0.035, 0.07, -0.13))


def rect_box(w, h, d, y, z):
    return box(w, h, d, 0.004).move(0, y, z)


def sniper(mesh):
    """Bolt-action sniper rifle, about 1.1 m: long thin barrel with a muzzle brake, a big
    scope, a skeleton stock, a box magazine and a bolt worked from the left side."""
    g = "sniper"
    grip = box(0.034, 0.11, 0.048, 0.008).rot(pitch=-16).move(0, -0.034, 0.02)
    guard = box(0.012, 0.012, 0.07).move(0, -0.012, -0.045) + box(0.012, 0.04, 0.012).move(0, 0.002, -0.08)
    receiver = _run([_sec(0.046, 0.05, -0.06, 0.06, ch=0.01), _sec(0.046, 0.05, 0.20, 0.06, ch=0.01)])
    fore = _run([_sec(0.05, 0.05, 0.12, 0.035, ch=0.014), _sec(0.05, 0.05, 0.44, 0.035, ch=0.014),
                 _sec(0.036, 0.036, 0.47, 0.04, ch=0.01)])
    # Skeleton stock: a top bar, a bottom bar and the butt
    stock = (_run([_sec(0.032, 0.03, -0.05, 0.065, ch=0.006), _sec(0.032, 0.03, -0.20, 0.062, ch=0.006)])
             + _run([_sec(0.03, 0.025, -0.02, -0.005, ch=0.006), _sec(0.03, 0.025, -0.20, -0.02, ch=0.006)])
             + _run([_sec(0.04, 0.12, -0.20, 0.025, ch=0.012), _sec(0.04, 0.12, -0.235, 0.025, ch=0.012)]))
    _add(mesh, g, "gun", "pistol", grip + guard + receiver)
    _add(mesh, g, "polymer", "pistol", fore + stock)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.042, 0.124, -0.236, 0.025, ch=0.012), _sec(0.042, 0.124, -0.25, 0.025, ch=0.012)]))
    _add(mesh, g, "accent", "pistol", _run([_sec(0.053, 0.012, 0.18, 0.045), _sec(0.053, 0.012, 0.42, 0.045)]))
    _add(mesh, g, "detail", "pistol", _tube(0.012, 0.44, 0.80, 0.058, 6))
    _add(mesh, g, "gun", "pistol", _tube(0.02, 0.80, 0.86, 0.058, 6))   # muzzle brake
    # Scope on two rings
    tube = _run([_sec(0.03, 0.03, -0.06, 0.125, ch=0.01), _sec(0.04, 0.04, -0.035, 0.125, ch=0.013),
                 _sec(0.03, 0.03, -0.01, 0.125, ch=0.01), _sec(0.03, 0.03, 0.14, 0.125, ch=0.01),
                 _sec(0.052, 0.052, 0.20, 0.125, ch=0.017), _sec(0.052, 0.052, 0.24, 0.125, ch=0.017)])
    rings = box(0.02, 0.04, 0.016).move(0, 0.095, -0.02) + box(0.02, 0.04, 0.016).move(0, 0.095, -0.14)
    _add(mesh, g, "gun", "pistol", tube + rings)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.034, 0.034, 0.06, 0.125, ch=0.011), _sec(0.034, 0.034, 0.075, 0.125, ch=0.011)]))
    _add(mesh, g, "lens", "pistol", _run([_sec(0.044, 0.044, 0.2405, 0.125, ch=0.014), _sec(0.044, 0.044, 0.243, 0.125, ch=0.014)]))
    _add(mesh, g, "detail", "pistol_mag", box(0.03, 0.075, 0.07, 0.008).move(0, -0.005, -0.10))
    # The bolt: a cocking handle on the left with a ball knob.
    _add(mesh, g, "detail", "pistol_slide", box(0.02, 0.022, 0.07, 0.004).move(-0.03, 0.06, -0.035))
    _add(mesh, g, "gun", "pistol_slide", prism(6, 0.007, 0.05).rot(roll=90).move(-0.06, 0.06, -0.02))
    _add(mesh, g, "accent", "pistol_slide", ball(0.014).move(-0.088, 0.06, -0.02))


# ---------------------------------------------------------------------------
# The newer guns

def _grip(pitch=-16.0, w=0.034, h=0.11):
    return box(w, h, 0.048, 0.008).rot(pitch=pitch).move(0, -0.034, 0.02)


def _guard():
    return box(0.012, 0.012, 0.068).move(0, -0.012, -0.044) + box(0.012, 0.04, 0.012).move(0, 0.002, -0.078)


def revolver(mesh):
    """A big six-shooter, about 34 cm: a long ribbed barrel, a fluted cylinder that
    swings out to the left for reloads, a hammer that cocks back after every shot."""
    g = "revolver"
    grip = box(0.036, 0.12, 0.05, 0.012).rot(pitch=-22).move(0, -0.04, 0.024)
    frame = (_run([_sec(0.036, 0.06, -0.03, 0.04, ch=0.008), _sec(0.036, 0.06, 0.10, 0.04, ch=0.008)])
             + box(0.03, 0.014, 0.04).move(0, 0.075, -0.06))
    _add(mesh, g, "gun", "pistol", grip.move(0, 0, 0) + frame + _guard())
    _add(mesh, g, "wood", "pistol", box(0.04, 0.09, 0.044, 0.012).rot(pitch=-22).move(0, -0.05, 0.026))
    _add(mesh, g, "gun", "pistol", _tube(0.014, 0.10, 0.285, 0.066, 8))
    _add(mesh, g, "detail", "pistol", box(0.018, 0.016, 0.18).move(0, 0.082, -0.19)
         + box(0.006, 0.014, 0.01).move(0, 0.094, -0.275))
    _add(mesh, g, "accent", "pistol", box(0.04, 0.008, 0.05).move(0, 0.064, -0.11))
    # The cylinder, on the magazine bone: it swings out to the side.
    _add(mesh, g, "detail", "pistol_mag", _tube(0.03, 0.025, 0.098, 0.046, 6))
    _add(mesh, g, "accent", "pistol_mag", _tube(0.031, 0.055, 0.065, 0.046, 6))
    _add(mesh, g, "gun", "pistol", _tube(0.008, 0.098, 0.105, 0.046, 6))   # the crane
    # The hammer, on the slide bone: it rocks back after a shot.
    _add(mesh, g, "gun", "pistol_slide", box(0.012, 0.03, 0.016, 0.003).rot(pitch=20).move(0, 0.078, 0.022))


def machine_pistol(mesh):
    """A boxy full-auto sidearm, about 27 cm: an extended magazine, a compensator and a
    folding front hand stop."""
    g = "machine_pistol"
    grip = box(0.034, 0.11, 0.05, 0.008).rot(pitch=-12).move(0, -0.035, 0.018)
    frame = loft([rect(0.034, 0.19, 0.022, 0.006, cz=-0.06), rect(0.034, 0.20, 0.05, 0.006, cz=-0.06)])
    _add(mesh, g, "gun", "pistol", grip + frame + _guard())
    _add(mesh, g, "detail", "pistol", box(0.022, 0.03, 0.012).move(0, -0.0, -0.17))   # hand stop
    slide = loft([rect(0.04, 0.22, 0.05, 0.008, cz=-0.06), rect(0.04, 0.22, 0.08, 0.01, cz=-0.06)])
    _add(mesh, g, "gun", "pistol_slide", slide)
    _add(mesh, g, "accent", "pistol_slide", box(0.042, 0.008, 0.06).move(0, 0.064, 0.0))
    _add(mesh, g, "detail", "pistol", _tube(0.016, 0.17, 0.235, 0.064, 6))   # compensator
    _add(mesh, g, "accent", "pistol", _tube(0.017, 0.215, 0.225, 0.064, 6))
    mag = box(0.026, 0.21, 0.034, 0.004).rot(pitch=-12).move(0, -0.08, 0.012)
    _add(mesh, g, "polymer", "pistol_mag", mag)
    _add(mesh, g, "accent", "pistol_mag", box(0.028, 0.014, 0.036).rot(pitch=-12).move(0, -0.18, 0.0))


def break_action(mesh):
    """A side-by-side double barrel, about 85 cm, with a wooden stock and fore-end. The
    barrels and fore-end (on the magazine bone) tip down on their hinge to reload."""
    g = "break_action"
    grip = box(0.036, 0.11, 0.05, 0.01).rot(pitch=-22).move(0, -0.034, 0.024)
    receiver = _run([_sec(0.05, 0.06, -0.04, 0.05, ch=0.012), _sec(0.05, 0.06, 0.13, 0.05, ch=0.012)])
    stock = _run([_sec(0.044, 0.06, -0.04, 0.04, ch=0.012), _sec(0.04, 0.05, -0.11, 0.03, ch=0.012),
                  _sec(0.046, 0.11, -0.22, 0.012, ch=0.014), _sec(0.046, 0.115, -0.25, 0.012, ch=0.014)])
    _add(mesh, g, "gun", "pistol", receiver + _guard())
    _add(mesh, g, "wood", "pistol", grip + stock)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.05, 0.12, -0.252, 0.012, ch=0.014), _sec(0.05, 0.12, -0.27, 0.012, ch=0.014)]))
    _add(mesh, g, "detail", "pistol", box(0.012, 0.016, 0.03).rot(pitch=-30).move(0, 0.085, 0.0))   # top lever
    barrels = _tube(0.017, 0.13, 0.66, 0.066, 8, x=-0.017) + _tube(0.017, 0.13, 0.66, 0.066, 8, x=0.017)
    _add(mesh, g, "detail", "pistol_mag", barrels)
    _add(mesh, g, "gun", "pistol_mag", box(0.072, 0.018, 0.53).move(0, 0.05, -0.395)
         + box(0.006, 0.008, 0.5).move(0, 0.088, -0.40))
    _add(mesh, g, "wood", "pistol_mag", _run([_sec(0.06, 0.04, 0.14, 0.03, ch=0.012), _sec(0.064, 0.045, 0.36, 0.03, ch=0.014)]))
    _add(mesh, g, "accent", "pistol_mag", _run([_sec(0.068, 0.02, 0.36, 0.035), _sec(0.068, 0.02, 0.38, 0.035)]))


def smg(mesh):
    """A compact submachine gun, about 55 cm: a boxy receiver, a straight magazine in
    the grip's front, a vertical foregrip and a skeleton stock."""
    g = "smg"
    receiver = _run([_sec(0.046, 0.065, -0.06, 0.05, ch=0.01), _sec(0.046, 0.065, 0.30, 0.05, ch=0.01)])
    _add(mesh, g, "gun", "pistol", _grip(-14) + _guard() + receiver)
    _add(mesh, g, "polymer", "pistol", box(0.03, 0.085, 0.036, 0.008).move(0, -0.035, -0.215))   # foregrip
    _add(mesh, g, "detail", "pistol", _tube(0.022, 0.30, 0.42, 0.052, 8))   # shroud
    _add(mesh, g, "gun", "pistol", _tube(0.012, 0.42, 0.47, 0.052, 6))
    _add(mesh, g, "accent", "pistol", _run([_sec(0.049, 0.012, 0.0, 0.07), _sec(0.049, 0.012, 0.22, 0.07)]))
    stock = (_run([_sec(0.02, 0.018, -0.06, 0.06), _sec(0.02, 0.018, -0.22, 0.055)])
             + _run([_sec(0.02, 0.018, -0.06, 0.02), _sec(0.02, 0.018, -0.22, 0.03)])
             + box(0.036, 0.09, 0.02, 0.006).move(0, 0.042, 0.225))
    _add(mesh, g, "polymer", "pistol", stock)
    _add(mesh, g, "detail", "pistol", box(0.02, 0.022, 0.06).move(0, 0.094, -0.06) + box(0.024, 0.03, 0.01).move(0, 0.1, -0.03))
    _add(mesh, g, "lens", "pistol", box(0.016, 0.018, 0.003).move(0, 0.104, -0.025))
    _add(mesh, g, "detail", "pistol_mag", box(0.026, 0.17, 0.034, 0.004).move(0, -0.06, -0.085))
    _add(mesh, g, "accent", "pistol_mag", box(0.028, 0.014, 0.036).move(0, -0.142, -0.085))
    _add(mesh, g, "gun", "pistol_slide", box(0.012, 0.016, 0.03, 0.004).move(-0.03, 0.07, -0.1))


def burst_rifle(mesh):
    """A sleek burst rifle, about 85 cm: a smooth shroud over the barrel, a long top
    sight with a glowing lens, a box magazine and a charging handle at the back."""
    g = "burst_rifle"
    upper = _run([_sec(0.05, 0.06, -0.06, 0.06, ch=0.014), _sec(0.05, 0.06, 0.20, 0.06, ch=0.014),
                  _sec(0.054, 0.07, 0.24, 0.056, ch=0.018), _sec(0.054, 0.07, 0.50, 0.056, ch=0.018),
                  _sec(0.04, 0.05, 0.56, 0.056, ch=0.012)])
    _add(mesh, g, "gun", "pistol", _grip(-18) + _guard() + upper)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.057, 0.016, 0.27, 0.074), _sec(0.057, 0.016, 0.46, 0.074)])
         + _run([_sec(0.057, 0.008, 0.27, 0.036), _sec(0.057, 0.008, 0.46, 0.036)]))
    _add(mesh, g, "detail", "pistol", _tube(0.011, 0.56, 0.62, 0.056, 6))
    stock = _run([_sec(0.044, 0.055, -0.05, 0.05, ch=0.012), _sec(0.04, 0.06, -0.16, 0.04, ch=0.012),
                  _sec(0.046, 0.11, -0.22, 0.025, ch=0.014), _sec(0.046, 0.11, -0.24, 0.025, ch=0.014)])
    _add(mesh, g, "polymer", "pistol", stock)
    _add(mesh, g, "detail", "pistol", _run([_sec(0.03, 0.03, -0.04, 0.11, ch=0.008), _sec(0.03, 0.03, 0.16, 0.11, ch=0.008)]))
    _add(mesh, g, "lens", "pistol", _run([_sec(0.022, 0.022, 0.161, 0.11), _sec(0.022, 0.022, 0.164, 0.11)]))
    _add(mesh, g, "detail", "pistol_mag", box(0.028, 0.14, 0.05, 0.006).rot(pitch=8).move(0, -0.045, -0.10))
    _add(mesh, g, "accent", "pistol_mag", box(0.03, 0.014, 0.052).rot(pitch=8).move(0, -0.11, -0.11))
    _add(mesh, g, "gun", "pistol_slide", box(0.03, 0.016, 0.03, 0.005).move(-0.034, 0.075, 0.02))


def lmg(mesh):
    """A belt-fed light machine gun, about 1 m: a big receiver with a top cover, a box
    of ammunition hanging underneath, a vented barrel shroud and a carry handle."""
    g = "lmg"
    receiver = _run([_sec(0.062, 0.08, -0.07, 0.05, ch=0.014), _sec(0.062, 0.08, 0.24, 0.05, ch=0.014)])
    _add(mesh, g, "gun", "pistol", _grip(-18, 0.036) + _guard() + receiver)
    stock = _run([_sec(0.05, 0.07, -0.06, 0.045, ch=0.014), _sec(0.046, 0.08, -0.2, 0.03, ch=0.014),
                  _sec(0.05, 0.12, -0.25, 0.02, ch=0.016), _sec(0.05, 0.12, -0.27, 0.02, ch=0.016)])
    _add(mesh, g, "polymer", "pistol", stock)
    _add(mesh, g, "polymer", "pistol", _run([_sec(0.056, 0.05, 0.24, 0.03, ch=0.014), _sec(0.056, 0.05, 0.42, 0.03, ch=0.014)]))
    _add(mesh, g, "detail", "pistol", _tube(0.026, 0.24, 0.66, 0.06, 8))
    vents = Part([])
    for i in range(5):
        vents = vents + _tube(0.028, 0.45 + i * 0.04, 0.47 + i * 0.04, 0.06, 8)
    _add(mesh, g, "accent", "pistol", vents)
    _add(mesh, g, "gun", "pistol", _tube(0.012, 0.66, 0.76, 0.06, 6) + _tube(0.02, 0.76, 0.80, 0.06, 6))
    _add(mesh, g, "detail", "pistol", box(0.016, 0.05, 0.016).move(0, 0.112, -0.10) + box(0.016, 0.05, 0.016).move(0, 0.112, -0.26)
         + box(0.018, 0.016, 0.19).move(0, 0.14, -0.18))   # carry handle
    _add(mesh, g, "gun", "pistol_slide", box(0.064, 0.018, 0.2, 0.004).move(0, 0.095, -0.06))   # the top cover
    box_mag = box(0.07, 0.11, 0.12, 0.01).move(0, -0.04, -0.12)
    _add(mesh, g, "polymer", "pistol_mag", box_mag)
    _add(mesh, g, "accent", "pistol_mag", box(0.072, 0.02, 0.122).move(0, -0.08, -0.12))
    _add(mesh, g, "detail", "pistol", box(0.012, 0.012, 0.18).rot(pitch=8).move(-0.025, 0.02, -0.52)
         + box(0.012, 0.012, 0.18).rot(pitch=8).move(0.025, 0.02, -0.52))   # folded bipod


def lever_action(mesh):
    """A lever-action rifle, about 95 cm: wood stock and fore-end, a tube magazine under
    the octagonal barrel, and the lever loop behind the trigger."""
    g = "lever_action"
    grip = box(0.034, 0.10, 0.046, 0.01).rot(pitch=-24).move(0, -0.03, 0.026)
    receiver = _run([_sec(0.04, 0.07, -0.03, 0.05, ch=0.01), _sec(0.04, 0.07, 0.15, 0.05, ch=0.01)])
    stock = _run([_sec(0.038, 0.06, -0.04, 0.035, ch=0.012), _sec(0.036, 0.05, -0.12, 0.025, ch=0.012),
                  _sec(0.042, 0.11, -0.24, 0.0, ch=0.014), _sec(0.042, 0.115, -0.26, 0.0, ch=0.014)])
    _add(mesh, g, "gun", "pistol", receiver)
    _add(mesh, g, "wood", "pistol", grip + stock + _run([_sec(0.042, 0.04, 0.15, 0.035, ch=0.012), _sec(0.042, 0.04, 0.42, 0.035, ch=0.012)]))
    _add(mesh, g, "accent", "pistol", _run([_sec(0.044, 0.12, -0.262, 0.0, ch=0.014), _sec(0.044, 0.12, -0.275, 0.0, ch=0.014)])
         + box(0.042, 0.012, 0.03).move(0, 0.03, -0.43))
    _add(mesh, g, "detail", "pistol", _tube(0.013, 0.15, 0.78, 0.066, 8) + _tube(0.009, 0.15, 0.70, 0.04, 6))
    _add(mesh, g, "gun", "pistol", box(0.006, 0.016, 0.01).move(0, 0.086, -0.75) + box(0.016, 0.012, 0.012).move(0, 0.084, -0.12))
    _add(mesh, g, "detail", "pistol", box(0.006, 0.01, 0.03).move(-0.021, 0.055, -0.06))   # loading gate
    # The lever loop, on the slide bone: it swings down about its pin and back.
    lever = (box(0.01, 0.01, 0.075).move(0, -0.012, -0.03) + box(0.01, 0.06, 0.01).move(0, -0.04, 0.008)
             + box(0.01, 0.01, 0.05).move(0, -0.07, -0.01) + box(0.01, 0.05, 0.01).move(0, -0.045, -0.036))
    _add(mesh, g, "gun", "pistol_slide", lever)
    _add(mesh, g, "accent", "pistol_slide", box(0.012, 0.012, 0.03).move(0, -0.072, -0.01))
    _add(mesh, g, "detail", "pistol_mag", _tube(0.007, 0.02, 0.06, 0.055, 6))   # one round, for reloads (hidden in the action)


def bolt_action(mesh):
    """A bolt-action rifle, about 1 m, with iron sights: a full-length wooden stock, a
    bolt worked from the left side, like the sniper's."""
    g = "bolt_action"
    receiver = _run([_sec(0.04, 0.045, -0.05, 0.06, ch=0.01), _sec(0.04, 0.045, 0.16, 0.06, ch=0.01)])
    stock = (_run([_sec(0.044, 0.05, -0.04, 0.03, ch=0.012), _sec(0.04, 0.045, -0.12, 0.025, ch=0.012),
                   _sec(0.046, 0.115, -0.24, 0.004, ch=0.014), _sec(0.046, 0.12, -0.26, 0.004, ch=0.014)])
             + _run([_sec(0.046, 0.05, 0.0, 0.03, ch=0.014), _sec(0.046, 0.05, 0.55, 0.04, ch=0.014),
                     _sec(0.03, 0.03, 0.6, 0.048, ch=0.01)]))
    _add(mesh, g, "gun", "pistol", receiver + _guard())
    _add(mesh, g, "wood", "pistol", _grip(-20, 0.036) + stock)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.048, 0.125, -0.262, 0.004, ch=0.014), _sec(0.048, 0.125, -0.275, 0.004, ch=0.014)])
         + _run([_sec(0.05, 0.01, 0.34, 0.068), _sec(0.05, 0.01, 0.36, 0.068)]))
    _add(mesh, g, "detail", "pistol", _tube(0.011, 0.16, 0.80, 0.06, 6))
    _add(mesh, g, "gun", "pistol", box(0.006, 0.022, 0.012).move(0, 0.078, -0.77) + box(0.022, 0.02, 0.016).move(0, 0.09, -0.12)
         + box(0.004, 0.012, 0.014).move(-0.008, 0.105, -0.12) + box(0.004, 0.012, 0.014).move(0.008, 0.105, -0.12))
    _add(mesh, g, "detail", "pistol_mag", box(0.026, 0.03, 0.06, 0.006).move(0, 0.01, -0.09))
    _add(mesh, g, "detail", "pistol_slide", box(0.02, 0.022, 0.07, 0.004).move(-0.026, 0.06, -0.03))
    _add(mesh, g, "gun", "pistol_slide", prism(6, 0.007, 0.045).rot(roll=90).move(-0.055, 0.06, -0.01))
    _add(mesh, g, "accent", "pistol_slide", ball(0.013).move(-0.08, 0.06, -0.01))


def railgun(mesh):
    """A railgun, about 1 m: two long rails over a glowing coil, a power cell that
    clips in behind the grip, and a sleeve that snaps back when it fires."""
    g = "railgun"
    body = _run([_sec(0.06, 0.07, -0.07, 0.05, ch=0.018), _sec(0.06, 0.08, 0.22, 0.05, ch=0.02),
                 _sec(0.05, 0.06, 0.28, 0.05, ch=0.016)])
    _add(mesh, g, "gun", "pistol", _grip(-14, 0.036) + _guard() + body)
    stock = _run([_sec(0.05, 0.07, -0.06, 0.05, ch=0.016), _sec(0.04, 0.06, -0.18, 0.04, ch=0.014),
                  _sec(0.05, 0.12, -0.24, 0.025, ch=0.018), _sec(0.05, 0.12, -0.26, 0.025, ch=0.018)])
    _add(mesh, g, "polymer", "pistol", stock)
    rails = (_run([_sec(0.05, 0.016, 0.22, 0.098), _sec(0.05, 0.016, 0.80, 0.098)])
             + _run([_sec(0.05, 0.016, 0.22, 0.026), _sec(0.05, 0.016, 0.78, 0.026)]))
    _add(mesh, g, "gun", "pistol", rails)
    _add(mesh, g, "detail", "pistol", _tube(0.012, 0.28, 0.78, 0.062, 6))
    coils = Part([])
    for i in range(6):
        coils = coils + _tube(0.026, 0.32 + i * 0.075, 0.345 + i * 0.075, 0.062, 8)
    _add(mesh, g, "lens", "pistol", coils)
    _add(mesh, g, "accent", "pistol", _run([_sec(0.064, 0.02, -0.02, 0.07), _sec(0.064, 0.02, 0.2, 0.07)]))
    _add(mesh, g, "detail", "pistol", _run([_sec(0.028, 0.03, -0.02, 0.112, ch=0.008), _sec(0.028, 0.03, 0.14, 0.112, ch=0.008)]))
    _add(mesh, g, "lens", "pistol", _run([_sec(0.02, 0.02, 0.141, 0.112), _sec(0.02, 0.02, 0.144, 0.112)]))
    _add(mesh, g, "gun", "pistol_slide", _tube(0.034, 0.24, 0.30, 0.062, 8))   # the recoil sleeve
    _add(mesh, g, "detail", "pistol_mag", box(0.034, 0.07, 0.07, 0.008).move(0, -0.005, 0.105))
    _add(mesh, g, "lens", "pistol_mag", box(0.036, 0.012, 0.05).move(0, 0.01, 0.105))


def rocket_launcher(mesh):
    """A shoulder rocket launcher, about 1.05 m: a fat tube with a flared back blast
    cone, a front handle and a sight box. The rocket (magazine bone) goes in at the back."""
    g = "rocket_launcher"
    y = 0.115
    tube = prism(10, 0.058, 0.86, phase=0.31).rot(pitch=-90).move(0, y, -0.25)
    _add(mesh, g, "polymer", "pistol", tube)
    _add(mesh, g, "gun", "pistol", prism(10, 0.068, 0.06, phase=0.31).rot(pitch=-90).move(0, y, -0.65)
         + prism(10, 0.06, 0.12, r_top=0.078, phase=0.31).rot(pitch=90).move(0, y, 0.22))
    _add(mesh, g, "accent", "pistol", prism(10, 0.06, 0.05, phase=0.31).rot(pitch=-90).move(0, y, -0.4)
         + prism(10, 0.06, 0.05, phase=0.31).rot(pitch=-90).move(0, y, 0.0))
    _add(mesh, g, "gun", "pistol", box(0.03, 0.11, 0.05, 0.008).rot(pitch=-12).move(0, -0.03, 0.02)
         + box(0.03, 0.04, 0.10).move(0, 0.045, -0.02) + _guard())
    _add(mesh, g, "gun", "pistol", box(0.03, 0.09, 0.04, 0.008).move(0, 0.01, -0.24) + box(0.03, 0.04, 0.05).move(0, 0.05, -0.24))
    _add(mesh, g, "detail", "pistol", box(0.04, 0.05, 0.09, 0.008).move(-0.075, y + 0.02, -0.12))
    _add(mesh, g, "lens", "pistol", box(0.032, 0.036, 0.004).move(-0.075, y + 0.02, -0.166))
    # The rocket: its nose shows in the tube's mouth; a reload brings a new one in from behind.
    _add(mesh, g, "accent", "pistol_mag", prism(8, 0.04, 0.08, r_top=0.005).rot(pitch=-90).move(0, y, -0.72))
    _add(mesh, g, "detail", "pistol_mag", prism(8, 0.04, 0.5).rot(pitch=-90).move(0, y, -0.43))


def grenade_launcher(mesh):
    """A revolving grenade launcher, about 75 cm: a fat six-round drum (magazine bone),
    a short wide barrel, a folding stock and a ladder sight."""
    g = "grenade_launcher"
    frame = _run([_sec(0.05, 0.05, -0.06, 0.04, ch=0.012), _sec(0.05, 0.05, 0.10, 0.04, ch=0.012)])
    _add(mesh, g, "gun", "pistol", _grip(-18, 0.036) + _guard() + frame)
    _add(mesh, g, "gun", "pistol", box(0.02, 0.15, 0.02).move(0, 0.07, -0.20) + box(0.02, 0.02, 0.26).move(0, 0.135, -0.18))
    _add(mesh, g, "detail", "pistol", _tube(0.034, 0.26, 0.48, 0.07, 10))
    _add(mesh, g, "gun", "pistol", _tube(0.04, 0.48, 0.52, 0.07, 10))
    _add(mesh, g, "polymer", "pistol", _run([_sec(0.05, 0.05, 0.26, 0.03, ch=0.014), _sec(0.05, 0.05, 0.40, 0.03, ch=0.014)]))
    stock = (_run([_sec(0.02, 0.02, -0.06, 0.05), _sec(0.02, 0.02, -0.25, 0.04)])
             + box(0.04, 0.11, 0.02, 0.008).move(0, 0.02, 0.255))
    _add(mesh, g, "polymer", "pistol", stock)
    _add(mesh, g, "detail", "pistol", box(0.012, 0.04, 0.01).move(0, 0.12, -0.05) + box(0.012, 0.03, 0.01).move(0, 0.11, -0.46))
    _add(mesh, g, "detail", "pistol_mag", _tube(0.068, 0.10, 0.26, 0.07, 6))
    _add(mesh, g, "accent", "pistol_mag", _tube(0.07, 0.16, 0.19, 0.07, 6))
    _add(mesh, g, "gun", "pistol_slide", box(0.03, 0.03, 0.02).move(0, 0.06, 0.02))   # the hammer


BUILD = {"pistol": pistol, "shotgun": shotgun, "rifle": rifle, "sniper": sniper, "revolver": revolver,
         "machine_pistol": machine_pistol, "break_action": break_action, "smg": smg, "burst_rifle": burst_rifle,
         "lmg": lmg, "lever_action": lever_action, "bolt_action": bolt_action, "railgun": railgun,
         "rocket_launcher": rocket_launcher, "grenade_launcher": grenade_launcher}


def add_all(mesh):
    for gun in IDS:
        BUILD[gun](mesh)
