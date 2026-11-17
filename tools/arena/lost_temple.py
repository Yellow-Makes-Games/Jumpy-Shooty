"""Lost Temple: a large outdoor arena (up to 16 players) in a jungle clearing ringed by
cliffs. A stepped pyramid in the middle (grand stairs north and south, a crypt tunnel
through its base, a shrine on top), a ruined palace with a breakable plank upper floor
(north-west), an aqueduct and a broken tower (north-east), treehouses joined by rope
bridges (south-west), a ruined courtyard with a hut (south-east), an excavation
scaffold (west) and a stone gate (east).

Heights: ground 0 m, pyramid tiers 3, 6 and 9 m (shrine roof 14.3 m), palace upper
floor 4.3 m, aqueduct 7 m, broken tower 14 m, treehouses 6 m, scaffold 4.5 and 9 m.
"""
import math
from arena_builder import Map, palette

PAL = "res://game/maps/palettes/lost_temple.tres"

COLORS = {
    "grass": (0.36, 0.52, 0.24), "grass_dark": (0.28, 0.43, 0.2), "dirt": (0.5, 0.4, 0.28),
    "paving": (0.66, 0.62, 0.52), "temple": (0.7, 0.64, 0.5), "temple_dark": (0.55, 0.5, 0.4),
    "temple_light": (0.8, 0.75, 0.62), "carving": (0.62, 0.52, 0.36), "gold": (0.95, 0.74, 0.25),
    "stone": (0.6, 0.58, 0.54), "stone_dark": (0.45, 0.44, 0.42), "moss": (0.3, 0.5, 0.22),
    "rock": (0.5, 0.47, 0.43), "rock_dark": (0.38, 0.36, 0.34), "plank": (0.6, 0.44, 0.27),
    "wood_wall": (0.52, 0.38, 0.24), "timber": (0.4, 0.29, 0.19), "rope": (0.72, 0.62, 0.42),
    "thatch": (0.78, 0.66, 0.38), "trunk": (0.42, 0.32, 0.22), "leaves": (0.24, 0.5, 0.22),
    "leaves_light": (0.36, 0.6, 0.26), "leaves_dark": (0.17, 0.38, 0.17), "vine": (0.2, 0.44, 0.18),
    "water": (0.25, 0.52, 0.6), "torch": (1.0, 0.62, 0.22), "crystal": (0.35, 0.9, 0.85),
    "cloth_red": (0.7, 0.18, 0.14), "cloth_blue": (0.18, 0.32, 0.6), "pot": (0.68, 0.4, 0.26),
}
GLOW = {"torch": 2.0, "crystal": 1.6, "gold": 0.3}
BREAKABLE = {"plank": 200, "wood_wall": 120, "thatch": 80, "cloth_red": 40}


def build(path):
    m = Map("LostTemple", PAL,
            {"sky": {"sky_top_color": (0.26, 0.52, 0.8), "sky_horizon_color": (0.8, 0.88, 0.86),
                     "ground_bottom_color": (0.3, 0.38, 0.24), "ground_horizon_color": (0.7, 0.78, 0.68)},
             "lines": ["ambient_light_source = 2", "ambient_light_color = Color(0.74, 0.84, 0.8, 1)",
                       "ambient_light_energy = 0.65", "tonemap_mode = 2", "tonemap_white = 2.6",
                       "ssao_enabled = true", "glow_enabled = true"]},
            (55, 140, (1.0, 0.92, 0.78), 1.1),
            {"face_shade": "Vector3(0.93, 0.84, 0.66)", "kill_height": "-8.0",
             "bounds": "Rect2(-50, -50, 100, 100)", "swing_point": "Vector3(0, 14.3, 0)"})
    ground(m)
    pyramid(m)
    palace(m)
    aqueduct(m)
    treehouses(m)
    courtyard(m)
    middle(m)
    cliffs(m)
    spawns(m)
    pickups(m)
    m.write(path)
    palette(path.replace("game/maps/", "game/maps/palettes/").replace(".tscn", ".tres"), COLORS, GLOW, BREAKABLE)


def ground(m):
    g = m.group("Ground")
    m.box(g, "Grass", "grass", (-62, -1, -62), (62, 0, 62))
    m.box(g, "Far", "grass_dark", (-220, -1.2, -220), (220, -0.2, 220))
    m.box(g, "Plaza", "paving", (-22, 0, -22), (22, 0.03, 22), solid=False)
    for (x0, z0, x1, z1) in ((-2.5, -40, 2.5, -22), (-2.5, 22, 2.5, 46), (-46, -2, -22, 2), (22, -2, 46, 2)):
        m.box(g, "Path", "dirt", (x0, 0, z0), (x1, 0.025, z1), solid=False)


def pyramid(m):
    f = m.folder("Pyramid")
    g = m.group("Tiers", f)
    # Tier 1 (0-3 m) is built round a crypt: a tunnel east-west and a chamber in the middle.
    m.box(g, "Tier1North", "temple", (-15, 0, -15), (15, 3, -4))
    m.box(g, "Tier1South", "temple", (-15, 0, 4), (15, 3, 15))
    for sz in ((-4, -1.5), (1.5, 4)):
        m.box(g, "Tier1Side", "temple", (-15, 0, sz[0]), (-4, 3, sz[1]))
        m.box(g, "Tier1Side", "temple", (4, 0, sz[0]), (15, 3, sz[1]))
    m.box(g, "CryptCeiling", "temple_dark", (-15, 2.8, -4), (15, 3, 4))
    m.box(g, "Tier2", "temple", (-10.5, 3, -10.5), (10.5, 6, 10.5))
    m.box(g, "Tier3", "temple", (-6, 6, -6), (6, 9, 6))
    for (lo, hi, y) in (((-15, -15), (15, 15), 3), ((-10.5, -10.5), (10.5, 10.5), 6), ((-6, -6), (6, 6), 9)):
        m.box(g, "Trim", "temple_light", (lo[0] - 0.1, y - 0.35, lo[1] - 0.1), (hi[0] + 0.1, y, hi[1] + 0.1), solid=False)
    # Carved bands and vines on the faces.
    for (half, y0) in ((15, 1.0), (10.5, 4.0), (6, 7.0)):
        for s in (-1, 1):
            m.box(g, "Band", "carving", (-half - 0.05, y0, s * half - 0.05), (half + 0.05, y0 + 0.6, s * half + 0.05), solid=False)
            m.box(g, "Band", "carving", (s * half - 0.05, y0, -half - 0.05), (s * half + 0.05, y0 + 0.6, half + 0.05), solid=False)
    for (x, z, h) in ((-12, -15.06, 2.6), (9, -15.06, 2.2), (15.06, 8, 2.8), (-15.06, -9, 2.4), (-7, 10.56, 2.8), (10.56, -4, 2.5)):
        if abs(z) > 15:
            m.box(g, "Vine", "vine", (x - 0.6, 3 - h, z - 0.04), (x + 0.6, 3, z + 0.04), solid=False)
        elif abs(x) > 15:
            m.box(g, "Vine", "vine", (x - 0.04, 3 - h, z - 0.6), (x + 0.04, 3, z + 0.6), solid=False)
        elif abs(z) > 10.5:
            m.box(g, "Vine", "vine", (x - 0.6, 6 - h, z - 0.04), (x + 0.6, 6, z + 0.04), solid=False)
        else:
            m.box(g, "Vine", "vine", (x - 0.04, 6 - h, z - 0.6), (x + 0.04, 6, z + 0.6), solid=False)
    # Crypt: torches and a crystal on a plinth.
    c = m.group("Crypt", f)
    m.box(c, "Plinth", "temple_dark", (-0.8, 0, -0.8), (0.8, 0.9, 0.8))
    m.box(c, "Crystal", "crystal", (-0.3, 0.9, -0.3), (0.3, 1.9, 0.3), solid=False)
    for (x, z) in ((-3.9, -3), (3.9, -3), (-3.9, 3), (3.9, 3)):
        m.box(c, "Torch", "torch", (x - 0.1, 1.6, z - 0.15), (x + 0.1, 2.0, z + 0.15), solid=False)
    for x in (-15.05, 15.05):
        m.box(c, "Lintel", "carving", (x - 0.1, 2.3, -2.0), (x + 0.1, 2.8, 2.0), solid=False)
    # Grand stairs, north and south, from the plaza to the shrine at 9 m.
    for sz in (-1, 1):
        m.stairs(f, "GrandStairs", (0, 0, sz * 24), (0, 9, sz * 6), 5, kind="temple_light", side="temple_dark",
                 rise=0.3, base=0, fill=True)
        for sx in (-1, 1):
            m.box(f, "Lion", "temple_dark", (sx * 4.6 - 0.8, 0, sz * 25 - 1.2), (sx * 4.6 + 0.8, 1.6, sz * 25 + 1.2))
            m.box(f, "LionHead", "temple_dark", (sx * 4.6 - 0.6, 1.6, sz * 24.2 - 0.6), (sx * 4.6 + 0.6, 2.6, sz * 24.2 + 0.6))
            m.box(f, "Brazier", "stone_dark", (sx * 3.2 - 0.4, 9, sz * 6.6 - 0.4), (sx * 3.2 + 0.4, 9.9, sz * 6.6 + 0.4))
            m.box(f, "Flame", "torch", (sx * 3.2 - 0.25, 9.9, sz * 6.6 - 0.25), (sx * 3.2 + 0.25, 10.3, sz * 6.6 + 0.25), solid=False)
    # Shrine on top: pillars at the corners, walls east and west with doors, a stepped roof.
    s = m.group("Shrine", f)
    for x in (-5, 5):
        for z in (-5, 5):
            m.box(s, "Pillar", "temple_light", (x - 0.6, 9, z - 0.6), (x + 0.6, 13.5, z + 0.6))
    for x in (-5, 5):
        m.wall(s, "Wall", "temple", (x, -4.4), (x, 4.4), 9, 13.5, 0.8, holes=[(3.4, 5.4, 9, 12)])
    m.box(s, "Roof", "temple_dark", (-6.5, 13.5, -6.5), (6.5, 14.3, 6.5))
    m.box(s, "RoofCap", "temple", (-3.5, 14.3, -3.5), (3.5, 15.3, 3.5))
    m.box(s, "RoofGold", "gold", (-1, 15.3, -1), (1, 16.3, 1))
    m.box(s, "Altar", "temple_dark", (-1.2, 9, -0.7), (1.2, 10.1, 0.7))
    m.box(s, "AltarGold", "gold", (-0.4, 10.1, -0.3), (0.4, 10.5, 0.3), solid=False)
    m.box(s, "Banner", "cloth_red", (-4.55, 10.5, -3.6), (-4.5, 13.0, -2.4), solid=False)
    m.box(s, "Banner", "cloth_red", (4.5, 10.5, 2.4), (4.55, 13.0, 3.6), solid=False)


def palace(m):
    """North-west: a two-storey ruin. Plank upper floor and wooden partitions break."""
    g = m.group("Palace")
    X0, X1, Z0, Z1 = -42, -22, -42, -26
    m.box(g, "Floor", "paving", (X0, 0, Z0), (X1, 0.03, Z1), solid=False)
    m.wall(g, "NorthWall", "stone", (X0, Z0), (X1, Z0), 0, 8, 0.8, holes=[(3, 5, 5.2, 7.0), (9, 11, 5.2, 7.0), (14, 16, 5.2, 7.0)])
    m.wall(g, "SouthWall", "stone", (X0, Z1), (X1, Z1), 0, 6.5, 0.8, holes=[(8, 11, 0, 3.2), (3, 5, 5.0, 6.5), (14, 17, 1.2, 2.8)])
    m.wall(g, "WestWall", "stone", (X0, Z0), (X0, Z1), 0, 8, 0.8, holes=[(6, 9, 0, 3.2), (11, 13, 5.2, 7.0)])
    m.wall(g, "EastWall", "stone", (X1, Z0), (X1, Z1), 0, 5.5, 0.8, holes=[(5, 8, 0, 3.2), (11, 13, 1.2, 2.8)])
    m.box(g, "EastRuin", "stone", (X1 - 0.4, 5.5, Z0), (X1 + 0.4, 7.2, Z0 + 4))
    m.box(g, "SouthRuin", "stone", (X0, 6.5, Z1 - 0.4), (X0 + 7, 8, Z1 + 0.4))
    # Upper floor at 4.3 m: west half full depth, east half stops short of the stairs.
    m.box(g, "UpperWest", "plank", (X0, 4.0, Z0), (-31, 4.3, Z1))
    m.box(g, "UpperEast", "plank", (-31, 4.0, Z0), (X1, 4.3, -28.6))
    m.box(g, "Beam", "timber", (-31, 3.6, -28.8), (X1, 4.0, -28.4))
    for (x, z) in ((-31, -34), (-26.5, -35), (-36, -30.5)):
        m.box(g, "Post", "timber", (x - 0.25, 0, z - 0.25), (x + 0.25, 4.0, z + 0.25))
    m.stairs(g, "Stairs", (-23, 0, -27.6), (-31, 4.3, -27.6), 1.8, kind="stone_dark", side="stone", base=0)
    m.rail(g, "StairRail", "timber", (-31, -28.65), (X1, -28.65), 4.3, 1.0, 0.12)
    # Partitions: ground floor (north-south) and upper floor (east-west).
    m.wall(g, "Partition", "wood_wall", (-36, Z0), (-36, Z1), 0, 4.0, 0.25, holes=[(9, 10.6, 0, 2.6)])
    m.wall(g, "Partition", "wood_wall", (X0, -34), (-31, -34), 4.3, 8, 0.25, holes=[(4.5, 6.1, 4.3, 6.8)])
    # Part of the roof survives over the west rooms; broken beams over the rest.
    m.box(g, "Roof", "stone_dark", (X0, 8, Z0), (-33, 8.6, Z1))
    for x in (-30, -26):
        m.box(g, "RoofBeam", "timber", (x - 0.2, 7.6, Z0), (x + 0.2, 8.0, Z1 + 0.4))
    m.box(g, "FallenBeam", "timber", (-29, 0, -40), (-24, 0.5, -39.4))
    m.box(g, "Rubble", "stone_dark", (-25, 0, -32), (-23.2, 1.0, -30))
    m.box(g, "Rubble", "stone", (-24.5, 1.0, -31.6), (-23.4, 1.6, -30.6))
    m.box(g, "Throne", "gold", (-40.5, 4.3, -37), (-39.5, 6.0, -35.8))
    m.box(g, "ThroneSeat", "cloth_blue", (-40.6, 4.3, -37.1), (-39.0, 5.0, -35.7))
    for z in (-40, -32, -28.5):
        m.box(g, "Torch", "torch", (X0 + 0.42, 2.4, z - 0.15), (X0 + 0.55, 2.8, z + 0.15), solid=False)
    m.box(g, "Vines", "vine", (X1 + 0.42, 1.0, -41), (X1 + 0.46, 5.5, -39), solid=False)


def aqueduct(m):
    """North-east: an aqueduct at 7 m from a ramp at its west end to a broken tower."""
    g = m.group("Aqueduct")
    Z0, Z1 = -35, -30
    m.slab(g, "Ramp", "stone", (8, 0, -32.5), (20, 7, -32.5), 3.2, thick=0.6)
    m.box(g, "RampWall", "stone_dark", (8, 0, -34.3), (20, 0.8, -34.1), solid=False)
    m.box(g, "Deck", "stone", (20, 6, Z0), (44, 7, Z1))
    for zz in (Z0, Z1 - 0.4):
        m.box(g, "Lip", "stone_dark", (20, 7, zz), (40, 7.5, zz + 0.4))
    m.box(g, "Water", "water", (20, 7, Z0 + 0.4), (40, 7.04, Z1 - 0.4), solid=False)
    for x in (22, 28, 34):
        m.box(g, "Pier", "stone", (x - 0.7, 0, Z0 + 0.4), (x + 0.7, 6, Z1 - 0.4))
        m.box(g, "Arch", "stone_dark", (x + 0.7, 5.2, Z0 + 0.6), (x + 5.3, 6, Z1 - 0.6), solid=False)
    m.box(g, "Moss", "moss", (24, 7.5, Z0), (30, 7.55, Z0 + 0.4), solid=False)
    t = m.group("BrokenTower")
    m.box(t, "Tower", "stone", (40, 0, -37), (46, 13.4, -28))
    m.box(t, "Top", "stone_dark", (39.6, 13.4, -37.4), (46.4, 14, -27.6))
    m.box(t, "Battlement", "stone", (39.6, 14, -37.4), (41, 15, -36))
    m.box(t, "Battlement", "stone", (45, 14, -29), (46.4, 15, -27.6))
    m.box(t, "Battlement", "stone", (45, 14, -37.4), (46.4, 15.4, -35))
    m.box(t, "Window", "rock_dark", (39.95, 9, -33.5), (40.05, 11, -32), solid=False)
    m.box(t, "Vines", "vine", (39.94, 4, -30), (39.98, 13.4, -28.6), solid=False)


def tree(m, parent, name, x, z, height=18, canopy=11):
    g = m.group(name, parent, at=(x, 0, z))
    m.cyl(g, "Trunk", "trunk", (0, 0, 0), 2.2, height, sides=10)
    m.cyl(g, "Roots", "trunk", (0, 0, 0), 3.4, 0.8, sides=10)
    m.cyl(g, "Canopy", "leaves", (0, height - 5, 0), canopy, 3.6, sides=12)
    m.cyl(g, "CanopyTop", "leaves_light", (0, height - 1.4, 0), canopy * 0.65, 2.4, sides=10)
    m.cyl(g, "CanopyLow", "leaves_dark", (0, height - 6.2, 0), canopy * 0.8, 1.2, sides=12, solid=False)
    return g


def treehouses(m):
    """South-west: three big trees with plank platforms at 6 m and rope bridges between them."""
    f = m.folder("Treehouses")
    trees = {"A": (-34, 27), "B": (-34, 40), "C": (-22, 38)}
    for k, (x, z) in trees.items():
        tree(m, f, "Tree" + k, x, z)
    p = m.group("Platforms", f)
    plats = {"A": (-37.5, -30.5, 23.5, 30.5), "B": (-37.5, -30.5, 36.5, 43.5), "C": (-25.5, -18.5, 34.5, 41.5)}
    for k, (x0, x1, z0, z1) in plats.items():
        m.box(p, "Deck" + k, "plank", (x0, 5.7, z0), (x1, 6.0, z1))
        for (bx, bz) in ((x0 + 0.3, z0 + 0.3), (x1 - 0.3, z0 + 0.3), (x0 + 0.3, z1 - 0.3), (x1 - 0.3, z1 - 0.3)):
            m.box(p, "Strut", "timber", (bx - 0.15, 0, bz - 0.15), (bx + 0.15, 5.7, bz + 0.15))
    # Rope rails, open where bridges and the ramp arrive.
    rails = [
        ("A", (-37.5, 23.5), (-30.5, 23.5), [(2.3, 4.7)]), ("A", (-37.5, 30.5), (-30.5, 30.5), [(2.4, 4.6)]),
        ("A", (-37.5, 23.5), (-37.5, 30.5), []), ("A", (-30.5, 23.5), (-30.5, 30.5), []),
        ("B", (-37.5, 36.5), (-30.5, 36.5), [(2.4, 4.6)]), ("B", (-37.5, 43.5), (-30.5, 43.5), []),
        ("B", (-37.5, 36.5), (-37.5, 43.5), []), ("B", (-30.5, 36.5), (-30.5, 43.5), [(1.4, 3.6)]),
        ("C", (-25.5, 34.5), (-18.5, 34.5), [(2.3, 4.7)]), ("C", (-25.5, 41.5), (-18.5, 41.5), []),
        ("C", (-18.5, 34.5), (-18.5, 41.5), []), ("C", (-25.5, 34.5), (-25.5, 41.5), [(3.4, 5.6)]),
    ]
    for k, a, b, holes in rails:
        m.rail(p, "Rope" + k, "rope", a, b, 6.0, 0.9, 0.08, holes=holes)
    # Rope bridges: A-B (north-south) and B-C (east-west).
    b = m.group("Bridges", f)
    m.box(b, "BridgeAB", "plank", (-35.2, 5.75, 30.5), (-32.8, 5.95, 36.5))
    m.box(b, "BridgeBC", "plank", (-30.5, 5.75, 37.8), (-25.5, 5.95, 40.2))
    for x in (-35.3, -32.8):
        m.box(b, "Rope", "rope", (x, 6.6, 30.5), (x + 0.1, 6.7, 36.5), solid=False)
    for zz in (37.7, 40.2):
        m.box(b, "Rope", "rope", (-30.5, 6.6, zz), (-25.5, 6.7, zz + 0.1), solid=False)
    # A ramp from the ground up to platform A.
    m.slab(f, "Ramp", "plank", (-34, 0, 14), (-34, 6.0, 23.5), 2.2, thick=0.3, unbreakable=True)
    m.box(f, "RampPost", "timber", (-35.2, 0, 21.0), (-34.9, 5.0, 21.3))
    m.box(f, "RampPost", "timber", (-33.1, 0, 21.0), (-32.8, 5.0, 21.3))
    m.slab(f, "RampC", "plank", (-22, 0, 24), (-22, 6.0, 34.5), 2.2, thick=0.3, unbreakable=True)
    # A storage hut on the ground (wooden walls and a thatch roof, both break).
    h = m.group("StoreHut", f)
    m.wall(h, "Wall", "wood_wall", (-46, 28), (-40, 28), 0, 3.2, 0.25, holes=[(2.2, 3.8, 1.2, 2.2)])
    m.wall(h, "Wall", "wood_wall", (-46, 33), (-40, 33), 0, 3.2, 0.25, holes=[(1.5, 3.0, 1.2, 2.2)])
    m.wall(h, "Wall", "wood_wall", (-46, 28), (-46, 33), 0, 3.2, 0.25)
    m.wall(h, "Wall", "wood_wall", (-40, 28), (-40, 33), 0, 3.2, 0.25, holes=[(1.8, 3.4, 0, 2.4)])
    m.box(h, "Roof", "thatch", (-46.6, 3.2, 27.4), (-39.4, 3.5, 33.6))
    m.box(h, "Pots", "pot", (-45.4, 0, 31.6), (-44.4, 0.9, 32.6))


def courtyard(m):
    """South-east: low broken walls (vault over them), standing and fallen columns, a dais, a hut."""
    g = m.group("Courtyard")
    m.box(g, "Floor", "paving", (22, 0, 22), (42, 0.03, 42), solid=False)
    for (a, b) in (((22, 22), (30, 22)), ((34, 22), (42, 22)), ((22, 42), (28, 42)), ((32, 42), (42, 42)),
                   ((22, 22), (22, 30)), ((22, 36), (22, 42)), ((42, 22), (42, 28)), ((42, 38), (42, 42))):
        m.wall(g, "LowWall", "stone", a, b, 0, 1.1, 0.7)
    for (x, z, h) in ((27, 27, 2.0), (37, 26, 5.0), (27, 37, 6.5), (37, 38.5, 3.5)):
        m.cyl(g, "Column", "temple_light", (x, 0, z), 1.6, h, sides=12)
        m.cyl(g, "ColumnTop", "temple_dark", (x, h, z), 1.9, 0.3, sides=12)
    m.lying_cyl(g, "FallenColumn", "temple_light", (31, 0.8, 24.6), 1.6, 6.5, axis="x", sides=12)
    # A raised dais with ramps north and south.
    m.box(g, "Dais", "temple", (29, 0, 29), (35, 1.2, 35))
    m.slab(g, "DaisRamp", "temple_light", (32, 1.2, 29), (32, 0, 26.2), 3, thick=0.4)
    m.slab(g, "DaisRamp", "temple_light", (32, 1.2, 35), (32, 0, 37.8), 3, thick=0.4)
    m.box(g, "Statue", "temple_dark", (31.2, 1.2, 31.2), (32.8, 3.6, 32.8))
    m.box(g, "StatueHead", "gold", (31.5, 3.6, 31.5), (32.5, 4.4, 32.5))
    # Hut: wooden walls and a thatch roof.
    h = m.group("Hut", g)
    m.wall(h, "Wall", "wood_wall", (36, 29), (42, 29), 0, 3.2, 0.25, holes=[(2.2, 3.8, 0, 2.4)])
    m.wall(h, "Wall", "wood_wall", (36, 34.5), (42, 34.5), 0, 3.2, 0.25, holes=[(3.6, 5.0, 1.2, 2.2)])
    m.wall(h, "Wall", "wood_wall", (36, 29), (36, 34.5), 0, 3.2, 0.25, holes=[(1.5, 3.1, 0, 2.4)])
    m.wall(h, "Wall", "wood_wall", (42, 29), (42, 34.5), 0, 3.2, 0.25)
    m.box(h, "Roof", "thatch", (35.4, 3.2, 28.4), (42.6, 3.5, 35.1))
    m.box(h, "Table", "timber", (39, 0, 31.2), (41, 0.8, 32.4))


def middle(m):
    f = m.folder("Grounds")
    # Obelisks east and west of the pyramid (wall-run them, hook their tops).
    for x in (-24, 24):
        for z in (-8, 8):
            g = m.group("Obelisk", f, at=(x, 0, z))
            m.box(g, "Base", "temple_dark", (-1.3, 0, -1.3), (1.3, 0.8, 1.3))
            m.box(g, "Shaft", "temple_light", (-0.8, 0.8, -0.8), (0.8, 11, 0.8))
            m.box(g, "Tip", "gold", (-0.5, 11, -0.5), (0.5, 12, 0.5))
            m.box(g, "Glyphs", "carving", (-0.85, 4, -0.5), (0.85, 8, 0.5), solid=False)
    # East: a stone gate (stand on the lintel).
    g = m.group("EastGate", f)
    for z in (-4.5, 4.5):
        m.box(g, "Post", "temple", (33, 0, z - 1), (35, 8, z + 1))
    m.box(g, "Lintel", "temple_dark", (32.6, 8, -5.6), (35.4, 9.4, 5.6))
    m.box(g, "Carving", "gold", (32.55, 8.3, -1), (32.6, 9.1, 1), solid=False)
    m.box(g, "Rubble", "stone", (37, 0, 6.5), (39, 0.9, 8.5))
    # West: an excavation scaffold (plank decks at 4.5 and 9 m, both break) with a ramp.
    s = m.group("Scaffold", f)
    for x in (-38, -32):
        for z in (-3, 3):
            m.box(s, "Pole", "timber", (x - 0.15, 0, z - 0.15), (x + 0.15, 9.8, z + 0.15))
    m.box(s, "DeckLow", "plank", (-38.2, 4.2, -3.2), (-31.8, 4.5, 3.2))
    m.box(s, "DeckHigh", "plank", (-38.2, 8.7, -3.2), (-31.8, 9.0, 3.2))
    m.slab(s, "Ramp", "plank", (-25.5, 0, -2), (-31.8, 4.5, -2), 2, thick=0.3, unbreakable=True)
    m.rail(s, "Rail", "timber", (-38.2, 3.1), (-31.8, 3.1), 9.0, 1.0, 0.1)
    m.rail(s, "Rail", "timber", (-38.2, -3.1), (-31.8, -3.1), 9.0, 1.0, 0.1)
    m.box(s, "Tarp", "cloth_blue", (-38.2, 9.8, -3.2), (-31.8, 9.9, 3.2), solid=False)
    m.box(s, "Crate", "plank", (-37, 4.5, 1), (-35.8, 5.7, 2.2))
    m.box(s, "Dig", "dirt", (-30, 0, 4), (-26, 0.6, 9))
    # Hedge walls north and south.
    h = m.group("Hedges", f)
    for (x0, x1, z) in ((-16, -2.5, -38), (2.5, 16, -38), (-16, -6, 38), (6, 16, 38)):
        m.box(h, "Hedge", "leaves_dark", (x0, 0, z - 0.8), (x1, 2.6, z + 0.8))
    # Fallen logs, bushes and boulders for cover.
    c = m.group("Cover", f)
    m.lying_cyl(c, "Log", "trunk", (-10, 0.7, -29), 1.4, 9, axis="x", sides=10)
    m.lying_cyl(c, "Log", "trunk", (12, 0.7, 29), 1.4, 8, axis="x", sides=10)
    m.lying_cyl(c, "Log", "trunk", (-17, 0.6, 14), 1.2, 6, axis="z", sides=10)
    for (x, z, s_) in ((14, -24, 1.4), (-8, 20, 1.2), (18, 12, 1.3), (-20, -16, 1.2), (8, -20, 1.0), (28, 16, 1.4),
                       (-28, 12, 1.3), (16, 44, 1.6), (-14, -44, 1.6), (44, 12, 1.5), (-44, -14, 1.5)):
        m.box(c, "Bush", "leaves", (x - s_, 0, z - s_), (x + s_, s_ * 1.0, z + s_))
    for (x, z, w, h) in ((20, -44, 3, 2.2), (-44, 18, 2.6, 1.8), (44, -18, 2.4, 2.6), (-20, 44, 3, 1.6)):
        m.box(c, "Boulder", "rock", (x - w / 2, 0, z - w / 2), (x + w / 2, h, z + w / 2))
    # Extra trees round the edges.
    for (x, z) in ((14, -43), (-44, -6), (44, 44), (44, 22), (-10, 44), (-44, -46 + 2)):
        tree(m, f, "Tree", x, z, height=16, canopy=9)


def cliffs(m):
    """A ring of cliffs round the clearing (you leave the map past them)."""
    g = m.group("Cliffs")
    heights = [14, 18, 12, 20, 16, 13, 19, 15, 17, 12, 18, 14]
    i = 0
    for side in ("n", "s", "e", "w"):
        u = -58
        while u < 58:
            w = 10 + (i * 7) % 6
            h = heights[i % len(heights)]
            depth = 6 + (i * 3) % 4
            kind = "rock" if i % 2 == 0 else "rock_dark"
            if side == "n":
                lo, hi = (u, 0, -48 - depth), (u + w, h, -48)
            elif side == "s":
                lo, hi = (u, 0, 48), (u + w, h, 48 + depth)
            elif side == "e":
                lo, hi = (48, 0, u), (48 + depth, h, u + w)
            else:
                lo, hi = (-48 - depth, 0, u), (-48, h, u + w)
            m.box(g, "Cliff", kind, lo, hi)
            m.box(g, "CliffMoss", "moss", (lo[0], h, lo[2]), (hi[0], h + 0.3, hi[2]), solid=False)
            u += w
            i += 1
    # A waterfall down the north cliff.
    m.box(g, "Waterfall", "water", (-6, 0, -48.2), (-2, 16, -48.05), solid=False)
    m.box(g, "Pool", "water", (-8, 0, -48), (0, 0.05, -45), solid=False)


def spawns(m):
    pts = [
        ((-18, 0, -18), (0, 0)), ((18, 0, -18), (0, 0)), ((-18, 0, 18), (0, 0)), ((18, 0, 18), (0, 0)),
        ((0, 9, -3.5), (0, -20)), ((-2.5, 0, -2.6), (10, 0)),
        ((-26, 0, -38), (0, 0)), ((-39, 0, -30), (0, 0)), ((-38, 4.3, -38), (0, 0)),
        ((30, 7, -32.5), (0, 0)), ((-34, 6, 24.6), (0, 0)), ((-19.5, 6, 35.5), (0, 0)),
        ((25, 0, 25), (0, 0)), ((39, 0, 25), (0, 0)), ((25, 0, 40), (0, 0)),
        ((-24, 0, 10), (0, 0)), ((40, 0, 0), (0, 0)), ((8, 0, -43), (0, 0)), ((-10, 0, 41), (0, 0)),
        ((44, 0, -44), (0, 0)), ((-30, 0, -14), (0, 0)), ((30, 0, 12), (0, 0)),
    ]
    for p, t in pts:
        m.spawn(p, t)


def pickups(m):
    for (p, w) in [
        ((0, 0, 2.8), "shotgun"), ((5.4, 14.3, 5.4), "sniper"), ((37, 7, -32.5), "rifle"), ((43, 14, -32.5), "railgun"),
        ((-29, 0, -36), "smg"), ((-40, 4.3, -30), "break_action"), ((-36.5, 6, 42.5), "axe"), ((-24.6, 6, 38.6), "bat"),
        ((33.5, 1.2, 30.2), "grenade_launcher"), ((-35, 9, 0), "lever_action"), ((38.5, 0, 33), "brass_knuckles"),
        ((38, 0, -2), "lmg"), ((-12, 0, -20), "revolver"), ((10, 0, 20), "sword"), ((-10, 0, -40), "bolt_action"),
    ]:
        m.weapon(p, w)
