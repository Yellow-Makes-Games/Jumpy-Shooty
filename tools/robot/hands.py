"""The robots' hands: a palm with an armour plate on its back, a trigger finger, three
more fingers that move as one, and a thumb, with a round joint at every knuckle. Every
robot has the same hand bones (rig.py: INDEX_AT, FINGERS_AT, THUMB_AT), so one hand is
built here and each design takes it at its own bulk and in its own materials.

Built as the right hand with the arm hanging at rest, open: the palm on the outside of
the grip facing in, the fingers pointing down, the thumb pointing forward. The left is
its mirror image. How a hand is held (open, a fist, round a grip...) is a pose: rig.HANDS.
"""
from kit import loft, prism, rect
from rig import GRIP_AT, INDEX_AT, FINGERS_AT, THUMB_AT, FINGER_BONES, THUMB_BONES

PALM_IN = 0.020        # the palm's inner face, out from the middle of the grip (a grip is up to 4 cm wide)
FINGER = 0.019         # one finger's width, with a 2 mm gap to the next
MITT = (-0.021, 0.0, 0.021)   # the three fingers, across their knuckle


def _at(part, p=(0.0, 0.0, 0.0)):
    return part.move(GRIP_AT[0] + p[0], GRIP_AT[1] + p[1], GRIP_AT[2] + p[2])


def _digit(thick, wide, length, x, top, z, taper):
    """One bone of a finger, hanging down from `top`: a little narrower at its far end."""
    c = min(thick, wide) * 0.28
    return loft([rect(thick, wide, top, c, cx=x, cz=z),
                 rect(thick * (0.5 + taper * 0.5), wide * (0.6 + taper * 0.4), top - length * 0.7, c * 0.9, cx=x, cz=z),
                 rect(thick * taper, wide * taper, top - length, c * taper, cx=x, cz=z)])


def _joint(r, wide, x, y, z):
    """A knuckle: a short round pin across the finger."""
    return prism(8, r, wide, phase=0.39).rot(pitch=90).move(x, y, z)


def add(mesh, bulk=1.0, body="joint", plate="armor", trim="accent", pin="detail"):
    """Adds both hands to a robot. bulk: how thick the palm and fingers are (1 = the
    Vanguard's). body: the material of the palm and fingers; plate: of the armour on the
    back of the hand; trim: of the bar across the knuckles; pin: of the knuckle joints."""
    thick = min(max(0.0155 * bulk, 0.013), 0.019)   # a finger, palm side to back
    deep = min(max(0.017 * bulk, 0.014), 0.024)     # the palm
    out = PALM_IN + deep                            # the back of the palm
    mid = PALM_IN + deep / 2.0
    x = INDEX_AT[0]
    first, second = FINGER_BONES
    parts = [
        # The palm: wider at the knuckles than at the wrist, its lower edge sloping from
        # the trigger finger's knuckle up to the little finger's.
        (_at(loft([rect(deep, 0.094, -0.016, 0.006, cx=mid, cz=0.029), rect(deep, 0.098, 0.004, 0.006, cx=mid, cz=0.029),
                   rect(deep, 0.07, 0.046, 0.008, cx=mid, cz=0.018)])), body, "hand"),
        (_at(_joint(0.021, deep + 0.02, 0.0, 0.0, 0.0).rot(yaw=90), (mid - 0.006, 0.047, 0.006)), pin, "hand"),   # the wrist
        # The plate on the back of the hand: a shield, cut in at the wrist.
        (_at(loft([rect(0.007 * bulk, 0.06, -0.006, 0.004, cx=out + 0.0035 * bulk, cz=0.029),
                   rect(0.008 * bulk, 0.09, 0.006, 0.004, cx=out + 0.004 * bulk, cz=0.029),
                   rect(0.008 * bulk, 0.084, 0.026, 0.004, cx=out + 0.004 * bulk, cz=0.027),
                   rect(0.006 * bulk, 0.05, 0.044, 0.003, cx=out + 0.003 * bulk, cz=0.02)])), plate, "hand"),
        (_at(loft([rect(0.005, 0.088, -0.017, 0.002, cx=out + 0.0015, cz=0.029), rect(0.005, 0.088, -0.009, 0.002, cx=out + 0.0015, cz=0.029)])),
         trim, "hand"),
    ]

    def finger(at, across, bone):
        z = at[2] + across
        parts.append((_at(_joint(thick * 0.62, FINGER, x, at[1], z)), pin, "hand"))
        parts.append((_at(_digit(thick, FINGER, first, x, at[1], z, 0.88)), body, bone))
        parts.append((_at(_joint(thick * 0.56, FINGER - 0.001, x, at[1] - first, z)), pin, bone))
        parts.append((_at(_digit(thick * 0.9, FINGER - 0.001, second, x, at[1] - first, z, 0.62)), body, bone + "2"))

    finger(INDEX_AT, 0.0, "index")
    for across in MITT:
        finger(FINGERS_AT, across, "fingers")
    # The thumb, built hanging down and then turned to point forward.
    first, second = THUMB_BONES
    wide = thick + 0.003
    for length, taper, start, bone in ((first, 0.9, 0.0, "thumb"), (second, 0.66, first, "thumb2")):
        digit = _digit(wide if bone == "thumb" else wide * 0.9, 0.02, length, 0.0, 0.0, 0.0, taper).rot(pitch=-90)
        parts.append((_at(digit, (THUMB_AT[0], THUMB_AT[1], THUMB_AT[2] - start)), body, bone))
    parts.append((_at(_joint(wide * 0.6, 0.02, 0.0, 0.0, 0.0).rot(roll=90), (THUMB_AT[0], THUMB_AT[1], THUMB_AT[2])), pin, "hand"))
    parts.append((_at(_joint(wide * 0.52, 0.019, 0.0, 0.0, 0.0).rot(roll=90), (THUMB_AT[0], THUMB_AT[1], THUMB_AT[2] - first)), pin, "thumb"))
    for part, material, bone in parts:
        tail = "2" if bone.endswith("2") else ""
        stem = bone[:-1] if tail else bone
        mesh.add(part, material, "%s_r%s" % (stem, tail))
        mesh.add(part.mirrored(), material, "%s_l%s" % (stem, tail))
