"""Rail Yard: a large arena (up to 16 players). A brick station hall with a mezzanine and a
walkable roof on the north side, four tracks with trains you can run through, island
platforms under canopies, a covered footbridge over everything, and a goods yard with a
shed, a signal box and a water tower on the south side.

Floors: street and yard 0 m, platforms and concourse 1 m, mezzanine and footbridge
6.5 m, station roof 13 m, signal box 4 m, water tower deck 10 m.
"""
import math
from arena_builder import Map, palette

PAL = "res://game/maps/palettes/rail_yard.tres"

COLORS = {
    "ground": (0.55, 0.52, 0.47), "street": (0.42, 0.42, 0.43), "pavement": (0.68, 0.67, 0.64),
    "ballast": (0.48, 0.45, 0.41), "rail": (0.36, 0.34, 0.33), "sleeper": (0.32, 0.25, 0.2),
    "platform": (0.78, 0.76, 0.72), "platform_edge": (0.96, 0.8, 0.18), "tactile": (0.9, 0.86, 0.7),
    "brick": (0.62, 0.3, 0.22), "brick_dark": (0.45, 0.22, 0.17), "stone_trim": (0.86, 0.82, 0.72),
    "tile": (0.82, 0.8, 0.74), "tile_dark": (0.42, 0.4, 0.38), "floorboard": (0.64, 0.47, 0.3),
    "plaster": (0.9, 0.86, 0.76), "glass": (0.64, 0.8, 0.86), "glass_rail": (0.62, 0.78, 0.84),
    "iron": (0.17, 0.33, 0.27), "iron_dark": (0.13, 0.2, 0.18), "canopy": (0.75, 0.78, 0.76),
    "roof": (0.33, 0.36, 0.4), "steel": (0.5, 0.53, 0.56), "steel_dark": (0.3, 0.32, 0.35),
    "train": (0.78, 0.2, 0.17), "train_stripe": (0.96, 0.93, 0.86), "train_roof": (0.55, 0.57, 0.6),
    "train_floor": (0.36, 0.38, 0.42), "train_seat": (0.2, 0.33, 0.6), "window_dark": (0.15, 0.2, 0.26),
    "loco": (0.16, 0.36, 0.58), "loco_yellow": (0.95, 0.75, 0.12), "wagon": (0.45, 0.3, 0.22),
    "wagon_grey": (0.52, 0.54, 0.52), "tank": (0.2, 0.2, 0.22), "coal": (0.12, 0.12, 0.13),
    "shed_wall": (0.56, 0.62, 0.6), "shed_roof": (0.48, 0.5, 0.52), "crate": (0.7, 0.55, 0.34),
    "crate_dark": (0.55, 0.42, 0.26), "pallet": (0.6, 0.5, 0.36), "concrete": (0.66, 0.66, 0.64),
    "bench": (0.42, 0.28, 0.18), "kiosk": (0.2, 0.45, 0.36), "awning": (0.86, 0.3, 0.24),
    "lamp": (1.0, 0.95, 0.8), "signal_red": (1.0, 0.2, 0.15), "signal_green": (0.3, 1.0, 0.45),
    "clock": (0.97, 0.95, 0.88), "sign": (0.12, 0.2, 0.36), "tunnel": (0.06, 0.06, 0.07),
    "backdrop": (0.6, 0.55, 0.52), "backdrop_dark": (0.48, 0.44, 0.43), "water_tank": (0.38, 0.42, 0.36),
    "timber": (0.42, 0.32, 0.22), "fence": (0.3, 0.32, 0.3), "plant": (0.34, 0.56, 0.3),
}
GLOW = {"lamp": 1.4, "signal_red": 2.5, "signal_green": 2.5, "clock": 0.4}
BREAKABLE = {
    "glass": 25, "glass_rail": 40, "plaster": 120, "floorboard": 220, "canopy": 140,
    "shed_wall": 110, "shed_roof": 140,
}

TRACKS = [-9.5, 0.5, 5.5, 15.5]          # track centre lines (z)
ISLANDS = [(-7, -2), (8, 13)]            # island platforms (z from, to)


def build(path):
    m = Map("RailYard", PAL,
            {"sky": {"sky_top_color": (0.3, 0.5, 0.82), "sky_horizon_color": (0.86, 0.84, 0.8),
                     "ground_bottom_color": (0.5, 0.47, 0.42), "ground_horizon_color": (0.8, 0.78, 0.74)},
             "lines": ["ambient_light_source = 2", "ambient_light_color = Color(0.78, 0.8, 0.88, 1)",
                       "ambient_light_energy = 0.7", "tonemap_mode = 2", "tonemap_white = 2.6",
                       "ssao_enabled = true", "glow_enabled = true"]},
            (48, 215, (1.0, 0.93, 0.82), 1.05),
            {"face_shade": "Vector3(0.93, 0.84, 0.66)", "kill_height": "-8.0",
             "bounds": "Rect2(-52, -46, 104, 92)", "swing_point": "Vector3(0, 9.6, 0)"})
    ground(m)
    tracks(m)
    platforms(m)
    station(m)
    footbridge(m)
    trains(m)
    gantries(m)
    yard(m)
    perimeter(m)
    spawns(m)
    pickups(m)
    m.write(path)
    palette(path.replace("game/maps/", "game/maps/palettes/").replace(".tscn", ".tres"), COLORS, GLOW, BREAKABLE)


def ground(m):
    g = m.group("Ground")
    m.box(g, "Yard", "ground", (-60, -1, -50), (60, 0, 50))
    m.box(g, "Far", "ground", (-200, -1.2, -200), (200, -0.15, 200), tint=(0.92, 0.92, 0.9))
    m.box(g, "Street", "street", (-50, 0, -46), (50, 0.02, -40), solid=False)
    m.box(g, "Pavement", "pavement", (-50, 0, -40), (50, 0.12, -36.4))


def tracks(m):
    f = m.folder("Tracks")
    m.box(f, "Ballast", "ballast", (-50, 0, -12), (50, 0.1, 18))
    for i, z in enumerate(TRACKS):
        g = m.group("Track%d" % (i + 1), f)
        for side in (-0.72, 0.72):
            m.box(g, "Rail", "rail", (-50, 0.1, z + side - 0.06), (50, 0.26, z + side + 0.06), solid=False)
        x = -49.0
        while x < 50:
            m.box(g, "Sleeper", "sleeper", (x - 0.13, 0.1, z - 1.25), (x + 0.13, 0.16, z + 1.25), solid=False)
            x += 1.5


def platforms(m):
    f = m.folder("Platforms")
    # Platform 1 runs along the station front; the islands sit between the tracks.
    plats = [("Platform1", -16, -12, 44, "1")] + [("Platform%d" % (i + 2), z0, z1, 38, str(i + 2)) for i, (z0, z1) in enumerate(ISLANDS)]
    for name, z0, z1, half, label in plats:
        g = m.group(name, f)
        m.box(g, "Deck", "platform", (-half, 0, z0), (half, 1.0, z1))
        for zz in (z0, z1):
            if name == "Platform1" and zz == z0:
                continue
            inner = zz + (0.45 if zz == z0 else -0.45)
            m.box(g, "Edge", "platform_edge", (-half, 1.0, min(zz, inner) if zz == z0 else inner), (half, 1.02, inner if zz == z0 else zz), solid=False)
            t = inner + (0.25 if zz == z0 else -0.25)
            m.box(g, "Tactile", "tactile", (-half, 1.0, min(inner, t)), (half, 1.015, max(inner, t)), solid=False)
        for sx in (-1, 1):   # ramps down to the track bed at both ends
            a = (sx * half, 1.0, (z0 + z1) / 2)
            b = (sx * (half + 4.5), 0.1, (z0 + z1) / 2)
            m.slab(g, "EndRamp", "platform", a, b, z1 - z0, thick=0.6)
        # Benches and lamp posts along the middle.
        mid = (z0 + z1) / 2
        for x in range(-30, 31, 12):
            if abs(x) < 4 or (name != "Platform1" and abs(x) in (6, 18)) or (name == "Platform1" and abs(x) == 30):
                continue
            m.box(g, "Bench", "bench", (x - 1.2, 1.0, mid - 0.3), (x + 1.2, 1.45, mid + 0.3))
            m.box(g, "BenchBack", "bench", (x - 1.2, 1.45, mid - 0.06), (x + 1.2, 1.95, mid + 0.06), solid=False)
        for x in range(-36, 37, 12):
            if name == "Platform1":
                break
            if abs(x) <= 12:
                continue
            m.cyl(g, "LampPost", "iron", (x, 1.0, mid), 0.18, 3.2, sides=8, solid=False)
            m.box(g, "Lamp", "lamp", (x - 0.25, 4.0, mid - 0.25), (x + 0.25, 4.3, mid + 0.25), solid=False)
        m.sign("PLATFORM " + label, (-20, 3.0, mid), yaw=0, size=72, col=(1, 1, 1, 1), parent="Signs")
        m.sign("PLATFORM " + label, (20, 3.0, mid), yaw=math.pi, size=72, col=(1, 1, 1, 1), parent="Signs")
    # Canopies over the islands, kept clear of the footbridge stairs.
    for i, (z0, z1) in enumerate(ISLANDS):
        g = m.group("Canopy%d" % (i + 1), f)
        mid = (z0 + z1) / 2
        spans = [(-34, -3), (13, 34)] if i == 0 else [(-34, -13), (3, 34)]
        for (x0, x1) in spans:
            m.box(g, "Roof", "canopy", (x0, 5.5, z0 - 0.2), (x1, 5.8, z1 + 0.2))
            m.box(g, "Fascia", "iron", (x0, 5.2, z0 - 0.3), (x1, 5.8, z0 - 0.2), solid=False)
            m.box(g, "Fascia", "iron", (x0, 5.2, z1 + 0.2), (x1, 5.8, z1 + 0.3), solid=False)
            x = x0 + 1.5
            while x <= x1 - 1.4:
                m.box(g, "Column", "iron", (x - 0.15, 1.0, mid - 0.15), (x + 0.15, 5.5, mid + 0.15))
                m.box(g, "Bracket", "iron", (x - 0.1, 5.0, z0), (x + 0.1, 5.5, z1), solid=False)
                x += 8


def station(m):
    f = m.folder("Station")
    X0, X1, Z0, Z1 = -30, 30, -36, -16
    g = m.group("Hall", f)
    m.box(g, "Concourse", "tile", (X0, 0, Z0), (X1, 1.0, Z1))
    for x in range(-28, 29, 4):   # darker tile bands
        m.box(g, "Band", "tile_dark", (x - 0.2, 1.0, Z0 + 0.5), (x + 0.2, 1.01, Z1 - 0.5), solid=False)
    # Front steps down to the street.
    m.stairs(g, "FrontSteps", (0, 0.12, -39.6), (0, 1.0, -36.4), 10, kind="stone_trim", rise=0.22, base=0)
    for sx in (-1, 1):
        m.box(g, "StepCheek", "brick_dark", (sx * 5 - 0.4, 0, -40), (sx * 5 + 0.4, 1.3, -36.4))
    # Outer walls (thick brick, they never break).
    T = 0.8
    m.wall(g, "NorthWall", "brick", (X0, Z0), (X1, Z0), 0, 13.6, T,
           holes=[(25, 35, 1.0, 5.5), (10, 14, 1.0, 4.0), (46, 50, 1.0, 4.0),
                  (4, 8, 8.0, 11.0), (18, 22, 8.0, 11.0), (38, 42, 8.0, 11.0), (52, 56, 8.0, 11.0)])
    for x0 in (4, 18, 38, 52):   # upper windows, glazed
        m.box(g, "Window", "glass", (X0 + x0, 8.0, Z0 - 0.05), (X0 + x0 + 4, 11.0, Z0 + 0.05))
    for x in (X0, X1):
        m.wall(g, "EndWall", "brick", (x, Z0), (x, Z1), 0, 13.6, T, holes=[(6, 10, 8.0, 11.0), (14, 18, 1.0, 4.2)])
        m.box(g, "EndWindow", "glass", (x - 0.05, 8.0, Z0 + 6), (x + 0.05, 11.0, Z0 + 10))
    # The platform side: a brick band with a clock over an open arcade of iron columns.
    m.wall(g, "FrontBand", "brick", (X0, Z1), (X1, Z1), 7.5, 13.6, 0.8, holes=[(27.5, 32.5, 7.5, 10.2)])
    m.box(g, "Cornice", "stone_trim", (X0 - 0.3, 13.6, Z1 - 0.6), (X1 + 0.3, 14.0, Z1 + 0.6))
    m.box(g, "Cornice", "stone_trim", (X0 - 0.3, 13.6, Z0 - 0.6), (X1 + 0.3, 14.0, Z0 + 0.6))
    m.cyl(g, "Clock", "clock", (0, 11.8, Z1 + 0.42), 2.6, 0.12, sides=24, solid=False, cols=((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    for x in (-23, -17, -11, -5, 5, 11, 17, 23):
        m.box(g, "ArcadeColumn", "iron", (x - 0.25, 1.0, Z1 - 0.25), (x + 0.25, 7.5, Z1 + 0.25))
    for x0, x1 in ((-30, -26), (26, 30)):
        m.box(g, "Pier", "brick", (x0, 1.0, Z1 - 0.4), (x1, 7.5, Z1 + 0.4))
    m.sign("CENTRAL", (-14, 10.6, Z1 + 0.5), size=150, col=(0.97, 0.94, 0.86, 1))
    m.sign("STATION", (14, 10.6, Z1 + 0.5), size=150, col=(0.97, 0.94, 0.86, 1))
    for sx in (-1, 1):   # steps down from the end doors
        m.slab(g, "EndDoorRamp", "stone_trim", (sx * 30.4, 1.0, -20), (sx * 34.4, 0, -20), 4, thick=0.5)
    m.sign("CENTRAL STATION", (0, 6.6, Z0 - 0.5), yaw=math.pi, size=110, col=(0.97, 0.94, 0.86, 1))

    # Mezzanine: z -36..-24 at 6.5 m, offices at both ends, a gallery in the middle.
    mz = m.group("Mezzanine", f)
    MZ = -24
    for (x0, x1) in ((X0, -14), (-14, 14), (14, X1)):
        m.box(mz, "Floor", "floorboard", (x0, 6.2, Z0), (x1, 6.5, MZ))
    m.box(mz, "Beam", "iron_dark", (X0, 5.7, MZ - 0.3), (X1, 6.2, MZ))
    for x in (-21, -7, 7, 21):
        m.box(mz, "Post", "iron", (x - 0.25, 1.0, MZ - 0.5), (x + 0.25, 5.7, MZ))
    # Glass railing along the edge, open where the stairs and the footbridge meet it.
    m.rail(mz, "Railing", "glass_rail", (X0, MZ - 0.06), (X1, MZ - 0.06), 6.5, 1.1, 0.12,
           holes=[(13.5, 16.0), (28, 32), (44.0, 46.5)])
    m.box(mz, "Handrail", "iron", (X0, 7.6, MZ - 0.02), (X1, 7.7, MZ + 0.14), solid=False)
    # Stairs up from the concourse (south of the mezzanine edge, with a landing at the top).
    for sx in (-1, 1):
        m.stairs(mz, "Stairs", (sx * 26, 1.0, -22.6), (sx * 16.5, 6.5, -22.6), 2.6, kind="stone_trim", side="iron", base=1.0)
        m.box(mz, "Landing", "floorboard", (min(sx * 16.5, sx * 14), 6.2, MZ - 0.01), (max(sx * 16.5, sx * 14), 6.5, -21.3), unbreakable=True)
        m.box(mz, "LandingPost", "iron", (sx * 15.25 - 0.2, 1.0, -21.7), (sx * 15.25 + 0.2, 6.2, -21.3))
    # Office partitions (plaster, they break) with doors.
    for x in (-14, 14):
        m.wall(mz, "Partition", "plaster", (x, Z0), (x, MZ), 6.5, 13.0, 0.25, holes=[(7.0, 8.6, 6.5, 8.8)])
    for sx in (-1, 1):   # cubicle screens
        m.wall(mz, "Screen", "plaster", (sx * 26, -29.3), (sx * 17, -29.3), 6.5, 8.1, 0.12, holes=[(4, 5.5, 6.5, 8.1)])
    for (cx, cz) in ((-24, -31), (-18, -31), (24, -31), (18, -31), (-24, -27.5), (22, -27.5)):
        m.box(mz, "Desk", "timber", (cx - 1.0, 6.5, cz - 0.5), (cx + 1.0, 7.3, cz + 0.5))
    for cx in (-26.5, 26.5):
        m.box(mz, "Cabinet", "steel", (cx - 1.5, 6.5, Z0 + 0.4), (cx + 1.5, 8.3, Z0 + 1.0))
    # The gallery: benches and a café counter.
    m.box(mz, "Counter", "kiosk", (-6, 6.5, -31.5), (6, 7.6, -30.5))
    for x in (-9, 9):
        m.box(mz, "GalleryBench", "bench", (x - 1.5, 6.5, -29.5), (x + 1.5, 6.95, -28.9))
    # Stair to the roof, along the north wall, under a hatch.
    m.stairs(mz, "RoofStairs", (-8, 6.5, -34.4), (3.3, 13.6, -34.4), 2.4, kind="steel_dark", side="iron", base=6.5)
    m.rail(mz, "StairGuard", "iron", (-8, -33.1), (3.3, -33.1), 6.5, 1.1, 0.1)

    # Roof at 13 m, with a hatch over the roof stair and a skylight (glass, breakable) over the hall.
    r = m.group("Roof", f)
    m.box(r, "RoofWest", "roof", (X0, 13.0, Z0), (-10, 13.6, Z1))
    m.box(r, "RoofEast", "roof", (10, 13.0, Z0), (X1, 13.6, Z1))
    m.box(r, "RoofMidNorth", "roof", (-10, 13.0, Z0), (-2.0, 13.6, -24))
    m.box(r, "RoofMidNorth", "roof", (-2.0, 13.0, -33.1), (10, 13.6, -24))
    m.box(r, "RoofHatchEnd", "roof", (3.3, 13.0, Z0), (10, 13.6, -33.1))
    m.box(r, "RoofMidSouth", "roof", (-10, 13.0, -18.5), (10, 13.6, Z1))
    for x0 in range(-10, 10, 4):
        m.box(r, "Skylight", "glass", (x0, 13.3, -24), (x0 + 4, 13.5, -18.5))
    for x0 in range(-10, 11, 4):
        m.box(r, "SkylightBar", "iron", (x0 - 0.1, 13.0, -24), (x0 + 0.1, 13.6, -18.5))
    m.rail(r, "HatchGuard", "iron", (-2.0, -33.0), (3.3, -33.0), 13.6, 1.0, 0.1)
    m.rail(r, "HatchGuard", "iron", (-2.05, Z0 + 0.4), (-2.05, -33.0), 13.6, 1.0, 0.1)
    for (x0, z0) in ((-26, -32), (18, -30)):
        m.box(r, "Vent", "steel", (x0, 13.6, z0), (x0 + 3, 15.2, z0 + 2.5))
    m.box(r, "ClockTower", "brick", (-3, 14.0, -18.5), (3, 18.5, -16.4))
    m.box(r, "ClockTowerCap", "stone_trim", (-3.4, 18.5, -18.9), (3.4, 19.0, -16.0))

    # Concourse furniture: ticket office (plaster walls), kiosks, benches.
    t = m.group("TicketOffice", f)
    m.wall(t, "Wall", "plaster", (-7, -33), (7, -33), 1.0, 4.4, 0.25, holes=[(9, 11, 1.0, 3.2)])
    m.wall(t, "Front", "plaster", (-7, -28.5), (7, -28.5), 1.0, 4.4, 0.25, holes=[(1, 5, 2.2, 3.4), (9, 13, 2.2, 3.4)])
    for x in (-7, 7):
        m.wall(t, "Side", "plaster", (x, -33), (x, -28.5), 1.0, 4.4, 0.25)
    m.box(t, "Roof", "floorboard", (-7.2, 4.4, -33.2), (7.2, 4.7, -28.3))
    m.box(t, "Counter", "timber", (-7, 1.0, -28.4), (7, 2.1, -27.9))
    m.sign("TICKETS", (0, 3.9, -28.3), size=64, col=(1, 0.86, 0.4, 1))
    k = m.group("Kiosks", f)
    for cx in (-21, 21):
        m.box(k, "Kiosk", "kiosk", (cx - 2, 1.0, -31), (cx + 2, 3.4, -28))
        m.box(k, "Awning", "awning", (cx - 2.3, 3.4, -28.6), (cx + 2.3, 3.6, -27.4))
    for x in (-12, 12):
        m.box(k, "Bench", "bench", (x - 1.5, 1.0, -20.3), (x + 1.5, 1.45, -19.7))
    m.box(k, "Departures", "sign", (-4, 3.0, -23.4), (4, 5.2, -23.0), solid=False)
    m.sign("DEPARTURES", (0, 4.6, -22.9), size=48, col=(1, 0.86, 0.3, 1))


def footbridge(m):
    """A covered footbridge from the mezzanine over all four tracks, with stairs down to
    the two island platforms and to the yard."""
    g = m.group("Footbridge")
    Z0, Z1 = -24, 20
    m.box(g, "Deck", "steel_dark", (-2, 6.1, Z0), (2, 6.5, Z1), unbreakable=True)
    # Side panels, open where the stairs arrive (platform 2 stair on the east, platform 3 on the west).
    m.wall(g, "EastSide", "iron", (2.05, -16), (2.05, Z1), 6.5, 7.6, 0.1, holes=[(10.3, 12.7, 6.5, 7.6)])
    m.wall(g, "WestSide", "iron", (-2.05, -16), (-2.05, Z1), 6.5, 7.6, 0.1, holes=[(25.3, 27.7, 6.5, 7.6)])
    m.box(g, "Roof", "canopy", (-2.4, 9.5, -16), (2.4, 9.8, Z1))
    z = -14.0
    while z <= Z1:
        for sx in (-1, 1):
            m.box(g, "RoofPost", "iron", (sx * 2.1 - 0.1, 6.5, z - 0.1), (sx * 2.1 + 0.1, 9.5, z + 0.1), solid=False)
        z += 4
    for (z0, z1) in ((-13.6, -12.4), (-4.9, -4.1), (10.1, 10.9), (19.0, 20.0)):
        for sx in (-1, 1):
            m.box(g, "Leg", "iron", (sx * 1.6 - 0.25, 0 if z0 > 18 else 1.0, z0), (sx * 1.6 + 0.25, 6.1, z1))
    # Stairs: platform 2 (east side), platform 3 (west side), down to the yard (south end).
    m.stairs(g, "StairsPlatform2", (12.2, 1.0, -4.5), (2.0, 6.5, -4.5), 2.4, kind="steel_dark", side="iron", base=1.0)
    m.stairs(g, "StairsPlatform3", (-12.2, 1.0, 10.5), (-2.0, 6.5, 10.5), 2.4, kind="steel_dark", side="iron", base=1.0)
    m.stairs(g, "StairsYard", (0, 0, 31.2), (0, 6.5, Z1), 4.0, kind="steel_dark", side="iron", base=0)
    m.sign("PLATFORMS 2 - 3", (0, 9.0, -15.9), size=56, col=(1, 1, 1, 1))


def carriage(m, parent, name, x0, x1, z, doors=(0.2, 0.5, 0.8)):
    """A passenger carriage you can walk through: floor at 1 m (platform height), doors on
    both sides, open window bands, gangway doors at both ends."""
    g = m.group(name, parent)
    W = 1.5
    L = x1 - x0
    m.box(g, "Under", "steel_dark", (x0 + 1, 0.3, z - 1.1), (x1 - 1, 0.7, z + 1.1))
    for bx in (x0 + 3, x1 - 3):
        m.box(g, "Bogie", "steel_dark", (bx - 1.4, 0.1, z - 1.0), (bx + 1.4, 0.6, z + 1.0), solid=False)
    m.box(g, "Floor", "train_floor", (x0, 0.7, z - W), (x1, 1.0, z + W))
    holes = [(L * f - 0.8, L * f + 0.8, 1.0, 3.3) for f in doors]
    win = []
    u = 1.0
    while u < L - 1.0:
        if all(abs(u + 0.9 - L * f) > 1.9 for f in doors):
            win.append((u, u + 1.8, 2.0, 3.2))
        u += 2.4
    for side in (-1, 1):
        zz = z + side * (W - 0.08)
        m.wall(g, "Side", "train", (x0, zz), (x1, zz), 1.0, 4.0, 0.16, holes=sorted(holes + win))
        m.box(g, "Stripe", "train_stripe", (x0, 1.6, zz - 0.1), (x1, 1.75, zz + 0.1), solid=False)
        for fd in doors:   # door plates over the gap to the platform edge
            dx = x0 + L * fd
            za, zb = sorted((z + side * W, z + side * (W + 1.0)))
            m.box(g, "DoorPlate", "steel", (dx - 0.8, 0.85, za), (dx + 0.8, 1.0, zb))
    for xx in (x0 + 0.08, x1 - 0.08):
        m.wall(g, "End", "train", (xx, z - W), (xx, z + W), 1.0, 4.0, 0.16, holes=[(1.0, 2.0, 1.0, 3.2)])
    m.box(g, "Roof", "train_roof", (x0, 4.0, z - W - 0.05), (x1, 4.3, z + W + 0.05))
    for u in range(4, int(L) - 3, 4):
        if all(abs(u - L * f) > 1.8 for f in doors):
            m.box(g, "Seat", "train_seat", (x0 + u - 0.8, 1.0, z - W + 0.2), (x0 + u + 0.8, 1.55, z - W + 0.7))
            m.box(g, "Seat", "train_seat", (x0 + u - 0.8, 1.0, z + W - 0.7), (x0 + u + 0.8, 1.55, z + W - 0.2))
    return g


def trains(m):
    f = m.folder("Trains")
    # Track 1: a passenger train you can run through between platforms 1 and 2.
    zA = TRACKS[0]
    for i, (x0, x1) in enumerate(((-38, -20), (-19, -1), (2, 20))):
        carriage(m, f, "Carriage%d" % (i + 1), x0, x1, zA)
    loco(m, f, "Engine", 21, 37, zA, "loco", face=1)
    for (x0, x1) in ((-20, -19), (-1, 2)):
        m.box(f, "Gangway", "steel", (x0, 0.85, zA - 0.5), (x1, 1.0, zA + 0.5))
    # Track 2: a freight engine and box wagons at the east end.
    zB = TRACKS[1]
    loco(m, f, "FreightEngine", 6, 20, zB, "loco_yellow", face=-1)
    for i, x0 in enumerate((21, 34)):
        g = m.group("BoxWagon%d" % (i + 1), f)
        m.box(g, "Under", "steel_dark", (x0 + 0.5, 0.3, zB - 1.1), (x0 + 11.5, 0.8, zB + 1.1))
        m.box(g, "Body", "wagon", (x0, 0.8, zB - 1.5), (x0 + 12, 4.0, zB + 1.5))
        m.box(g, "Roof", "wagon_grey", (x0 - 0.1, 4.0, zB - 1.6), (x0 + 12.1, 4.25, zB + 1.6))
        m.box(g, "Door", "wagon_grey", (x0 + 4.5, 1.0, zB - 1.56), (x0 + 7.5, 3.8, zB + 1.56), solid=False)
    # Track 3: tank wagons at the west end.
    zC = TRACKS[2]
    for i, x0 in enumerate((-44, -31)):
        g = m.group("TankWagon%d" % (i + 1), f)
        m.box(g, "Frame", "steel_dark", (x0, 0.3, zC - 1.2), (x0 + 12, 1.0, zC + 1.2))
        m.lying_cyl(g, "Tank", "tank", (x0 + 6, 2.5, zC), 2.9, 11.0, axis="x", sides=16)
        m.cyl(g, "Dome", "tank", (x0 + 6, 3.8, zC), 1.2, 0.6, sides=12)
        m.box(g, "Walkway", "steel", (x0 + 1, 3.9, zC - 0.6), (x0 + 11, 4.0, zC + 0.6))
    # Track 4: open coal wagons under the gantries.
    zD = TRACKS[3]
    for i, x0 in enumerate((-36, -24, 4, 16, 28)):
        g = m.group("CoalWagon%d" % (i + 1), f)
        m.box(g, "Under", "steel_dark", (x0 + 0.5, 0.3, zD - 1.1), (x0 + 10.5, 0.9, zD + 1.1))
        m.box(g, "Floor", "wagon_grey", (x0, 0.9, zD - 1.5), (x0 + 11, 1.4, zD + 1.5))
        for zz in (zD - 1.42, zD + 1.42):
            m.box(g, "Side", "wagon_grey", (x0, 1.4, zz - 0.08), (x0 + 11, 3.2, zz + 0.08))
        for xx in (x0 + 0.08, x0 + 10.92):
            m.box(g, "End", "wagon_grey", (xx - 0.08, 1.4, zD - 1.5), (xx + 0.08, 3.2, zD + 1.5))
        m.box(g, "Coal", "coal", (x0 + 0.3, 1.4, zD - 1.3), (x0 + 10.7, 2.6, zD + 1.3))
    # Buffer stops at the east ends of tracks 3 and 4.
    for z in (zC, zD):
        g = m.group("Buffer", f)
        m.box(g, "Stop", "steel_dark", (46, 0.1, z - 1.4), (47.5, 1.6, z + 1.4))
        m.box(g, "Beam", "loco_yellow", (45.6, 0.8, z - 1.5), (46, 1.3, z + 1.5))


def loco(m, parent, name, x0, x1, z, kind, face=1):
    """An engine: a cab at the front end (`face` +1 = east, -1 = west) and a long bonnet."""
    g = m.group(name, parent)
    m.box(g, "Under", "steel_dark", (x0 + 0.5, 0.3, z - 1.2), (x1 - 0.5, 1.0, z + 1.2))
    m.box(g, "Deck", "steel", (x0, 1.0, z - 1.5), (x1, 1.3, z + 1.5))
    cab = (x1 - 4.5, x1 - 0.5) if face > 0 else (x0 + 0.5, x0 + 4.5)
    hood = (x0 + 0.5, cab[0]) if face > 0 else (cab[1], x1 - 0.5)
    m.box(g, "Hood", kind, (hood[0], 1.3, z - 1.1), (hood[1], 3.6, z + 1.1))
    m.box(g, "Cab", kind, (cab[0], 1.3, z - 1.45), (cab[1], 4.3, z + 1.45))
    m.box(g, "CabRoof", "train_roof", (cab[0] - 0.1, 4.3, z - 1.5), (cab[1] + 0.1, 4.5, z + 1.5))
    wx = cab[1] if face > 0 else cab[0]
    m.box(g, "Windscreen", "window_dark", (wx - 0.06, 3.0, z - 1.2), (wx + 0.06, 4.0, z + 1.2), solid=False)
    for zz in (z - 1.47, z + 1.47):
        m.box(g, "CabWindow", "window_dark", (cab[0] + 0.6, 3.0, zz - 0.03), (cab[1] - 0.6, 3.9, zz + 0.03), solid=False)
    m.box(g, "Stripe", "loco_yellow" if kind != "loco_yellow" else "steel_dark", (x0, 1.3, z - 1.52), (x1, 1.55, z + 1.52), solid=False)
    lx = x1 + 0.02 if face > 0 else x0 - 0.02
    m.box(g, "Headlamp", "lamp", (lx - 0.05, 3.5, z - 0.3), (lx + 0.05, 3.8, z + 0.3), solid=False)


def gantries(m):
    """Overhead line gantries across the tracks: iron beams to grapple and walk along."""
    f = m.folder("Gantries")
    for x in (-36, -20, 20, 36):
        g = m.group("Gantry", f)
        m.box(g, "PostNorth", "iron", (x - 0.25, 1.0, -13.5), (x + 0.25, 8.2, -13.0))
        m.box(g, "PostSouth", "iron", (x - 0.25, 0, 18.6), (x + 0.25, 8.2, 19.1))
        m.box(g, "Beam", "iron", (x - 0.3, 7.6, -13.5), (x + 0.3, 8.2, 19.1))
        for z in TRACKS:
            m.box(g, "Dropper", "iron_dark", (x - 0.04, 6.2, z - 0.04), (x + 0.04, 7.6, z + 0.04), solid=False)
    w = m.group("Wires", f)
    for z in TRACKS:
        m.box(w, "Wire", "iron_dark", (-50, 6.15, z - 0.03), (50, 6.21, z + 0.03), solid=False)
        m.box(w, "Catenary", "iron_dark", (-50, 7.3, z - 0.03), (50, 7.36, z + 0.03), solid=False)
    # Signals on platform 1 and the yard side.
    for (x, z, col) in ((-44, -13, "signal_red"), (44, -13, "signal_green"), (-46, 18.8, "signal_green"), (46, 18.8, "signal_red")):
        g = m.group("Signal", f)
        base = 1.0 if z < 0 else 0.0
        m.box(g, "Post", "steel_dark", (x - 0.15, base, z - 0.15), (x + 0.15, base + 5.0, z + 0.15))
        m.box(g, "Head", "steel_dark", (x - 0.35, base + 5.0, z - 0.3), (x + 0.35, base + 6.4, z + 0.3))
        m.box(g, "Light", col, (x - 0.2, base + 5.8, z - 0.32), (x + 0.2, base + 6.2, z + 0.32), solid=False)


def crates(m, parent, name, x, z, layout):
    """A stack of 1.2 m crates: layout is a list of (dx, dz, height in crates)."""
    g = m.group(name, parent, at=(x, 0, z))
    for i, (dx, dz, h) in enumerate(layout):
        for k in range(h):
            kind = "crate" if (i + k) % 2 == 0 else "crate_dark"
            m.box(g, "Crate", kind, (dx - 0.6, k * 1.2, dz - 0.6), (dx + 0.6, (k + 1) * 1.2, dz + 0.6))
    return g


def yard(m):
    f = m.folder("Yard")
    # Goods shed: corrugated walls and roof (both break), loading office on a mezzanine.
    s = m.group("GoodsShed", f)
    SX0, SX1, SZ0, SZ1 = -44, -14, 24, 40
    m.box(s, "Floor", "concrete", (SX0, 0, SZ0), (SX1, 0.12, SZ1))
    m.wall(s, "NorthWall", "shed_wall", (SX0, SZ0), (SX1, SZ0), 0.12, 8.0, 0.3, holes=[(5, 10, 0.12, 5.0), (19, 24, 0.12, 5.0)])
    m.wall(s, "SouthWall", "shed_wall", (SX0, SZ1), (SX1, SZ1), 0.12, 8.0, 0.3, holes=[(13, 17, 1.5, 3.5)])
    m.wall(s, "WestWall", "shed_wall", (SX0, SZ0), (SX0, SZ1), 0.12, 8.0, 0.3, holes=[(4, 12, 4.8, 6.6)])
    m.wall(s, "EastWall", "shed_wall", (SX1, SZ0), (SX1, SZ1), 0.12, 8.0, 0.3, holes=[(5, 10, 0.12, 4.5)])
    for x0 in range(SX0, SX1, 6):
        m.box(s, "RoofPanel", "shed_roof", (x0, 8.0, SZ0 - 0.3), (x0 + 6, 8.3, SZ1 + 0.3))
    for x in range(SX0 + 6, SX1, 6):
        m.box(s, "Truss", "steel_dark", (x - 0.15, 7.2, SZ0), (x + 0.15, 8.0, SZ1))
        m.box(s, "Column", "steel_dark", (x - 0.2, 0.12, SZ0 + 0.15), (x + 0.2, 7.2, SZ0 + 0.55))
        m.box(s, "Column", "steel_dark", (x - 0.2, 0.12, SZ1 - 0.55), (x + 0.2, 7.2, SZ1 - 0.15))
    m.box(s, "OfficeFloor", "floorboard", (SX0, 3.7, 35), (-26, 4.0, SZ1))
    m.box(s, "OfficeBeam", "steel_dark", (SX0, 3.3, 34.7), (-26, 3.7, 35.1))
    for x in (-38, -32, -26.3):
        m.box(s, "OfficePost", "steel_dark", (x - 0.2, 0.12, 34.7), (x + 0.2, 3.3, 35.1))
    m.rail(s, "OfficeRail", "steel", (SX0, 35.05), (-26, 35.05), 4.0, 1.1, 0.1, holes=[(13.8, 16.0)])
    m.stairs(s, "OfficeStairs", (-29.1, 0.12, 27), (-29.1, 4.0, 35), 2.2, kind="steel_dark", side="steel", base=0.12)
    crates(m, s, "ShedCrates", -36, 29, [(0, 0, 2), (1.2, 0, 3), (2.4, 0, 1), (0, 1.2, 1), (1.2, 1.2, 2)])
    crates(m, s, "ShedCrates", -22, 30, [(0, 0, 1), (0, 1.2, 2), (1.2, 1.2, 1)])
    m.box(s, "Forklift", "loco_yellow", (-21, 0.12, 34), (-19, 2.2, 36.5))
    m.sign("GOODS", (-29, 6.4, SZ0 - 0.2), yaw=math.pi, size=120, col=(0.98, 0.9, 0.7, 1))

    # Signal box: a brick ground floor and a glazed lookout room at 4 m, stairs on the east side.
    b = m.group("SignalBox", f)
    BX0, BX1, BZ0, BZ1 = 24, 32, 22, 28
    m.box(b, "Base", "brick", (BX0, 0, BZ0), (BX1, 3.7, BZ0 + 0.5))
    m.box(b, "Base", "brick", (BX0, 0, BZ1 - 0.5), (BX1, 3.7, BZ1))
    m.wall(b, "BaseWest", "brick", (BX0 + 0.25, BZ0 + 0.5), (BX0 + 0.25, BZ1 - 0.5), 0, 3.7, 0.5, holes=[(2, 3.4, 0, 2.6)])
    m.wall(b, "BaseEast", "brick", (BX1 - 0.25, BZ0 + 0.5), (BX1 - 0.25, BZ1 - 0.5), 0, 3.7, 0.5)
    m.box(b, "Floor", "floorboard", (BX0, 3.7, BZ0), (BX1, 4.0, BZ1), unbreakable=True)
    m.box(b, "Lookout", "timber", (BX0, 4.0, BZ0), (BX1, 5.0, BZ0 + 0.2))
    m.box(b, "Lookout", "timber", (BX0, 4.0, BZ1 - 0.2), (BX1, 5.0, BZ1))
    m.box(b, "LookoutWest", "timber", (BX0, 4.0, BZ0 + 0.2), (BX0 + 0.2, 5.0, BZ1 - 0.2))
    m.wall(b, "LookoutEast", "timber", (BX1 - 0.1, BZ0 + 0.2), (BX1 - 0.1, BZ1 - 0.2), 4.0, 5.0, 0.2, holes=[(0.6, 2.2, 4.0, 5.0)])
    m.box(b, "DoorFrame", "timber", (BX1 - 0.2, 6.6, BZ0 + 0.8), (BX1, 7.2, BZ0 + 2.4))
    m.box(b, "Glass", "glass", (BX0, 5.0, BZ0), (BX1, 7.2, BZ0 + 0.1))
    m.box(b, "Glass", "glass", (BX0, 5.0, BZ1 - 0.1), (BX1, 7.2, BZ1))
    m.box(b, "GlassWest", "glass", (BX0, 5.0, BZ0 + 0.1), (BX0 + 0.1, 7.2, BZ1 - 0.1))
    m.box(b, "Roof", "roof", (BX0 - 0.6, 7.2, BZ0 - 0.6), (BX1 + 0.6, 7.6, BZ1 + 0.6))
    m.box(b, "Levers", "signal_red", (BX0 + 1, 4.0, BZ0 + 2.6), (BX1 - 2.5, 4.9, BZ0 + 3.4))
    m.stairs(b, "Stairs", (33.4, 0, 32.4), (33.4, 4.0, 24.6), 2.2, kind="timber", side="timber", base=0)
    m.box(b, "Landing", "timber", (BX1, 3.7, BZ0), (34.6, 4.0, 24.6))
    m.box(b, "LandingPost", "timber", (34.2, 0, BZ0 + 0.1), (34.5, 3.7, BZ0 + 0.4))
    m.sign("SIGNAL BOX", (28, 6.2, BZ1 + 0.15), size=56, col=(1, 1, 1, 1))

    # Water tower: four legs and a tank over a deck at 10 m (grapple up, or rocket-boot).
    w = m.group("WaterTower", f)
    cx, cz = 38, 35
    for dx in (-2.6, 2.6):
        for dz in (-2.6, 2.6):
            m.box(w, "Leg", "timber", (cx + dx - 0.3, 0, cz + dz - 0.3), (cx + dx + 0.3, 9.7, cz + dz + 0.3))
    m.box(w, "Brace", "timber", (cx - 2.6, 4.6, cz - 2.7), (cx + 2.6, 4.9, cz - 2.5), solid=False)
    m.box(w, "Brace", "timber", (cx - 2.6, 4.6, cz + 2.5), (cx + 2.6, 4.9, cz + 2.7), solid=False)
    m.box(w, "Deck", "timber", (cx - 4, 9.7, cz - 4), (cx + 4, 10.0, cz + 4))
    m.cyl(w, "Tank", "water_tank", (cx, 10.0, cz), 5.4, 4.6, sides=20)
    m.cyl(w, "Cap", "roof", (cx, 14.6, cz), 5.8, 0.4, sides=20)
    m.rail(w, "Rail", "timber", (cx - 4, cz - 3.95), (cx + 4, cz - 3.95), 10.0, 1.0, 0.1)
    m.rail(w, "Rail", "timber", (cx - 4, cz + 3.95), (cx + 4, cz + 3.95), 10.0, 1.0, 0.1)

    # Crates, pallets and a sleeper pile for cover across the yard.
    crates(m, f, "Crates", 8, 25, [(0, 0, 2), (1.2, 0, 1), (0, 1.2, 1)])
    crates(m, f, "Crates", -8, 24, [(0, 0, 1), (1.2, 0, 2), (2.4, 0, 1)])
    crates(m, f, "Crates", 14, 36, [(0, 0, 3), (1.2, 0, 2), (0, 1.2, 2), (1.2, 1.2, 1)])
    crates(m, f, "Crates", -7, 35, [(0, 0, 2), (0, 1.2, 1)])
    crates(m, f, "Crates", 44, 24, [(0, 0, 1), (0, 1.2, 2)])
    p = m.group("SleeperPile", f)
    for k in range(4):
        m.box(p, "Sleepers", "sleeper", (20, k * 0.3, 39 - k * 0.2), (27, (k + 1) * 0.3, 41 - k * 0.2))
    for (x, z) in ((-10, 29), (4, 39), (19, 30)):
        g = m.group("Pallet", f, at=(x, 0, z))
        m.box(g, "Pallet", "pallet", (-0.6, 0, -0.5), (0.6, 0.15, 0.5))
        m.box(g, "Sacks", "crate_dark", (-0.5, 0.15, -0.4), (0.5, 0.9, 0.4))


def perimeter(m):
    f = m.folder("Perimeter")
    g = m.group("Walls", f)
    for x in (-50, 50):
        # Track portals: dark tunnel mouths in the side walls.
        m.wall(g, "SideWall", "brick_dark", (x, -46), (x, 46), 0, 6.0, 1.0, holes=[(34, 64, 0, 5.2)])
        m.box(g, "Tunnel", "tunnel", (x - 0.4 if x < 0 else x + 0.4, 0, -12), (x - 1.0 if x < 0 else x + 1.0, 5.2, 18))
        m.box(g, "Arch", "stone_trim", (x - 0.6, 5.2, -12), (x + 0.6, 6.4, 18))
    m.box(g, "SouthWall", "brick_dark", (-50, 0, 45.5), (50, 6.0, 46.5))
    m.box(g, "NorthWall", "brick_dark", (-50, 0, -46.5), (50, 3.0, -45.5))
    # Town backdrop beyond the walls (out of reach).
    b = m.group("Backdrop", f)
    x = -60
    i = 0
    for (w, h) in ((14, 16), (10, 22), (18, 14), (12, 26), (16, 18), (11, 12), (20, 20), (13, 24), (9, 15)):
        kind = "backdrop" if i % 2 == 0 else "backdrop_dark"
        m.box(b, "Building", kind, (x, 0, -66), (x + w, h, -52))
        x += w + 1
        i += 1
    for (z0, z1, h) in ((-40, -16, 18), (22, 44, 14)):
        for sx in (-1, 1):
            m.box(b, "Building", "backdrop_dark", (sx * 58 - 6, 0, z0), (sx * 58 + 6, h, z1))
    for x in range(-56, 57, 14):
        m.box(b, "Warehouse", "backdrop", (x, 0, 54), (x + 12, 10, 66))


def spawns(m):
    pts = [
        # concourse
        ((-24, 1.0, -26), (0, -10)), ((24, 1.0, -26), (0, -10)), ((-10, 1.0, -34), (0, 0)), ((10, 1.0, -34), (0, 0)),
        # mezzanine and roof
        ((-22, 6.5, -34), (0, -10)), ((22, 6.5, -34), (0, -10)), ((-6, 6.5, -26.5), (0, 0)), ((24, 13.6, -20), (0, 0)),
        # platforms
        ((-33, 1.0, -14), (0, 0)), ((33, 1.0, -14), (0, 0)), ((-24, 1.0, -3.2), (0, 10)), ((28, 1.0, -3.2), (0, 10)),
        ((-28, 1.0, 10.5), (0, -10)), ((24, 1.0, 10.5), (0, -10)),
        # yard, shed, signal box
        ((-34, 0.12, 37.5), (0, 0)), ((-18, 0.12, 27), (0, 0)), ((-40, 4.0, 38), (0, 0)), ((30.6, 4.0, 26.6), (0, 0)),
        ((8, 0, 32), (0, 0)), ((40, 0, 28), (0, 0)), ((-4, 0, 42), (0, 0)), ((30, 0, 40), (0, 0)),
    ]
    for p, t in pts:
        m.spawn(p, t)


def pickups(m):
    for (p, w) in [
        ((0, 1.0, -26.5), "shotgun"), ((0, 6.5, -30), "sniper"), ((-27, 6.5, -27.5), "revolver"),
        ((0, 13.6, -28), "railgun"), ((-9, 1.0, -14), "smg"), ((0, 1.0, -4.5), "rifle"),
        ((0, 1.0, 10.5), "lmg"), ((-10, 4.3, TRACKS[0]), "dagger"), ((28, 4.0, 24.6 - 1.4), "lever_action"),
        ((-33, 0.12, 32.5), "grenade_launcher"), ((-35, 4.0, 37.5), "hammer"), ((38, 10.0, 31.6), "rocket_launcher"),
        ((10, 0, 41), "burst_rifle"), ((0, 6.5, 6), "spear"), ((-42, 0.1, 0.5), "machine_pistol"),
    ]:
        m.weapon(p, w)
