"""Builds the arena maps made from code: python3 tools/arena/build_arena_maps.py [name...]
(rail_yard, lost_temple, neon_arcade; all three when none are given). Writes
game/maps/NAME.tscn and game/maps/palettes/NAME.tres, overwriting any hand edits."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

import rail_yard  # noqa: E402

MAPS = {"rail_yard": rail_yard}
try:
    import lost_temple  # noqa: E402
    MAPS["lost_temple"] = lost_temple
except ImportError:
    pass
try:
    import neon_arcade  # noqa: E402
    MAPS["neon_arcade"] = neon_arcade
except ImportError:
    pass

if __name__ == "__main__":
    for name in sys.argv[1:] or list(MAPS):
        os.chdir(ROOT)
        MAPS[name].build("game/maps/%s.tscn" % name)
