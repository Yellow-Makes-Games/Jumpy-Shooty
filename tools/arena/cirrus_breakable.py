#!/usr/bin/env python3
"""Ticks Breakable on Cirrus's walls, floors, roofs and panes (kept as a record; a second
run changes nothing).

Cirrus was built with only the Labs' glass breakable. With fine destruction on, its
buildings break. This edits game/maps/cirrus.tscn as text:

 - on the quad (the clock tower): every solid, drawn box of one of KINDS that is thin
   enough to break cell by cell (see MapDestruction: one side at most 0.6 m, the face at
   least 7 square metres) gets `breakable = true`. That is the tower's walls: its corner
   pilasters, cornices, stair and belfry are not thin boxes, so they stand whatever
   happens, and the clock stays up.
 - in the five buildings, which are held up by their walls (see MapFrame, and
   tools/arena/cirrus_frames.py), every such box breaks however small it is (a face of
   0.4 square metres or more): nothing of a building is left that cannot be shot away.
 - the two domes (the Observatory's and the Lecture Hall's roof) are no boxes: they
   break as whole blocks, all at once, after DOME_HEALTH of damage.

    python3 tools/arena/cirrus_breakable.py
"""
import os
import re

SCENE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "cirrus.tscn")
KINDS = {"stone", "stone_warm", "floor_wood", "floor_tile", "glass_window", "glass_sky", "paving"}
MAX_THICKNESS = 0.6
MIN_AREA = 7.0
SMALL_AREA = 0.4          # ...in a building held up by its walls
DOMES = {"Observatory/Building/Dome/DomeShell", "LectureHall/Building/Shell/RoofShell"}
DOME_HEALTH = 1500        # about six rockets
BEFORE = ("shape", "size", "kind", "sides", "inner", "arc", "solid", "drawn", "material_type")   # a block's settings that come before Breakable


def main():
    with open(SCENE) as fh:
        text = fh.read()
    block_id = re.search(r'path="res://game/arena/map_block\.gd" id="([^"]+)"', text).group(1)
    parts = re.split(r"(?m)^(?=\[)", text)
    ticked = {}
    for n, part in enumerate(parts):
        if not part.startswith("[node ") or 'script = ExtResource("%s")' % block_id not in part:
            continue
        lines = part.split("\n")
        props = {}
        for i, line in enumerate(lines):
            m = re.match(r"^(\w+) = (.*)$", line)
            if m:
                props[m.group(1)] = (i, m.group(2))
        kind = props.get("kind", (0, '"concrete"'))[1].strip('"')
        head = re.match(r'\[node name="([^"]+)" type="[^"]+" parent="([^"]+)"', lines[0])
        if "breakable" in props or not head:
            continue
        path = head.group(2) + "/" + head.group(1)
        if path in DOMES:
            after = max(props[name][0] for name in BEFORE if name in props)
            lines[after + 1:after + 1] = ["breakable = true", 'break_settings = "Whole Block"', "break_health = %d.0" % DOME_HEALTH]
            parts[n] = "\n".join(lines)
            ticked["dome"] = ticked.get("dome", 0) + 1
            continue
        if kind not in KINDS:
            continue
        in_building = "/Building" in path
        if props.get("shape", (0, "0"))[1] != "0" or props.get("solid", (0, "true"))[1] != "true" or props.get("drawn", (0, "true"))[1] != "true":
            continue
        size = re.match(r"Vector3\(([^)]*)\)", props.get("size", (0, "Vector3(1, 1, 1)"))[1])
        dims = sorted(float(v) for v in size.group(1).split(","))
        if dims[0] > MAX_THICKNESS + 0.0005 or dims[1] * dims[2] < (SMALL_AREA if in_building else MIN_AREA):
            continue
        after = max(props[name][0] for name in BEFORE if name in props)
        lines.insert(after + 1, "breakable = true")
        parts[n] = "\n".join(lines)
        ticked[kind] = ticked.get(kind, 0) + 1
    with open(SCENE, "w") as fh:
        fh.write("".join(parts))
    print("ticked:", ", ".join("%s %d" % (k, ticked[k]) for k in sorted(ticked)) or "nothing")


if __name__ == "__main__":
    main()
