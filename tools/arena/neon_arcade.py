"""Neon Arcade: an arcade on a city block (about 82 x 70 m to walk, up to 12 players).

    python3 tools/arena/build_arena_maps.py neon_arcade

writes game/maps/neon_arcade.tscn and game/maps/palettes/neon_arcade.tres FROM SCRATCH. The
scene is an ordinary map scene and is what people edit afterwards (in the Godot editor), so
running this again OVERWRITES ANY HAND EDITS: only do it to rebuild the whole map on purpose.

The arcade (this file) is one hall, 42 x 30 m inside and 9.2 m high, its front (south) all
glass onto Main Street: rows of cabinets round a change booth, six pillars that hold the
roof, a mezzanine at 4.5 m round three sides behind glass railings with a party room, a
lounge, a claw alcove and a stock room under it, a stage, a prize counter, trusses at
7.4 m to stand on and grapple, two glazed skylights and a roof with the big sign. Ways
in: the front doors, a side entrance on the side street (east), a side door and the
fire escape in the alley (west: up to the mezzanine and on to the roof), the loading
door and a back door on the back lot (north).

The block round it (tools/arena/neon_arcade_block.py): Main Street along the front with a
diner, a laundromat and a pocket plaza across it; a side street east with a record
shop and a filling station; an alley west with a noodle bar; a back lot north.

Everything breaks the fine way (MapRoot.fine_destruction). The arcade and its four
neighbours are each a MapFrame held up by its walls: shoot enough of a wall away and what
it held comes down, to the ground. The arcade's roof also stands on its six pillars (real
columns: explosives and heavy rounds take them out), and the filling station's canopy on
four. Brick is chewed through by small arms, the roofs want explosives, floors of wood
and partitions go to anything, glass shatters a pane at a time.

Heights: floor 0, stage 0.6, booth roof 3, mezzanine 4.5, trusses 7.4-8, roof 9.6.
Machines, furniture and street furniture are in tools/arena/neon_arcade_kit.py.
"""
import math
import neon_arcade_kit as K
from neon_arcade_kit import ArcadeMap, At, PAL
import neon_arcade_block as block
import neon_arcade_details as details

X0, X1, Z0, Z1 = -21.0, 21.0, -15.0, 15.0     # inside faces of the arcade's outer walls
WT = 0.5                                       # how thick they are
OX0, OX1, OZ0, OZ1 = X0 - WT, X1 + WT, Z0 - WT, Z1 + WT          # their outside faces
WX0, WX1, WZ0, WZ1 = X0 - WT / 2, X1 + WT / 2, Z0 - WT / 2, Z1 + WT / 2   # their middles
MY = 4.5                                       # mezzanine floor
MZ, MXW, MXE, MZE = -9.0, -15.0, 15.0, 5.0     # its edges: north part z < MZ, west x < MXW, east x > MXE as far south as MZE
UNDER = MY - 0.3                               # its underside
RB, RT = 9.2, 9.6                              # roof slab
PT = 0.25                                      # partition walls
ROOM_Z = MZ - PT / 2                           # the middle of the rooms' front walls, under the mezzanine's edge
LX = [WX0, -10.5, 0.0, 10.5, WX1]              # the frame's lines: the outer walls and the pillars
LZ = [WZ0, -5.0, 5.0, WZ1]
SKY = [(-8.0, -2.5, -3.0, 3.0), (2.5, 8.0, -3.0, 3.0)]   # the skylights (x0, x1, z0, z1)


def build(path):
    m = ArcadeMap("NeonArcade", PAL,
                  {"sky": {}, "lines": ["ambient_light_source = 2", "ambient_light_color = Color(0.78, 0.74, 0.95, 1)",
                                        "ambient_light_energy = 1.05", "tonemap_mode = 2", "tonemap_white = 2.4",
                                        "ssao_enabled = true", "glow_enabled = true", "glow_intensity = 1.1"]},
                  (32, 250, (1.0, 0.72, 0.6), 0.9),
                  {"face_shade": "Vector3(0.93, 0.84, 0.66)", "decor_shadows": "false", "kill_height": "-6.0",
                   "bounds": "Rect2(%s, %s, %s, %s)" % (block.BX0 - 1, block.BZ0 - 1, block.BX1 - block.BX0 + 2, block.BZ1 - block.BZ0 + 2),
                   "fine_destruction": "true", "break_small_walls": "true", "swing_point": "Vector3(0, 7.4, 0)",
                   "metadata/breakable_migrated": "true"})
    m.folder("Ground")
    m.folder("Arcade")
    m.box("Ground", "ArcadeFloor", "carpet", (OX0, -0.5, OZ0), (OX1, 0, OZ1))
    shell(m)
    mezzanine(m)
    rooms(m)
    games(m)
    upstairs(m)
    roof(m)
    fire_escape(m)
    dressing(m)
    m.frame("ArcadeFrame", ["Arcade"], LX, LZ, [MY, RT], held_by_walls=True, to_the_ground=True, ground=-0.5,
            column_kind='"pillar"', column_health=700.0, cave_share=0.5, overhang=2.6)
    block.build(m)
    details.build(m)
    spawns(m)
    pickups(m)
    m.write(path)
    K.write_palette(path.replace("game/maps/", "game/maps/palettes/").replace(".tscn", ".tres"))


# ---------------------------------------------------------------------------
# The building

FRONT_PANES = ((-18.5, -15.0), (-15.0, -11.5), (-9.5, -6.25), (-6.25, -3.0), (3.0, 6.25), (6.25, 9.5), (11.5, 15.0), (15.0, 18.5))
FRONT_UPPER = ((-17.5, -12.5), (-8.5, -4.0), (4.0, 8.5), (12.5, 17.5))


def shell(m):
    w = m.folder("Walls", "Arcade")
    cut_x, cut_z = LX[1:-1], LZ[1:-1]
    # North (the back lot): the loading door and a back door.
    m.wall(w, "NorthWall", "brick", (OX0, WZ0), (OX1, WZ0), 0, RB, WT, inside="wall", side=1, cuts=cut_x,
           holes=[(-19.5, -16.5, 0, 3.2), (10.0, 11.4, 0, 2.6)])
    # South (Main Street): the shop front. Piers at the corners, either side of the doors
    # and under the pillar lines; glass between; a row of windows up on the mezzanine's level.
    holes = [(-18.5, -11.5, 0.6, 4.0), (-9.5, -3.0, 0.6, 4.0), (-2.0, 2.0, 0, 3.2), (3.0, 9.5, 0.6, 4.0), (11.5, 18.5, 0.6, 4.0)]
    holes += [(a, b, 5.6, 8.0) for a, b in FRONT_UPPER]
    m.wall(w, "FrontWall", "brick", (OX0, WZ1), (OX1, WZ1), 0, RB, WT, inside="wall", side=-1, cuts=cut_x, holes=holes)
    for (a, b) in FRONT_PANES:
        m.pane(w, "glass", "x", WZ1, a, b, 0.6, 4.0, bars=(1, 1))
    for (a, b) in FRONT_UPPER:
        m.pane(w, "glass", "x", WZ1, a, b, 5.6, 8.0, bars=(2, 0))
    for (a, b, y0, y1) in holes:
        m.trim(w, "x", WZ1, WT, a, b, y0, y1, sill=y0 > 0)
    # West (the alley): a side door, the mezzanine's door onto the fire escape, a high window.
    west = [(6.0, 7.6, 0, 2.6), (-6.2, -4.6, MY, MY + 2.5), (8.5, 12.5, 5.6, 8.0)]
    m.wall(w, "WestWall", "brick", (WX0, Z0), (WX0, Z1), 0, RB, WT, inside="wall", side=1, cuts=cut_z, holes=west)
    m.pane(w, "glass", "z", WX0, 8.5, 12.5, 5.6, 8.0, bars=(2, 0))
    # East (the side street): the lounge's fire door, the side entrance, two high windows.
    east = [(-13.0, -11.4, 0, 2.6), (11.0, 13.0, 0, 3.0), (-1.5, 2.5, 5.6, 8.0), (6.5, 10.5, 5.6, 8.0)]
    m.wall(w, "EastWall", "brick", (WX1, Z0), (WX1, Z1), 0, RB, WT, inside="wall", side=-1, cuts=cut_z, holes=east)
    for (a, b) in ((-1.5, 2.5), (6.5, 10.5)):
        m.pane(w, "glass", "z", WX1, a, b, 5.6, 8.0, bars=(2, 0))
    for line, hs in ((WX0, west), (WX1, east)):
        for (a, b, y0, y1) in hs:
            m.trim(w, "z", line, WT, a, b, y0, y1, sill=y0 > 0 and y0 != MY)
    m.trim(w, "x", WZ0, WT, -19.5, -16.5, 0, 3.2, sill=False)
    m.trim(w, "x", WZ0, WT, 10.0, 11.4, 0, 2.6, sill=False)
    # The six pillars: with the outer walls they hold the roof up (the frame's columns).
    p = m.folder("Pillars", "Arcade")
    for x in cut_x:
        for z in cut_z:
            m.box(p, "Pillar", "pillar", (x - 0.4, 0, z - 0.4), (x + 0.4, RB, z + 0.4))
    # Trusses under the roof, on the pillar lines: stand on them or hook them.
    t = m.folder("Trusses", "Arcade")
    for z in cut_z:
        m.box(t, "Truss", "truss", (X0, 7.4, z - 0.2), (X1, 8.0, z + 0.2))
    for x in cut_x:
        m.box(t, "Truss", "truss", (x - 0.2, 7.4, Z0), (x + 0.2, 8.0, cut_z[0] - 0.2))
        m.box(t, "Truss", "truss", (x - 0.2, 7.4, cut_z[0] + 0.2), (x + 0.2, 8.0, cut_z[1] - 0.2))
        m.box(t, "Truss", "truss", (x - 0.2, 7.4, cut_z[1] + 0.2), (x + 0.2, 8.0, Z1))
    m.box(t, "LightBar", "truss", (10.7, 7.4, 8.2), (X1, 7.7, 8.6))
    # The canopy over the front doors.
    c = m.group("Marquee", "Arcade")
    zf = OZ1 + 2.6
    m.box(c, "Canopy", "cab_black", (-5.0, 3.5, OZ1), (5.0, 3.95, zf))
    for k in range(9):
        for j in range(2):
            m.strip(c, "Bulb", "marquee", (-4.3 + k * 1.05, 3.44, OZ1 + 0.6 + j * 1.2), (-4.1 + k * 1.05, 3.5, OZ1 + 0.8 + j * 1.2))
    for (y0, y1, kind) in ((3.5, 3.58, "neon_pink"), (3.87, 3.95, "neon_cyan")):
        m.on_wall(c, "CanopyNeon", kind, "x", zf, 1, -5.0, 5.0, y0, y1, 0.05)
        for (face, out) in ((-5.0, -1), (5.0, 1)):
            m.on_wall(c, "CanopyNeon", kind, "z", face, out, OZ1, zf, y0, y1, 0.05)
    m.text(c, "OPEN 24 HRS", "x", zf, 1, 0.0, 3.6, 0.036, "neon_yellow", depth=0.04)
    for x in (-4.4, 4.4):
        m.rod(c, "CanopyStay", "steel", (x, 3.95, zf - 0.3), (x, 5.6, OZ1 + 0.02), thick=0.06)
    # The canopy over the loading door, and the shutter rolled up above it.
    c = m.group("DockCanopy", "Arcade")
    m.box(c, "Canopy", "steel", (-20.6, 3.5, OZ0 - 2.6), (-15.4, 3.7, OZ0))
    for x in (-20.3, -15.7):
        m.rod(c, "CanopyStay", "steel", (x, 3.7, OZ0 - 2.4), (x, 5.0, OZ0 - 0.02), thick=0.06)
    m.on_wall(c, "CanopyLamp", "lamp", "x", OZ0, -1, -19.0, -17.0, 3.3, 3.42, 0.1)
    m.on_wall(w, "ShutterRoll", "shutter", "x", Z0, 1, -19.6, -16.4, 3.25, 3.75, 0.3)


def rail_run(m, g, axis, line, c0, c1, neon):
    """Glass railing along the mezzanine's edge from c0 to c1: panes of about 3 m, a lit handrail on each."""
    n = max(1, int(math.ceil((c1 - c0) / 3.2 - 1e-6)))
    for k in range(n):
        a, b = c0 + (c1 - c0) * k / n, c0 + (c1 - c0) * (k + 1) / n
        if axis == "x":
            m.box(g, "Railing", "glass_rail", (a, MY, line - 0.05), (b, MY + 1.1, line + 0.05), breaks=True)
            m.strip(g, "Handrail", neon, (a + 0.02, MY + 1.1, line - 0.04), (b - 0.02, MY + 1.17, line + 0.04))
        else:
            m.box(g, "Railing", "glass_rail", (line - 0.05, MY, a), (line + 0.05, MY + 1.1, b), breaks=True)
            m.strip(g, "Handrail", neon, (line - 0.04, MY + 1.1, a + 0.02), (line + 0.04, MY + 1.17, b - 0.02))


def mezzanine(m):
    g = m.folder("Mezzanine", "Arcade")
    cut_x, cut_z = LX[1:-1], LZ[1:-1]
    m.deck(g, "FloorNorth", "mezz_floor", X0, X1, Z0, MZ, MY, 0.3, cuts_x=cut_x, under="ceiling")
    m.deck(g, "FloorWest", "mezz_floor", X0, MXW, MZ, Z1, MY, 0.3, cuts_z=cut_z, under="ceiling")
    m.deck(g, "FloorEast", "mezz_floor", MXE, X1, MZ, MZE, MY, 0.3, cuts_z=cut_z, under="ceiling")
    # Edge beams under it, and the posts they stand on where no room's wall does.
    b = m.group("Beams", g)
    m.box(b, "EdgeBeam", "steel", (MXW, UNDER - 0.4, MZ - 0.4), (MXE, UNDER, MZ - 0.02))
    m.box(b, "EdgeBeam", "steel", (MXW - 0.4, UNDER - 0.4, MZ), (MXW, UNDER, Z1))
    m.box(b, "EdgeBeam", "steel", (MXE, UNDER - 0.4, MZ), (MXE + 0.4, UNDER, MZE))
    m.box(b, "EdgeBeam", "steel", (MXE + 0.4, UNDER - 0.4, MZE - 0.4), (X1, UNDER, MZE))
    for x in (-9.0,):
        m.box(b, "Post", "steel", (x - 0.15, 0, MZ - 0.35), (x + 0.15, UNDER - 0.4, MZ - 0.05))
    for z in (-4.5, 0.5, 5.5, 8.3, 11.7, 14.7):
        m.box(b, "Post", "steel", (MXW - 0.35, 0, z - 0.15), (MXW - 0.05, UNDER - 0.4, z + 0.15))
    for z in (-4.5, 0.0, 4.75):
        m.box(b, "Post", "steel", (MXE + 0.05, 0, z - 0.15), (MXE + 0.35, UNDER - 0.4, z + 0.15))
    # Glass railings, open where the stairs arrive.
    r = m.folder("Railings", g)
    rail_run(m, r, "x", MZ - 0.06, MXW, 11.6, "neon_cyan")
    rail_run(m, r, "x", MZ - 0.06, 14.0, MXE, "neon_cyan")
    rail_run(m, r, "z", MXW - 0.06, MZ, 8.8, "neon_pink")
    rail_run(m, r, "z", MXW - 0.06, 11.2, Z1 - 0.06, "neon_pink")
    rail_run(m, r, "z", MXE + 0.06, MZ, MZE, "neon_yellow")
    rail_run(m, r, "x", MZE - 0.06, MXE + 0.11, X1 - 0.08, "neon_yellow")
    # Two stairs up from the hall.
    m.stairs(g, "StairsWest", (-7.0, 0, 10.0), (MXW, MY, 10.0), 2.4, kind="steel", side="truss", base=0, cheek_stop=0.14)
    m.stairs(g, "StairsEast", (12.8, 0, -1.0), (12.8, MY, MZ), 2.4, kind="steel", side="truss", base=0, cheek_stop=0.14)
    # Lights under it: flat on its underside, so they break with it.
    for x in range(-19, 20, 4):
        K.tube_light(m, g, (x - 0.7, -12.2), (x + 0.7, -11.9), UNDER)
    for z in range(-6, 14, 4):
        K.tube_light(m, g, (-18.15, z - 0.7), (-17.85, z + 0.7), UNDER)
    for z in (-6, -2, 2):
        K.tube_light(m, g, (17.85, z - 0.7), (18.15, z + 0.7), UNDER)


def rooms(m):
    """Under the north mezzanine: a stock room, the claw alcove, the party room and a lounge."""
    g = m.folder("Rooms", "Arcade")
    H = UNDER
    kw = dict(thick=PT)
    # Front walls, under the mezzanine's edge.
    m.wall(g, "StockFront", "partition", (X0, ROOM_Z), (-14.0, ROOM_Z), 0, H, holes=[(-18.5, -17.1, 0, 2.6)], **kw)
    m.wall(g, "PartyFront", "partition", (-4.0, ROOM_Z), (8.0, ROOM_Z), 0, H, holes=[(-2.6, 1.0, 1.0, 2.8), (4.6, 6.2, 0, 2.6)], **kw)
    m.wall(g, "LoungeFront", "partition", (8.0, ROOM_Z), (X1, ROOM_Z), 0, H, holes=[(8.8, 10.4, 0, 2.6), (17.0, 18.6, 0, 2.6)], **kw)
    m.pane(g, "glass", "x", ROOM_Z, -2.6, 1.0, 1.0, 2.8, bars=(1, 0))
    # Walls between them.
    m.wall(g, "StockSide", "partition", (-14.0 + PT / 2, Z0), (-14.0 + PT / 2, MZ - PT), 0, H, holes=[(-12.6, -11.2, 0, 2.6)], **kw)
    m.wall(g, "PartySide", "partition", (-4.0 + PT / 2, Z0), (-4.0 + PT / 2, MZ - PT), 0, H, **kw)
    m.wall(g, "PartySide", "partition", (8.0 - PT / 2, Z0), (8.0 - PT / 2, MZ - PT), 0, H, **kw)
    for (a, b, top) in ((-18.5, -17.1, 2.6), (4.6, 6.2, 2.6), (8.8, 10.4, 2.6), (17.0, 18.6, 2.6)):
        m.trim(g, "x", ROOM_Z, PT, a, b, 0, top, sill=False, kind="neon_pink", wide=0.06, proud=0.03, sides=(1,))
    m.trim(g, "x", ROOM_Z, PT, -2.6, 1.0, 1.0, 2.8, kind="neon_cyan", wide=0.06, proud=0.03, sides=(1,))
    m.text(g, "PARTY", "x", MZ, 1, 2.9, 3.05, 0.07, "neon_pink", depth=0.04)
    m.text(g, "LOUNGE", "x", MZ, 1, 13.9, 3.05, 0.07, "neon_cyan", depth=0.04)
    m.text(g, "STAFF", "x", MZ, 1, -17.8, 3.05, 0.06, "neon_yellow", depth=0.04)

    # Stock room: racks of boxes down the west wall, pallets, crates by the loading door.
    s = m.folder("StockRoom", g)
    for z in (-13.4, -11.2):
        a = At(m, m.group("Rack", s), (X0 + 0.45, 0, z), "+x")
        for sx in (-0.9, 0.9):
            a.s("Upright", "steel", (sx - 0.04, 0, -0.4), (sx + 0.04, 3.26, 0.4))
        for k, y in enumerate((0.5, 1.4, 2.3, 3.2)):
            a.s("Shelf", "shelf", (-0.97, y - 0.06, -0.42), (0.97, y, 0.42))
            if k < 3:
                for j in range(3):
                    sz = 0.42 + 0.08 * ((k + j) % 3)
                    a.b("Box", "cardboard", (-0.8 + j * 0.6, y, -0.3), (-0.8 + j * 0.6 + sz, y + sz, 0.3),
                        tint=(1, 1, 1) if (k + j) % 2 else (0.88, 0.88, 0.88))
    K.pallet(m, s, -15.2, -13.6, load="cardboard")
    K.pallet(m, s, -15.2, -10.6, load="cab_blue")
    K.crate(m, s, -19.9, -10.0, size=1.0)
    K.crate(m, s, -15.0, -12.0, size=0.8)
    K.boxes(m, s, -17.4, -9.9, n=3, seed=2)

    # The claw alcove.
    c = m.folder("ClawAlcove", g)
    for k, x in enumerate((-12.6, -10.5, -8.4, -6.3)):
        K.claw_machine(m, c, x, -14.25, "+z", kind=("cab_yellow", "cab_purple", "cab_green", "cab_red")[k],
                       neon=("neon_pink", "neon_cyan", "neon_yellow", "neon_green")[k])
    m.strip(c, "AlcoveRug", "carpet_teal", (-13.6, 0, -13.2), (-4.4, 0.02, -9.6))

    # The party room.
    r = m.folder("PartyRoom", g)
    a = K.table(m, r, 2.0, -12.2, wide=4.2, deep=1.3)
    for k in range(4):
        K.chair(m, r, 0.5 + k * 1.0, -11.2, "-z", seat=("prize", "prize_blue", "prize_green", "prize_pink")[k])
        K.chair(m, r, 0.5 + k * 1.0, -13.2, "+z", seat=("prize_pink", "prize_green", "prize_blue", "prize")[k])
    cake = m.group("Cake", r)
    m.cyl(cake, "Cake", "counter", (2.0, 0.76, -12.2), 0.5, 0.2, sides=12, solid=False)
    m.cyl(cake, "CakeTop", "hockey", (2.0, 0.96, -12.2), 0.42, 0.05, sides=12, solid=False)
    for dx in (-0.1, 0.0, 0.1):
        m.strip(cake, "Candle", "neon_yellow", (1.985 + dx, 1.01, -12.215), (2.015 + dx, 1.13, -12.185))
    for (px, pz) in ((0.5, -12.5), (1.2, -11.9), (2.9, -12.5), (3.5, -11.9)):
        m.cyl(cake, "Plate", "hockey", (px, 0.76, pz), 0.26, 0.03, sides=10, solid=False)
        m.cyl(cake, "Cup", "prize_blue", (px + 0.24, 0.76, pz + 0.1), 0.08, 0.12, sides=6, solid=False)
    K.sofa(m, r, 6.4, -14.3, "+z", wide=2.4, kind="sofa_red")
    K.boxes(m, r, -3.0, -14.2, n=3, kind="prize_pink", seed=1)
    K.plant(m, r, 7.2, -10.0, size=0.9, kind="leaves_pink")
    d = m.group("Details", r)
    kinds = ("prize", "prize_blue", "counter", "sofa", "cab_yellow")
    x, k = -3.4, 0
    while x < 7.4:
        m.on_wall(d, "Bunting", kinds[k % 5], "x", Z0, 1, x, x + 0.3, 3.0 + 0.1 * (k % 2), 3.4, 0.03)
        x += 0.55
        k += 1
    m.on_wall(d, "BuntingLine", "table", "x", Z0, 1, -3.6, 7.6, 3.4, 3.43, 0.02)
    for (bx, bz, by, kind) in ((0.4, -13.9, 2.3, "prize_blue"), (3.6, -14.0, 2.6, "cab_yellow"), (-3.2, -10.2, 2.4, "prize_pink"),
                               (7.3, -13.2, 2.8, "prize")):
        b = m.group("Balloon", r)
        m.dome(b, "Balloon", kind, (bx, by + 0.22, bz), (0.44, 0.26, 0.44), sides=8, solid=False)
        m.dome(b, "Balloon", kind, (bx, by + 0.22, bz), (0.44, 0.22, 0.44), sides=8, flip=True, solid=False)
        m.strip(b, "BalloonString", "table", (bx - 0.01, 0, bz - 0.01), (bx + 0.01, by, bz + 0.01))

    # The lounge: sofas round low tables, vending machines along the back wall.
    l = m.folder("Lounge", g)
    m.strip(l, "LoungeRug", "carpet_teal", (12.0, 0, -14.4), (20.4, 0.02, -9.8))
    for k, x in enumerate((12.6, 14.0, 15.4)):
        K.vending(m, l, x, -14.5, "+z", ("cab_red", "cab_blue", "cab_green")[k])
    K.sofa(m, l, 18.2, -14.3, "+z", wide=2.6)
    K.sofa(m, l, 20.3, -11.0, "-x", wide=2.2)
    K.round_table(m, l, 18.3, -12.4, d=1.1, height=0.5)
    K.sofa(m, l, 14.6, -10.2, "-z", wide=2.6, kind="sofa_red")
    K.round_table(m, l, 14.6, -12.0, d=1.0, height=0.5)
    K.plant(m, l, 20.3, -14.3, size=1.1)
    K.plant(m, l, 8.8, -14.3, size=1.0)
    K.bin_(m, l, 11.8, -14.4)
    for (x, z) in ((14.6, -12.0), (18.3, -12.4)):
        K.ceiling_lamp(m, l, x, H, z, drop=0.6, d=0.7, kind="neon_pink")


def games(m):
    f = m.folder("Games", "Arcade")
    kinds = ["cab_red", "cab_blue", "cab_black", "cab_yellow", "cab_green", "cab_purple"]
    screens = ["screen", "screen_pink", "screen_green"]
    neons = ["neon_cyan", "neon_pink", "neon_yellow", "neon_green"]
    # Four rows of cabinets back to back, between the pillars.
    r = m.folder("Rows", f)
    i = 0
    for zc in (-5.0, 5.0):
        for s in (-1, 1):
            xs = [s * (1.3 + 1.3 * k) for k in range(7)]
            for x in xs:
                K.cabinet(m, r, x, zc - 0.47, "-z", kinds[i % 6], screen=screens[i % 3], neon=neons[i % 4])
                K.cabinet(m, r, x, zc + 0.47, "+z", kinds[(i + 3) % 6], screen=screens[(i + 1) % 3], neon=neons[(i + 2) % 4])
                i += 1
            a, b = min(xs) - 0.5, max(xs) + 0.5
            m.strip(r, "RowLight", "neon_yellow" if zc < 0 else "neon_pink", (a, 2.1, zc - 0.06), (b, 2.22, zc + 0.06))
    # The change booth in the middle: climb onto its roof.
    b = m.group("ChangeBooth", f)
    m.box(b, "Booth", "counter", (-2.0, 0, -1.5), (2.0, 2.7, 1.5))
    m.box(b, "Roof", "steel", (-2.2, 2.7, -1.7), (2.2, 3.0, 1.7))
    for (face, out) in ((1.5, 1), (-1.5, -1)):
        m.on_wall(b, "Window", "screen", "x", face, out, -1.4, 1.4, 1.2, 2.1, 0.05)
        m.on_wall(b, "Ledge", "steel", "x", face, out, -1.5, 1.5, 1.08, 1.16, 0.24)
        m.on_wall(b, "Bars", "frame", "x", face, out, -0.03, 0.03, 1.2, 2.1, 0.03, lift=0.05)
        m.text(b, "TOKENS", "x", face, out, 0.0, 2.24, 0.05, "neon_white", depth=0.04)
        m.on_wall(b, "Neon", "neon_green", "x", face + out * 0.2, out, -2.2, 2.2, 2.8, 2.92, 0.05)
    for (face, out) in ((2.0, 1), (-2.0, -1)):
        m.on_wall(b, "Neon", "neon_green", "z", face + out * 0.2, out, -1.7, 1.7, 2.8, 2.92, 0.05)
        a = sorted((face, face + out * 0.05))
        m.pipe(b, "Coin", "cab_yellow", (a[0], 1.5, 0), (a[1], 1.5, 0), 1.1, sides=16)
        a = sorted((face + out * 0.05, face + out * 0.08))
        m.pipe(b, "CoinInner", "prize", (a[0], 1.5, 0), (a[1], 1.5, 0), 0.7, sides=16)
    # Skee-ball lanes (north-west of the hall).
    s = m.folder("SkeeBall", f)
    for k, x in enumerate((-13.9, -12.7, -11.5)):
        K.skee_ball(m, s, x, -5.6, "-z", neon=("neon_orange", "neon_cyan", "neon_pink")[k])
    # Air hockey.
    K.air_hockey(m, f, -4.2, 10.6, along="x")
    K.air_hockey(m, f, 4.6, 8.7, along="x")
    # Racing games, facing the shop front.
    for k, x in enumerate((6.6, 8.1, 9.6, 11.1)):
        K.racer(m, f, x, 12.5, "+z", ("cab_red", "cab_blue", "cab_yellow", "cab_green")[k])
    # Hoops in the south-west corner.
    for x in (-13.4, -12.0, -10.6):
        K.hoops(m, f, x, 13.3, "-z")
    # By the doors: token machines and a photo booth.
    K.token_machine(m, f, -2.9, 14.6, "-z")
    K.token_machine(m, f, 2.9, 14.6, "-z")
    K.photo_booth(m, f, 4.6, 14.1, "-z")
    # Pinball down the west wall, under the mezzanine.
    p = m.folder("Pinball", f)
    for k, z in enumerate((-7.6, -6.1, -4.6, -3.1, -1.6, -0.1, 1.4, 2.9, 4.4, 9.4, 10.9, 12.4, 13.9)):
        K.pinball(m, p, X0 + 0.75, z, "+x", ("cab_blue", "cab_red", "cab_purple", "cab_green")[k % 4])
    # The stage (south-east): two dance machines, a ramp up its west side, a mirror ball over it.
    st = m.group("Stage", f)
    m.box(st, "Stage", "stage", (15.5, 0, 5.9), (20.9, 0.6, 11.0))
    m.slab(st, "Ramp", "stage", (15.5, 0.6, 8.45), (13.7, 0, 8.45), 5.1, thick=0.3)
    for (face, out) in ((5.9, -1), (11.0, 1)):
        m.on_wall(st, "EdgeLight", "neon_pink", "x", face, out, 15.5, 20.9, 0.44, 0.54, 0.03)
    for z in (7.1, 9.8):
        K.dance_machine(m, f, 19.0, z, "-x", y=0.6)
    ball = m.group("MirrorBall", "Arcade/Trusses")
    m.pipe(ball, "MirrorBallRod", "steel", (17.6, 6.9, 8.4), (17.6, 7.4, 8.4), 0.05)
    m.dome(ball, "MirrorBall", "hockey", (17.6, 6.5, 8.4), (0.8, 0.4, 0.8), sides=10, solid=False)
    m.dome(ball, "MirrorBall", "hockey", (17.6, 6.5, 8.4), (0.8, 0.4, 0.8), sides=10, flip=True, solid=False)
    m.cyl(ball, "MirrorBallBand", "screen", (17.6, 6.44, 8.4), 0.84, 0.12, sides=10, solid=False)
    # The prize counter under the east mezzanine: vault it to get behind.
    pc = m.folder("PrizeCounter", f)
    c = m.group("Counter", pc)
    for (z0, z1) in ((-8.6, -4.8), (-4.2, -1.0), (0.4, 4.4)):
        m.bev(c, "Counter", "counter", (15.45, 0, z0), (16.05, 1.1, z1), 0.04)
        m.strip(c, "CounterTop", "neon_pink", (15.4, 1.1, z0 - 0.02), (16.1, 1.16, z1 + 0.02))
        m.on_wall(c, "CounterGlass", "screen", "z", 15.45, -1, z0 + 0.3, z1 - 0.3, 0.3, 0.8, 0.03)
    sh = m.group("Shelves", pc)
    m.box(sh, "Shelves", "shelf", (20.3, 0, -8.6), (X1, 3.6, 4.4))
    toys = ("prize", "prize_blue", "prize_green", "prize_pink", "cab_yellow", "sofa")
    for row, y in enumerate((0.6, 1.5, 2.4, 3.3)):
        m.on_wall(sh, "ShelfBoard", "counter", "z", 20.3, -1, -8.5, 4.3, y - 0.06, y, 0.45)
        for k in range(14):
            z = -8.1 + k * 0.9
            sz = 0.17 + 0.05 * ((k + row) % 3)
            if row < 3:
                kind = toys[(k * 5 + row) % 6]
                if (k + row) % 3 == 0:
                    m.dome(sh, "Toy", kind, (20.05, y + sz, z), (sz * 2, sz, sz * 2), sides=6, solid=False)
                    m.dome(sh, "Toy", kind, (20.05, y + sz, z), (sz * 2, sz, sz * 2), sides=6, flip=True, solid=False)
                else:
                    m.strip(sh, "Toy", kind, (19.95, y, z - sz), (20.25, y + sz * 2.2, z + sz))
    m.text(pc, "PRIZES", "z", MXE, -1, -2.0, UNDER - 0.38, 0.05, "neon_yellow", depth=0.04)
    for k, z in enumerate((-6.6, -2.6, 2.4)):
        K.stool(m, pc, 17.6, z, kind=("prize_pink", "prize_blue", "prize_green")[k])
    reg = m.group("Till", pc)
    m.strip(reg, "Till", "cab_black", (15.55, 1.16, -3.0), (15.95, 1.42, -2.4))
    m.strip(reg, "TillScreen", "screen_green", (15.5, 1.3, -2.9), (15.56, 1.5, -2.5))
    m.cyl(reg, "TicketRoll", "paper", (15.75, 1.16, -6.6), 0.3, 0.16, sides=10, solid=False)


def upstairs(m):
    """On the mezzanine."""
    g = m.folder("Upstairs", "Arcade")
    kinds = ["cab_purple", "cab_green", "cab_red", "cab_blue", "cab_yellow", "cab_black"]
    # North: a row of cabinets against the back wall, a sofa corner, the VR corner.
    for k in range(6):
        K.cabinet(m, g, -10.6 + k * 1.3, Z0 + 0.5, "+z", kinds[k], y=MY, screen=("screen", "screen_pink", "screen_green")[k % 3],
                  neon=("neon_pink", "neon_cyan")[k % 2])
    K.sofa(m, g, -18.2, Z0 + 0.55, "+z", wide=2.6, y=MY)
    K.sofa(m, g, X0 + 0.55, -11.6, "+x", wide=2.4, y=MY, kind="sofa_red")
    K.round_table(m, g, -18.4, -12.0, y=MY, d=1.0, height=0.5)
    K.plant(m, g, X0 + 0.6, Z0 + 0.6, y=MY, size=1.0)
    vr = m.folder("VR", g)
    for k, x in enumerate((1.5, 4.5, 7.5)):
        neon = ("neon_green", "neon_cyan", "neon_purple")[k]
        pod = m.group("VRPod", vr)
        m.cyl(pod, "Mat", "cab_black", (x, MY, -12.4), 2.2, 0.03, sides=16, solid=False)
        m.pipe(pod, "Ring", neon, (x, MY + 0.03, -12.4), (x, MY + 0.06, -12.4), 2.2, sides=16, inner=2.0)
        m.cyl(pod, "Stand", "steel", (x + 0.9, MY, -14.2), 0.1, 1.3, sides=6, solid=False)
        m.bev(pod, "Headset", "cab_black", (x + 0.72, MY + 1.3, -14.34), (x + 1.08, MY + 1.5, -14.06), 0.04, solid=False)
        m.strip(pod, "Visor", neon, (x + 0.76, MY + 1.36, -14.07), (x + 1.04, MY + 1.46, -14.03))
        m.on_wall(pod, "VRScreen", "screen", "x", Z0, 1, x - 1.0, x + 1.0, MY + 1.5, MY + 2.7, 0.05)
    m.text(vr, "VR", "x", Z0, 1, 4.5, MY + 3.0, 0.1, "neon_green", depth=0.05)
    K.sofa(m, g, 12.5, Z0 + 0.55, "+z", wide=2.4, y=MY)
    K.vending(m, g, 10.2, Z0 + 0.45, "+z", "cab_purple", y=MY)
    # West: cabinets along the wall, a sofa, a table by the high window.
    for k, z in enumerate((-2.4, -1.1, 0.2, 1.5)):
        K.cabinet(m, g, X0 + 0.5, z, "+x", kinds[(k + 2) % 6], y=MY, screen=("screen_pink", "screen")[k % 2], neon="neon_yellow")
    K.sofa(m, g, X0 + 0.55, 4.6, "+x", wide=2.4, y=MY)
    K.round_table(m, g, -18.4, 13.0, y=MY, d=1.1)
    for (dx, dz) in ((-0.9, 0), (0.9, 0), (0, -0.9)):
        K.stool(m, g, -18.4 + dx, 13.0 + dz, y=MY, kind="prize_blue")
    K.plant(m, g, X0 + 0.6, 14.3, y=MY, size=1.1, kind="leaves_pink")
    K.bin_(m, g, -15.6, -8.2, y=MY)
    # East: a snack bar with stools, cabinets along the wall.
    bar = m.group("SnackBar", g)
    m.bev(bar, "Bar", "counter", (16.3, MY, -3.0), (16.9, MY + 1.1, 3.4), 0.04)
    m.strip(bar, "BarTop", "neon_cyan", (16.25, MY + 1.1, -3.02), (16.95, MY + 1.16, 3.42))
    for k in range(5):
        m.cyl(bar, "Cup", ("prize", "prize_blue", "prize_pink")[k % 3], (16.6, MY + 1.16, -2.4 + k * 1.3), 0.1, 0.16, sides=6, solid=False)
    for z in (-2.2, -0.6, 1.0, 2.6):
        K.stool(m, g, 15.7, z, y=MY, kind="prize_pink")
    for k, z in enumerate((-7.8, -6.5, -5.2)):
        K.cabinet(m, g, X1 - 0.5, z, "-x", kinds[k], y=MY, screen=("screen_green", "screen")[k % 2], neon="neon_pink")
    back = m.group("BarBack", g)
    m.box(back, "BarBack", "shelf", (X1 - 0.5, MY, -3.0), (X1, MY + 2.2, 3.4))
    for row, y in enumerate((MY + 1.0, MY + 1.6)):
        m.on_wall(back, "BarShelf", "neon_pink", "z", X1 - 0.5, -1, -2.9, 3.3, y - 0.05, y, 0.3)
        for k in range(10):
            m.strip(back, "Bottle", ("prize_green", "prize", "prize_blue", "screen_pink")[(k + row) % 4],
                    (X1 - 0.72, y, -2.7 + k * 0.62), (X1 - 0.6, y + 0.34, -2.58 + k * 0.62))


def roof(m):
    g = m.folder("Roof", "Arcade")
    cut_x, cut_z = LX[1:-1], LZ[1:-1]
    m.deck(g, "Roof", "roof", OX0, OX1, OZ0, OZ1, RT, RT - RB, holes=SKY, cuts_x=cut_x, cuts_z=cut_z, under="ceiling")
    # The skylights: four panes each in a steel grid, a kerb round the opening.
    for (x0, x1, z0, z1) in SKY:
        xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
        for (a, b) in ((x0, xm), (xm, x1)):
            for (c, d) in ((z0, zm), (zm, z1)):
                m.box(g, "Skylight", "glass", (a, RT - 0.16, c), (b, RT - 0.06, d), breaks=True)
        k = m.group("SkylightKerb", g)
        for (lo, hi) in (((x0 - 0.2, z0 - 0.2), (x1 + 0.2, z0)), ((x0 - 0.2, z1), (x1 + 0.2, z1 + 0.2)),
                         ((x0 - 0.2, z0), (x0, z1)), ((x1, z0), (x1 + 0.2, z1))):
            m.box(k, "Kerb", "steel", (lo[0], RT, lo[1]), (hi[0], RT + 0.3, hi[1]))
        m.strip(k, "SkylightBar", "frame", (xm - 0.05, RT - 0.06, z0), (xm + 0.05, RT + 0.04, z1))
        m.strip(k, "SkylightBar", "frame", (x0, RT - 0.06, zm - 0.05), (xm - 0.05, RT + 0.04, zm + 0.05))
        m.strip(k, "SkylightBar", "frame", (xm + 0.05, RT - 0.06, zm - 0.05), (x1, RT + 0.04, zm + 0.05))
    # The parapet, open at the north-west corner where the fire escape arrives.
    p = m.folder("Parapet", g)
    top = RT + 1.0
    m.wall(p, "Parapet", "brick", (-19.5, OZ0 + 0.15), (OX1, OZ0 + 0.15), RT, top, 0.3, cuts=cut_x)
    m.wall(p, "Parapet", "brick", (OX0, OZ1 - 0.15), (OX1, OZ1 - 0.15), RT, top, 0.3, cuts=cut_x)
    m.wall(p, "Parapet", "brick", (OX0 + 0.15, OZ0), (OX0 + 0.15, OZ1 - 0.3), RT, top, 0.3, cuts=cut_z)
    m.wall(p, "Parapet", "brick", (OX1 - 0.15, OZ0 + 0.3), (OX1 - 0.15, OZ1 - 0.3), RT, top, 0.3, cuts=cut_z)
    # Plant on the roof.
    K.ac_unit(m, g, -15.0, -11.0, RT)
    K.ac_unit(m, g, -11.0, -11.0, RT)
    K.ac_unit(m, g, 15.0, -10.5, RT, face="+x")
    K.ac_unit(m, g, -16.0, 9.0, RT, face="-x", size=(2.0, 1.3, 1.8))
    K.water_tank(m, g, 15.5, 8.5, RT)
    v = m.group("Vent", g)
    m.box(v, "Vent", "steel", (13.0, RT, -2.0), (14.0, RT + 2.4, -1.0))
    m.strip(v, "VentCap", "steel", (12.85, RT + 2.4, -2.15), (14.15, RT + 2.55, -0.85))
    h = m.group("Hatch", g)
    m.box(h, "Hatch", "steel", (-2.0, RT, -11.0), (0.0, RT + 0.5, -9.0))
    m.strip(h, "HatchLid", "hazard", (-2.05, RT + 0.5, -11.05), (0.05, RT + 0.56, -8.95))
    mast = m.group("Mast", g)
    m.cyl(mast, "Mast", "steel", (19.0, RT, -13.0), 0.16, 6.0, sides=6)
    m.strip(mast, "Beacon", "beacon", (18.8, RT + 6.0, -13.2), (19.2, RT + 6.4, -12.8))
    for y in (RT + 3.0, RT + 4.5):
        m.strip(mast, "Aerial", "steel", (18.3, y, -13.03), (19.7, y + 0.06, -12.97))
    # The big sign along the front edge.
    s = m.group("BigSign", g)
    zs = OZ1 - 0.6
    for x in (-9.0, -3.0, 3.0, 9.0):
        m.box(s, "SignLeg", "truss", (x - 0.15, RT, zs - 0.15), (x + 0.15, RT + 1.2, zs + 0.15))
        m.rod(s, "SignStay", "truss", (x, RT + 3.4, zs - 0.1), (x, RT, zs - 2.4), thick=0.08)
    m.box(s, "SignBoard", "cab_black", (-10.0, RT + 1.2, zs - 0.1), (10.0, RT + 4.4, zs + 0.1))
    K.neon_box(m, s, "x", zs + 0.1, 1, -9.9, 9.9, RT + 1.3, RT + 4.3, "neon_cyan", wide=0.12)
    m.text(s, "NEON", "x", zs + 0.1, 1, -5.85, RT + 1.75, 0.3, "neon_pink", depth=0.08)
    m.text(s, "ARCADE", "x", zs + 0.1, 1, 4.05, RT + 1.75, 0.3, "neon_cyan", depth=0.08)


def fire_escape(m):
    """In the alley, up the west wall: ground to the mezzanine's door, then on up to the roof."""
    g = m.folder("FireEscape", "Arcade")
    xa, xb = OX0 - 2.0, OX0
    xm = (xa + xb) / 2
    K.flight(m, g, "Flight1", (xm, 0, 4.5), (xm, MY, -3.5), 1.8)
    l1 = m.group("Landing1", g)
    m.box(l1, "Landing", "grate", (xa, MY - 0.15, -7.0), (xb, MY, -3.5))
    K.flight(m, g, "Flight2", (xm, MY, -7.0), (xm, RT, OZ0), 1.8)
    l2 = m.group("Landing2", g)
    m.box(l2, "Landing", "grate", (xa, RT - 0.15, OZ0 - 2.0), (-19.5, RT, OZ0))
    for (l, y, spots) in ((l1, MY, ((xa + 0.1, -6.9), (xa + 0.1, -3.6))), (l2, RT, ((xa + 0.1, OZ0 - 1.9), (-19.6, OZ0 - 1.9)))):
        for (x, z) in spots:
            m.box(l, "Leg", "steel", (x - 0.08, 0, z - 0.08), (x + 0.08, y - 0.15, z + 0.08))
    # Rails round the landings (drawn bars over a solid pane you cannot see).
    m.rail_box(l1, (xa, MY, -7.0), (xa + 0.1, MY + 1.0, -3.5))
    m.rail_box(l2, (xa, RT, OZ0 - 2.0), (xa + 0.1, RT + 1.0, OZ0))
    m.rail_box(l2, (xa + 0.1, RT, OZ0 - 2.0), (-19.5, RT + 1.0, OZ0 - 1.9))
    m.rail_box(l2, (-19.6, RT, OZ0 - 1.9), (-19.5, RT + 1.0, OZ0))
    m.on_wall(l1, "ExitLamp", "neon_green", "z", OX0, -1, -6.2, -4.6, MY + 2.7, MY + 2.9, 0.08)


# ---------------------------------------------------------------------------
# Dressing: drawn only. On a wall that breaks, a piece lies against the wall (never in
# it) and goes when the wall behind it does.

def dressing(m):
    g = m.group("Details", "Arcade/Walls")
    # Neon round the top of the hall, over the high windows.
    for (axis, face, out, a, b, kind) in (("x", Z0, 1, X0, X1, "neon_cyan"), ("x", Z1, -1, X0, X1, "neon_pink"),
                                          ("z", X0, 1, Z0, Z1, "neon_pink"), ("z", X1, -1, Z0, Z1, "neon_cyan")):
        m.on_wall(g, "NeonStrip", kind, axis, face, out, a + 0.1, b - 0.1, 8.4, 8.52, 0.06)
    # Posters high on the walls.
    art = (("cab_red", "neon_cyan"), ("cab_yellow", "neon_pink"), ("cab_blue", "neon_yellow"), ("sofa", "neon_pink"),
           ("counter", "neon_cyan"), ("prize", "neon_green"))
    for k, x in enumerate((-17.5, -12.5, -7.0, -2.0, 12.5, 17.5)):   # (the VR screens are between)
        K.poster(m, g, "x", Z0, 1, x, MY + 1.9, 2.4, 1.9, *art[k % 6])
    for k, z in enumerate((-11.0, -1.0, 3.0)):
        K.poster(m, g, "z", X0, 1, z, 5.6, 2.4, 1.9, *art[(k + 2) % 6])
    for k, z in enumerate((-11.5, -5.0, 4.5)):
        K.poster(m, g, "z", X1, -1, z, 5.6, 2.4, 1.9, *art[(k + 4) % 6])
    # The high-score board over the doors, inside.
    m.on_wall(g, "ScoreBoard", "cab_black", "x", Z1, -1, -3.4, 3.4, 4.5, 7.9, 0.05)
    m.text(g, "HIGH SCORES", "x", Z1, -1, 0.0, 7.1, 0.085, "neon_yellow", depth=0.03, lift=0.05)
    for k in range(5):
        y = 6.5 - k * 0.4
        m.on_wall(g, "ScoreName", ("screen", "screen_pink")[k % 2], "x", Z1, -1, 0.4, 2.7 - 0.3 * (k % 3), y, y + 0.16, 0.02, lift=0.05)
        m.on_wall(g, "ScoreNumber", "marquee", "x", Z1, -1, -2.8, -0.8 + 0.25 * (k % 2), y, y + 0.16, 0.02, lift=0.05)
    # Outside: neon bands on the brick, lamps by the side doors.
    for (axis, face, out, a, b) in (("x", OZ1, 1, OX0, OX1), ("z", OX1, 1, OZ0, OZ1), ("z", OX0, -1, OZ0, OZ1), ("x", OZ0, -1, -15.0, OX1)):
        m.on_wall(g, "FasciaNeon", "neon_pink", axis, face, out, a + 0.2, b - 0.2, 8.6, 8.72, 0.06)
        m.on_wall(g, "FasciaNeon", "neon_cyan", axis, face, out, a + 0.2, b - 0.2, 8.85, 8.97, 0.06)
    m.text(g, "ARCADE", "z", OX1, 1, 1.0, 4.4, 0.16, "neon_cyan", depth=0.07)
    K.neon_box(m, g, "z", OX1, 1, 10.7, 13.3, 3.2, 3.9, "neon_yellow", wide=0.08)
    m.text(g, "IN", "z", OX1, 1, 12.0, 3.37, 0.05, "neon_yellow", depth=0.05)
    m.on_wall(g, "DoorLamp", "lamp", "z", OX0, -1, 6.3, 7.3, 2.75, 2.87, 0.1)
    m.on_wall(g, "DoorLamp", "lamp", "x", OZ0, -1, 10.2, 11.2, 2.75, 2.87, 0.1)
    m.on_wall(g, "DoorLamp", "neon_green", "z", OX1, 1, -12.7, -11.7, 2.75, 2.87, 0.1)
    # Ducts under the roof along the side walls (clear of it), with vents.
    d = m.group("Ducts", "Arcade/Trusses")
    for z in (-13.6, 13.6):
        m.strip(d, "Duct", "ac_unit", (X0 + 0.3, 8.0, z - 0.4), (X1 - 0.3, 8.5, z + 0.4))
        for x in range(-18, 19, 6):
            m.strip(d, "DuctVent", "cab_black", (x - 0.4, 7.96, z - 0.2), (x + 0.4, 8.0, z + 0.2))
    # Lamps and spot cans under the trusses.
    for k, (x, z) in enumerate(((-15.75, -5.0), (-5.25, -5.0), (5.25, -5.0), (15.75, -5.0), (-15.75, 5.0), (-5.25, 5.0),
                                (5.25, 5.0), (15.75, 5.0), (-10.5, 0.0), (0.0, 10.0), (10.5, 0.0), (0.0, -10.0), (10.5, 10.5), (-10.5, 10.5))):
        kind = ("neon_pink", "neon_cyan", "neon_yellow", "neon_green")[k % 4]
        m.strip(d, "SpotCan", "cab_black", (x - 0.16, 7.05, z - 0.16), (x + 0.16, 7.4, z + 0.16))
        m.strip(d, "SpotLens", kind, (x - 0.11, 7.0, z - 0.11), (x + 0.11, 7.05, z + 0.11))
    for x in (-10.5, 0.0, 10.5):
        for (z0, z1) in ((-3.6, -0.6), (0.6, 3.6)):
            m.strip(d, "TrussLight", "lamp", (x - 0.14, 7.3, z0), (x + 0.14, 7.4, z1))
    # A walk of dark tile from the doors to the booth, and round it.
    f = m.group("FloorDetails", "Arcade/Games")
    m.strip(f, "Walk", "tile_dark", (-1.6, 0, 2.6), (1.6, 0.02, Z1))
    m.strip(f, "Walk", "tile_dark", (-3.2, 0, -2.6), (3.2, 0.02, 2.6))
    for (x0, x1, kind) in ((-1.6, -1.5, "neon_cyan"), (1.5, 1.6, "neon_pink")):
        m.strip(f, "WalkEdge", kind, (x0, 0.02, 2.7), (x1, 0.035, Z1 - 0.1))


def spawns(m):
    pts = [
        # in the arcade
        ((-8.0, 0, -1.5), (0, 0)), ((7.5, 0, 1.5), (0, 0)), ((-11.5, 0, 8.0), (0, 0)), ((0.0, 0, 9.0), (0, 0)),
        ((13.5, 0, 2.0), (0, 0)), ((-8.0, 0, -11.5), (0, 0)), ((11.0, 0, -11.0), (0, 0)),
        ((-18.0, MY, 1.0), (0, 0)), ((8.0, MY, -11.0), (0, 0)), ((18.5, MY, -6.0), (0, 0)),
    ]
    for p, t in pts + block.SPAWNS:
        m.spawn(p, t)


def pickups(m):
    for (p, w) in [
        ((0, 3.0, 0), "air_cannon"), ((0, RT, 11.0), "sniper"), ((-17.5, MY, 10.2), "rifle"), ((0, MY, -11.6), "smg"),
        ((2.0, 0, -10.2), "revolver"), ((18.0, 0.6, 8.4), "katana"), ((18.3, 0, 0.0), "dagger"),
        ((-18.0, 0, -12.2), "machine_pistol"), ((9.0, 0, -6.8), "energy_sword"), ((-18.5, 0, 8.6), "akimbo"),
        ((18.2, MY, 1.5), "shotgun"),
    ] + block.WEAPONS:
        m.weapon(p, w)
    # Deathmatch power-ups (MapItemSpawn): double damage on the roof between the skylights,
    # uber on the stage; health on the mezzanine, in the rooms and round the block.
    for (p, item) in [
        ((0.0, RT, 0.0), "damage"), ((16.4, 0.6, 10.2), "uber"), ((-18.0, MY, 7.4), "health_medium"),
        ((15.5, MY, -12.0), "health_medium"), ((5.4, 0, -12.2), "health_small"), ((-9.0, 0, 13.0), "health_small"),
    ] + block.ITEMS:
        m.item(p, item)
