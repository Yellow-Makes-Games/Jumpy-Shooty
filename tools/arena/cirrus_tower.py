#!/usr/bin/env python3
"""Makes the walls of Cirrus's clock tower breakable, between corners that are not (kept
as a record; a second run changes nothing).

The tower's four walls are boxes 0.6 m thick that run from corner to corner and from the
ground to the belfry. This edits game/maps/cirrus.tscn as text, cutting each of them
in three:

 - the corner (the last CORNER metres at each end of the north and south walls, and the
   matching ends of the east and west ones) cannot break: with the pilasters on them the
   four corners are pillars from the ground to the belfry, and hold it up;
 - what is above the upper ledge (the clock stage: STAGE and up) cannot break either: it
   spans from pillar to pillar and carries the clock faces, so they can never fall;
 - the rest, between the pillars and below the clock, breaks (Breakable ticked).

The arched tops of its door and window slits are no boxes: they break as whole blocks.
The map's Break Small Walls is ticked, so the narrow bits of wall between the slits
break too.

    python3 tools/arena/cirrus_tower.py
"""
import os
import re

SCENE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "cirrus.tscn")
SHELL = "Quad/ClockTower/Shell"
INSIDE = 4.0       # the breakable wall runs from -INSIDE to INSIDE along each side; past that is corner
STAGE = 20.4       # the top of the upper ledge: the clock stage starts here
ARCH_HEALTH = 150


def num(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") or "0"


def main():
    with open(SCENE) as fh:
        text = fh.read()
    if "break_small_walls" not in text:
        text = text.replace("fine_destruction = true\n", "fine_destruction = true\nbreak_small_walls = true\n", 1)
    parts = re.split(r"(?m)^(?=\[)", text)
    cut = arches = 0
    for n, part in enumerate(parts):
        head = re.match(r'\[node name="(Wall(?:North|South|East|West)\w*)" type="[^"]+" parent="%s"\]' % SHELL, part)
        if not head:
            continue
        name = head.group(1)
        props = dict(re.findall(r"(?m)^(\w+) = (.*)$", part))
        if props.get("shape", "0") != "0":
            if "breakable" not in props:   # an arch
                part = re.sub(r"(?m)^(kind = .*)$", '\\1\nbreakable = true\nbreak_settings = "Whole Block"\nbreak_health = %d.0' % ARCH_HEALTH, part, count=1)
                parts[n] = part
                arches += 1
            continue
        at = [float(v) for v in re.match(r"Transform3D\(([^)]*)\)", props["transform"]).group(1).split(",")][9:]
        size = [float(v) for v in re.match(r"Vector3\(([^)]*)\)", props["size"]).group(1).split(",")]
        along = 0 if size[0] > size[2] or size[2] <= 0.61 else 2
        if size[2 - along] > 0.61:
            continue   # (not a wall of the shell)
        a0, a1 = at[along] - size[along] / 2, at[along] + size[along] / 2
        y0, y1 = at[1] - size[1] / 2, at[1] + size[1] / 2
        plain = re.sub(r"(?m)^breakable = true\n", "", part)
        pieces = []   # (suffix, along from, to, y from, to, breaks)
        for lo, hi in ((a0, min(a1, -INSIDE)), (max(a0, INSIDE), a1)):
            if hi - lo > 0.01:
                pieces.append(("Corner", lo, hi, y0, y1, False))
        m0, m1 = max(a0, -INSIDE), min(a1, INSIDE)
        if m1 - m0 > 0.01:
            if min(y1, STAGE) - y0 > 0.01:
                pieces.append(("", m0, m1, y0, min(y1, STAGE), True))
            if y1 - max(y0, STAGE) > 0.01:
                pieces.append(("Top", m0, m1, max(y0, STAGE), y1, False))
        if len(pieces) == 1 and ("breakable" in props) == pieces[0][5] and (pieces[0][0] == "" or name.endswith(pieces[0][0])):
            continue   # (already cut)
        out = []
        for suffix, lo, hi, b, t, breaks in pieces:
            where = list(at)
            where[along] = (lo + hi) / 2
            where[1] = (b + t) / 2
            long = list(size)
            long[along] = hi - lo
            long[1] = t - b
            piece = re.sub(r'(?m)^\[node name="[^"]+"', '[node name="%s"' % (name if name.endswith(suffix) else name + suffix), plain, count=1)
            piece = re.sub(r"(?m)^transform = .*$", "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s)" % ", ".join(num(v) for v in where), piece, count=1)
            piece = re.sub(r"(?m)^size = .*$", "size = Vector3(%s)" % ", ".join(num(v) for v in long), piece, count=1)
            if breaks:
                piece = re.sub(r"(?m)^(kind = .*)$", "\\1\nbreakable = true", piece, count=1)
            out.append(piece)
        parts[n] = "".join(out)
        cut += 1
    with open(SCENE, "w") as fh:
        fh.write("".join(parts))
    print("cut %d walls, ticked %d arches" % (cut, arches))


if __name__ == "__main__":
    main()
