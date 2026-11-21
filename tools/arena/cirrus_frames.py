#!/usr/bin/env python3
"""Gives each of Cirrus's five buildings a MapFrame, so it can be brought down (run once:
it is kept as a record).

The buildings have no columns: they stand on their walls (MapFrame.held_by_walls). Each
frame goes inside its island, so its lines are in the island's own frame: three bays
along the front, two deep, and a level for each upper floor and the roof. This edits
game/maps/cirrus.tscn as text; an island that already has a Frame is left alone, but
for To The Ground, which it is given if it has not got it: the ground floor comes down
too, so a whole building can be levelled.

    python3 tools/arena/cirrus_frames.py
"""
import os

SCENE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "cirrus.tscn")
SCRIPT = '[ext_resource type="Script" path="res://game/arena/map_frame.gd" id="10_frame"]\n'
# island: (half the building's width between its side walls' middles, the tops of its upper floors and roof)
BUILDINGS = {
    "Observatory": (13.4, [5.5, 10.0]),
    "Labs": (14.0, [5.5, 11.95]),
    "LectureHall": (14.0, [5.5, 12.55]),
    "Cafeteria": (14.0, [5.5, 11.95]),
    "Library": (14.0, [5.5, 11.0, 18.35]),
}
FRONT, BACK = -1.4, 13.6   # the middles of the front and back walls
GROUND = "to_the_ground = true\nground = -0.5"   # (the walls stand on the deck, at 0)


def num(x):
    return ("%.2f" % x).rstrip("0").rstrip(".")


def main():
    with open(SCENE) as fh:
        text = fh.read()
    if SCRIPT not in text:
        last = text.rfind("[ext_resource ")
        end = text.index("\n", last) + 1
        text = text[:end] + SCRIPT + text[end:]
    for island, (half, tops) in BUILDINGS.items():
        have = '[node name="Frame" type="Node3D" parent="%s"]' % island
        if have in text:
            start = text.index(have)
            end = text.index("\n\n", start)
            if "to_the_ground" not in text[start:end]:
                text = text[:end] + "\n" + GROUND + text[end:]
                print("to the ground:", island)
            continue
        before = '[node name="Building" type="Node3D" parent="%s"]' % island
        assert text.count(before) == 1, island
        third = half * 2.0 / 3.0
        lines_x = [-half, -half + third, half - third, half]
        node = "\n".join([
            '[node name="Frame" type="Node3D" parent="%s"]' % island,
            'script = ExtResource("10_frame")',
            'parts = Array[NodePath]([NodePath("../Building")])',
            "lines_x = PackedFloat32Array(%s)" % ", ".join(num(x) for x in lines_x),
            "lines_z = PackedFloat32Array(%s)" % ", ".join(num(z) for z in [FRONT, (FRONT + BACK) / 2.0, BACK]),
            "floor_tops = PackedFloat32Array(%s)" % ", ".join(num(t) for t in tops),
            "held_by_walls = true",
            GROUND,
            "", ""])
        text = text.replace(before, node + before)
        print("framed", island)
    with open(SCENE, "w") as fh:
        fh.write(text)


if __name__ == "__main__":
    main()
