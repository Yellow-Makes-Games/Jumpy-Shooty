"""Neon Arcade's last layer of things to look at: signs, lamps, pipes, pixel art, bikes,
wires, weeds. Nearly all drawn only. What hangs on a building is in that building's
folder, so it goes when the wall behind it does and falls with the building.
"""
import neon_arcade_kit as K
from neon_arcade_kit import At


def build(m):
    arcade_outside(m)
    arcade_inside(m)
    arcade_roof(m)
    neighbours(m)
    back_lot(m)
    streets(m)


def arcade_outside(m):
    from neon_arcade import OX0, OX1, OZ0, OZ1, RB
    g = m.group("OutsideDetails", "Arcade/Walls")
    # The back wall: three pictures in neon dots, the dock's name, pipes, vents, a lamp over the door.
    for (x, art, kind) in ((-7.5, "heart", "neon_pink"), (0.0, "bolt", "neon_yellow"), (7.0, "star", "neon_cyan")):
        K.pixel_art(m, g, "x", OZ0, -1, x, 4.3, 0.42, art, kind, depth=0.06)
    m.text(g, "DELIVERIES", "x", OZ0, -1, -18.0, 3.95, 0.05, "neon_orange", depth=0.05)
    for x in (-13.5, 13.5):
        K.drainpipe(m, g, "x", OZ0, -1, x, 0, RB - 0.2)
    K.wall_vent(m, g, "x", OZ0, -1, -11.0, 6.9)
    K.wall_vent(m, g, "x", OZ0, -1, 17.0, 6.9)
    K.wall_lamp(m, g, "x", OZ0, -1, 10.7, 2.95)
    m.on_wall(g, "FuseBox", "ac_unit", "x", OZ0, -1, 12.0, 12.9, 0.9, 2.2, 0.26)
    m.on_wall(g, "FuseBoxDoor", "frame", "x", OZ0, -1, 12.08, 12.82, 1.0, 2.1, 0.02, lift=0.26)
    m.on_wall(g, "FuseBoxMark", "hazard", "x", OZ0, -1, 12.3, 12.6, 1.6, 1.9, 0.02, lift=0.28)
    m.pipe(g, "Conduit", "steel", (12.45, 2.2, OZ0 - 0.07), (12.45, RB - 0.3, OZ0 - 0.07), 0.07, sides=6)
    # The alley wall: lamps over the doors, a pipe, a picture; an arrow to the way in.
    K.wall_lamp(m, g, "z", OX0, -1, 6.8, 2.95)
    K.drainpipe(m, g, "z", OX0, -1, 13.8, 0, RB - 0.2)
    K.pixel_art(m, g, "z", OX0, -1, 11.0, 1.0, 0.3, "note", "neon_green", depth=0.05)
    K.wall_vent(m, g, "z", OX0, -1, -12.0, 2.6, w=1.0, h=0.6)
    # The side street wall: a blade sign, lamps, pipes.
    K.blade_sign(m, g, "z", OX1, 1, -7.5, 3.6, "GAMES", "neon_pink", px=0.1, edge="neon_cyan")
    K.wall_lamp(m, g, "z", OX1, 1, -12.2, 2.95)
    for z in (-14.6, 4.9):
        K.drainpipe(m, g, "z", OX1, 1, z, 0, RB - 0.2)
    K.wall_vent(m, g, "z", OX1, 1, -9.5, 6.4)
    # The front: a blade sign at each end.
    K.blade_sign(m, g, "x", OZ1, 1, -20.6, 4.3, "PLAY", "neon_yellow", px=0.1, edge="neon_pink")
    K.blade_sign(m, g, "x", OZ1, 1, 20.6, 4.3, "WIN", "neon_green", px=0.1, edge="neon_pink")


def arcade_inside(m):
    from neon_arcade import X0, X1, Z0, Z1, MY
    g = m.group("HallDetails", "Arcade/Trusses")
    # Banners hanging from the trusses over the hall, a neon arrow to each stair.
    for k, (x, z) in enumerate(((-5.2, -5.0), (5.2, -5.0), (-5.2, 5.0), (5.2, 5.0))):
        kind = ("awning_red", "awning_teal", "awning_yellow", "cab_purple")[k]
        m.strip(g, "BannerRod", "steel", (x - 0.9, 7.34, z - 0.03), (x + 0.9, 7.4, z + 0.03))
        m.strip(g, "Banner", kind, (x - 0.8, 5.3, z - 0.02), (x + 0.8, 7.34, z + 0.02))
        for s in (-1, 1):
            K.pixel_art(m, g, "x", z + s * 0.02, s, x, 5.8, 0.16, ("star", "heart", "bolt", "note")[k], "hockey", depth=0.02)
    e = m.group("ExitSigns", "Arcade/Walls")
    m.text(e, "EXIT", "x", Z1, -1, 0.0, 3.46, 0.04, "neon_green", depth=0.04)
    m.text(e, "EXIT", "z", X1, -1, 12.0, 3.26, 0.04, "neon_green", depth=0.04)
    m.text(e, "EXIT", "z", X0, 1, 6.8, 2.8, 0.04, "neon_green", depth=0.04)
    m.text(e, "EXIT", "x", Z0, 1, 10.7, 2.8, 0.04, "neon_green", depth=0.04)


def arcade_roof(m):
    from neon_arcade import RT
    g = m.folder("RoofDetails", "Arcade/Roof")
    K.deck_chair(m, g, -10.6, 7.6, "+z", y=RT)
    K.deck_chair(m, g, -9.2, 7.6, "+z", y=RT, kind="awning_red")
    c = m.group("Cooler", g)
    m.bev(c, "Cooler", "cab_blue", (-8.4, RT, 8.3), (-7.8, RT + 0.42, 8.7), 0.04)
    m.strip(c, "CoolerLid", "hockey", (-8.42, RT + 0.42, 8.28), (-7.78, RT + 0.48, 8.72))
    K.dish(m, g, 17.2, -3.4, RT, face="+z")
    K.dish(m, g, -18.6, 2.6, RT, face="+x", d=1.1)
    p = m.group("RoofPipes", g)
    m.pipe(p, "RoofPipe", "steel", (-13.0, RT + 0.2, -9.6), (-13.0, RT + 0.2, 8.2), 0.16, sides=6)
    m.pipe(p, "RoofPipe", "steel", (-13.0, RT + 0.2, 8.2), (-15.0, RT + 0.2, 8.2), 0.16, sides=6)
    for z in (-8.0, -3.0, 2.0, 7.0):
        m.strip(p, "PipeBlock", "truss", (-13.14, RT, z - 0.1), (-12.86, RT + 0.13, z + 0.1))
    K.pallet(m, g, 10.5, 10.5, y=RT, load="cardboard")
    K.crate(m, g, -3.0, -12.4, y=RT, size=0.8)


def neighbours(m):
    from neon_arcade_block import NOODLE, RECORD, DINER, WASH
    # The noodle bar: a blade sign on Main Street, a lamp over the back door, pipes.
    n = m.group("OutsideDetails", "NoodleBar")
    K.blade_sign(m, n, "x", NOODLE[3], 1, -37.2, 3.4, "NOODLES", "neon_orange", px=0.075, edge="neon_red")
    K.wall_lamp(m, n, "x", NOODLE[2], -1, -33.8, 2.95)
    K.wall_lamp(m, n, "x", NOODLE[2], -1, -29.7, 3.9 + 2.75)
    K.drainpipe(m, n, "z", NOODLE[1], 1, -3.2, 0, 7.2)
    K.drainpipe(m, n, "x", NOODLE[2], -1, -37.2, 0, 7.2)
    K.wall_vent(m, n, "x", NOODLE[2], -1, -36.0, 2.2, w=1.0, h=0.6)
    K.pixel_art(m, n, "z", NOODLE[1], 1, 5.4, 4.7, 0.2, "heart", "neon_red", depth=0.05)
    # The record shop: a blade sign, a note in neon dots on its street wall, a lamp at the back.
    r = m.group("OutsideDetails", "RecordShop")
    K.blade_sign(m, r, "z", RECORD[0], -1, 14.9, 3.9, "MUSIC", "neon_yellow", px=0.085, edge="neon_purple")
    K.pixel_art(m, r, "z", RECORD[0], -1, 7.6, 4.6, 0.24, "note", "neon_purple", depth=0.05)
    K.wall_lamp(m, r, "x", RECORD[2], -1, 35.7, 2.95)
    K.drainpipe(m, r, "x", RECORD[2], -1, 42.2, 0, 7.2)
    K.drainpipe(m, r, "x", RECORD[3], 1, 42.4, 0, 7.2)
    # The diner: ceiling fans, a lamp over the side door, sauce on the counter.
    d = m.group("MoreDetails", "Diner")
    for x in (-19.5, -15.0, -10.5):
        K.ceiling_fan(m, d, x, 3.8, 34.6)
    K.wall_lamp(m, d, "z", DINER[1], 1, 35.8, 2.95)
    for k in range(6):
        x = -20.9 + k * 2.0
        m.cyl(d, "Sauce", ("cab_red", "cab_yellow")[k % 2], (x, 1.1, 36.75), 0.07, 0.2, sides=6, solid=False)
        m.strip(d, "Napkins", "chrome", (x + 0.2, 1.1, 36.68), (x + 0.34, 1.26, 36.8))
    K.drainpipe(m, d, "z", DINER[0], -1, 39.6, 0, 3.7)
    # The laundromat: a lamp over the side door, 24H in the window's corner, a pipe.
    w = m.group("MoreDetails", "Laundromat")
    K.wall_lamp(m, w, "z", WASH[0], -1, 35.8, 2.95)
    m.text(w, "OPEN 24H", "x", WASH[2], -1, 3.9, 2.95, 0.03, "neon_pink", depth=0.04)
    K.drainpipe(m, w, "z", WASH[1], 1, 39.6, 0, 3.7)
    K.ceiling_fan(m, w, 3.6, 3.8, 34.8)
    K.ceiling_fan(m, w, 8.6, 3.8, 36.6)


def back_lot(m):
    from neon_arcade_block import BX0, BZ0
    s = m.folder("BackLotDetails")
    p = m.group("LotPaint", s)
    for k in range(8):   # a stop block at the head of each bay
        c = -6.6 + k * 2.8
        m.strip(p, "TyreStop", "kerb", (c - 0.9, 0, BZ0 + 0.75), (c + 0.9, 0.12, BZ0 + 1.0))
    for (x, z, d) in ((-1.0, -25.4, 1.3), (10.2, -25.0, 1.0), (4.6, -26.2, 0.8), (-17.8, -19.4, 1.6), (-27.0, -12.0, 1.2)):
        m.cyl(p, "OilStain", "tyre", (x, 0, z), d, 0.012, sides=9, solid=False)
    # Tags on the fence.
    f = m.group("FenceTags", s)
    m.text(f, "HIGH SCORE", "x", BZ0 - 0.02, 1, -19.0, 0.9, 0.13, "screen_pink", depth=0.03)
    m.text(f, "1UP", "x", BZ0 - 0.02, 1, 6.4, 1.0, 0.13, "screen_green", depth=0.03)
    m.text(f, "GAME ON", "z", BX0 - 0.02, 1, -22.0, 1.0, 0.12, "screen", depth=0.03)
    K.weeds(m, s, ((-25.0, BZ0 + 0.3), (-21.6, BZ0 + 0.35), (-15.0, BZ0 + 0.3), (-9.4, BZ0 + 0.3), (0.2, BZ0 + 0.3), (9.0, BZ0 + 0.3),
                   (15.0, BZ0 + 0.35), (20.8, BZ0 + 0.4), (BX0 + 0.3, -24.0), (BX0 + 0.35, -15.2), (BX0 + 0.3, -6.0),
                   (-21.9, -16.0), (20.9, -15.9), (-26.2, -3.0), (-21.8, 9.6), (-26.1, 14.6)))
    K.pallet(m, s, 19.6, -20.6, load="crate")
    K.traffic_cone(m, s, -20.4, -19.2)
    K.traffic_cone(m, s, -15.6, -19.4)
    K.boxes(m, s, 19.4, -16.2, n=2, seed=7)


def streets(m):
    from neon_arcade_block import MAIN_N, MAIN_S, SIDE_E
    s = m.folder("StreetDetails")
    for x in (-30.4, -23.5, -16.8):
        K.parking_meter(m, s, x, MAIN_N - 0.45)
    for x in (-15.4, -8.6, 5.6, 12.4, 34.6, 41.4):
        K.parking_meter(m, s, x, MAIN_S + 0.45)
    # Bikes at a rail by the arcade's front (you cannot walk through the row).
    b = m.group("BikeRack", s)
    m.box(b, "RackBlock", "frame", (-19.9, 0, 16.0), (-17.3, 1.0, 17.7), drawn=False)
    m.pipe(b, "Rack", "steel", (-19.9, 0.75, 16.2), (-17.3, 0.75, 16.2), 0.07, sides=6)
    for x in (-19.85, -17.35):
        m.strip(b, "RackPost", "steel", (x - 0.035, 0, 16.165), (x + 0.035, 0.75, 16.235))
    for k, x in enumerate((-19.4, -18.6, -17.8)):
        K.bike(m, b, x, 16.86, "+z", ("cab_red", "cab_blue", "cab_yellow")[k])
    K.sign_board(m, s, 3.6, 17.3, "+z", "PLAY", "neon_yellow")
    K.sign_board(m, s, -17.2, 30.4, "-z", "PIE", "neon_red", px=0.035)
    K.phone_booth(m, s, 22.7, 16.9, "-x")
    # Street names at the junction.
    n = m.group("StreetNames", s)
    m.cyl(n, "NamePole", "steel", (21.0, 0, 18.9), 0.12, 3.5, sides=6)
    m.strip(n, "NamePlate", "cab_green", (20.2, 2.9, 18.87), (21.8, 3.2, 18.93))
    m.strip(n, "NamePlate", "cab_green", (20.97, 3.24, 18.1), (21.03, 3.54, 19.7))
    for out in (-1, 1):
        m.text(n, "MAIN ST", "x", 18.9 + out * 0.03, out, 21.0, 2.95, 0.028, "hockey", depth=0.015)
        m.text(n, "2ND AVE", "z", 21.0 + out * 0.03, out, 18.9, 3.29, 0.028, "hockey", depth=0.015)
    # Poles and wires down the side street, across to the arcade and the record shop.
    w = m.group("Wires", s)
    xs = SIDE_E + 1.45
    K.utility_pole(m, s, xs, -23.0, along="z")
    K.utility_pole(m, s, xs, -5.0, along="z")
    for dx in (-0.98, 0.98):
        K.wire(m, w, (xs + dx, 8.64, -23.0), (xs + dx, 8.64, -5.0), sag=0.7)
    K.wire(m, w, (xs - 0.98, 8.64, -5.0), (33.3, 8.5, -0.8), sag=0.2)
    K.wire(m, w, (xs - 0.98, 8.64, -23.0), (21.4, 10.3, -15.2), sag=0.6)
    K.wire(m, w, (xs + 0.98, 8.64, -23.0), (38.4, 3.7, -24.0), sag=0.3)
    # Litter.
    l = m.group("Litter", s)
    for k, (x, z) in enumerate(((-5.6, 18.2), (11.2, 19.1), (-22.0, 29.4), (5.2, 30.6), (22.8, -3.0), (32.4, 12.6), (-24.6, -6.0), (-3.6, 36.0),
                                (26.0, 16.6))):
        m.strip(l, "Paper", "paper", (x - 0.16, 0, z - 0.11), (x + 0.16, 0.012, z + 0.11), tint=(1, 1, 1) if k % 2 else (0.85, 0.85, 0.8))
    K.weeds(m, s, ((-5.9, 32.2), (-2.1, 34.0), (-5.8, 39.6), (22.0, -21.0), (43.0, -1.4), (33.3, -1.3)))
