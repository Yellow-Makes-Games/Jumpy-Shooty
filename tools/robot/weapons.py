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

IDS = ("pistol", "shotgun", "rifle", "sniper")

# Where the left fist holds each gun (gun space), and on which bone: the shotgun's
# hand rides on the pump. The pistol is held in both hands round the grip instead.
SUPPORT = {
    "shotgun": {"grip": (0.0, 0.020, -0.30), "on": "pistol_slide"},
    "rifle": {"grip": (0.0, 0.010, -0.235)},
    "sniper": {"grip": (0.0, 0.012, -0.30)},
}

KINDS = {
    "gun": {"color": (0.17, 0.18, 0.21), "metallic": 0.6, "roughness": 0.4},
    "detail": {"color": (0.36, 0.38, 0.42), "metallic": 0.3, "roughness": 0.5},
    "accent": {"color": (0.95, 0.35, 0.25), "metallic": 0.1, "roughness": 0.5},
    "lens": {"color": (0.05, 0.10, 0.14), "metallic": 0.2, "roughness": 0.15, "emission": (0.10, 0.45, 0.60)},
    "polymer": {"color": (0.27, 0.28, 0.30), "metallic": 0.05, "roughness": 0.75},
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


BUILD = {"pistol": pistol, "shotgun": shotgun, "rifle": rifle, "sniper": sniper}


def add_all(mesh):
    for gun in IDS:
        BUILD[gun](mesh)
