"""Neon Arcade's city block: the streets round the arcade and its neighbours (see
tools/arena/neon_arcade.py, which builds the arcade itself and calls build() here).

    north   the back lot: parking, the loading dock, a billboard, a half court
    west    an alley, and across it a noodle bar with a flat over it
    east    a side street, and across it a record shop (a pool room upstairs) and a
            filling station
    south   Main Street, and across it a pocket plaza, a diner, a laundromat and a hotel
            (the hotel is a front only)

x east, z south. The ground is level everywhere (kerbs are painted on): the body cannot
step up one, and bots' paths must not cross one. Four neighbours are buildings you go
into, each a MapFrame held up by its walls like the arcade; the filling station's
canopy stands on four columns. What you can walk is BX0..BX1 by BZ0..BZ1, shut in by
walls you cannot see just outside the fences, barriers and buildings you can.
"""
import math
import neon_arcade_kit as K
from neon_arcade_kit import At

BX0, BX1, BZ0, BZ1 = -38.5, 43.5, -28.5, 40.5      # what can be walked
FAR = 90.0
MAIN_N, MAIN_S, SOUTH_ROW = 19.5, 28.5, 31.5       # Main Street: its kerbs, and the fronts across it
SIDE_W, SIDE_E, EAST_ROW = 24.0, 31.0, 33.0        # the side street: its kerbs, and the fronts across it
NOODLE = (-38.0, -26.5, -4.0, 15.5)                # the neighbours' footprints: x0, x1, z0, z1
RECORD = (33.0, 43.0, -1.0, 15.5)
DINER = (-24.0, -6.0, 31.5, 40.5)
WASH = (-2.0, 12.0, 31.5, 40.5)
T = 0.5                                            # their outer walls

SPAWNS = [
    ((-12.0, 0, 17.4), (0, 40)), ((12.5, 0, 17.4), (0, 40)), ((-20.0, 0, 30.0), (0, 0)), ((8.0, 0, 30.0), (0, 0)),
    ((-2.0, 0, -20.5), (0, 0)), ((10.0, 0, -19.5), (0, 0)), ((-30.0, 0, -21.0), (0, 0)), ((-24.8, 0, 11.0), (-24.8, 0)),
    ((37.0, 0, -5.0), (0, 0)), ((-29.5, 0, 12.5), (-29.5, 0)), ((-34.0, 3.9, 11.0), (-30, 11)), ((36.5, 3.9, 12.0), (36.5, 0)),
    ((35.5, 0, 2.4), (30, 2.4)), ((-14.5, 0, 34.4), (0, 20)), ((4.0, 0, 34.6), (0, 20)), ((-33.4, 0, 38.9), (0, 20)),
]
WEAPONS = [
    ((18.0, 8.2, -25.6), "rocket_launcher"), ((-32.0, 7.7, 6.0), "grenade_launcher"), ((-9.0, 0, -18.2), "hammer"),
    ((-15.0, 0, 38.6), "auto_shotgun"), ((38.4, 5.3, -15.0), "lmg"), ((8.0, 0, 37.6), "crossbow"),
    ((37.5, 3.9, 3.0), "plasma_pistol"), ((-33.5, 0, 33.4), "flare_gun"), ((-24.6, 0, -2.0), "bat"),
    ((-33.0, 0, -8.2), "burst_rifle"),
]
ITEMS = [
    ((27.5, 0, 24.0), "health_medium"), ((-33.5, 0, -19.0), "health_small"), ((-32.5, 0, -1.0), "health_small"),
    ((39.0, 0, 11.0), "health_small"), ((-9.6, 0, 34.7), "health_small"), ((14.0, 0, -24.0), "health_medium"),
]


def build(m):
    ground(m)
    edges(m)
    backdrop(m)
    noodle_bar(m)
    record_shop(m)
    diner(m)
    laundromat(m)
    hotel(m)
    filling_station(m)
    back_lot(m)
    alley(m)
    plaza(m)
    streets(m)


# ---------------------------------------------------------------------------
# The ground

def ground(m):
    from neon_arcade import OX0, OX1, OZ0, OZ1
    g = "Ground"
    F = FAR

    def slab(name, kind, x0, x1, z0, z1):
        """A piece of ground: solid where it can be walked, only drawn beyond the edges
        (so the bots' map of the floor is of the block and not of the city)."""
        a0, a1, b0, b1 = max(x0, BX0 - 1.0), min(x1, BX1 + 1.0), max(z0, BZ0 - 1.0), min(z1, BZ1 + 1.0)
        if a0 >= a1 or b0 >= b1:
            m.box(g, name + "Beyond", kind, (x0, -0.5, z0), (x1, 0, z1), solid=False)
            return
        m.box(g, name, kind, (a0, -0.5, b0), (a1, 0, b1))
        for (c0, c1, d0, d1) in ((x0, a0, z0, z1), (a1, x1, z0, z1), (a0, a1, z0, b0), (a0, a1, b1, z1)):
            if c1 - c0 > 1e-6 and d1 - d0 > 1e-6:
                m.box(g, name + "Beyond", kind, (c0, -0.5, d0), (c1, 0, d1), solid=False)

    slab("BackLot", "lot", -F, OX1, -F, OZ0)
    slab("BackLot", "lot", -F, NOODLE[1], OZ0, NOODLE[2])
    slab("BackLot", "lot", -F, NOODLE[0], NOODLE[2], OZ1)
    slab("NoodleFloor", "lino", NOODLE[0], NOODLE[1], NOODLE[2], NOODLE[3])
    slab("Alley", "alley", NOODLE[1], OX0, OZ0, OZ1)
    slab("Pavement", "sidewalk", OX1, SIDE_W, -F, OZ1)
    slab("SideStreet", "street", SIDE_W, SIDE_E, -F, MAIN_N)
    slab("Pavement", "sidewalk", SIDE_E, EAST_ROW, -F, OZ1)
    slab("Forecourt", "lot", EAST_ROW, F, -F, RECORD[2])
    slab("RecordFloor", "lino", RECORD[0], RECORD[1], RECORD[2], RECORD[3])
    slab("Behind", "lot", RECORD[1], F, RECORD[2], OZ1)
    slab("Pavement", "sidewalk", -F, SIDE_W, OZ1, MAIN_N)
    slab("Pavement", "sidewalk", SIDE_E, F, OZ1, MAIN_N)
    slab("MainStreet", "street", -F, F, MAIN_N, MAIN_S)
    slab("Pavement", "sidewalk", -F, F, MAIN_S, SOUTH_ROW)
    slab("Plaza", "plaza", -F, DINER[0], SOUTH_ROW, BZ1)
    slab("DinerFloor", "tile", DINER[0], DINER[1], DINER[2], DINER[3])
    slab("Alley", "alley", DINER[1], WASH[0], SOUTH_ROW, BZ1)
    slab("WashFloor", "tile_teal", WASH[0], WASH[1], WASH[2], WASH[3])
    slab("Behind", "lot", WASH[1], F, SOUTH_ROW, BZ1)
    slab("Behind", "lot", -F, F, BZ1, F)
    m.box(g, "Far", "street", (-260, -0.9, -260), (260, -0.6, 260), tint=(0.7, 0.7, 0.7), solid=False)

    # Paint: kerbs (a pale line along every pavement's edge), lane lines, crossings, bays.
    p = m.group("Paint", g)

    def paint(name, kind, x0, x1, z0, z1, h=0.02):
        m.strip(p, name, kind, (x0, 0, z0), (x1, h, z1))

    paint("Kerb", "kerb", BX0 - 6, SIDE_W, MAIN_N - 0.3, MAIN_N, 0.03)
    paint("Kerb", "kerb", SIDE_E, BX1 + 6, MAIN_N - 0.3, MAIN_N, 0.03)
    paint("Kerb", "kerb", BX0 - 6, BX1 + 6, MAIN_S, MAIN_S + 0.3, 0.03)
    paint("Kerb", "kerb", SIDE_W - 0.3, SIDE_W, BZ0 - 6, MAIN_N - 0.3, 0.03)
    paint("Kerb", "kerb", SIDE_E, SIDE_E + 0.3, BZ0 - 6, MAIN_N - 0.3, 0.03)
    x = BX0 - 4.0
    while x < BX1 + 2:
        if not 15.0 < x + 1.5 < 32.5:
            paint("CentreLine", "paint_yellow", x, x + 3.0, 23.9, 24.1)
        x += 6.0
    z = BZ0 - 3.0
    while z < 13.0:
        paint("CentreLine", "paint_yellow", 27.4, 27.6, z, z + 3.0)
        z += 6.0
    for k in range(8):     # the crossing over Main Street by the junction
        paint("Crossing", "paint", 16.4, 20.4, 20.0 + k * 1.05, 20.6 + k * 1.05)
    for k in range(6):     # ...and over the side street
        paint("Crossing", "paint", 24.5 + k * 1.1, 25.1 + k * 1.1, 15.9, 18.7)
    paint("StopLine", "paint", 24.2, 27.3, 14.6, 15.0)
    paint("StopLine", "paint", 21.2, 21.6, 24.3, 28.3)
    for (x, z) in ((-10.0, 22.0), (4.0, 26.2), (29.2, -18.0), (-24.0, 6.0), (36.0, 22.0)):
        m.cyl(p, "Manhole", "steel", (x, 0, z), 0.9, 0.02, sides=12, solid=False)
    for (x, z) in ((-20.0, 19.7), (9.0, 19.7), (-2.0, 28.3), (23.8, -12.0)):
        paint("Drain", "grate", x - 0.4, x + 0.4, z - 0.14, z + 0.14, 0.035)
    # The back lot's bays.
    for k in range(9):
        x = -8.0 + k * 2.8
        paint("Bay", "paint", x - 0.06, x + 0.06, BZ0 + 0.4, -23.0)
    paint("Bay", "paint", -8.0, 14.4, -23.06, -22.94)
    for k in range(5):
        paint("DockHatch", "paint_yellow", -19.6 + k * 0.7, -19.3 + k * 0.7, -18.6, -15.7)


def edges(m):
    """What shuts the block in: walls you cannot see (Blink Proof, so nobody blinks out of
    the map), and the fences and barriers you can."""
    e = m.group("Edges")
    H = 40.0
    m.box(e, "Barrier", "frame", (BX0 - 0.6, 0, BZ0 - 0.6), (BX0, H, BZ1 + 0.6), drawn=False, blink_proof=True)
    m.box(e, "Barrier", "frame", (BX1, 0, BZ0 - 0.6), (BX1 + 0.6, H, BZ1 + 0.6), drawn=False, blink_proof=True)
    m.box(e, "Barrier", "frame", (BX0, 0, BZ0 - 0.6), (BX1, H, BZ0), drawn=False, blink_proof=True)
    m.box(e, "Barrier", "frame", (BX0, 0, BZ1), (BX1, H, BZ1 + 0.6), drawn=False, blink_proof=True)
    f = m.group("Fences")
    # North: behind the back lot and the filling station; across the side street's far end, barriers.
    K.fence(m, f, (BX0, BZ0 - 0.1), (21.5, BZ0 - 0.1), 3.0)
    K.fence(m, f, (EAST_ROW, BZ0 - 0.1), (BX1, BZ0 - 0.1), 3.0)
    for x in (23.0, 25.8, 29.2, 32.0):
        K.barrier(m, f, x, BZ0 + 0.5, along="x", wide=2.4)
    # West: beside the back lot; across Main Street's west end, barriers; beside the plaza, a wall.
    K.fence(m, f, (BX0 - 0.1, BZ0), (BX0 - 0.1, NOODLE[2]), 3.0)
    for z in (16.9, 20.6, 24.0, 27.4, 30.1):
        K.barrier(m, f, BX0 + 0.5, z, along="z", wide=2.6)
    K.fence(m, f, (BX0 - 0.1, SOUTH_ROW), (BX0 - 0.1, BZ1), 3.0, kind="brick_tan")
    K.fence(m, f, (BX0, BZ1 + 0.1), (DINER[0], BZ1 + 0.1), 3.0, kind="brick_tan")
    K.fence(m, f, (DINER[1], BZ1 + 0.1), (WASH[0], BZ1 + 0.1), 3.0)
    # East: behind the filling station; across Main Street's east end, barriers.
    K.fence(m, f, (BX1 + 0.1, BZ0), (BX1 + 0.1, RECORD[2]), 3.0)
    for z in (16.9, 20.6, 24.0, 27.4, 30.1):
        K.barrier(m, f, BX1 - 0.5, z, along="z", wide=2.6)
    for (x, z) in ((BX0 + 1.6, 18.6), (BX0 + 1.6, 22.4), (BX0 + 1.6, 26.0), (BX1 - 1.6, 19.0), (BX1 - 1.6, 25.6), (24.6, BZ0 + 1.6),
                   (30.6, BZ0 + 1.6)):
        K.traffic_cone(m, f, x, z)


def backdrop(m):
    """The city beyond: towers with lit windows, nothing you can reach."""
    b = m.group("Backdrop")
    n = 0

    def tower(x0, x1, z0, z1, h, extra=None):
        nonlocal n
        kind = ("backdrop", "backdrop_dark", "backdrop_far")[n % 3]
        m.box(b, "Tower", kind, (x0, -0.4, z0), (x1, h, z1), solid=False)
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        if n % 3 == 0:
            m.cyl(b, "RoofTank", "ac_unit", (cx, h, cz), 3.2, 3.4, sides=10, solid=False)
            m.cyl(b, "RoofTankCap", "truss", (cx, h + 3.4, cz), 3.6, 0.3, sides=10, solid=False)
        elif n % 3 == 1:
            m.strip(b, "StairHead", kind, (cx - 2, h, cz - 2), (cx + 1.5, h + 3, cz + 2), tint=(0.8, 0.8, 0.85))
        if h >= 24:
            m.pipe(b, "Mast", "steel", (x1 - 2.5, h, cz), (x1 - 2.5, h + 7, cz), 0.2)
            m.strip(b, "Beacon", "beacon", (x1 - 2.7, h + 7, cz - 0.2), (x1 - 2.3, h + 7.4, cz + 0.2))
        n += 1

    # North, behind the back lot.
    x = -62.0
    for (w, h) in ((14, 18), (11, 26), (16, 15), (12, 30), (15, 21), (10, 17), (14, 27), (13, 19), (16, 23)):
        tower(x, x + w, BZ0 - 17.0, BZ0 - 2.0, h)
        x += w + 1.0
    # South, behind the diner and the laundromat.
    x = -62.0
    for (w, h) in ((15, 22), (12, 16), (14, 28), (13, 19)):
        tower(x, x + w, BZ1 + 1.6, BZ1 + 16.0, h)
        x += w + 1.0
    # West and east.
    z = -44.0
    for (d, h) in ((15, 20), (13, 27), (16, 17), (12, 24), (14, 30), (15, 18)):
        tower(BX0 - 18.0, BX0 - 2.4, z, z + d, h)
        z += d + 1.0
    z = -44.0
    for (d, h) in ((14, 25), (16, 18), (13, 29), (15, 21), (12, 26), (14, 19)):
        tower(BX1 + 2.4, BX1 + 18.0, z, z + d, h)
        z += d + 1.0
    # Far towers, a ring further out.
    for k in range(14):
        a = k / 14.0 * math.tau + 0.2
        r = 120.0 + 16.0 * (k % 3)
        cx, cz = math.sin(a) * r, math.cos(a) * r
        h = 34.0 + 9.0 * ((k * 5) % 4)
        m.box(b, "FarTower", "backdrop_far", (cx - 9, -0.4, cz - 9), (cx + 9, h, cz + 9), tint=(0.8, 0.8, 0.9), solid=False)


# ---------------------------------------------------------------------------
# A building you can go into

def shop(m, name, foot, tops, kind, inside, holes, lines_x, lines_z, floor_holes=(), ceiling="ceiling_light", upper="floor_wood",
         parapet=0.8, cave=0.5):
    """The shell of a neighbour: outer walls of `kind` (their inside faces painted
    `inside`) with openings, a floor at each of `tops` but the last, which is the roof,
    a parapet, and the MapFrame that lets it come down. holes: {"n"/"s"/"w"/"e": [(from,
    to, bottom, top, "glass" or nothing)...]}, from and to being x (n, s) or z (w, e)."""
    x0, x1, z0, z1 = foot
    g = m.folder(name)
    w = m.folder("Walls", g)
    top = tops[-1] - 0.4
    cx, cz = lines_x[1:-1], lines_z[1:-1]

    def one(label, a, b, side, hs, axis, line, cuts):
        m.wall(w, label, kind, a, b, 0, top, T, inside=inside, side=side, cuts=cuts, holes=[h[:4] for h in hs])
        for h in hs:
            c0, c1, y0, y1 = h[:4]
            glass = len(h) > 4 and h[4] == "glass"
            if glass:
                m.pane(w, "glass", axis, line, c0, c1, y0, y1, bars=(int((c1 - c0) / 1.7), 0))
            m.trim(w, axis, line, T, c0, c1, y0, y1, sill=glass)

    one("NorthWall", (x0, z0 + T / 2), (x1, z0 + T / 2), 1, holes.get("n", ()), "x", z0 + T / 2, cx)
    one("SouthWall", (x0, z1 - T / 2), (x1, z1 - T / 2), -1, holes.get("s", ()), "x", z1 - T / 2, cx)
    one("WestWall", (x0 + T / 2, z0 + T), (x0 + T / 2, z1 - T), 1, holes.get("w", ()), "z", x0 + T / 2, cz)
    one("EastWall", (x1 - T / 2, z0 + T), (x1 - T / 2, z1 - T), -1, holes.get("e", ()), "z", x1 - T / 2, cz)
    f = m.folder("Floors", g)
    for y in tops[:-1]:
        m.deck(f, "Floor", upper, x0 + T, x1 - T, z0 + T, z1 - T, y, 0.3, holes=floor_holes, cuts_x=cx, cuts_z=cz, under=ceiling)
    m.deck(f, "Roof", "roof", x0, x1, z0, z1, tops[-1], 0.4, cuts_x=cx, cuts_z=cz, under=ceiling)
    if parapet:
        p = m.folder("Parapet", g)
        y0, y1 = tops[-1], tops[-1] + parapet
        m.wall(p, "Parapet", kind, (x0, z0 + 0.15), (x1, z0 + 0.15), y0, y1, 0.3, cuts=cx)
        m.wall(p, "Parapet", kind, (x0, z1 - 0.15), (x1, z1 - 0.15), y0, y1, 0.3, cuts=cx)
        m.wall(p, "Parapet", kind, (x0 + 0.15, z0 + 0.3), (x0 + 0.15, z1 - 0.3), y0, y1, 0.3, cuts=cz)
        m.wall(p, "Parapet", kind, (x1 - 0.15, z0 + 0.3), (x1 - 0.15, z1 - 0.3), y0, y1, 0.3, cuts=cz)
    m.frame(name + "Frame", [name], lines_x, lines_z, tops, held_by_walls=True, to_the_ground=True, ground=-0.5, cave_share=cave,
            overhang=2.2)
    return g


# ---------------------------------------------------------------------------
# West: the noodle bar, a flat over it

def noodle_bar(m):
    x0, x1, z0, z1 = NOODLE
    F1, RT = 3.9, 7.7
    holes = {
        "s": [(-36.8, -32.6, 0.7, 3.0, "glass"), (-31.0, -29.4, 0, 2.6), (-36.2, -33.8, 4.9, 6.6, "glass"), (-30.6, -28.2, 4.9, 6.6, "glass")],
        "e": [(1.0, 2.6, 0, 2.6), (8.6, 12.2, 0.9, 2.9, "glass"), (8.4, 10.0, F1, F1 + 2.5), (-1.6, 1.0, 4.9, 6.6, "glass")],
        "n": [(-34.6, -33.0, 0, 2.6), (-30.5, -28.9, F1, F1 + 2.5)],
    }
    g = shop(m, "NoodleBar", NOODLE, [F1, RT], "brick_red", "wall_warm", holes, [x0 + T / 2, -32.25, x1 - T / 2], [z0 + T / 2, 5.75, z1 - T / 2])
    xi0, xi1, zi0, zi1 = x0 + T, x1 - T, z0 + T, z1 - T
    C1 = F1 - 0.3
    # Ground floor: the kitchen at the back behind a partition, the bar, tables by the alley window.
    r = m.folder("Bar", g)
    m.wall(r, "KitchenWall", "partition", (xi0, 3.0), (-31.4, 3.0), 0, C1, 0.2, holes=[(-36.4, -34.0, 1.1, 2.3)])
    c = m.group("Counter", r)
    m.bev(c, "Counter", "wood", (-33.6, 0, 4.4), (-32.9, 1.05, 12.6), 0.04)
    m.strip(c, "CounterTop", "wood_light", (-33.7, 1.05, 4.3), (-32.8, 1.11, 12.7))
    for k in range(6):
        z = 5.2 + k * 1.3
        m.cyl(c, "Bowl", "bowl", (-33.25, 1.11, z), 0.34, 0.14, sides=10, solid=False)
        m.cyl(c, "Broth", "neon_orange" if k % 2 else "prize", (-33.25, 1.2, z), 0.28, 0.03, sides=10, solid=False)
        m.rod(c, "Chopsticks", "wood_light", (-33.05, 1.27, z - 0.2), (-33.4, 1.3, z + 0.16), thick=0.02)
        K.stool(m, r, -32.2, z, kind="seat_red")
    k_ = m.group("Range", r)
    m.box(k_, "Range", "steel", (xi0, 0, 4.6), (xi0 + 0.9, 0.95, 12.4))
    m.box(k_, "Hood", "steel", (xi0, 2.3, 5.4), (xi0 + 1.1, 2.9, 11.6))
    for k in range(4):
        z = 5.6 + k * 1.9
        m.cyl(k_, "Pot", "chrome", (xi0 + 0.45, 0.95, z), 0.6, 0.45, sides=10, solid=False)
        m.cyl(k_, "Burner", "neon_orange", (xi0 + 0.45, 0.95, z), 0.7, 0.04, sides=10, solid=False)
        m.dome(k_, "Steam", "hockey", (xi0 + 0.45, 1.5, z), (0.4, 0.25, 0.4), sides=6, solid=False)
    for row, y in enumerate((1.5, 1.95)):
        m.on_wall(k_, "Shelf", "wood", "z", xi0, 1, 12.8, 14.6, y - 0.05, y, 0.3)
        for j in range(4):
            m.cyl(k_, "Bowl", "bowl", (xi0 + 0.16, y, 13.0 + j * 0.46), 0.26, 0.12, sides=8, solid=False)
    for (z, k) in ((5.0, 0), (13.6, 1)):
        K.table(m, r, -28.3, z, wide=1.0, deep=1.0, kind="wood_light")
        K.chair(m, r, -28.3, z - 0.85, "+z", kind="wood", seat="seat_red")
        K.chair(m, r, -28.3, z + 0.85, "-z", kind="wood", seat="seat_red")
    for z in (9.4, 11.4):
        K.table(m, r, -28.0, z, wide=0.8, deep=1.0, kind="wood_light")
        K.chair(m, r, -28.95, z, "+x", kind="wood", seat="seat_red")
    # The kitchen.
    kt = m.folder("Kitchen", g)
    fr = m.group("Fridge", kt)
    m.bev(fr, "Fridge", "white_goods", (xi0, 0, -3.3), (xi0 + 0.9, 2.1, -1.9), 0.05)
    m.strip(fr, "FridgeHandle", "chrome", (xi0 + 0.9, 0.8, -2.0), (xi0 + 0.96, 1.6, -1.94))
    pr = m.group("Prep", kt)
    m.box(pr, "PrepTable", "steel", (-36.4, 0, 1.4), (-33.4, 0.9, 2.6))
    for j in range(3):
        m.cyl(pr, "Pan", "frame", (-36.0 + j * 1.0, 0.9, 2.0), 0.5, 0.08, sides=10, solid=False)
    K.crate(m, kt, -28.2, -2.6, size=0.9)
    K.boxes(m, kt, -30.2, -2.9, n=3, seed=4)
    sk = m.group("Sacks", kt)
    for j in range(3):
        m.dome(sk, "Sack", "paper", (-36.8 + j * 0.2, 0, 0.0 + j * 0.55), (0.8, 0.5, 0.6), sides=6, solid=False)
    # Lanterns under the ceiling, a menu over the range.
    d = m.group("Details", r)
    for k, z in enumerate((5.2, 7.8, 10.4, 13.0)):
        K.lantern(m, d, -31.4, C1, z, drop=0.35)
        K.lantern(m, d, -29.2, C1, z + 0.6, kind="lamp_warm", drop=0.5)
    m.on_wall(d, "Menu", "cab_black", "z", xi0, 1, 5.6, 11.4, 2.95, 3.45, 0.05)
    for k in range(6):
        m.on_wall(d, "MenuLine", ("lamp_warm", "neon_orange")[k % 2], "z", xi0, 1, 5.9 + k * 0.9, 6.5 + k * 0.9, 3.1, 3.3, 0.02, lift=0.05)
    for k, x in enumerate((-36.2, -31.2)):
        K.poster(m, d, "x", zi0, 1, x, 1.2, 1.0, 1.5, ("cab_red", "cab_yellow")[k], "neon_orange")
    K.plant(m, r, -27.7, 14.3, size=0.9)
    K.plant(m, r, -36.9, 14.4, size=0.8, kind="leaves_pink")

    # Upstairs: a flat. A living room at the front, a bedroom at the back.
    u = m.folder("Flat", g)
    C2 = RT - 0.4
    m.wall(u, "RoomWall", "partition", (xi0, 6.0), (xi1, 6.0), F1, C2, 0.2, holes=[(-33.8, -32.2, F1, F1 + 2.3)])
    K.sofa(m, u, -36.9, 10.6, "+x", wide=2.6, y=F1, kind="sofa_red")
    K.round_table(m, u, -35.0, 10.6, y=F1, d=1.0, height=0.45, kind="wood_light")
    tv = m.group("TV", u)
    m.box(tv, "TVStand", "wood", (-29.2, F1, 12.8), (-27.3, F1 + 0.55, 14.6))
    m.strip(tv, "TV", "cab_black", (-27.6, F1 + 0.7, 12.9), (-27.45, F1 + 1.7, 14.5))
    m.strip(tv, "TVScreen", "screen", (-27.63, F1 + 0.76, 12.96), (-27.6, F1 + 1.64, 14.44))
    m.strip(u, "Rug", "carpet_teal", (-36.0, F1, 8.6), (-31.4, F1 + 0.02, 12.8))
    sh = m.group("Bookshelf", u)
    m.box(sh, "Bookshelf", "wood", (-31.6, F1, 6.1), (-28.6, F1 + 2.0, 6.5))
    for row in range(4):
        for j in range(7):
            m.strip(sh, "Book", ("cab_red", "cab_blue", "prize", "cab_green", "paper")[(row * 3 + j) % 5],
                    (-31.5 + j * 0.4, F1 + 0.12 + row * 0.47, 6.5), (-31.2 + j * 0.4, F1 + 0.46 + row * 0.47, 6.56))
    K.plant(m, u, -27.6, 7.0, y=F1, size=1.0)
    K.ceiling_lamp(m, u, -33.5, C2, 10.6, drop=0.5, d=0.8)
    bed = m.group("Bed", u)
    m.bev(bed, "Bed", "bed", (-37.4, F1, -3.3), (-35.4, F1 + 0.55, -0.4), 0.06)
    m.bev(bed, "Pillow", "paper", (-37.2, F1 + 0.55, -3.2), (-35.6, F1 + 0.72, -2.6), 0.06, solid=False)
    m.strip(bed, "Headboard", "wood", (-37.45, F1, -3.45), (-35.35, F1 + 1.2, -3.3))
    wd = m.group("Wardrobe", u)
    m.box(wd, "Wardrobe", "wood", (-37.4, F1, 3.6), (-36.6, F1 + 2.2, 5.8))
    m.strip(wd, "WardrobeGap", "frame", (-36.6, F1 + 0.1, 4.68), (-36.57, F1 + 2.1, 4.72))
    dk = m.group("Desk", u)
    m.box(dk, "Desk", "wood_light", (-27.95, F1 + 0.7, 1.6), (-27.05, F1 + 0.78, 4.0))   # (by the alley wall, clear of the back door)
    for z in (1.7, 3.9):
        m.strip(dk, "DeskLeg", "steel", (-27.9, F1, z - 0.03), (-27.1, F1 + 0.7, z + 0.03))
    m.strip(dk, "Monitor", "cab_black", (-27.2, F1 + 0.9, 2.35), (-27.14, F1 + 1.5, 3.25))
    m.strip(dk, "MonitorGlow", "screen_green", (-27.22, F1 + 0.95, 2.41), (-27.2, F1 + 1.45, 3.19))
    m.strip(dk, "MonitorFoot", "cab_black", (-27.3, F1 + 0.78, 2.7), (-27.16, F1 + 0.9, 2.9))
    K.chair(m, u, -28.6, 2.8, "+x", y=F1, kind="steel", seat="cab_blue")
    m.strip(u, "Rug", "carpet", (-35.0, F1, 0.2), (-31.0, F1 + 0.02, 3.4))
    K.ceiling_lamp(m, u, -33.0, C2, 1.0, drop=0.5, d=0.7)
    # The balcony over the alley, the stair up the back.
    b = m.group("Balcony", g)
    m.box(b, "Balcony", "grate", (x1, F1 - 0.15, 7.9), (x1 + 1.6, F1, 10.5))
    m.rail_box(b, (x1 + 1.5, F1, 7.9), (x1 + 1.6, F1 + 1.0, 10.5))
    m.rail_box(b, (x1, F1, 7.9), (x1 + 1.5, F1 + 1.0, 8.0))
    m.rail_box(b, (x1, F1, 10.4), (x1 + 1.5, F1 + 1.0, 10.5))
    for z in (8.0, 10.4):
        m.rod(b, "BalconyStay", "steel", (x1 + 1.5, F1 - 0.15, z), (x1 + 0.02, F1 - 1.3, z), thick=0.07)
    K.plant(m, b, x1 + 1.1, 8.5, y=F1, size=0.6)
    st = m.folder("BackStair", g)
    l = m.group("Landing", st)
    m.box(l, "Landing", "grate", (-31.2, F1 - 0.15, z0 - 1.8), (-28.2, F1, z0))
    for x in (-31.1, -28.3):
        m.box(l, "Leg", "steel", (x - 0.08, 0, z0 - 1.78), (x + 0.08, F1 - 0.15, z0 - 1.62))
    m.rail_box(l, (-31.2, F1, z0 - 1.8), (-31.1, F1 + 1.0, z0))
    m.rail_box(l, (-28.3, F1, z0 - 1.8), (-28.2, F1 + 1.0, z0))
    m.rail_box(l, (-31.1, F1, z0 - 1.8), (-30.6, F1 + 1.0, z0 - 1.7))
    K.flight(m, st, "Flight", (-29.5, 0, -13.0), (-29.5, F1, z0 - 1.8), 1.7)
    # The roof: a tank, the kitchen's flue, and the bowl.
    rf = m.folder("RoofThings", g)
    K.water_tank(m, rf, -34.0, 0.5, RT, d=2.8, legs=1.6, h=2.6)
    K.ac_unit(m, rf, -29.5, -1.0, RT, size=(2.0, 1.3, 1.8))
    fl = m.group("Flue", rf)
    m.cyl(fl, "Flue", "steel", (-36.4, RT, 8.0), 0.6, 2.2, sides=8)
    m.cone(fl, "FlueCap", "steel", (-36.4, RT + 2.3, 8.0), 1.0, 0.4, sides=8, solid=False)
    bw = m.group("BowlSign", rf)
    m.cyl(bw, "BowlPost", "steel", (-31.0, RT, 13.0), 0.3, 1.6, sides=8)
    m.dome(bw, "Bowl", "bowl", (-31.0, RT + 3.0, 13.0), (3.2, 1.4, 3.2), sides=14, flip=True)
    m.cyl(bw, "BowlRim", "neon_red", (-31.0, RT + 2.94, 13.0), 3.3, 0.12, sides=14, solid=False)
    m.dome(bw, "Noodles", "neon_yellow", (-31.0, RT + 3.0, 13.0), (2.9, 0.5, 2.9), sides=12, solid=False)
    m.rod(bw, "Chopstick", "wood_light", (-31.6, RT + 3.2, 13.2), (-29.6, RT + 5.2, 12.6), thick=0.1)
    m.rod(bw, "Chopstick", "wood_light", (-31.3, RT + 3.2, 13.4), (-29.2, RT + 5.0, 13.0), thick=0.1)
    for k, dx in enumerate((-0.7, 0.0, 0.7)):
        m.dome(bw, "Steam", "neon_white", (-31.4 + dx, RT + 3.9 + 0.4 * (k % 2), 13.0), (0.4, 0.3, 0.4), sides=6, solid=False)
    # The front: an awning, the name, lanterns; a sign down the alley side.
    f = m.group("Front", g)
    K.awning(m, f, "x", z1, 1, -37.2, -28.8, 3.5, reach=1.5, drop=0.55, kind="awning_red", stripes=7)
    m.text(f, "RAMEN", "x", z1, 1, -32.25, 3.85, 0.085, "neon_red", depth=0.06)
    for k, x in enumerate((-36.6, -34.6, -32.6, -30.6, -28.9)):
        K.lantern(m, f, x, 2.95, z1 + 1.2, drop=0.1)
    m.on_wall(f, "Noren", "awning_red", "x", z1, 1, -31.0, -29.4, 2.2, 2.6, 0.04)
    K.neon_box(m, f, "z", x1, 1, 0.7, 2.9, 2.75, 3.4, "neon_red", wide=0.07)
    m.text(f, "OPEN", "z", x1, 1, 1.8, 2.93, 0.045, "neon_orange", depth=0.05)
    ac = m.group("WallUnit", g)
    m.box(ac, "WallUnit", "ac_unit", (x1, 4.4, 3.4), (x1 + 0.5, 5.1, 4.6), solid=False)
    m.on_wall(ac, "WallUnitFan", "frame", "z", x1 + 0.5, 1, 3.6, 4.4, 4.5, 5.0, 0.03)


# ---------------------------------------------------------------------------
# East: the record shop, a pool room over it

def record_shop(m):
    x0, x1, z0, z1 = RECORD
    F1, RT = 3.9, 7.7
    holes = {
        "w": [(5.0, 6.6, 0, 2.6), (0.8, 4.0, 0.7, 3.0, "glass"), (9.4, 13.8, 0.7, 3.0, "glass"), (1.0, 3.6, 4.9, 6.6, "glass"),
              (10.2, 12.8, 4.9, 6.6, "glass")],
        "s": [(34.4, 36.8, 0.7, 3.0, "glass"), (39.2, 41.6, 0.7, 3.0, "glass"), (34.6, 36.6, 4.9, 6.6, "glass"), (39.4, 41.4, 4.9, 6.6, "glass")],
        "n": [(35.0, 36.4, 0, 2.6)],
    }
    HOLE = (40.7, x1 - T, 2.3, 9.9)     # the stairwell
    g = shop(m, "RecordShop", RECORD, [F1, RT], "brick_tan", "wall_teal", holes, [x0 + T / 2, 38.0, x1 - T / 2],
             [z0 + T / 2, 7.25, z1 - T / 2], floor_holes=[HOLE])
    xi0, xi1, zi0, zi1 = x0 + T, x1 - T, z0 + T, z1 - T
    C1 = F1 - 0.3
    s = m.folder("Shop", g)
    m.stairs(s, "Stairs", (41.6, 0, 9.5), (41.6, F1, 2.3), 1.7, kind="wood", base=0)
    # Bins of records in two rows, a counter by the door, a listening corner.
    for row, x in enumerate((35.6, 37.9)):
        for k in range(5):
            z = 8.6 + k * 1.25 if row == 0 else 1.2 + k * 1.25 + (5.0 if k > 2 else 0)
            b = m.group("RecordBin", s)
            m.box(b, "Bin", "wood", (x - 0.5, 0, z - 0.5), (x + 0.5, 0.85, z + 0.5))
            for j in range(6):
                m.strip(b, "Sleeve", ("cab_red", "prize", "cab_blue", "prize_pink", "cab_green", "cab_yellow")[(j + k + row) % 6],
                        (x - 0.42, 0.85, z - 0.42 + j * 0.14), (x + 0.42, 1.13, z - 0.34 + j * 0.14))
    c = m.group("Counter", s)
    m.bev(c, "Counter", "wood", (34.0, 0, 6.9), (36.6, 1.05, 7.5), 0.04)
    m.strip(c, "CounterTop", "neon_purple", (33.95, 1.05, 6.85), (36.65, 1.1, 7.55))
    m.cyl(c, "Turntable", "cab_black", (35.0, 1.1, 7.2), 0.5, 0.06, sides=12, solid=False)
    m.cyl(c, "Record", "vinyl", (35.0, 1.16, 7.2), 0.42, 0.015, sides=12, solid=False)
    m.cyl(c, "RecordLabel", "neon_orange", (35.0, 1.175, 7.2), 0.14, 0.01, sides=8, solid=False)
    m.strip(c, "Till", "cab_black", (36.0, 1.1, 7.0), (36.4, 1.36, 7.4))
    sp = m.group("Speakers", s)
    for z in (zi0 + 0.1, zi0 + 1.3):
        m.box(sp, "Speaker", "cab_black", (xi1 - 0.9, 0, z), (xi1, 1.5, z + 1.0))
        for y in (0.45, 1.1):
            m.pipe(sp, "SpeakerCone", "steel", (xi1 - 0.93, y, z + 0.5), (xi1 - 0.9, y, z + 0.5), 0.5, sides=10)
    d = m.group("Details", s)
    for k, z in enumerate((7.45, 8.6)):
        K.poster(m, d, "z", xi0, 1, z, 1.2, 0.9, 1.5, ("cab_purple", "prize_pink")[k], "neon_purple")
    for k, x in enumerate((37.2, 38.8)):
        K.poster(m, d, "x", zi0, 1, x, 1.3, 1.2, 1.5, ("cab_yellow", "sofa")[k], "neon_cyan")
    # Records on the east wall.
    for row in range(2):
        for k in range(4):
            z = 10.6 + k * 1.1
            y = 1.3 + row * 1.0
            m.on_wall(d, "WallSleeve", ("cab_red", "prize_blue", "cab_yellow", "prize_green")[(k + row) % 4], "z", xi1, -1, z - 0.4, z + 0.4, y, y + 0.8, 0.03)
            m.pipe(d, "WallRecord", "vinyl", (xi1 - 0.06, y + 0.4, z), (xi1 - 0.03, y + 0.4, z), 0.6, sides=10)
    for z in (2.0, 6.0, 10.0, 13.5):
        K.tube_light(m, d, (35.0, z - 0.15), (38.5, z + 0.15), C1, kind="neon_purple" if z in (6.0, 13.5) else "lamp")
    K.plant(m, s, 34.1, 14.3, size=0.9)
    # Upstairs: a pool table, a bar corner, a jukebox.
    u = m.folder("PoolRoom", g)
    C2 = RT - 0.4
    r = m.group("StairRail", u)
    m.rail_box(r, (HOLE[0] - 0.1, F1, HOLE[2]), (HOLE[0], F1 + 1.0, HOLE[3]))
    m.rail_box(r, (HOLE[0], F1, HOLE[3]), (HOLE[1], F1 + 1.0, HOLE[3] + 0.1))
    pt = m.group("PoolTable", u)
    m.bev(pt, "PoolTable", "wood", (35.6, F1 + 0.3, 3.6), (37.2, F1 + 0.85, 6.6), 0.05)
    m.strip(pt, "Felt", "felt", (35.75, F1 + 0.85, 3.75), (37.05, F1 + 0.87, 6.45))
    for (sx, sz) in ((35.75, 3.75), (37.05, 3.75), (35.75, 6.45), (37.05, 6.45)):
        m.box(pt, "PoolLeg", "wood", (sx - 0.1, F1, sz - 0.1), (sx + 0.1, F1 + 0.3, sz + 0.1), solid=False)
    for k, (dx, dz, kind) in enumerate(((0.0, 0.0, "hockey"), (0.2, 0.9, "cab_red"), (-0.2, 1.1, "cab_yellow"), (0.1, 1.4, "cab_blue"),
                                        (-0.3, -0.8, "cab_black"))):
        m.dome(pt, "PoolBall", kind, (36.4 + dx, F1 + 0.93, 4.8 + dz), (0.12, 0.06, 0.12), sides=6, solid=False)
        m.dome(pt, "PoolBall", kind, (36.4 + dx, F1 + 0.93, 4.8 + dz), (0.12, 0.06, 0.12), sides=6, flip=True, solid=False)
    m.rod(pt, "Cue", "wood_light", (35.9, F1 + 0.9, 4.0), (36.9, F1 + 0.95, 3.3), thick=0.03)
    K.ceiling_lamp(m, u, 36.4, C2, 5.1, drop=0.9, d=1.2, kind="lamp_warm")
    bar = m.group("Bar", u)
    m.bev(bar, "Bar", "wood", (34.2, F1, 12.6), (38.8, F1 + 1.1, 13.2), 0.04)
    m.strip(bar, "BarTop", "neon_purple", (34.15, F1 + 1.1, 12.55), (38.85, F1 + 1.15, 13.25))
    for k in range(4):
        K.stool(m, u, 34.8 + k * 1.2, 11.9, y=F1, kind="cab_purple")
    for k in range(8):
        m.on_wall(bar, "Bottle", ("prize_green", "prize", "prize_blue", "screen_pink")[k % 4], "x", zi1, -1, 39.8 + k * 0.3, 39.95 + k * 0.3,
                  F1 + 1.4, F1 + 1.75, 0.1)
    m.on_wall(bar, "BottleShelf", "wood", "x", zi1, -1, 39.6, 42.3, F1 + 1.34, F1 + 1.4, 0.24)
    jb = At(m, m.group("Jukebox", u), (34.2, F1, 8.6), "+x")
    jb.s("Body", "cab_red", (-0.5, 0, -0.35), (0.5, 1.3, 0.35), bevel=0.06)
    jb.pipe("Arch", "neon_yellow", (0, 1.3, -0.3), (0, 1.3, 0.36), 1.0, sides=12)
    jb.b("Window", "screen_pink", (-0.34, 0.7, 0.3), (0.34, 1.2, 0.38))
    jb.b("Grille", "chrome", (-0.38, 0.12, 0.3), (0.38, 0.55, 0.38))
    K.sofa(m, u, 34.1, 1.6, "+x", wide=2.6, y=F1, kind="sofa")
    K.round_table(m, u, 36.0, 1.6, y=F1, d=0.9, height=0.5)   # (clear of the head of the stairs)
    for dz in (-0.9, 0.9):
        K.stool(m, u, 36.9, 1.6 + dz, y=F1, height=0.5, kind="cab_purple")
    dd = m.group("Details", u)
    m.pipe(dd, "Dartboard", "cab_black", (xi0 + 0.02, F1 + 1.7, 8.0), (xi0 + 0.07, F1 + 1.7, 8.0), 0.9, sides=12)
    m.pipe(dd, "DartRing", "neon_red", (xi0 + 0.07, F1 + 1.7, 8.0), (xi0 + 0.09, F1 + 1.7, 8.0), 0.5, sides=12, inner=0.36)
    m.text(dd, "POOL", "x", zi0, 1, 37.0, F1 + 2.2, 0.08, "neon_green", depth=0.05)
    # The roof: a billboard toward the arcade, plant.
    rf = m.folder("RoofThings", g)
    bb = m.group("Billboard", rf)
    xs = x0 + 0.7
    for z in (3.0, 7.0, 11.0):
        m.box(bb, "BillboardLeg", "truss", (xs - 0.15, RT, z - 0.15), (xs + 0.15, RT + 1.4, z + 0.15))
        m.rod(bb, "BillboardStay", "truss", (xs, RT + 3.6, z), (xs + 2.4, RT, z), thick=0.08)
    m.box(bb, "BillboardBoard", "cab_black", (xs - 0.1, RT + 1.4, 1.8), (xs + 0.1, RT + 4.6, 12.2))
    K.neon_box(m, bb, "z", xs - 0.1, -1, 1.9, 12.1, RT + 1.5, RT + 4.5, "neon_purple", wide=0.12)
    m.text(bb, "VINYL", "z", xs - 0.1, -1, 7.0, RT + 2.1, 0.26, "neon_yellow", depth=0.08)
    disc = m.group("Disc", rf)
    m.pipe(disc, "Disc", "vinyl", (xs - 0.36, RT + 6.0, 7.0), (xs - 0.2, RT + 6.0, 7.0), 2.6, sides=16)
    m.pipe(disc, "DiscLabel", "neon_orange", (xs - 0.42, RT + 6.0, 7.0), (xs - 0.36, RT + 6.0, 7.0), 0.9, sides=12)
    m.box(disc, "DiscPost", "truss", (xs - 0.32, RT + 4.6, 6.9), (xs - 0.12, RT + 4.8, 7.1), solid=False)
    K.ac_unit(m, rf, 39.5, 3.0, RT, size=(2.2, 1.4, 1.8))
    K.ac_unit(m, rf, 39.5, 11.5, RT, face="+x", size=(2.0, 1.3, 1.8))
    # The front: awnings over the windows, the name over the door.
    f = m.group("Front", g)
    K.awning(m, f, "z", x0, -1, 0.6, 4.2, 3.62, reach=1.2, drop=0.45, kind="awning_teal", stripes=3)
    K.awning(m, f, "z", x0, -1, 9.2, 14.0, 3.62, reach=1.2, drop=0.45, kind="awning_teal", stripes=5)
    m.text(f, "RECORDS", "z", x0, -1, 5.8, 2.9, 0.05, "neon_purple", depth=0.06)
    K.awning(m, f, "x", z1, 1, 34.2, 41.8, 3.62, reach=1.2, drop=0.45, kind="awning_teal", stripes=6)


# ---------------------------------------------------------------------------
# South: the diner, the laundromat, the hotel's front

def diner(m):
    x0, x1, z0, z1 = DINER
    RT = 4.2
    holes = {
        "n": [(-22.4, -17.0, 0.9, 3.0, "glass"), (-16.0, -14.4, 0, 2.6), (-12.0, -7.6, 0.9, 3.0, "glass")],
        "e": [(35.0, 36.6, 0, 2.6)],
        "w": [(34.0, 38.0, 0.9, 3.0, "glass")],
    }
    g = shop(m, "Diner", DINER, [RT], "diner_wall", "wall_cream", holes, [x0 + T / 2, -15.0, x1 - T / 2], [z0 + T / 2, z1 - T / 2])
    xi0, xi1, zi0, zi1 = x0 + T, x1 - T, z0 + T, z1 - T
    C = RT - 0.4
    r = m.folder("Room", g)
    for x in (-21.1, -18.5, -10.9, -8.3):
        K.booth(m, r, x, zi0 + 0.85, along="x")
        K.ceiling_lamp(m, r, x, C, zi0 + 0.85, drop=0.7, d=0.6, kind="neon_red")
    # The counter, with stools; the kitchen behind it.
    c = m.group("Counter", r)
    m.bev(c, "Counter", "white_goods", (-21.4, 0, 36.6), (-9.4, 1.05, 37.3), 0.04)
    m.strip(c, "CounterTop", "seat_red", (-21.5, 1.05, 36.5), (-9.3, 1.1, 37.4))
    m.strip(c, "CounterBand", "chrome", (-21.42, 0.5, 36.56), (-9.38, 0.62, 36.6))
    for k in range(8):
        K.stool(m, r, -20.6 + k * 1.5, 35.9, kind="seat_red")
    for k in range(4):
        x = -20.0 + k * 3.0
        m.cyl(c, "Plate", "bowl", (x, 1.1, 36.95), 0.3, 0.03, sides=10, solid=False)
        m.dome(c, "Pie", ("prize", "cab_red")[k % 2], (x, 1.13, 36.95), (0.24, 0.1, 0.24), sides=8, solid=False)
        m.cyl(c, "Mug", "bowl", (x + 0.9, 1.1, 36.8), 0.1, 0.12, sides=6, solid=False)
    kt = m.group("Kitchen", r)
    m.box(kt, "Grill", "steel", (-21.0, 0, zi1 - 0.9), (-13.0, 0.95, zi1))
    m.box(kt, "Hood", "chrome", (-20.0, 2.5, zi1 - 1.0), (-14.0, 3.1, zi1))
    for k in range(3):
        m.strip(kt, "Hotplate", "neon_orange", (-19.6 + k * 2.2, 0.95, zi1 - 0.75), (-18.4 + k * 2.2, 0.98, zi1 - 0.15))
    m.bev(kt, "Fridge", "white_goods", (-12.4, 0, zi1 - 0.9), (-10.6, 2.1, zi1), 0.05)
    m.strip(kt, "FridgeHandle", "chrome", (-11.56, 0.8, zi1 - 0.96), (-11.44, 1.7, zi1 - 0.9))
    m.on_wall(kt, "MenuBoard", "cab_black", "x", zi1, -1, -20.0, -14.0, 3.15, 3.7, 0.05)
    for k in range(5):
        m.on_wall(kt, "MenuLine", ("neon_red", "marquee")[k % 2], "x", zi1, -1, -19.7 + k * 1.2, -18.9 + k * 1.2, 3.3, 3.55, 0.02, lift=0.05)
    jb = At(m, m.group("Jukebox", r), (-13.2, 0, zi0 + 0.45), "+z")
    jb.s("Body", "cab_yellow", (-0.5, 0, -0.35), (0.5, 1.3, 0.35), bevel=0.06)
    jb.pipe("Arch", "neon_red", (0, 1.3, -0.3), (0, 1.3, 0.36), 1.0, sides=12)
    jb.b("Window", "screen", (-0.34, 0.7, 0.3), (0.34, 1.2, 0.38))
    jb.b("Grille", "chrome", (-0.38, 0.12, 0.3), (0.38, 0.55, 0.38))
    K.plant(m, r, xi1 - 0.6, zi0 + 0.6, size=0.9)
    K.bin_(m, r, xi1 - 0.6, 38.0)
    d = m.group("Details", r)
    for (x0_, x1_) in ((-23.0, -16.6), (-12.4, -7.0)):
        m.on_wall(d, "ChromeBand", "chrome", "x", zi0, 1, x0_, x1_, 0.55, 0.7, 0.03)
    m.pipe(d, "Clock", "bowl", (-8.6, 3.2, zi1 - 0.05), (-8.6, 3.2, zi1 - 0.02), 0.8, sides=12)
    m.pipe(d, "ClockRing", "neon_red", (-8.6, 3.2, zi1 - 0.08), (-8.6, 3.2, zi1 - 0.05), 0.92, sides=12, inner=0.8)
    # Outside: chrome and red bands, the name on the roof, an arrow.
    f = m.group("Front", g)
    for (axis, face, out, a, b) in (("x", z0, -1, x0, x1), ("z", x0, -1, z0, z1), ("z", x1, 1, z0, z1)):
        m.on_wall(f, "Band", "seat_red", axis, face, out, a + 0.1, b - 0.1, 3.25, 3.5, 0.04)
        m.on_wall(f, "BandNeon", "neon_red", axis, face, out, a + 0.1, b - 0.1, 3.58, 3.68, 0.06)
    s = m.group("RoofSign", g)
    zs = z0 + 0.7
    for x in (-18.5, -15.0, -11.5):
        m.box(s, "SignLeg", "truss", (x - 0.12, RT, zs - 0.12), (x + 0.12, RT + 1.0, zs + 0.12))
        m.rod(s, "SignStay", "truss", (x, RT + 2.6, zs + 0.1), (x, RT, zs + 2.0), thick=0.08)
    m.box(s, "SignBoard", "seat_red", (-19.2, RT + 1.0, zs - 0.1), (-10.8, RT + 3.4, zs + 0.1))
    K.neon_box(m, s, "x", zs - 0.1, -1, -19.1, -10.9, RT + 1.1, RT + 3.3, "neon_white", wide=0.1)
    m.text(s, "DINER", "x", zs - 0.1, -1, -15.0, RT + 1.45, 0.22, "neon_white", depth=0.08)
    K.ac_unit(m, m.folder("RoofThings", g), -9.0, 37.5, RT, size=(2.0, 1.2, 1.8))
    v = m.group("Stack", g)
    m.cyl(v, "Stack", "chrome", (-17.0, RT, 39.0), 0.6, 1.8, sides=8)
    m.cone(v, "StackCap", "chrome", (-17.0, RT + 1.9, 39.0), 1.0, 0.36, sides=8, solid=False)


def washer(m, parent, x, z, face, y=0.0, dryer=False):
    """A washing machine (or, with `dryer`, a bigger dryer): a white box with a round door."""
    a = At(m, m.group("Dryer" if dryer else "Washer", parent), (x, y, z), face)
    h = 1.9 if dryer else 0.95
    a.s("Body", "white_goods", (-0.42, 0, -0.4), (0.42, h, 0.36), bevel=0.03)
    cy = 1.0 if dryer else 0.45
    a.pipe("Door", "chrome", (0, cy, 0.34), (0, cy, 0.4), 0.56, sides=12)
    a.pipe("Drum", "drum", (0, cy, 0.4), (0, cy, 0.42), 0.42, sides=12)
    a.b("Panel", "frame", (-0.36, h - 0.2, 0.3), (0.36, h - 0.06, 0.39))
    a.b("Light", "screen_green" if (int(x * 3 + z) % 3) else "neon_orange", (0.18, h - 0.17, 0.36), (0.3, h - 0.09, 0.41))
    return a


def laundromat(m):
    x0, x1, z0, z1 = WASH
    RT = 4.2
    holes = {
        "n": [(0.4, 2.0, 0, 2.6), (6.4, 10.8, 0.7, 3.0, "glass")],
        "w": [(35.0, 36.6, 0, 2.6)],
    }
    g = shop(m, "Laundromat", WASH, [RT], "stucco", "wall_cream", holes, [x0 + T / 2, 5.0, x1 - T / 2], [z0 + T / 2, z1 - T / 2])
    xi0, xi1, zi0, zi1 = x0 + T, x1 - T, z0 + T, z1 - T
    C = RT - 0.4
    r = m.folder("Room", g)
    for k in range(9):
        washer(m, r, 0.2 + k * 0.95, zi1 - 0.4, "-z")
    for k in range(5):
        washer(m, r, xi1 - 0.4, 33.4 + k * 0.95, "-x", dryer=True)
    t = K.table(m, r, 3.6, 36.2, wide=3.6, deep=1.2, kind="table")
    for k, (dx, kind) in enumerate(((-1.2, "prize_blue"), (-0.3, "paper"), (0.7, "prize_pink"))):
        m.bev(t.g, "Laundry", kind, (3.6 + dx - 0.3, 0.76, 35.95), (3.6 + dx + 0.3, 0.76 + 0.16 + 0.05 * k, 36.45), 0.04, solid=False)
    K.bench(m, r, 8.0, 34.4, "-z", kind="wood_light")
    for k, (x, z) in enumerate(((0.2, 33.6), (6.4, 37.6))):
        ct = m.group("Cart", r)
        m.box(ct, "Cart", "chrome", (x - 0.4, 0.2, z - 0.3), (x + 0.4, 0.85, z + 0.3))
        m.dome(ct, "Washing", ("prize_blue", "cab_red")[k], (x, 0.85, z), (0.7, 0.3, 0.5), sides=8, solid=False)
        for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            m.cyl(ct, "Castor", "tyre", (x + sx * 0.3, 0, z + sz * 0.22), 0.12, 0.2, sides=6, solid=False)
    K.vending(m, r, xi0 + 0.45, 38.4, "+x", "cab_blue")
    K.bin_(m, r, 2.6, zi0 + 0.5)
    K.plant(m, r, 5.4, zi0 + 0.6, size=0.9)
    d = m.group("Details", r)
    for x in (1.0, 4.0, 7.0, 10.0):
        K.tube_light(m, d, (x - 0.15, 33.4), (x + 0.15, 38.0), C)
    m.on_wall(d, "Notice", "paper", "x", zi0, 1, 3.0, 4.4, 1.4, 2.4, 0.03)
    m.on_wall(d, "PriceBoard", "cab_black", "z", xi0, 1, 32.6, 34.6, 1.6, 2.6, 0.04)
    for k in range(4):
        m.on_wall(d, "PriceLine", "screen", "z", xi0, 1, 32.8, 34.0 + 0.1 * (k % 2), 1.75 + k * 0.2, 1.87 + k * 0.2, 0.02, lift=0.04)
    f = m.group("Front", g)
    K.awning(m, f, "x", z0, -1, 0.0, 11.4, 3.62, reach=1.3, drop=0.45, kind="awning_teal", stripe="paper", stripes=8)
    s = m.group("RoofSign", g)
    zs = z0 + 0.7
    for x in (3.0, 7.0):
        m.box(s, "SignLeg", "truss", (x - 0.12, RT, zs - 0.12), (x + 0.12, RT + 0.9, zs + 0.12))
        m.rod(s, "SignStay", "truss", (x, RT + 2.3, zs + 0.1), (x, RT, zs + 1.8), thick=0.08)
    m.box(s, "SignBoard", "cab_blue", (1.6, RT + 0.9, zs - 0.1), (8.4, RT + 3.1, zs + 0.1))
    m.text(s, "WASH", "x", zs - 0.1, -1, 5.0, RT + 1.3, 0.2, "neon_cyan", depth=0.08)
    for k, (dx, dy, d_) in enumerate(((9.2, 2.6, 0.9), (9.9, 3.5, 0.6), (9.3, 4.2, 0.4))):
        m.dome(s, "Bubble", "neon_cyan", (dx, RT + dy, zs), (d_, d_ * 0.5, d_), sides=8, solid=False)
        m.dome(s, "Bubble", "neon_cyan", (dx, RT + dy, zs), (d_, d_ * 0.5, d_), sides=8, flip=True, solid=False)
    K.ac_unit(m, m.folder("RoofThings", g), 3.0, 37.5, RT, size=(2.0, 1.2, 1.8))


def hotel(m):
    """Across Main Street, east of the laundromat: a tall front and nothing behind it."""
    g = m.group("Hotel")
    x0, x1, z0 = WASH[1] + 0.6, BX1 + 2.4, SOUTH_ROW
    m.box(g, "HotelBase", "brick_tan", (x0, 0, z0), (x1, 5.0, z0 + 16.0))
    m.box(g, "Hotel", "backdrop", (x0, 5.0, z0), (x1, 30.0, z0 + 16.0), blink_proof=True)
    m.on_wall(g, "Cornice", "frame", "x", z0, -1, x0, x1, 5.0, 5.4, 0.3)
    # The entrance: a canopy on two posts, lit doors, a red carpet, trees in tubs.
    c = m.group("HotelCanopy")
    m.box(c, "Canopy", "awning_red", (22.0, 3.7, MAIN_S + 0.4), (30.0, 4.1, z0))
    for x in (22.4, 29.6):
        m.cyl(c, "CanopyPost", "chrome", (x, 0, MAIN_S + 0.8), 0.2, 3.7, sides=8)
    m.on_wall(c, "CanopyEdge", "neon_yellow", "x", MAIN_S + 0.4, -1, 22.0, 30.0, 3.75, 3.87, 0.05)
    for k in range(6):
        m.strip(c, "CanopyBulb", "marquee", (22.8 + k * 1.3, 3.64, 30.0), (23.0 + k * 1.3, 3.7, 30.2))
    m.on_wall(g, "Doors", "window_lit", "x", z0, -1, 24.0, 28.0, 0, 3.0, 0.06)
    for x in (24.0, 26.0, 28.0):
        m.on_wall(g, "DoorFrame", "frame", "x", z0, -1, x - 0.06, x + 0.06, 0, 3.0, 0.04, lift=0.06)
    m.on_wall(g, "DoorFrame", "frame", "x", z0, -1, 23.9, 28.1, 3.0, 3.14, 0.04, lift=0.06)
    m.strip(g, "RedCarpet", "awning_red", (24.4, 0, MAIN_S + 0.3), (27.6, 0.02, z0))
    for x in (23.0, 29.0):
        K.plant(m, g, x, z0 - 0.6, size=1.3)
    for k, (a, b) in enumerate(((13.6, 20.6), (31.4, 38.4), (39.4, 43.0))):
        m.on_wall(g, "LobbyWindow", "window_lit", "x", z0, -1, a, b, 0.8, 3.4, 0.05)
        m.on_wall(g, "LobbyWindowBar", "frame", "x", z0, -1, (a + b) / 2 - 0.05, (a + b) / 2 + 0.05, 0.8, 3.4, 0.03, lift=0.05)
    # The name down the front.
    for k, ch in enumerate("HOTEL"):
        m.text(g, ch, "x", z0, -1, 16.6, 24.0 - k * 3.0, 0.32, "neon_cyan", depth=0.12)
    K.neon_box(m, g, "x", z0, -1, 15.2, 18.0, 11.2, 26.8, "neon_pink", wide=0.14, depth=0.1)


# ---------------------------------------------------------------------------
# East: the filling station

def filling_station(m):
    g = m.folder("GasCanopy")
    xs, zs = (35.5, 41.0), (-20.0, -10.0)
    TOP = 5.3
    for x in xs:
        for z in zs:
            m.box(g, "Column", "column", (x - 0.3, 0, z - 0.3), (x + 0.3, TOP - 0.5, z + 0.3))
    m.deck(g, "Canopy", "canopy", 34.0, 42.6, -22.0, -8.0, TOP, 0.5)
    for (axis, face, out, a, b) in (("x", -8.0, 1, 34.0, 42.6), ("x", -22.0, -1, 34.0, 42.6), ("z", 34.0, -1, -22.0, -8.0), ("z", 42.6, 1, -22.0, -8.0)):
        m.on_wall(g, "CanopyBand", "neon_green", axis, face, out, a, b, TOP - 0.34, TOP - 0.16, 0.05)
    for z in (-18.0, -15.0, -12.0):
        for x in (36.8, 39.8):
            m.strip(g, "CanopyLamp", "lamp", (x - 0.5, TOP - 0.55, z - 0.25), (x + 0.5, TOP - 0.5, z + 0.25))
    m.frame("CanopyFrame", ["GasCanopy"], list(xs), list(zs), [TOP], column_kind='"column"', column_health=500.0, overhang=2.2, slab=0.55)
    s = m.folder("FillingStation")
    # Two pump islands under the canopy.
    for z in (-17.0, -13.0):
        i = m.group("PumpIsland", s)
        m.bev(i, "Island", "kerb", (36.4, 0, z - 0.6), (40.1, 0.16, z + 0.6), 0.05)
        for x in (37.2, 39.3):
            a = At(m, m.group("Pump", s), (x, 0.16, z), "+z")
            a.s("Body", "cab_red", (-0.4, 0, -0.28), (0.4, 1.7, 0.28), bevel=0.04)
            for sz in (-1, 1):
                z0_, z1_ = sorted((sz * 0.2, sz * 0.31))
                a.b("Screen", "screen_green", (-0.28, 1.05, z0_), (0.28, 1.45, z1_))
                a.b("Buttons", "frame", (-0.28, 0.7, z0_), (0.28, 0.95, z1_))
            a.b("Top", "neon_green", (-0.44, 1.7, -0.32), (0.44, 1.82, 0.32))
            a.pipe("Hose", "tyre", (0.42, 1.2, 0), (0.6, 0.5, 0.1), 0.06)
            a.b("Nozzle", "frame", (0.4, 0.9, -0.06), (0.52, 1.25, 0.06))
        K.bollard(m, s, 36.0, z, lit="signal_amber")
        K.bollard(m, s, 40.5, z, lit="signal_amber")
    # The kiosk at the back (a front only), the price sign by the street, odds and ends.
    k = m.group("Kiosk", s)
    m.box(k, "Kiosk", "stucco", (38.4, 0, BZ0), (BX1, 3.4, -24.4))
    m.box(k, "KioskRoof", "canopy", (38.0, 3.4, BZ0), (BX1, 3.7, -24.0))
    m.on_wall(k, "KioskWindow", "window_lit", "x", -24.4, 1, 39.0, 41.4, 1.0, 2.6, 0.05)
    m.on_wall(k, "KioskDoor", "frame", "x", -24.4, 1, 41.9, 43.0, 0, 2.3, 0.05)
    m.on_wall(k, "KioskBand", "neon_green", "x", -24.0, 1, 38.0, BX1, 3.46, 3.6, 0.05)
    m.text(k, "24H", "x", -24.4, 1, 40.2, 2.75, 0.07, "neon_green", depth=0.05)
    ice = m.group("IceChest", s)
    m.bev(ice, "IceChest", "white_goods", (38.5, 0, -24.4), (38.9, 1.1, -23.0), 0.04)
    p = m.group("PriceSign", s)
    m.cyl(p, "Pole", "steel", (34.2, 0, -3.6), 0.3, 6.2, sides=8)
    m.box(p, "Board", "cab_black", (34.0, 3.4, -5.0), (34.4, 6.6, -2.2))
    for (face, out) in ((34.0, -1), (34.4, 1)):
        m.text(p, "GAS", "z", face, out, -3.6, 5.5, 0.11, "neon_green", depth=0.05)
        for row in range(3):
            m.on_wall(p, "Price", ("neon_yellow", "neon_white", "neon_orange")[row], "z", face, out, -4.6, -2.6 - 0.3 * (row % 2),
                      3.7 + row * 0.55, 4.05 + row * 0.55, 0.04)
    ty = m.group("Tyres", s)
    for k_ in range(4):
        m.cyl(ty, "Tyre", "tyre", (42.6, k_ * 0.26, -5.0), 0.8 - 0.04 * (k_ % 2), 0.24, sides=10)
    for (x, z, kind) in ((42.4, -6.4, "cab_blue"), (41.6, -6.0, "cab_red")):
        d = m.group("Drum", s)
        m.cyl(d, "Drum", kind, (x, 0, z), 0.6, 0.9, sides=10)
        m.cyl(d, "DrumRim", "frame", (x, 0.9, z), 0.62, 0.04, sides=10, solid=False)
    air = At(m, m.group("AirMachine", s), (34.4, 0, -24.0), "+x")
    air.s("Body", "cab_yellow", (-0.35, 0, -0.3), (0.35, 1.4, 0.3), bevel=0.04)
    air.b("Dial", "bowl", (-0.2, 0.9, 0.26), (0.2, 1.25, 0.33))
    air.pipe("Hose", "tyre", (0.3, 0.6, 0.2), (0.3, 0.1, 0.5), 0.05)
    K.car(m, s, 38.25, -15.0, "-z", "car_green")
    K.lamp_post(m, s, 42.6, -1.8, "-z", height=5.5, reach=1.4)


# ---------------------------------------------------------------------------
# North: the back lot

def back_lot(m):
    s = m.folder("BackLot")
    # Parked: the delivery truck, three cars.
    K.truck(m, s, -12.8, -22.6, "+z")
    K.car(m, s, -5.2, -25.6, "+z", "car_red")
    K.car(m, s, 3.2, -25.6, "+z", "car_black")
    K.car(m, s, 8.8, -25.4, "+z", "car_white")
    # Against the arcade's back wall: dumpsters, pallets, crates.
    K.dumpster(m, s, 2.6, -16.3, "-z")
    K.dumpster(m, s, 5.2, -16.3, "-z", kind="cab_blue")
    K.pallet(m, s, -11.8, -16.3, load="cardboard")
    K.pallet(m, s, -10.2, -16.2)
    K.crate(m, s, -13.6, -16.1, size=1.0)
    K.crate(m, s, -13.6, -16.1, y=1.0, size=0.7)
    K.crate(m, s, 16.4, -16.1, size=1.0)
    K.boxes(m, s, 7.2, -16.1, n=3, seed=3)
    for (x, z) in ((-21.2, -20.4), (-14.8, -20.4)):
        K.bollard(m, s, x, z, lit="signal_amber")
    K.lamp_post(m, s, -4.0, BZ0 + 0.7, "+z", height=6.5, reach=1.8)
    K.lamp_post(m, s, 11.6, BZ0 + 0.7, "+z", height=6.5, reach=1.8)
    # The billboard: a catwalk to stand on, 8 m up.
    b = m.group("Billboard", s)
    z = -26.6
    for x in (15.6, 20.4):
        m.box(b, "Leg", "truss", (x - 0.2, 0, z - 0.2), (x + 0.2, 12.6, z + 0.2))
        for k in range(16):
            m.strip(b, "Rung", "steel", (x - 0.2, 0.4 + k * 0.48, z + 0.2), (x + 0.2, 0.46 + k * 0.48, z + 0.26))
    m.box(b, "Catwalk", "grate", (14.8, 8.0, z - 0.1), (21.2, 8.2, z + 2.0))
    m.rail_box(b, (14.8, 8.2, z + 1.9), (21.2, 9.2, z + 2.0))
    m.box(b, "Board", "cab_black", (14.6, 8.9, z - 0.3), (21.4, 12.8, z - 0.1))
    m.on_wall(b, "Art", "cab_purple", "x", z - 0.1, 1, 14.9, 21.1, 9.2, 12.5, 0.03)
    m.text(b, "PLAY", "x", z - 0.1, 1, 18.0, 10.0, 0.26, "neon_yellow", depth=0.06, lift=0.03)
    K.neon_box(m, b, "x", z - 0.1, 1, 14.75, 21.25, 9.05, 12.65, "neon_pink", wide=0.1, lift=0.03)
    for x in (16.0, 18.0, 20.0):
        m.rod(b, "LampArm", "steel", (x, 12.8, z - 0.2), (x, 13.4, z + 0.9), thick=0.05)
        m.strip(b, "Lamp", "lamp", (x - 0.2, 13.3, z + 0.8), (x + 0.2, 13.4, z + 1.1))
    # West of the alley: a half court, a container to run through.
    c = m.group("Court", s)
    m.strip(c, "Court", "court", (-37.6, 0, -27.8), (-27.6, 0.02, -16.4))
    for (lo, hi) in (((-37.6, -27.8), (-27.6, -27.68)), ((-37.6, -16.52), (-27.6, -16.4)), ((-37.6, -27.8), (-37.48, -16.4)),
                     ((-27.72, -27.8), (-27.6, -16.4)), ((-34.4, -27.8), (-34.28, -22.4)), ((-30.92, -27.8), (-30.8, -22.4)),
                     ((-34.4, -22.52), (-30.8, -22.4))):
        m.strip(c, "CourtLine", "paint", (lo[0], 0.02, lo[1]), (hi[0], 0.035, hi[1]))
    m.pipe(c, "CourtArc", "paint", (-32.6, 0.02, -22.4), (-32.6, 0.035, -22.4), 3.6, sides=16, inner=3.36)
    h = m.group("Hoop", s)
    m.cyl(h, "HoopPole", "steel", (-32.6, 0, BZ0 + 0.5), 0.24, 3.4, sides=8)
    m.rod(h, "HoopArm", "steel", (-32.6, 3.3, BZ0 + 0.5), (-32.6, 3.3, BZ0 + 1.4), thick=0.12)
    m.box(h, "Backboard", "hockey", (-33.5, 2.8, BZ0 + 1.4), (-31.7, 3.9, BZ0 + 1.5))
    m.on_wall(h, "BackboardSquare", "neon_orange", "x", BZ0 + 1.5, 1, -32.9, -32.3, 3.05, 3.5, 0.02)
    m.pipe(h, "Ring", "neon_orange", (-32.6, 3.05, BZ0 + 1.76), (-32.6, 3.09, BZ0 + 1.76), 0.46, sides=12, inner=0.4)
    ball = m.group("Ball", s)
    m.dome(ball, "Ball", "neon_orange", (-29.4, 0.13, -18.2), (0.26, 0.13, 0.26), sides=8, solid=False)
    m.dome(ball, "Ball", "neon_orange", (-29.4, 0.13, -18.2), (0.26, 0.13, 0.26), sides=8, flip=True, solid=False)
    K.bench(m, s, -36.6, -14.6, "+z")
    ct = m.group("Container", s)
    m.box(ct, "ContainerSide", "container", (-37.8, 0, -9.5), (-31.8, 2.6, -9.4))
    m.box(ct, "ContainerSide", "container", (-37.8, 0, -7.1), (-31.8, 2.6, -7.0))
    m.box(ct, "ContainerTop", "container", (-37.8, 2.6, -9.5), (-31.8, 2.7, -7.0))
    for x in (-37.8, -31.9):
        m.strip(ct, "ContainerEnd", "frame", (x, 2.3, -9.4), (x + 0.1, 2.6, -7.1))
    K.crate(m, s, -36.9, -6.2, size=0.9)
    K.dumpster(m, s, -37.4, -11.6, "+x")


def alley(m):
    """Between the arcade and the noodle bar."""
    s = m.folder("AlleyThings")
    K.dumpster(m, s, -25.7, 13.0, "+x")
    K.bin_(m, s, -25.9, 4.2)
    K.bin_(m, s, -25.9, 5.0, kind="cab_blue")
    K.boxes(m, s, -25.8, 6.4, n=3, seed=5)
    K.crate(m, s, -25.9, -7.2, size=0.9)
    K.pallet(m, s, -25.8, -9.0, load="cardboard")
    # A line of lanterns from the noodle bar across to the arcade (it hangs from the bar).
    l = m.group("LanternLine", "NoodleBar")
    m.rod(l, "LanternWire", "frame", (NOODLE[1] + 0.02, 6.2, 12.0), (-23.6, 5.2, 12.0), thick=0.03)
    for k, x in enumerate((-25.9, -25.2, -24.5)):
        K.lantern(m, l, x, 6.02 - 0.3 * k, 12.0, drop=0.12, kind=("lantern", "lamp_warm", "lantern")[k])
    for z in (-14.0, 0.5):
        p = m.group("Puddle", s)
        m.cyl(p, "Puddle", "water", (-24.6, 0, z), 1.6, 0.012, sides=10, solid=False, tint=(0.5, 0.5, 0.6))


# ---------------------------------------------------------------------------
# South-west: the pocket plaza

def plaza(m):
    s = m.folder("PlazaThings")
    # A fountain in the middle.
    f = m.group("Fountain", s)
    fx, fz = -31.2, 36.6
    m.cyl(f, "Basin", "planter", (fx, 0, fz), 3.6, 0.4, sides=16)
    m.pipe(f, "BasinRim", "planter", (fx, 0.4, fz), (fx, 0.6, fz), 3.6, sides=16, inner=3.1)
    m.cyl(f, "Water", "water", (fx, 0.4, fz), 3.1, 0.06, sides=16, solid=False)
    m.cyl(f, "Stem", "planter", (fx, 0.4, fz), 0.5, 1.1, sides=8)
    m.dome(f, "Bowl", "planter", (fx, 1.9, fz), (1.6, 0.5, 1.6), sides=12, flip=True, solid=False)
    m.cyl(f, "BowlWater", "water", (fx, 1.84, fz), 1.4, 0.06, sides=12, solid=False)
    m.pipe(f, "Glow", "neon_cyan", (fx, 0.05, fz), (fx, 0.12, fz), 3.76, sides=16, inner=3.6)
    K.street_tree(m, s, -36.2, 33.8, kind="leaves_pink", size=0.95, grate=False)
    K.street_tree(m, s, -26.0, 39.0, kind="leaves_pink", size=0.85, grate=False)
    K.street_tree(m, s, -36.4, 39.2, kind="leaves", size=0.8, grate=False)
    for (x, z) in ((-36.2, 33.8), (-26.0, 39.0), (-36.4, 39.2)):
        t = m.group("TreeBed", s)
        m.cyl(t, "TreeBed", "planter", (x, 0, z), 2.2, 0.4, sides=10)
        m.cyl(t, "TreeSoil", "soil", (x, 0.4, z), 1.8, 0.04, sides=10, solid=False)
    K.bench(m, s, -31.2, 33.4, "+z")
    K.bench(m, s, -27.2, 35.6, "-x")
    K.bin_(m, s, -29.6, 33.2)
    # A snack cart.
    c = At(m, m.group("SnackCart", s), (-34.6, 0, 36.2), "+x")
    c.s("Body", "cab_red", (-1.1, 0.3, -0.6), (1.1, 1.2, 0.6), bevel=0.05)
    c.b("Top", "wood_light", (-1.2, 1.2, -0.7), (1.2, 1.28, 0.7))
    for sx in (-1, 1):
        c.pipe("Wheel", "tyre", (sx * 0.8, 0.3, -0.66), (sx * 0.8, 0.3, 0.66), 0.6, sides=10)
        c.b("Post", "steel", (sx * 1.1 - 0.03, 1.28, -0.03), (sx * 1.1 + 0.03, 2.3, 0.03))
    c.wedge("Roof", "awning_yellow", (-1.3, 2.3, -0.9), (1.3, 2.7, 0.0), tall="+z")
    c.wedge("Roof", "awning_red", (-1.3, 2.3, 0.0), (1.3, 2.7, 0.9), tall="-z")
    for k in range(3):
        c.cyl("Pan", "chrome", (-0.7 + k * 0.7, 1.28, 0.1), 0.4, 0.1, sides=8)
    c.b("Lamp", "lamp_warm", (-0.9, 2.2, -0.05), (0.9, 2.28, 0.05))
    # A hedge along the back, lamps.
    h = m.group("Hedge", s)
    m.box(h, "HedgeBed", "planter", (BX0, 0, BZ1 - 1.0), (DINER[0] - 0.6, 0.5, BZ1))
    m.bev(h, "Hedge", "hedge", (BX0 + 0.1, 0.5, BZ1 - 0.9), (DINER[0] - 0.7, 1.4, BZ1 - 0.1), 0.15, solid=False)
    K.lamp_post(m, s, -25.0, 32.4, "-x", height=4.2, reach=0.9, kind="lamp_warm")
    K.lamp_post(m, s, -37.6, 36.6, "+x", height=4.2, reach=0.9, kind="lamp_warm")


# ---------------------------------------------------------------------------
# The streets' furniture

def streets(m):
    s = m.folder("StreetThings")
    # Main Street, the arcade's side.
    for x in (-33.0, -9.5, 9.5):
        K.lamp_post(m, s, x, MAIN_N - 0.6, "+z")
    K.street_tree(m, s, -16.0, 18.2, size=0.8)
    K.street_tree(m, s, 16.0, 18.2, size=0.8)
    K.hydrant(m, s, -8.0, 18.9)
    K.mailbox(m, s, 7.4, 18.7, "-z")
    K.news_box(m, s, 8.3, 18.8, "-z", "cab_red")
    K.news_box(m, s, 8.9, 18.8, "-z", "cab_blue")
    for x in (-6.5, -3.2, 3.2, 6.5):
        K.bollard(m, s, x, MAIN_N - 0.5)
    K.bench(m, s, -13.5, 16.2, "+z")
    K.bench(m, s, 13.5, 16.2, "+z")
    K.bin_(m, s, -11.4, 16.1)
    K.bin_(m, s, 20.6, 16.3)
    K.plant(m, s, -2.8, 16.2, size=1.1, pot="planter")
    K.plant(m, s, 2.8, 16.2, size=1.1, pot="planter")
    # ...and the far side.
    for x in (-21.0, 2.0, 21.0):
        K.lamp_post(m, s, x, MAIN_S + 0.6, "-z")
    K.hydrant(m, s, 13.6, 29.2)
    K.news_box(m, s, -5.2, 29.3, "+z", "cab_yellow")
    K.bin_(m, s, -3.4, 30.8)
    K.street_tree(m, s, 17.0, 30.0, size=0.8)
    K.street_tree(m, s, 33.0, 30.0, size=0.8)
    # A bus shelter outside the plaza: glass that breaks.
    b = m.group("BusShelter", s)
    for x in (-33.4, -29.6):
        m.box(b, "ShelterPost", "steel", (x - 0.06, 0, 30.9), (x + 0.06, 2.5, 31.02))
    m.box(b, "ShelterRoof", "frame", (-33.6, 2.5, 29.6), (-29.4, 2.62, 31.1))
    m.pane(b, "glass", "x", 30.96, -33.34, -31.5, 0.3, 2.4, name="ShelterGlass")
    m.pane(b, "glass", "x", 30.96, -31.5, -29.66, 0.3, 2.4, name="ShelterGlass")
    m.box(b, "ShelterBench", "wood_light", (-33.0, 0.4, 30.4), (-30.0, 0.48, 30.86))
    for x in (-32.8, -30.2):
        m.strip(b, "BenchLeg", "steel", (x - 0.04, 0, 30.5), (x + 0.04, 0.4, 30.8))
    m.strip(b, "ShelterLight", "lamp", (-33.2, 2.44, 30.0), (-29.8, 2.5, 30.2))
    m.cyl(b, "StopPole", "steel", (-28.8, 0, 29.3), 0.1, 2.7, sides=6)
    m.strip(b, "StopSign", "neon_cyan", (-29.1, 2.3, 29.27), (-28.5, 2.8, 29.33))
    # Parked along Main Street.
    K.car(m, s, -27.0, MAIN_N + 1.2, "+x", "car_blue")
    K.car(m, s, -20.0, MAIN_N + 1.2, "+x", "car_white")
    K.car(m, s, 9.0, MAIN_S - 1.2, "-x", "car_yellow", taxi=True)
    K.car(m, s, -12.0, MAIN_S - 1.2, "-x", "car_red")
    K.car(m, s, 38.0, MAIN_S - 1.2, "-x", "car_black")
    # The junction: two traffic lights.
    K.traffic_light(m, s, 23.2, MAIN_N - 0.5, "+z")
    K.traffic_light(m, s, 32.0, MAIN_S + 0.5, "-z")
    # The side street.
    K.lamp_post(m, s, SIDE_W - 0.6, -20.0, "+x")
    K.lamp_post(m, s, SIDE_W - 0.6, 2.0, "+x")
    K.lamp_post(m, s, SIDE_E + 0.6, -9.0, "-x")
    K.hydrant(m, s, 23.2, -6.0)
    K.car(m, s, 29.9, 9.0, "-z", "car_green")
    K.news_box(m, s, 31.9, 17.2, "-z", "cab_green")
    K.mailbox(m, s, 32.2, 3.0, "-x")
    K.bin_(m, s, 32.3, 8.2)
    # Wires of lanterns over Main Street, lamp post to lamp post.
    for k, (xa, xb) in enumerate(((-9.5, 2.0), (9.5, 21.0))):
        w = m.group("StreetLanterns", s)
        m.rod(w, "Wire", "frame", (xa, 5.6, MAIN_N - 0.6), (xb, 5.6, MAIN_S + 0.6), thick=0.03)
        for j in range(5):
            t = (j + 1) / 6.0
            x, z = xa + (xb - xa) * t, MAIN_N - 0.6 + (MAIN_S - MAIN_N + 1.2) * t
            K.lantern(m, w, x, 5.6, z, drop=0.1, kind=("lantern", "neon_cyan", "neon_pink")[(j + k) % 3])
