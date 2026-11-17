"""Builds the four race maps: Rooftop Run, Foundry, Sky Ruins and Summit Plunge.

    python3 tools/race/build_race_maps.py          # all four
    python3 tools/race/build_race_maps.py foundry  # one

Writes game/maps/<id>.tscn and game/maps/palettes/<id>.tres. The scenes are the
real maps from then on: edit them in Godot like the other maps. Running this
again overwrites them (and any hand edits), so only re-run it on purpose.
Each course is a list of sections from sections.py; each map's theme says
what its floors, walls and hazards are made of and how they are dressed.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from course import Course, fmt  # noqa: E402
import sections as S  # noqa: E402

JET = (0.45, 0.9, 1.0, 1)   # signs that name a move
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def env_block(sky_top, horizon, ground, ambient, ambient_energy, fog=None, glow=True, extra=()):
    c = lambda t: "Color(%s, 1)" % ", ".join(fmt(v) for v in t)
    lines = ['[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]',
             "sky_top_color = %s" % c(sky_top), "sky_horizon_color = %s" % c(horizon),
             "ground_bottom_color = %s" % c(ground), "ground_horizon_color = %s" % c(horizon), "",
             '[sub_resource type="Sky" id="Sky_1"]', 'sky_material = SubResource("Sky_mat")', "",
             '[sub_resource type="Environment" id="Environment_1"]', "background_mode = 2", 'sky = SubResource("Sky_1")',
             "ambient_light_source = 2", "ambient_light_color = %s" % c(ambient),
             "ambient_light_energy = %s" % fmt(ambient_energy), "tonemap_mode = 2", "tonemap_white = 2.6",
             "ssao_enabled = true"]
    if glow:
        lines += ["glow_enabled = true", "glow_intensity = 0.9", "glow_bloom = 0.08"]
    if fog:
        lines += ["fog_enabled = true", "fog_light_color = %s" % c(fog[0]), "fog_density = %s" % fmt(fog[1]),
                  "fog_sky_affect = %s" % fmt(fog[2] if len(fog) > 2 else 0.3)]
    lines += list(extra)
    return lines


def sun_rows(elevation_deg, azimuth_deg):
    """Basis rows of a light pointing down at `elevation` from the `azimuth` direction."""
    e, a = math.radians(elevation_deg), math.radians(azimuth_deg)
    # The light shines along its -z. Build z pointing back toward the sun.
    z = (math.cos(e) * math.sin(a), math.sin(e), math.cos(e) * math.cos(a))
    x = (math.cos(a), 0.0, -math.sin(a))
    y = (z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0])
    return (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])


def write_palette(path, colors, glow):
    out = ['[gd_resource type="Resource" script_class="MapPalette" format=3]', "",
           '[ext_resource type="Script" path="res://game/arena/map_palette.gd" id="1_pal"]', "", "[resource]",
           'script = ExtResource("1_pal")', "colors = Dictionary[String, Color]({"]
    out += ['"%s": Color(%s, 1),' % (k, ", ".join(fmt(v) for v in colors[k])) for k in sorted(colors)]
    out[-1] = out[-1].rstrip(",")
    out += ["})", "glow = Dictionary[String, float]({"]
    out += ['"%s": %s,' % (k, fmt(glow[k])) for k in sorted(glow)]
    out[-1] = out[-1].rstrip(",")
    out += ["})", "roughness = 0.85", ""]
    with open(path, "w") as fh:
        fh.write("\n".join(out))


def h(*vals):
    """A repeatable 0..1 number from some values (for variety without randomness)."""
    s = 0
    for v in vals:
        s = (s * 131 + int(round(v * 10)) * 17 + 7) % 10007
    return (s % 1000) / 1000.0


# ---------------------------------------------------------------------------
# Themes

class Theme:
    thick = 1.0
    deck = "deck"
    obstacle = "obstacle"
    wall = "wall"
    duct = "duct"
    panel = "panel"
    tower = "tower"
    platform = "platform"
    stem = "stem"
    press = "press"
    hot = "hot"
    beam_hazard = "beam_hazard"
    ramp = "ramp"

    def under(self, c, g, f0, f1, top, w, r, open_side=0):
        pass

    def under_ramp(self, c, g, L, dy):
        pass

    def under_ramp_at(self, c, g, f0, L, dy):
        """under_ramp for a slope starting f0 ahead of the cursor."""
        pos = c.pos
        c.pos = c.w(f0)
        self.under_ramp(c, g, L, dy)
        c.pos = pos

    def takeoff(self, c, g, f, mark_only=False):
        """Chevrons on the floor before a take-off that needs the newer moves."""
        for i in range(3):
            ff = f - 1.2 - i * 1.4
            for sd in (-1, 1):
                c.box(g, "Chevron", ff - 0.35, ff + 0.35, sd * 0.4, sd * 1.6, 0, 0.03, "jet", solid=False,
                      cols=c.basis(yaw=sd * 0.6))

    def chute_mouth(self, c, g, f, top):
        for sd in (-1, 1):
            c.box(g, "Mouth", f - 0.3, f + 0.3, sd * 1.6, sd * (c.W / 2), top, top + 2.4, self.wall)
        c.box(g, "Lintel", f - 0.3, f + 0.3, -1.6, 1.6, top + 0.95, top + 2.4, "jet")

    def ledge(self, c, g, f, h):
        c.box(g, "Ledge", f, f + 1.0, -c.W / 2, c.W / 2, -self.thick, h - self.thick, self.wall)

    def beam(self, c, g, f, h):
        c.box(g, "Beam", f - 0.6, f + 0.6, -8, 8, h - 0.5, h + 0.5, "beam")

    def pool(self, c, g, f0, f1, y):
        c.box(g, "Pool", f0, f1, -c.W / 2 - 4, c.W / 2 + 4, y - 1.0, y, self.hot, hazard=True, solid=False)

    def tunnel(self, c, g, f0, f1):
        pass

    def panel_dressing(self, c, g, f0, f1, side):
        pass

    def start_dressing(self, c, g):
        pass

    def finish_dressing(self, c, g):
        pass


class Rooftops(Theme):
    STREET = -46.0
    thick = 0.5
    deck = "roof"
    obstacle = "ac_unit"
    wall = "brick"
    duct = "duct"
    panel = "billboard"
    tower = "building"
    platform = "roof"
    stem = "steel"
    hot = "live"
    beam_hazard = "fan_blade"
    ramp = "glass"
    colors = {
        "roof": (0.58, 0.56, 0.53), "roof_edge": (0.42, 0.4, 0.38), "building": (0.72, 0.62, 0.52),
        "building_b": (0.55, 0.6, 0.66), "building_c": (0.78, 0.74, 0.66), "brick": (0.62, 0.36, 0.28),
        "window": (0.36, 0.48, 0.6), "window_lit": (1.0, 0.82, 0.52), "ac_unit": (0.82, 0.83, 0.84),
        "duct": (0.66, 0.68, 0.7), "billboard": (0.18, 0.2, 0.24), "billboard_a": (0.95, 0.45, 0.2),
        "billboard_b": (0.25, 0.7, 0.85), "billboard_c": (0.95, 0.85, 0.3), "steel": (0.35, 0.37, 0.4),
        "crane": (0.95, 0.72, 0.12), "beam": (0.95, 0.72, 0.12), "live": (0.35, 0.75, 1.0),
        "fan_blade": (1.0, 0.32, 0.25), "glass": (0.55, 0.72, 0.82), "street": (0.22, 0.23, 0.25),
        "pad": (0.25, 0.27, 0.3), "pad_mark": (0.95, 0.95, 0.9), "tank": (0.5, 0.36, 0.25),
        "far_city": (0.66, 0.62, 0.62), "far_city_b": (0.55, 0.56, 0.62), "lamp": (1.0, 0.9, 0.7),
    }
    glow = {"live": 3.0, "fan_blade": 1.6, "window_lit": 1.2, "billboard_a": 0.6, "billboard_b": 0.6,
            "billboard_c": 0.6, "lamp": 2.0}

    def under(self, c, g, f0, f1, top, w, r, open_side=0):
        kinds = ["building", "building_b", "building_c"]
        k = kinds[int(h(f0, f1, top, c.pos[0], c.pos[2]) * 3) % 3]
        bw = w + 4.0
        c.box(g, "Building", f0, f1, r - bw / 2, r + bw / 2, self.STREET, top - self.thick - 0.02, k)
        # Window bands down the sides.
        y = top - 3.0
        while y > self.STREET + 4:
            for sd in (-1, 1):
                c.box(g, "Windows", f0 + 0.6, f1 - 0.6, r + sd * bw / 2, r + sd * (bw / 2 + 0.06), y - 1.0, y,
                      "window_lit" if h(y, f0, sd) > 0.82 else "window", solid=False)
            y -= 3.5
        # Low parapets along the roof's edges (not across the way).
        for sd in (-1, 1):
            if sd == open_side:
                continue
            c.box(g, "Parapet", f0, f1, r + sd * (w / 2), r + sd * (bw / 2), top - self.thick, top + 0.45, "roof_edge")

    def ledge(self, c, g, f, h_):
        pass   # the next roof's building is the wall you climb

    def under_ramp(self, c, g, L, dy):
        top = min(0, dy)
        c.box(g, "Building", 0, L, -c.W / 2 - 2, c.W / 2 + 2, self.STREET, top - 0.7, "building_c")
        for sd in (-1, 1):
            c.ramp(g, 0, 0.5, L, dy + 0.5, "steel", width=0.3, thick=0.6, r=sd * (c.W / 2 + 0.15), name="Rail")

    def beam(self, c, g, f, h_):
        # A crane: mast on one side, its jib reaching out over the street.
        side = 1 if h(f) > 0.5 else -1
        c.box(g, "Jib", f - 0.6, f + 0.6, -10 if side > 0 else -14, 14 if side > 0 else 10, h_ - 0.5, h_ + 0.5, "crane")
        c.box(g, "Mast", f - 0.8, f + 0.8, side * 11.2, side * 12.8, self.STREET, h_ + 6, "crane", solid=True)
        c.box(g, "Cab", f - 1.2, f + 1.2, side * 10.6, side * 13.4, h_ + 0.5, h_ + 3, "steel")
        c.box(g, "Counterweight", f - 1.0, f + 1.0, side * 14, side * 18, h_ - 1.5, h_ + 0.5, "steel")
        c.box(g, "Cable", f - 0.05, f + 0.05, side * 4.95, side * 5.05, h_ - 5, h_ - 0.5, "steel", solid=False)
        c.box(g, "Hook", f - 0.5, f + 0.5, side * 4.5, side * 5.5, h_ - 5.8, h_ - 5, "tank", solid=False)

    def panel_dressing(self, c, g, f0, f1, side):
        k = ["billboard_a", "billboard_b", "billboard_c"][int(h(f0, side) * 3) % 3]
        inner = side * 1.96
        c.box(g, "Poster", f0 + 0.5, f1 - 0.5, inner, side * 2.0, -2.5, 4.0, k, solid=False)
        for f in (f0 + 2, f1 - 2):
            c.box(g, "Leg", f - 0.3, f + 0.3, side * 2.4, side * 3.0, self.STREET, -4, "steel")

    def tunnel(self, c, g, f0, f1):
        for f in (f0 + 0.3, f1 - 0.3):
            c.box(g, "Rim", f - 0.15, f + 0.15, -1.7, 1.7, 0.9, 1.2, "steel", solid=False)

    def start_dressing(self, c, g):
        c.box(g, "Tank", -14, -10, -3, 1, 0, 0.2, "steel")
        c.block(g, "WaterTank", c.w(-12, 4.2, -1), (3.6, 4.0, 3.6), "tank", shape="cyl", sides=16)
        for sd in (-1, 1):
            c.box(g, "TankLeg", -12.2, -11.8, sd * 1.4 - 1.2, sd * 1.4 - 0.8, 0.2, 2.2, "steel")

    def finish_dressing(self, c, g):
        c.block(g, "Helipad", c.w(9, 0.03, 0), (7.0, 0.04, 7.0), "pad", shape="cyl", sides=24, solid=False)
        c.box(g, "H", 8.5, 9.5, -1.6, -1.0, 0.05, 0.08, "pad_mark", solid=False)
        c.box(g, "H", 8.5, 9.5, 1.0, 1.6, 0.05, 0.08, "pad_mark", solid=False)
        c.box(g, "H", 8.85, 9.15, -1.0, 1.0, 0.05, 0.08, "pad_mark", solid=False)


class Foundry(Theme):
    FLOOR = -16.0
    thick = 0.4
    deck = "grating"
    obstacle = "crate"
    wall = "steel_dark"
    duct = "conveyor"
    panel = "tank"
    tower = "furnace"
    platform = "plate"
    stem = "steel"
    press = "press"
    hot = "molten"
    beam_hazard = "molten"
    ramp = "chute"
    colors = {
        "grating": (0.42, 0.44, 0.46), "rail": (0.95, 0.72, 0.12), "steel": (0.32, 0.34, 0.37),
        "steel_dark": (0.22, 0.23, 0.25), "crate": (0.58, 0.44, 0.3), "conveyor": (0.18, 0.18, 0.2),
        "conveyor_belt": (0.1, 0.1, 0.11), "tank": (0.46, 0.5, 0.52), "tank_band": (0.72, 0.3, 0.18),
        "furnace": (0.3, 0.27, 0.26), "furnace_mouth": (1.0, 0.45, 0.1), "plate": (0.5, 0.48, 0.44),
        "press": (0.36, 0.38, 0.42), "molten": (1.0, 0.42, 0.08), "chute": (0.55, 0.52, 0.48),
        "hall": (0.26, 0.24, 0.24), "hall_band": (0.36, 0.3, 0.27), "truss": (0.3, 0.3, 0.32),
        "lamp": (1.0, 0.86, 0.6), "beam": (0.95, 0.72, 0.12), "pipe": (0.5, 0.36, 0.26), "hazard_stripe": (0.95, 0.75, 0.1),
    }
    glow = {"molten": 3.2, "furnace_mouth": 3.0, "lamp": 2.5, "hazard_stripe": 0.25}

    def under(self, c, g, f0, f1, top, w, r, open_side=0):
        L = f1 - f0
        n = max(2, int(L / 8) + 1)
        for i in range(n):
            f = f0 + 0.4 + (L - 0.8) * i / (n - 1)
            for sd in (-1, 1):
                c.box(g, "Post", f - 0.2, f + 0.2, r + sd * (w / 2 - 0.2) - 0.2, r + sd * (w / 2 - 0.2) + 0.2,
                      self.FLOOR - 2, top - self.thick, "steel")
        for sd in (-1, 1):
            if sd == open_side:
                continue
            c.box(g, "Rail", f0, f1, r + sd * w / 2 - 0.06, r + sd * w / 2 + 0.06, top + 0.95, top + 1.05, "rail")
            c.box(g, "Toe", f0, f1, r + sd * w / 2 - 0.08, r + sd * w / 2 + 0.08, top, top + 0.15, "steel")

    def under_ramp(self, c, g, L, dy):
        for sd in (-1, 1):
            c.ramp(g, 0, 0.8, L, dy + 0.8, "steel_dark", width=0.3, thick=1.2, r=sd * (c.W / 2 + 0.15), name="Side")

    def beam(self, c, g, f, h_):
        c.box(g, "CraneRail", f - 0.6, f + 0.6, -14, 14, h_ - 0.5, h_ + 0.5, "beam")
        c.box(g, "Trolley", f - 1.0, f + 1.0, -2.5, -0.5, h_ - 1.4, h_ - 0.5, "steel", solid=False)
        for sd in (-1, 1):
            c.box(g, "Column", f - 0.7, f + 0.7, sd * 13, sd * 14.4, self.FLOOR - 2, h_ + 4, "hall_band")

    def pool(self, c, g, f0, f1, y):
        c.box(g, "Molten", f0, f1, -c.W / 2 - 3, c.W / 2 + 3, y - 1.0, y, "molten", hazard=True, solid=False)
        for sd in (-1, 1):
            c.box(g, "Rim", f0, f1, sd * (c.W / 2 + 3), sd * (c.W / 2 + 4), y - 4, y + 0.6, "steel_dark")

    def panel_dressing(self, c, g, f0, f1, side):
        c.box(g, "Band", f0 - 0.05, f1 + 0.05, side * 1.95, side * 3.05, 3.2, 3.8, "tank_band", solid=False)
        c.box(g, "Base", f0, f1, side * 2.0, side * 3.0, self.FLOOR - 2, -4.0, "tank")

    def tunnel(self, c, g, f0, f1):
        c.box(g, "Pipe", f0 - 0.3, f1 + 0.3, -2.2, 2.2, -0.2, 2.6, "pipe", solid=False, drawn=False)

    def start_dressing(self, c, g):
        for i, f in enumerate((-14, -11)):
            c.box(g, "Crate", f, f + 2.4, 2.2, 3.8, 0, 2.0 + i * 0.6, "crate")

    def finish_dressing(self, c, g):
        c.box(g, "Stripe", 5.6, 6.4, -c.W / 2, c.W / 2, 0, 0.02, "hazard_stripe", solid=False)


class SkyRuins(Theme):
    thick = 1.2
    deck = "grass"
    obstacle = "rubble"
    wall = "stone"
    duct = "stone_dark"
    panel = "slab"
    tower = "stone"
    platform = "stone_light"
    stem = "stone_dark"
    press = "stone_dark"
    hot = "energy"
    beam_hazard = "energy"
    ramp = "stone_light"
    colors = {
        "grass": (0.46, 0.66, 0.36), "stone": (0.74, 0.7, 0.62), "stone_dark": (0.55, 0.52, 0.48),
        "stone_light": (0.86, 0.83, 0.76), "rubble": (0.68, 0.64, 0.56), "slab": (0.8, 0.77, 0.7),
        "rune": (0.45, 0.85, 1.0), "energy": (0.5, 0.95, 1.0), "gold": (0.95, 0.78, 0.3),
        "cloud": (0.97, 0.98, 1.0), "moss": (0.36, 0.52, 0.3), "beam": (0.86, 0.83, 0.76), "earth": (0.5, 0.4, 0.3),
    }
    glow = {"rune": 1.8, "energy": 2.6, "gold": 0.4}

    def under(self, c, g, f0, f1, top, w, r, open_side=0):
        L = f1 - f0
        y = top - self.thick
        inset = 0.0
        for i, depth in enumerate((2.5, 3.0, 3.5)):
            inset += 0.9 + 0.4 * i
            if L - 2 * inset < 1.0 or w - 2 * inset < 1.0:
                break
            c.box(g, "Rock", f0 + inset, f1 - inset, r - w / 2 + inset - 0.6, r + w / 2 - inset + 0.6, y - depth, y,
                  "earth" if i == 0 else "stone_dark")
            y -= depth
        c.box(g, "Rim", f0, f1, r - w / 2 - 0.4, r + w / 2 + 0.4, top - self.thick - 0.6, top - self.thick, "stone")

    def under_ramp(self, c, g, L, dy):
        for sd in (-1, 1):
            c.ramp(g, 0, 0.6, L, dy + 0.6, "stone", width=0.6, thick=1.4, r=sd * (c.W / 2 + 0.3), name="Wall")

    def beam(self, c, g, f, h_):
        # A ring arch: two pillars on floating rocks and a lintel to hook.
        c.box(g, "Lintel", f - 0.7, f + 0.7, -8, 8, h_ - 0.5, h_ + 0.6, "stone_light")
        c.box(g, "Rune", f - 0.72, f + 0.72, -2, 2, h_ - 0.52, h_ - 0.4, "rune", solid=False)
        for sd in (-1, 1):
            c.box(g, "Pillar", f - 0.7, f + 0.7, sd * 6.6, sd * 8, h_ - 14, h_ - 0.5, "stone")
            c.box(g, "Base", f - 2, f + 2, sd * 5.6, sd * 9, h_ - 17, h_ - 14, "stone_dark")

    def panel_dressing(self, c, g, f0, f1, side):
        c.box(g, "Rune", f0 + 2, f1 - 2, side * 1.97, side * 2.0, 1.4, 1.7, "rune", solid=False)

    def pool(self, c, g, f0, f1, y):
        c.box(g, "Rift", f0, f1, -c.W / 2 - 2, c.W / 2 + 2, y - 0.4, y, "energy", hazard=True, solid=False)

    def start_dressing(self, c, g):
        for sd in (-1, 1):
            c.box(g, "Obelisk", -15, -13.6, sd * 3.2 - 0.7, sd * 3.2 + 0.7, 0, 6, "stone_light")
            c.box(g, "Glow", -15.05, -13.55, sd * 3.2 - 0.2, sd * 3.2 + 0.2, 4, 5.5, "rune", solid=False)

    def finish_dressing(self, c, g):
        c.block(g, "Dais", c.w(10, 0.1, 0), (6.0, 0.2, 6.0), "gold", shape="cyl", sides=20, solid=False)


class Snow(Theme):
    """A groomed piste down a mountain ridge: snow over rock, ice where the walls are,
    pines on the shoulders. Each floor sits on a stepped rock mass that widens and
    deepens below it, so the course reads as a ridge on one huge mountain."""
    thick = 1.0
    deck = "snow"
    obstacle = "snow_drift"
    wall = "rock"
    duct = "ice_dark"
    panel = "ice"
    tower = "rock"
    platform = "ice"
    stem = "rock_dark"
    press = "rock_dark"
    hot = "meltwater"
    beam_hazard = "flag_red"
    ramp = "snow"
    colors = {
        "snow": (0.93, 0.95, 0.98), "snow_shade": (0.8, 0.86, 0.94), "snow_drift": (0.86, 0.9, 0.96),
        "ice": (0.62, 0.84, 0.96), "ice_dark": (0.38, 0.6, 0.78), "rock": (0.42, 0.42, 0.46),
        "rock_dark": (0.3, 0.3, 0.34), "pine": (0.15, 0.32, 0.24), "pine_dark": (0.1, 0.24, 0.18),
        "trunk": (0.36, 0.25, 0.17), "wood": (0.55, 0.36, 0.22), "wood_dark": (0.38, 0.24, 0.14),
        "roof_red": (0.72, 0.16, 0.13), "window_lit": (1.0, 0.8, 0.45), "lamp": (1.0, 0.88, 0.62),
        "flag_red": (0.95, 0.2, 0.15), "flag_blue": (0.15, 0.35, 0.95), "meltwater": (0.25, 0.75, 1.0),
        "valley": (0.82, 0.88, 0.95), "far_peak": (0.5, 0.54, 0.62), "far_snow": (0.95, 0.97, 1.0),
        "pole": (0.25, 0.26, 0.28),
    }
    glow = {"window_lit": 1.4, "lamp": 2.2, "meltwater": 1.4, "flag_red": 0.3}

    def under(self, c, g, f0, f1, top, w, r, open_side=0):
        y = top - self.thick
        # The ridge: snow shoulders a step down, then rock widening below.
        for i, (drop, extra, depth, kind) in enumerate(((2.5, 6, 6, "snow_shade"), (8, 18, 14, "rock"),
                                                         (20, 40, 40, "rock_dark"))):
            ext = 0 if i < 2 else 8   # the deepest step runs under the gaps too
            c.box(g, "Ridge", f0 - ext, f1 + ext, r - w / 2 - extra / 2, r + w / 2 + extra / 2, top - drop - depth,
                  top - drop if i else y, kind, solid=i < 2)
            if i == 1:
                c.box(g, "SnowCap", f0, f1, r - w / 2 - extra / 2, r + w / 2 + extra / 2, top - drop, top - drop + 0.4,
                      "snow", solid=False)
        # Snow banks along the edges of the piste, and a catch net of nothing under the
        # crevasses: falling in sends you back at once rather than after a long fall.
        for sd in (-1, 1):
            if sd == open_side:
                continue
            c.box(g, "Bank", f0, f1, r + sd * (w / 2 - 0.1), r + sd * (w / 2 + 1.4), top - self.thick, top + 0.35, "snow_drift")
        c.box(g, "Catch", f0 - 26, f1, r - w / 2 - 40, r + w / 2 + 40, top - 15, top - 14, "rock_dark",
              hazard=True, solid=False, drawn=False)
        # Pines on the lower shoulder.
        L = f1 - f0
        n = int(L / 7)
        for i in range(n):
            f = f0 + 3 + i * 7 + h(f0, i) * 3
            for sd in (-1, 1):
                if h(f, sd, top) < 0.45:
                    continue
                rr = r + sd * (w / 2 + 3.5 + h(sd, f) * 4.0)
                self.pine(c, g, f, rr, top - 8 + 0.4, 6 + h(f, sd) * 6)

    def pine(self, c, g, f, r, base, height):
        c.block(g, "Trunk", c.w(f, base + 0.8, r), (0.5, 1.6, 0.5), "trunk", shape="cyl", sides=6, solid=False)
        tiers = 4
        for i in range(tiers):
            k = i / tiers
            rad = (1.0 - k) * height * 0.32 + 0.4
            y = base + 1.4 + k * (height - 1.6)
            c.block(g, "Pine", c.w(f, y + 0.5, r), (rad * 2, height / tiers * 1.1, rad * 2), "pine" if i % 2 else "pine_dark",
                    shape="cyl", sides=7, solid=False)
            c.block(g, "PineSnow", c.w(f, y + height / tiers * 0.55 + 0.5, r), (rad * 1.3, 0.25, rad * 1.3), "snow",
                    shape="cyl", sides=7, solid=False)

    def under_ramp(self, c, g, L, dy):
        top = min(0, dy)
        steps = 4
        for i in range(steps):
            a, b = L * i / steps, L * (i + 1) / steps
            y = min(dy * (i + 1) / steps, dy * i / steps)   # the lower end of this stretch
            c.box(g, "Ridge", a, b, -c.W / 2 - 3, c.W / 2 + 3, y - 12, y - self.thick - 0.2, "rock")
            c.box(g, "Ridge", a, b, -c.W / 2 - 12, c.W / 2 + 12, y - 40, y - 10, "rock_dark", solid=False)
        for sd in (-1, 1):
            c.ramp(g, 0, 0.35, L, dy + 0.35, "snow_drift", width=1.4, thick=1.4, r=sd * (c.W / 2 + 0.6), name="Bank")
        c.box(g, "Catch", -4, L, -c.W / 2 - 40, c.W / 2 + 40, top - 15, top - 14, "rock_dark",
              hazard=True, solid=False, drawn=False)

    def ledge(self, c, g, f, h_):
        c.box(g, "Ledge", f, f + 1.0, -c.W / 2, c.W / 2, -self.thick, h_ - self.thick, "rock")

    def beam(self, c, g, f, h_):
        # A rock arch over the gorge: two crags and an icy span to hook.
        c.box(g, "Span", f - 0.8, f + 0.8, -9, 9, h_ - 0.6, h_ + 0.8, "ice_dark")
        c.box(g, "SpanSnow", f - 0.9, f + 0.9, -9, 9, h_ + 0.8, h_ + 1.2, "snow", solid=False)
        for sd in (-1, 1):
            c.box(g, "Crag", f - 1.5, f + 1.5, sd * 7.5, sd * 10.5, h_ - 40, h_ + 0.4, "rock")
            c.box(g, "CragSnow", f - 1.6, f + 1.6, sd * 7.4, sd * 10.6, h_ + 0.4, h_ + 1.0, "snow", solid=False)

    def panel_dressing(self, c, g, f0, f1, side):
        c.box(g, "IceBase", f0, f1, side * 2.0, side * 3.0, -40, -4.0, "rock")
        c.box(g, "IceTop", f0, f1, side * 1.95, side * 3.05, 5.0, 5.4, "snow", solid=False)

    def pool(self, c, g, f0, f1, y):
        c.box(g, "Water", f0, f1, -c.W / 2 - 3, c.W / 2 + 3, y - 1.0, y, "meltwater", hazard=True, solid=False)

    def chute_mouth(self, c, g, f, top):
        for sd in (-1, 1):
            c.box(g, "Mouth", f - 0.6, f + 0.6, sd * 1.6, sd * (c.W / 2 + 1.4), top, top + 3.0, "ice")
        c.box(g, "Lintel", f - 0.6, f + 0.6, -1.6, 1.6, top + 0.95, top + 3.0, "ice")
        c.box(g, "Cornice", f - 1.2, f + 0.6, -c.W / 2 - 1.4, c.W / 2 + 1.4, top + 3.0, top + 3.6, "snow", solid=False)

    def start_dressing(self, c, g):
        # The summit: a weather hut and a flag.
        c.box(g, "Hut", -15, -10, -c.W / 2 + 0.5, -c.W / 2 + 4.5, 0, 3.2, "wood")
        c.box(g, "HutRoof", -15.4, -9.6, -c.W / 2 + 0.1, -c.W / 2 + 4.9, 3.2, 3.8, "snow")
        c.box(g, "Mast", -12.6, -12.4, c.W / 2 - 2.1, c.W / 2 - 1.9, 0, 7, "pole")
        c.box(g, "Flag", -12.6, -12.5, c.W / 2 - 1.9, c.W / 2 + 0.4, 5.6, 6.9, "flag_red", solid=False)

    def finish_dressing(self, c, g):
        # The lodge at the bottom, past the line.
        f0 = 13
        c.box(g, "Lodge", f0, f0 + 4, -9, 9, 0, 4.5, "wood")
        c.box(g, "LodgeRoof", f0 - 0.6, f0 + 4.6, -9.6, 9.6, 4.5, 5.3, "roof_red")
        c.box(g, "LodgeSnow", f0 - 0.7, f0 + 4.7, -9.7, 9.7, 5.3, 5.6, "snow", solid=False)
        for i in range(5):
            rr = -6 + i * 3
            c.box(g, "Window", f0 - 0.05, f0, rr - 0.7, rr + 0.7, 1.4, 2.8, "window_lit", solid=False)
        for sd in (-1, 1):
            c.box(g, "Pole", 5.8, 6.2, sd * (c.W / 2 + 1.0) - 0.2, sd * (c.W / 2 + 1.0) + 0.2, 0, 4.5, "flag_blue" if sd < 0 else "flag_red")
            c.box(g, "Lamp", 5.6, 6.4, sd * (c.W / 2 + 1.0) - 0.4, sd * (c.W / 2 + 1.0) + 0.4, 4.5, 4.9, "lamp", solid=False)


# ---------------------------------------------------------------------------
# The courses

def rooftop_run():
    T = Rooftops()
    c = Course("RooftopRun", None, env_block((0.3, 0.46, 0.75), (0.98, 0.76, 0.52), (0.4, 0.35, 0.32),
                                                 (0.86, 0.78, 0.72), 0.85, fog=((0.95, 0.75, 0.55), 0.0035, 0.2)),
               (sun_rows(14, 235), (1.0, 0.8, 0.58), 1.15), (0, 0, 0))
    c.settings["face_shade"] = "Vector3(0.92, 0.82, 0.62)"
    S.start(c, T)
    c.sign(-4, 5.5, 0, "ROOFTOP RUN", 140, (1, 0.8, 0.45, 1))
    S.gaps(c, T, [(4.0, 10)])
    S.vaults(c, T, 2)
    S.gaps(c, T, [(5.0, 10), (6.5, 10, -1.0)])
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "BILLBOARD ALLEY", 90)
    S.wallrun(c, T, side=-1, panels=2)
    c.sign(2, 4, 0, "ROCKET GAP: JUMP + E", 70, JET)
    S.boost_gap(c, T, 19.0, land=18)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "DUCT MAZE", 90)
    S.slide_under(c, T, 10)
    c.sign(4, 3.5, 0, "DIVE IN: HOLD Q", 60, JET)
    S.belly_chute(c, T, 20, -5)
    S.vaults(c, T, 3)
    S.turn(c, T, right=True)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "THE CLIMB", 90)
    S.boost_wall(c, T, 7.0)
    S.chimney(c, T, 8.0)
    S.strips(c, T, 3)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "CRANE CROSSING", 90)
    S.grapple_swing(c, T, [(10, 11.0), (30, 12.0)], land_gap=8)
    S.gaps(c, T, [(6.0, 10)])
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "SIGN SKIPPING", 90)
    S.wallrun(c, T, side=1, panels=2)
    c.sign(2, 4, 0, "SLIDE, JUMP, FLOAT: SHIFT", 60, JET)
    S.ski_jump(c, T)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "LIVE WIRES", 90)
    S.strips(c, T, 3)
    S.sweepers(c, T, 2)
    S.turn(c, T, right=False)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "WATER TOWERS", 90)
    S.climb(c, T, [2.0])
    S.grapple_swing(c, T, [(14, 13.0)], land_gap=12)
    S.vaults(c, T, 2)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "GLASS ROOF", 90)
    S.slope(c, T, 22, -8, slide=True)
    c.sign(2, 4, 0, "FLOAT, THEN E", 70, JET)
    S.float_gap(c, T, 40.0, -6.0, land=16, boost=True)
    S.finish(c, T)
    _city(c)
    return c, T


def _city(c):
    """Far buildings round the course, so the roofs sit in a city."""
    x0, z0, x1, z1 = c.extent
    g = c.group("FarCity", "Scenery")
    import random
    rnd = random.Random(7)
    for i in range(70):
        side = i % 4
        t = rnd.random()
        if side == 0:
            x, z = x0 - 60 - rnd.random() * 50, z0 - 40 + t * (z1 - z0 + 80)
        elif side == 1:
            x, z = x1 + 60 + rnd.random() * 50, z0 - 40 + t * (z1 - z0 + 80)
        elif side == 2:
            x, z = x0 - 40 + t * (x1 - x0 + 80), z0 - 60 - rnd.random() * 50
        else:
            x, z = x0 - 40 + t * (x1 - x0 + 80), z1 + 60 + rnd.random() * 50
        hgt = 20 + rnd.random() * 70
        wid = 14 + rnd.random() * 20
        c.world_block(g, "Tower", (x, Rooftops.STREET + hgt / 2, z), (wid, hgt, wid * (0.7 + rnd.random() * 0.6)),
                "far_city" if rnd.random() < 0.5 else "far_city_b", solid=False)
    c.world_block(g, "Street", ((x0 + x1) / 2, Rooftops.STREET - 0.5, (z0 + z1) / 2), (x1 - x0 + 500, 1, z1 - z0 + 500), "street", solid=False)


def foundry():
    T = Foundry()
    c = Course("Foundry", None, env_block((0.05, 0.06, 0.1), (0.22, 0.16, 0.14), (0.08, 0.06, 0.05),
                                              (0.6, 0.55, 0.6), 0.75, fog=((0.4, 0.22, 0.12), 0.006, 0.1)),
               (sun_rows(38, 140), (0.75, 0.8, 1.0), 0.55), (0, 0, 0))
    c.settings["face_shade"] = "Vector3(0.9, 0.8, 0.6)"
    S.start(c, T)
    c.sign(-4, 5.5, 0, "FOUNDRY", 140, (1, 0.6, 0.3, 1))
    S.vaults(c, T, 3)
    S.slide_under(c, T, 8)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "MOLTEN POOL", 90)
    S.pistons(c, T, 4)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "PRESS ROW", 90)
    S.presses(c, T, 3)
    S.turn(c, T, right=True)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "TANK FARM", 90)
    S.wallrun(c, T, side=1, panels=2)
    c.sign(2, 4, 0, "ROCKET GAP: JUMP + E", 70, JET)
    S.boost_gap(c, T, 19.0, land=18)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "FURNACE STACK", 90)
    S.chimney(c, T, 9.0, side=-1)
    c.sign(4, 3.5, 0, "BOOST UP: JUMP + E", 60, JET)
    S.boost_wall(c, T, 7.0)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "CASTING HALL", 90)
    S.grapple_swing(c, T, [(10, 11.0), (30, 12.0)], land_gap=8)
    S.sweepers(c, T, 2)
    S.turn(c, T, right=True)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "STAMPING LINE", 90)
    S.belly_chute(c, T, 22, -6)
    S.presses(c, T, 4)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "SLAG LAKE", 90)
    S.pistons(c, T, 3)
    c.sign(2, 4, 0, "SLIDE, JUMP, FLOAT: SHIFT", 60, JET)
    S.ski_jump(c, T)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "BOILER WALL", 90)
    S.wallrun(c, T, side=-1, panels=2)
    S.vaults(c, T, 2)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "PIPE AND CHUTE", 90)
    S.slope(c, T, 24, -9, slide=True)
    c.sign(2, 4, 0, "CRANE FLING: LET GO + E", 60, JET)
    S.grapple_swing(c, T, [(12, 13.0)], land_gap=18, boost=True)
    S.strips(c, T, 3)
    S.finish(c, T)
    _hall(c)
    return c, T


def _hall(c):
    """The mill round the course: a molten floor under everything, walls, roof trusses and lamps."""
    x0, z0, x1, z1 = c.extent
    g = c.group("Mill", "Scenery")
    pad = 26
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    wx, wz = x1 - x0 + 2 * pad, z1 - z0 + 2 * pad
    y = Foundry.FLOOR
    c.world_block(g, "MoltenFloor", (cx, y - 0.5, cz), (wx, 1.0, wz), "molten", hazard=True, solid=False)
    c.world_block(g, "Bed", (cx, y - 3, cz), (wx, 2.0, wz), "steel_dark")
    top = c.max_y + 26
    for (px, pz, sx, sz) in ((cx, z0 - pad, wx, 2), (cx, z1 + pad, wx, 2), (x0 - pad, cz, 2, wz), (x1 + pad, cz, 2, wz)):
        c.world_block(g, "Wall", (px, (y + top) / 2, pz), (sx, top - y, sz), "hall")
        c.world_block(g, "Band", (px, y + 14, pz), (sx + 0.2, 1.2, sz + 0.2), "hall_band", solid=False)
    n = int(wx / 20)
    for i in range(n + 1):
        x = x0 - pad + wx * i / n
        c.world_block(g, "Truss", (x, top - 1, cz), (1.0, 1.6, wz), "truss", solid=False)
        for j in range(3):
            z = z0 - pad + wz * (j + 1) / 4
            c.world_block(g, "Lamp", (x, top - 2.2, z), (1.2, 0.3, 1.2), "lamp", solid=False)
    import random
    rnd = random.Random(3)
    for i in range(10):
        x = x0 - pad + 6 + rnd.random() * (wx - 12)
        z = z0 - pad + 3
        c.world_block(g, "Furnace", (x, y + 7, z), (8, 14, 4), "furnace")
        c.world_block(g, "Mouth", (x, y + 3, z + 2.02), (4, 3, 0.05), "furnace_mouth", solid=False)


def sky_ruins():
    T = SkyRuins()
    c = Course("SkyRuins", None, env_block((0.22, 0.45, 0.85), (0.78, 0.88, 0.98), (0.85, 0.9, 0.96),
                                               (0.82, 0.86, 0.94), 0.95, fog=((0.85, 0.9, 0.98), 0.0025, 0.15)),
               (sun_rows(48, 210), (1.0, 0.96, 0.88), 1.1), (0, 0, 0), width=8.0)
    c.settings["face_shade"] = "Vector3(0.93, 0.84, 0.66)"
    S.start(c, T)
    c.sign(-4, 6.5, 0, "SKY RUINS", 140, (0.8, 0.95, 1, 1))
    c.sign(4, 5, 0, "STEPPING STONES", 90)
    S.gaps(c, T, [(5.0, 9), (7.0, 10)])
    c.sign(2, 4, 0, "ROCKET GAP: JUMP + E", 70, JET)
    S.boost_gap(c, T, 19.0, land=18)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "SWEEPER BRIDGE", 90)
    S.sweepers(c, T, 3)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "WALL SLABS", 90)
    S.wallrun(c, T, side=1, panels=2)
    S.turn(c, T, right=False)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "RING ARCHES", 90)
    S.grapple_swing(c, T, [(10, 12.0), (30, 13.0)], land_gap=8)
    S.strips(c, T, 3)
    S.gaps(c, T, [(6.0, 10)])
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "SUNKEN TEMPLE", 90)
    S.slide_under(c, T, 8)
    S.belly_chute(c, T, 22, -6)
    S.vaults(c, T, 2)
    S.turn(c, T, right=False)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "THE SPIRE", 90)
    S.climb(c, T, [2.2])
    c.sign(4, 3.5, 0, "BOOST UP: JUMP + E", 60, JET)
    S.boost_wall(c, T, 7.0)
    S.chimney(c, T, 9.0)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "HIGH WINDS", 90)
    S.wallrun(c, T, side=-1, panels=2)
    S.run(c, T, 8)
    c.sign(2, 4, 0, "SLIDE, JUMP, FLOAT: SHIFT", 60, JET)
    S.ski_jump(c, T)
    S.sweepers(c, T, 2)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "DROP AND DASH", 90)
    S.slope(c, T, 26, -10, slide=True)
    S.run(c, T, 12)   # room to slow down: the pistons want a standing start
    S.pistons(c, T, 3)
    c.sign(2, 4, 0, "FLOAT, THEN E", 70, JET)
    S.float_gap(c, T, 40.0, -6.0, land=16, boost=True)
    S.finish(c, T)
    _clouds(c)
    return c, T


def _clouds(c):
    x0, z0, x1, z1 = c.extent
    g = c.group("Clouds", "Scenery")
    import random
    rnd = random.Random(11)
    for i in range(60):
        x = x0 - 80 + rnd.random() * (x1 - x0 + 160)
        z = z0 - 80 + rnd.random() * (z1 - z0 + 160)
        y = c.min_y - 40 - rnd.random() * 20
        s = 20 + rnd.random() * 35
        c.world_block(g, "Cloud", (x, y, z), (s, 3 + rnd.random() * 4, s * (0.5 + rnd.random() * 0.6)), "cloud", solid=False)
    for i in range(14):   # far floating rocks
        x = x0 - 70 + rnd.random() * (x1 - x0 + 140)
        z = z0 - 70 + rnd.random() * (z1 - z0 + 140)
        if x0 - 15 < x < x1 + 15 and z0 - 15 < z < z1 + 15:
            continue
        y = c.min_y + rnd.random() * 30
        s = 6 + rnd.random() * 14
        c.world_block(g, "FarIsle", (x, y, z), (s, 2, s * 0.8), "grass", solid=False)
        c.world_block(g, "FarRock", (x, y - 4, z), (s * 0.75, 6, s * 0.6), "stone_dark", solid=False)


def summit_plunge():
    """Down a big snowy mountain: slide the slopes, boost the crevasses, belly-slide the ice
    tunnels, swing the gorge on the rock arches and float the cliffs, to the lodge below."""
    T = Snow()
    c = Course("SummitPlunge", None, env_block((0.18, 0.4, 0.82), (0.86, 0.92, 1.0), (0.78, 0.84, 0.92),
                                                   (0.8, 0.86, 0.96), 0.9, fog=((0.84, 0.9, 0.98), 0.0009, 0.1)),
               (sun_rows(30, 200), (1.0, 0.95, 0.86), 1.25), (0, 0, 0), width=10.0)
    c.settings["face_shade"] = "Vector3(0.95, 0.86, 0.7)"
    S.start(c, T)
    c.sign(-4, 6, 0, "SUMMIT PLUNGE", 140, (0.85, 0.95, 1, 1))
    c.sign(6, 4.5, 0, "DROP IN: CROUCH TO SLIDE", 60, JET)
    S.slope(c, T, 30, -12, slide=True)
    S.gaps(c, T, [(6.0, 10, -1.5), (8.0, 12, -2.0)])
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "THE CREVASSE", 90)
    c.sign(9, 3.5, 0, "JUMP + E", 70, JET)
    S.boost_gap(c, T, 20.0, land=20, dy=-3.0)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "ICE TUNNEL", 90)
    c.sign(9, 3.5, 0, "DIVE IN: HOLD Q", 60, JET)
    S.belly_chute(c, T, 30, -10)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "ICE WALLS", 90)
    S.wallrun(c, T, side=1, panels=2)
    S.strips(c, T, 2)
    S.turn(c, T, right=True)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "SKI JUMP", 90)
    S.slope(c, T, 24, -9, slide=True)
    c.sign(2, 4, 0, "SLIDE, JUMP, FLOAT: SHIFT", 60, JET)
    S.ski_jump(c, T, L=20, dy=-8)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "THE GORGE", 90)
    S.grapple_swing(c, T, [(10, 11.0), (30, 12.0)], land_gap=8, dy=-3.0)
    S.sweepers(c, T, 2)
    S.turn(c, T, right=False)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "ICEFALL", 90)
    S.belly_chute(c, T, 26, -9)
    S.slope(c, T, 20, -7, slide=True)
    S.run(c, T, 10)
    c.sign(2, 4, 0, "FLOAT, THEN E", 70, JET)
    S.float_gap(c, T, 40.0, -8.0, land=18, boost=True)
    S.checkpoint(c, T)
    c.sign(4, 5, 0, "LAST RUN", 90)
    S.slope(c, T, 36, -14, slide=True)
    S.run(c, T, 10)
    c.sign(2, 4, 0, "SWING, LET GO + E", 60, JET)
    S.grapple_swing(c, T, [(12, 13.0)], land_gap=18, dy=-6.0, boost=True)
    S.gaps(c, T, [(9.0, 12, -2.0)])
    S.finish(c, T)
    _mountain(c)
    return c, T


def _mountain(c):
    """The rest of the range: far peaks round the course, and the valley floor below."""
    import random
    rnd = random.Random(5)
    x0, z0, x1, z1 = c.extent
    g = c.group("Range", "Scenery")
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    floor_y = c.min_y - 60
    c.world_block(g, "Valley", (cx, floor_y - 1, cz), (x1 - x0 + 900, 2, z1 - z0 + 900), "valley", solid=False)

    def peak(x, z, size, base_y, kind="far_peak"):
        # A cube stood on a corner, half buried: a sharp peak. A smaller white one on top is its snow.
        a, b = math.radians(45), math.atan(1 / math.sqrt(2))
        ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
        yaw = rnd.random() * math.pi
        cy, sy = math.cos(yaw), math.sin(yaw)
        # Rx(b) * Ry(a): a vertex up; then turned about y.
        X = (ca, sa * sb, -sa * cb)
        Y = (0.0, cb, sb)
        Z = (sa, -ca * sb, ca * cb)
        def turn(v):
            return (v[0] * cy + v[2] * sy, v[1], -v[0] * sy + v[2] * cy)
        cols = (turn(X), turn(Y), turn(Z))
        half = size * math.sqrt(3) / 2
        c.block(g, "Peak", (x, base_y, z), (size, size, size), kind, cols=cols, solid=False)
        cap = size * 0.42
        c.block(g, "PeakSnow", (x, base_y + half - cap * math.sqrt(3) / 2 + 0.3, z), (cap, cap, cap), "far_snow",
                cols=cols, solid=False)

    # The mountain under the course: a few huge peaks along it, the start on the highest.
    pts = c.points
    for i in range(0, len(pts), max(1, len(pts) // 7)):
        p = pts[i]
        size = 90 + rnd.random() * 30
        peak(p[0] + (rnd.random() - 0.5) * 30, p[2] + (rnd.random() - 0.5) * 30, size, p[1] - 28 - size * 0.87, "rock_dark")
    for i in range(26):
        ang = i / 26 * math.tau + rnd.random() * 0.2
        rad = max(x1 - x0, z1 - z0) * 0.5 + 160 + rnd.random() * 140
        x, z = cx + math.cos(ang) * rad, cz + math.sin(ang) * rad
        size = 120 + rnd.random() * 120
        peak(x, z, size, floor_y + size * 0.15)


def lab():
    """A test strip of the newer sections, for tuning them (not a real map)."""
    T = Foundry()
    c = Course("RaceLab", None, env_block((0.3, 0.46, 0.75), (0.8, 0.8, 0.8), (0.4, 0.35, 0.32), (0.86, 0.78, 0.72), 0.85),
               (sun_rows(40, 235), (1.0, 0.95, 0.9), 1.0), (0, 0, 0))
    import json
    spec = json.loads(os.environ.get("LAB", "[]"))
    S.start(c, T)
    for name, kw in spec:
        getattr(S, name)(c, T, **kw)
        S.checkpoint(c, T)
    S.finish(c, T)
    return c, T


MAPS = {"rooftop_run": rooftop_run, "foundry": foundry, "sky_ruins": sky_ruins, "summit_plunge": summit_plunge}
EXTRA = {"race_lab": lab}


def main(names):
    for name in names or MAPS:
        c, T = {**MAPS, **EXTRA}[name]()
        T.colors = {"jet": (0.25, 0.85, 1.0), **T.colors}
        T.glow = {"jet": 1.6, **T.glow}
        pal = "res://game/maps/palettes/%s.tres" % name
        write_palette(os.path.join(ROOT, "game/maps/palettes/%s.tres" % name), T.colors, T.glow)
        c.write(os.path.join(ROOT, "game/maps/%s.tscn" % name), pal)
        print("%s: %d nodes, %d gates, %d route points, extent %s, heights %.1f..%.1f" % (
            name, len(c.nodes), c.gate_count, len(c.points), [round(v) for v in c.extent], c.min_y, c.max_y))


if __name__ == "__main__":
    main(sys.argv[1:])
