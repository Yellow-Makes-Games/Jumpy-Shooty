"""Neon Arcade: a small arena (1v1 and small free-for-alls). One big room of arcade
cabinets with an L-shaped mezzanine (north and west walls) behind glass railings, a
party room under it, a change booth in the middle to climb, steel trusses under the
roof to hook, open skylights up to the roof, and a glass shop front onto the street.

Heights: floor 0 m, stage 0.6 m, booth roof 3 m, mezzanine 4.5 m, trusses 7.4-8 m,
roof 9.6 m.
"""
import math
from arena_builder import Map, palette

PAL = "res://game/maps/palettes/neon_arcade.tres"

COLORS = {
    "carpet": (0.2, 0.14, 0.32), "carpet_spots": (0.36, 0.2, 0.5), "tile": (0.22, 0.22, 0.26),
    "wall": (0.16, 0.15, 0.22), "wall_panel": (0.26, 0.22, 0.36), "wall_outer": (0.5, 0.48, 0.55),
    "mezz_floor": (0.3, 0.2, 0.42), "partition": (0.44, 0.3, 0.58), "glass": (0.55, 0.75, 0.86),
    "glass_rail": (0.5, 0.76, 0.86), "door": (0.4, 0.6, 0.7), "steel": (0.42, 0.44, 0.5),
    "truss": (0.3, 0.31, 0.36), "cab_red": (0.7, 0.16, 0.22), "cab_blue": (0.16, 0.3, 0.72),
    "cab_black": (0.1, 0.1, 0.13), "cab_yellow": (0.9, 0.7, 0.14), "screen": (0.3, 0.85, 1.0),
    "screen_pink": (1.0, 0.35, 0.75), "marquee": (1.0, 0.9, 0.55), "neon_pink": (1.0, 0.25, 0.7),
    "neon_cyan": (0.2, 0.95, 1.0), "neon_yellow": (1.0, 0.86, 0.2), "neon_green": (0.35, 1.0, 0.45),
    "counter": (0.85, 0.35, 0.55), "shelf": (0.36, 0.3, 0.44), "prize": (0.95, 0.6, 0.2),
    "prize_blue": (0.35, 0.6, 0.95), "stage": (0.12, 0.12, 0.16), "dance_pad": (0.9, 0.3, 0.9),
    "hockey": (0.9, 0.92, 0.96), "claw_glass": (0.6, 0.85, 0.95), "roof": (0.4, 0.4, 0.43),
    "parapet": (0.55, 0.52, 0.58), "ac_unit": (0.7, 0.72, 0.74), "sidewalk": (0.6, 0.6, 0.6),
    "street": (0.3, 0.3, 0.32), "backdrop": (0.36, 0.34, 0.44), "backdrop_dark": (0.26, 0.25, 0.34),
    "window_lit": (1.0, 0.85, 0.55), "lamp": (1.0, 0.95, 0.85), "table": (0.85, 0.85, 0.9),
    "sofa": (0.2, 0.7, 0.75), "kerb": (0.72, 0.72, 0.7),
}
GLOW = {"screen": 1.6, "screen_pink": 1.6, "marquee": 1.4, "neon_pink": 3.0, "neon_cyan": 3.0,
        "neon_yellow": 3.0, "neon_green": 3.0, "lamp": 1.5, "window_lit": 0.8, "dance_pad": 1.2}
BREAKABLE = {"glass": 25, "glass_rail": 40, "partition": 100, "mezz_floor": 200, "roof": 300}

X0, X1, Z0, Z1 = -18, 18, -14, 14     # inside faces of the outer walls
MZ, MX = -9, -13                      # mezzanine edges: north part z < MZ, west part x < MX
MY = 4.5                              # mezzanine floor height


def build(path):
    m = Map("NeonArcade", PAL,
            {"sky": {"sky_top_color": (0.14, 0.16, 0.36), "sky_horizon_color": (0.62, 0.42, 0.6),
                     "ground_bottom_color": (0.12, 0.1, 0.16), "ground_horizon_color": (0.5, 0.36, 0.5)},
             "lines": ["ambient_light_source = 2", "ambient_light_color = Color(0.78, 0.74, 0.95, 1)",
                       "ambient_light_energy = 1.05", "tonemap_mode = 2", "tonemap_white = 2.4",
                       "ssao_enabled = true", "glow_enabled = true", "glow_intensity = 1.1"]},
            (32, 250, (1.0, 0.72, 0.6), 0.9),
            {"face_shade": "Vector3(0.93, 0.84, 0.66)", "kill_height": "-6.0",
             "bounds": "Rect2(-23, -19, 46, 42)", "swing_point": "Vector3(0, 7.4, 0)"})
    shell(m)
    mezzanine(m)
    floor_games(m)
    party_room(m)
    street(m)
    roof(m)
    spawns(m)
    pickups(m)
    m.write(path)
    palette(path.replace("game/maps/", "game/maps/palettes/").replace(".tscn", ".tres"), COLORS, GLOW, BREAKABLE,
            roughness=0.7)


def shell(m):
    g = m.group("Shell")
    m.box(g, "Floor", "carpet", (X0 - 0.8, -0.5, Z0 - 0.8), (X1 + 0.8, 0, Z1 + 0.8))
    for (x, z, s) in ((-8, -2, 1.2), (4, 2, 1.0), (10, -5, 1.4), (-3, 8, 1.1), (12, 9, 0.9), (-10, 9, 1.0), (2, -7, 1.2)):
        m.box(g, "Spots", "carpet_spots", (x - s, 0, z - s * 0.6), (x + s, 0.01, z + s * 0.6), solid=False)
    H = 9.6
    m.box(g, "NorthWall", "wall", (X0 - 0.8, 0, Z0 - 0.8), (X1 + 0.8, H, Z0))
    m.box(g, "WestWall", "wall", (X0 - 0.8, 0, Z0), (X0, H, Z1))
    m.box(g, "EastWall", "wall", (X1, 0, Z0), (X1 + 0.8, H, Z1))
    m.box(g, "FireDoor", "steel", (X1 - 0.06, 0, Z0 + 1.5), (X1, 2.4, Z0 + 3.1), solid=False)
    m.box(g, "ExitSign", "neon_green", (X1 - 0.08, 2.6, Z0 + 1.9), (X1 - 0.02, 2.9, Z0 + 2.7), solid=False)
    # Shop front: glass panes (they break, and then the street is yours) and glass doors.
    m.wall(g, "Front", "wall_outer", (X0 - 0.8, Z1 + 0.4), (X1 + 0.8, Z1 + 0.4), 0, H, 0.8,
           holes=[(4.8, 14.8, 0.8, 4.0), (17.3, 20.3, 0, 3.0), (22.8, 32.8, 0.8, 4.0)])
    for x0 in (-14, -9, 4, 9):
        m.box(g, "Window", "glass", (x0, 0.8, Z1 + 0.34), (x0 + 5, 4.0, Z1 + 0.46))
    m.box(g, "Doors", "door", (-1.5, 0, Z1 + 0.34), (1.5, 3.0, Z1 + 0.46))
    # Wall panels and neon strips.
    for z in range(-12, 13, 4):
        m.box(g, "Panel", "wall_panel", (X0, 0.4, z - 1.6), (X0 + 0.05, 3.6, z + 1.6), solid=False)
    m.box(g, "NeonStrip", "neon_pink", (X0, 8.2, Z0), (X0 + 0.08, 8.35, Z1), solid=False)
    m.box(g, "NeonStrip", "neon_cyan", (X1 - 0.08, 8.2, Z0), (X1, 8.35, Z1), solid=False)
    m.box(g, "NeonStrip", "neon_cyan", (X0, 8.2, Z0), (X1, 8.35, Z0 + 0.08), solid=False)
    m.box(g, "NeonStrip", "neon_pink", (X0, 8.2, Z1 - 0.08), (X1, 8.35, Z1), solid=False)
    # Trusses under the roof (hook them, or stand on them).
    t = m.group("Trusses")
    for x in (-12, -6, 0, 6, 12):
        m.box(t, "Truss", "truss", (x - 0.2, 7.4, Z0), (x + 0.2, 8.0, Z1))
        m.box(t, "Light", "lamp", (x - 0.15, 7.25, -6), (x + 0.15, 7.4, 6), solid=False)
    m.box(t, "Spine", "truss", (X0, 7.6, -0.2), (X1, 8.0, 0.2))


def mezzanine(m):
    g = m.group("Mezzanine")
    m.box(g, "FloorNorth", "mezz_floor", (X0, MY - 0.3, Z0), (X1, MY, MZ))
    m.box(g, "FloorWest", "mezz_floor", (X0, MY - 0.3, MZ), (MX, MY, Z1))
    m.box(g, "EdgeBeam", "steel", (MX, MY - 0.7, MZ - 0.4), (X1, MY - 0.3, MZ))
    m.box(g, "EdgeBeam", "steel", (MX, MY - 0.7, MZ), (MX + 0.4, MY - 0.3, Z1))
    for x in (-7, -1, 6, 12, 17.6):
        m.box(g, "Column", "steel", (x - 0.2, 0, MZ - 0.4), (x + 0.2, MY - 0.7, MZ))
    for z in (-3, 3, 13.6):
        m.box(g, "Column", "steel", (MX, 0, z - 0.2), (MX + 0.4, MY - 0.7, z + 0.2))
    m.box(g, "Column", "steel", (MX, 0, MZ - 0.4), (MX + 0.4, MY - 0.7, MZ))
    # Glass railings, open where the stairs arrive.
    m.rail(g, "Railing", "glass_rail", (MX, MZ - 0.06), (X1, MZ - 0.06), MY, 1.1, 0.12, holes=[(25.0, 27.4)])
    m.rail(g, "Railing", "glass_rail", (MX + 0.06, MZ), (MX + 0.06, Z1), MY, 1.1, 0.12, holes=[(17.0, 19.4)])
    m.box(g, "Handrail", "neon_cyan", (MX, MY + 1.1, MZ - 0.1), (X1, MY + 1.18, MZ - 0.02), solid=False)
    m.box(g, "Handrail", "neon_pink", (MX + 0.02, MY + 1.1, MZ), (MX + 0.1, MY + 1.18, Z1), solid=False)
    m.stairs(g, "StairsEast", (13.2, 0, -1), (13.2, MY, MZ), 2.4, kind="steel", side="truss", base=0)
    m.stairs(g, "StairsWest", (-5, 0, 9.2), (MX, MY, 9.2), 2.4, kind="steel", side="truss", base=0)
    # Up top: sofas, a VR booth and a row of cabinets.
    m.box(g, "Sofa", "sofa", (-17.6, MY, -4), (-16.4, MY + 0.8, 1))
    m.box(g, "Sofa", "sofa", (-6, MY, -13.6), (-1, MY + 0.8, -12.4))
    for x in (2, 3.4, 4.8, 6.2, 7.6):
        cabinet(m, g, x, -13.2, 0, "cab_blue" if x % 2 else "cab_red", MY)
    m.box(g, "VRBooth", "partition", (-17.6, MY, 5), (-14.6, MY + 2.6, 5.15))
    m.box(g, "VRMat", "neon_green", (-17.4, MY, 5.4), (-14.8, MY + 0.02, 7.6), solid=False)
    m.sign("LEVEL 2", (16, MY + 2.4, MZ - 0.15), yaw=0, size=48, col=(0.4, 1.0, 1.0, 1))


def cabinet(m, parent, x, z, yaw, kind, y=0.0):
    """An arcade cabinet facing the way `yaw` turns its front (0 = facing south, +z)."""
    g = m.group("Cabinet", parent, at=(x, y, z), yaw=yaw)
    m.box(g, "Body", kind, (-0.55, 0, -0.45), (0.55, 2.1, 0.45))
    m.box(g, "Screen", "screen" if kind != "cab_red" else "screen_pink", (-0.42, 1.2, 0.45), (0.42, 1.75, 0.5), solid=False)
    m.box(g, "Marquee", "marquee", (-0.5, 1.85, 0.45), (0.5, 2.05, 0.52), solid=False)
    m.box(g, "Panel", "cab_black", (-0.5, 0.95, 0.45), (0.5, 1.1, 0.75), solid=False)
    return g


def floor_games(m):
    f = m.folder("Games")
    # Two rows of back-to-back cabinets, with a gap in the middle for the booth.
    r = m.group("Rows", f)
    kinds = ["cab_red", "cab_blue", "cab_black", "cab_yellow"]
    i = 0
    for zc in (-4, 5):
        for (xa, xb) in ((-10, -3), (3, 8)):
            x = xa + 0.55
            while x <= xb - 0.5:
                cabinet(m, r, x, zc - 0.45, math.pi, kinds[i % 4])
                cabinet(m, r, x, zc + 0.45, 0, kinds[(i + 1) % 4])
                x += 1.15
                i += 1
            m.box(r, "RowSign", "neon_yellow" if zc < 0 else "neon_pink", (xa, 2.15, zc - 0.05), (xb - 0.5, 2.35, zc + 0.05), solid=False)
    # Change booth in the middle: climb onto its roof.
    b = m.group("ChangeBooth", f)
    m.box(b, "Booth", "counter", (-2, 0, -1.5), (2, 2.7, 1.5))
    m.box(b, "Roof", "steel", (-2.2, 2.7, -1.7), (2.2, 3.0, 1.7))
    m.box(b, "Window", "screen", (-1.4, 1.2, 1.5), (1.4, 2.2, 1.55), solid=False)
    m.box(b, "Window", "screen", (-1.4, 1.2, -1.55), (1.4, 2.2, -1.5), solid=False)
    m.box(b, "Neon", "neon_green", (-2.25, 2.95, -1.75), (2.25, 3.05, 1.75), solid=False)
    m.sign("TOKENS", (0, 2.45, 1.56), size=40, col=(1, 1, 1, 1), parent=b)
    # Prize counter in the south-east corner (vault the counter to get in).
    p = m.group("PrizeCounter", f)
    m.box(p, "Front", "counter", (11, 0, 4), (11.6, 1.1, 12))
    m.box(p, "Side", "counter", (11, 0, 4), (17.4, 1.1, 4.6))
    m.box(p, "Side", "counter", (11, 0, 11.4), (17.4, 1.1, 12))
    m.box(p, "Top", "neon_pink", (10.95, 1.1, 3.95), (11.65, 1.16, 12.05), solid=False)
    m.box(p, "Shelves", "shelf", (17.2, 0, 4), (18, 3.6, 12))
    for (z, h, k) in ((5, 2.6, "prize"), (6.4, 3.0, "prize_blue"), (7.8, 2.2, "prize"), (9.2, 2.8, "prize_blue"), (10.6, 2.4, "prize")):
        m.box(p, "Prize", k, (16.8, h, z - 0.5), (17.2, h + 0.6, z + 0.5), solid=False)
    m.sign("PRIZES", (17.9, 4.3, 8), yaw=-math.pi / 2, size=72, col=(1, 0.85, 0.3, 1))
    # Stage with dance machines (south), a ramp up the front.
    s = m.group("Stage", f)
    m.box(s, "Stage", "stage", (-3, 0, 10), (5, 0.6, Z1 - 0.2))
    m.slab(s, "Ramp", "stage", (1, 0.6, 10), (1, 0, 8.2), 6, thick=0.3)
    for x in (-1, 3):
        m.box(s, "Pad", "dance_pad", (x - 0.8, 0.6, 11.4), (x + 0.8, 0.62, 13.0), solid=False)
        m.box(s, "Screen", "cab_black", (x - 0.9, 0.6, 13.2), (x + 0.9, 2.8, 13.7))
        m.box(s, "Glow", "screen_pink", (x - 0.7, 1.6, 13.15), (x + 0.7, 2.5, 13.2), solid=False)
    # Air hockey tables.
    h = m.group("AirHockey", f)
    for (x0, z0) in ((6.5, 8), (-10.5, 0)):
        m.box(h, "Table", "hockey", (x0, 0, z0), (x0 + 3, 0.9, z0 + 2))
        m.box(h, "Rim", "neon_cyan", (x0 - 0.05, 0.85, z0 - 0.05), (x0 + 3.05, 0.95, z0 + 2.05), solid=False)
    # Under the west mezzanine: pinball machines against the wall.
    pb = m.group("Pinball", f)
    for z in (-7, -5, -1, 1, 5, 7, 11):
        m.box(pb, "Pinball", "cab_blue" if z % 4 else "cab_red", (X0, 0, z - 0.4), (X0 + 1.2, 1.0, z + 0.4))
        m.box(pb, "Backbox", "cab_black", (X0, 1.0, z - 0.4), (X0 + 0.3, 2.0, z + 0.4))
        m.box(pb, "Lights", "screen", (X0 + 0.3, 1.2, z - 0.32), (X0 + 0.32, 1.9, z + 0.32), solid=False)
    # Under the north mezzanine, west of the party room: claw machines.
    c = m.group("ClawMachines", f)
    for x in (-11, -8, -5):
        m.box(c, "Base", "cab_yellow", (x - 0.7, 0, -13.4), (x + 0.7, 1.0, -12.0))
        m.box(c, "Case", "claw_glass", (x - 0.7, 1.0, -13.4), (x + 0.7, 2.4, -12.0))
        m.box(c, "Top", "neon_pink", (x - 0.72, 2.4, -13.42), (x + 0.72, 2.6, -11.98), solid=False)
    # Under the north mezzanine, east: a lounge behind a partition, with vending machines.
    m.wall(c, "LoungeWall", "partition", (12.4, MZ - 0.6), (X1, MZ - 0.6), 0, MY - 0.7, 0.25, holes=[(3.6, 5.2, 0, 2.6)])
    m.wall(c, "LoungeWall", "partition", (12.4, Z0), (12.4, MZ - 0.6), 0, MY - 0.7, 0.25)
    for x in (14, 15.4):
        m.box(c, "Vending", "cab_red" if x == 14 else "cab_blue", (x - 0.6, 0, -13.9), (x + 0.6, 2.2, -13.0))
        m.box(c, "VendingLight", "lamp", (x - 0.45, 0.9, -13.0), (x + 0.45, 2.0, -12.96), solid=False)


def party_room(m):
    """Under the north mezzanine: a party room with breakable walls."""
    g = m.group("PartyRoom")
    m.wall(g, "Front", "partition", (-2, MZ - 0.6), (11.6, MZ - 0.6), 0, MY - 0.7, 0.25, holes=[(6, 7.8, 0, 2.6), (1, 4.5, 1.1, 2.6)])
    m.wall(g, "Side", "partition", (-2, Z0), (-2, MZ - 0.6), 0, MY - 0.7, 0.25)
    m.wall(g, "Side", "partition", (11.6, Z0), (11.6, MZ - 0.6), 0, MY - 0.7, 0.25)
    m.box(g, "Table", "table", (0, 0, -12.6), (3.4, 0.8, -11.2))
    m.box(g, "Sofa", "sofa", (8, 0, -13.8), (11.2, 0.7, -12.8))
    m.box(g, "Balloons", "neon_pink", (1.2, 2.6, -12.2), (1.6, 3.2, -11.8), solid=False)
    m.sign("PARTY ROOM", (4.8, 3.3, MZ - 0.45), size=44, col=(1, 0.5, 0.85, 1))


def street(m):
    """Outside the shop front: a pavement (only reachable once the glass breaks) and a street."""
    g = m.group("Street")
    m.box(g, "Pavement", "sidewalk", (-23, -0.5, Z1 + 0.8), (23, 0, 21))
    m.box(g, "Kerb", "kerb", (-23, 0, 20.7), (23, 0.15, 21))
    m.box(g, "Road", "street", (-80, -0.7, 21), (80, -0.15, 44))
    m.box(g, "Far", "street", (-160, -0.9, -160), (160, -0.6, 160), tint=(0.7, 0.7, 0.7))
    for x in (-23.4, 23.4):
        m.box(g, "Fence", "steel", (x - 0.1, 0, Z1 + 0.8), (x + 0.1, 1.2, 21))
    m.box(g, "Barrier", "steel", (-23, 0, 22.8), (23, 12, 23.2), drawn=False)
    for x in (-16, -6, 6, 16):
        m.box(g, "Bollard", "steel", (x - 0.2, 0, 19.8), (x + 0.2, 1.0, 20.2))
    m.box(g, "Bench", "steel", (10, 0, 17.5), (12.5, 0.5, 18.1))
    m.box(g, "Awning", "neon_pink", (X0 - 0.8, 4.4, Z1 + 0.8), (X1 + 0.8, 4.6, Z1 + 2.4))
    b = m.group("Backdrop")
    x = -60
    i = 0
    for (w, h) in ((14, 18), (10, 24), (16, 14), (12, 28), (18, 20), (11, 16), (15, 22), (12, 18), (14, 26)):
        kind = "backdrop" if i % 2 == 0 else "backdrop_dark"
        m.box(b, "Building", kind, (x, -0.15, 30), (x + w, h, 44))
        for wy in range(3, int(h) - 2, 4):
            for wx in range(int(x) + 2, int(x + w) - 1, 3):
                if (wx + wy + i) % 3 == 0:
                    m.box(b, "Window", "window_lit", (wx, wy, 29.95), (wx + 1.2, wy + 1.6, 30.0), solid=False)
        x += w + 1
        i += 1
    for (x0, x1) in ((-60, -20), (20, 60)):
        m.box(b, "Neighbour", "backdrop_dark", (x0 if x0 < 0 else 19.6, -0.15, -40), (-19.6 if x0 < 0 else x1, 14, Z1 + 0.8))
    m.box(b, "Behind", "backdrop", (-30, -0.15, -50), (30, 16, -15.6))


def roof(m):
    g = m.group("Roof")
    T, B = 9.6, 9.1
    RX0, RX1, RZ0, RZ1 = X0 - 0.8, X1 + 0.8, Z0 - 0.8, Z1 + 0.8
    # Two open skylights over the middle of the room (fly up through them).
    m.box(g, "Roof", "roof", (RX0, B, RZ0), (RX1, T, -6))
    m.box(g, "Roof", "roof", (RX0, B, -3), (RX1, T, 3))
    m.box(g, "Roof", "roof", (RX0, B, 6), (RX1, T, RZ1))
    for (z0, z1) in ((-6, -3), (3, 6)):
        m.box(g, "Roof", "roof", (RX0, B, z0), (-8, T, z1))
        m.box(g, "Roof", "roof", (8, B, z0), (RX1, T, z1))
        for (a, b) in (((-8, z0), (8, z0)), ((-8, z1), (8, z1))):
            m.box(g, "Curb", "parapet", (a[0], T, a[1] - 0.1), (b[0], T + 0.4, b[1] + 0.1))
    m.box(g, "Parapet", "parapet", (RX0, T, RZ0), (RX1, T + 1.0, RZ0 + 0.3))
    m.box(g, "Parapet", "parapet", (RX0, T, RZ1 - 0.3), (RX1, T + 1.0, RZ1))
    m.box(g, "Parapet", "parapet", (RX0, T, RZ0), (RX0 + 0.3, T + 1.0, RZ1))
    m.box(g, "Parapet", "parapet", (RX1 - 0.3, T, RZ0), (RX1, T + 1.0, RZ1))
    for (x, z) in ((-14, -11), (-9, -11), (13, -10), (-14, 10)):
        m.box(g, "ACUnit", "ac_unit", (x - 1.2, T, z - 1), (x + 1.2, T + 1.6, z + 1))
    m.box(g, "Vent", "steel", (14, T, 8), (15, T + 2.4, 9))
    # The big sign along the front edge of the roof.
    m.box(g, "SignFrame", "truss", (-10, T + 1.0, RZ1 - 0.6), (10, T + 1.2, RZ1 - 0.4))
    m.box(g, "SignBoard", "cab_black", (-10, T + 1.2, RZ1 - 0.6), (10, T + 4.4, RZ1 - 0.4))
    m.box(g, "SignNeon", "neon_cyan", (-10.1, T + 4.4, RZ1 - 0.65), (10.1, T + 4.55, RZ1 - 0.35), solid=False)
    m.sign("NEON ARCADE", (0, T + 2.8, RZ1 - 0.34), size=220, col=(1.0, 0.4, 0.85, 1), pixel=0.012)


def spawns(m):
    pts = [
        ((-8, 0, -7), (0, 0)), ((7, 0, -7), (0, 0)), ((-11.5, 0, 2.5), (0, 0)), ((0, 0, 7.4), (0, 0)),
        ((14.5, 0, 1.2), (0, 0)), ((-15.5, 0, -12), (0, 0)), ((8, 0, -11.5), (0, 0)),
        ((-15.5, MY, 0), (0, 0)), ((10, MY, -11.5), (0, 0)), ((-8, MY, -11.5), (0, 0)),
        ((16.5, 0, -6), (0, 0)), ((-15.6, 0, 6), (0, 0)),
    ]
    for p, t in pts:
        m.spawn(p, t)


def pickups(m):
    for (p, w) in [
        ((0, 3.0, 0), "shotgun"), ((0, 9.6, 10), "sniper"), ((-16, MY, 12), "rifle"), ((0, MY, -11.2), "smg"),
        ((2, 0, -10.6), "revolver"), ((1, 0.6, 11.0), "hammer"), ((15, 0, 8), "dagger"), ((8, 0, 18), "burst_rifle"),
        ((-14.5, 0, -3), "machine_pistol"), ((9, 0, -6.6), "spear"),
    ]:
        m.weapon(p, w)
