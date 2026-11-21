#!/usr/bin/env python3
"""Ticks Breakable on Cirrus's walls, floors and panes (run once: it is kept as a record).

Cirrus was built with only the Labs' glass breakable. With fine destruction on, the walls
and floors of its buildings break too. This edits game/maps/cirrus.tscn as text: every
solid, drawn box of one of KINDS that is thin enough to break cell by cell (see
MapDestruction: one side at most 0.6 m, the face at least 7 square metres) gets
`breakable = true`. Blocks that already have it are left alone, so a second run changes
nothing.

    python3 tools/arena/cirrus_breakable.py
"""
import os
import re

SCENE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "cirrus.tscn")
KINDS = {"stone", "stone_warm", "floor_wood", "floor_tile", "glass_window", "glass_sky"}
MAX_THICKNESS = 0.6
MIN_AREA = 7.0
BEFORE = ("shape", "size", "kind", "solid", "drawn", "material_type")   # a block's settings that come before Breakable


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
        if kind not in KINDS or "breakable" in props:
            continue
        if props.get("shape", (0, "0"))[1] != "0" or props.get("solid", (0, "true"))[1] != "true" or props.get("drawn", (0, "true"))[1] != "true":
            continue
        size = re.match(r"Vector3\(([^)]*)\)", props.get("size", (0, "Vector3(1, 1, 1)"))[1])
        dims = sorted(float(v) for v in size.group(1).split(","))
        # (The game holds sizes in single precision, where 0.6 is a hair over 0.6: a block
        # exactly that thick, like the clock tower's walls, is too thick there.)
        if dims[0] >= MAX_THICKNESS or dims[1] * dims[2] < MIN_AREA:
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
