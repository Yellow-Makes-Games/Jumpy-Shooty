extends SceneTree
## Writes the sky engine's presets (SkyPreset, game/maps/sky/sky_preset.gd):
##  - the base looks, game/maps/sky/presets/<name>.tres
##  - each map's tuned copy of one, game/maps/sky/maps/<map>.tres
##  - the second looks map events blend to, game/maps/sky/maps/<map>_<look>.tres
##
##   godot --headless --path . --script tools/sky/make_sky_presets.gd [-- --force]
##
## A file that is already there is left alone (it may have been tuned in the editor
## since), unless --force. To start a new map's sky: add a line to MAPS (its base look
## and what to change), run this, and set the map's Sky to the new file.

const BASE_DIR := "res://game/maps/sky/presets/"
const MAP_DIR := "res://game/maps/sky/maps/"

var _force := false


## A colour given as the numbers a shader works in (linear), as the colour picker shows it.
static func L(r: float, g: float, b: float) -> Color:
	return Color(r, g, b).linear_to_srgb()


static func C(hex: String) -> Color:
	return Color(hex)


## The lighting flags all off: the map keeps its own sun, ambient light and fog.
const KEEP_LIGHTING := {"light_sun": false, "light_ambient": false, "light_fog": false}


func base_looks() -> Dictionary:
	return {
		"clear_day": {
			"zenith_color": C("#3f86e0"), "sky_color": C("#79b4f0"), "horizon_color": C("#d2e6f8"),
			"horizon_band": 0.22, "zenith_start": 0.04, "zenith_end": 0.85, "zenith_power": 0.75,
			"ground_color": C("#9aa39c"),
			"sun_color": C("#fff6e4"), "sun_disc": 2.5, "sun_radius": 0.038, "sun_glow": 0.22, "sun_glow_power": 12.0,
			"sun_core": 0.6, "sun_core_power": 200.0,
			"puff_amount": 0.7, "puff_color": C("#ffffff"), "puff_shade": C("#dfe7f2"), "puff_top": 0.55,
			"haze_amount": 0.25, "haze_height": 0.08,
			"silhouette_mode": 2, "silhouette_color": C("#7f9296"), "silhouette_height": 0.045, "silhouette_haze": 0.55,
			"light_sun_color": C("#fff5e0"), "light_sun_energy": 1.0,
			"light_ambient_color": C("#bac8e6"), "light_ambient_energy": 0.65,
		},
		"golden_hour": {
			"zenith_color": C("#4f74b5"), "sky_color": C("#e3b98c"), "horizon_color": C("#ffd59a"),
			"horizon_band": 0.18, "zenith_start": 0.1, "zenith_end": 0.8, "zenith_power": 1.0,
			"ground_color": C("#8a7468"),
			"glow_color": C("#ffb070"), "glow_amount": 0.35, "glow_falloff": 9.0,
			"sun_color": C("#ffd896"), "sun_disc": 2.6, "sun_radius": 0.045, "sun_glow": 0.42, "sun_glow_power": 7.0,
			"sun_core": 0.7, "sun_core_power": 80.0,
			"streak_amount": 0.8, "streak_color": C("#fff0dc"),
			"haze_amount": 0.2, "haze_height": 0.07,
			"silhouette_mode": 3, "silhouette_color": C("#6e5866"), "silhouette_height": 0.06, "silhouette_haze": 0.55,
			"light_sun_color": C("#ffd8a0"), "light_sun_energy": 1.15,
			"light_ambient_color": C("#dcc6bc"), "light_ambient_energy": 0.7,
		},
		"hazy_overcast": {
			"zenith_color": C("#5f8bb8"), "sky_color": C("#a9b8c2"), "horizon_color": C("#e6c99e"),
			"horizon_band": 0.25, "zenith_start": 0.05, "zenith_end": 0.9, "zenith_power": 0.8,
			"ground_color": C("#a39a8c"),
			"sun_color": C("#fff0d6"), "sun_disc": 0.8, "sun_radius": 0.05, "sun_glow": 0.3, "sun_glow_power": 5.0,
			"sun_core": 0.35, "sun_core_power": 40.0,
			"overcast_amount": 0.22, "overcast_color": C("#d8cdb8"),
			"haze_amount": 0.4, "haze_height": 0.06,
			"glow_color": C("#ffc98a"), "glow_amount": 0.18, "glow_falloff": 8.0,
			"puff_amount": 0.55, "puff_color": C("#f4e8d4"), "puff_shade": C("#b8aa98"), "puff_top": 0.4,
			"silhouette_mode": 1, "silhouette_color": C("#5a5654"), "silhouette_height": 0.06, "silhouette_haze": 0.35,
			"silhouette_seed": 1.0,
			"light_sun_color": C("#ffefd6"), "light_sun_energy": 0.85,
			"light_ambient_color": C("#d8d0c4"), "light_ambient_energy": 0.8,
			"light_fog_color": C("#e6dccb"), "light_fog_density": 0.0025,
		},
		"night_city": {
			"zenith_color": C("#0a0d1f"), "sky_color": C("#141a36"), "horizon_color": C("#3b2a44"),
			"horizon_band": 0.2, "zenith_start": 0.08, "zenith_end": 0.7, "zenith_power": 1.0,
			"ground_color": C("#151420"),
			"sun_disc": 0.0, "sun_glow": 0.0, "sun_core": 0.0,
			"moon_amount": 1.0, "moon_dir": Vector3(-0.35, 0.42, -0.84), "moon_radius": 0.05, "moon_phase": 0.35, "moon_glow": 0.2,
			"star_amount": 0.7, "star_density": 0.008, "star_scale": 170.0, "star_fade": 0.35, "star_twinkle": 0.4,
			"city_glow": 0.55, "city_glow_color": C("#ff9a5c"),
			"silhouette_mode": 1, "silhouette_color": C("#121526"), "silhouette_height": 0.075, "silhouette_haze": 0.12,
			"silhouette_lights": 1.4, "silhouette_light_color": C("#ffd79a"), "silhouette_seed": 3.0,
			"light_sun_color": C("#a9b8ff"), "light_sun_energy": 0.5,
			"light_ambient_color": C("#8c86b8"), "light_ambient_energy": 0.7,
		},
		"deep_space": {
			"zenith_color": C("#04060d"), "sky_color": C("#04060d"), "horizon_color": C("#04060d"),
			"floor_mode": 3,
			"sun_color": C("#fff8ec"), "sun_disc": 2.0, "sun_radius": 0.022, "sun_glow": 0.12, "sun_glow_power": 30.0,
			"sun_core": 0.4, "sun_core_power": 300.0,
			"star_amount": 1.2, "star_density": 0.016, "star_scale": 190.0, "star_twinkle": 0.3,
			"nebula_amount": 0.8, "nebula_color_a": C("#5c3a7c"), "nebula_color_b": C("#2a5c70"), "nebula_scale": 1.8,
			"light_sun_color": C("#f2f4ff"), "light_sun_energy": 1.1,
			"light_ambient_color": C("#7c84a8"), "light_ambient_energy": 0.6,
		},
		"planet_orbit": {
			"zenith_color": C("#05070f"), "sky_color": C("#05070f"), "horizon_color": C("#070a16"),
			"floor_mode": 3,
			"sun_color": C("#fff6e6"), "sun_disc": 2.0, "sun_radius": 0.025, "sun_glow": 0.12, "sun_glow_power": 30.0,
			"sun_core": 0.4, "sun_core_power": 300.0,
			"star_amount": 0.9, "star_density": 0.014, "star_scale": 180.0,
			"nebula_amount": 0.35, "nebula_color_a": C("#4c3a7a"), "nebula_color_b": C("#2a5a6e"),
			"planet_amount": 1.0, "planet_dir": Vector3(-0.5, 0.24, 0.83), "planet_radius": 0.5, "planet_style": 0,
			"planet_color_a": C("#6c9cc0"), "planet_color_b": C("#c4dcea"), "planet_color_c": C("#8a76b8"),
			"planet_ambient": 0.06, "planet_wrap": 0.15, "planet_tilt": 0.4, "planet_spin": 0.003,
			"ring_amount": 1.0, "ring_color": C("#e6e2f2"),
			"moon_amount": 1.0, "moon_dir": Vector3(0.55, 0.45, 0.7), "moon_radius": 0.045, "moon_color": C("#d6d2cc"), "moon_phase": -0.3, "moon_glow": 0.05,
			"light_sun_color": C("#fff4e6"), "light_sun_energy": 1.15,
			"light_ambient_color": C("#8a96b4"), "light_ambient_energy": 0.6,
		},
		"psychedelic": {
			"zenith_color": C("#2a1640"), "sky_color": C("#3b1e52"), "horizon_color": C("#4a2a5c"),
			"floor_mode": 3,
			"sun_disc": 0.0, "sun_glow": 0.0, "sun_core": 0.0,
			"psy_amount": 0.75, "psy_speed": 0.7, "psy_segments": 6.0, "psy_scale": 1.0, "psy_hue_drift": 1.0,
			"psy_color_a": C("#b8379c"), "psy_color_b": C("#2a9ab8"), "psy_color_c": C("#d9a03a"),
			"star_amount": 0.4, "star_density": 0.01,
			"horizon_cap": 1.1,
			"light_sun_color": C("#ffe8ff"), "light_sun_energy": 0.9,
			"light_ambient_color": C("#cbb4e0"), "light_ambient_energy": 0.75,
		},
		"surreal_dream": {
			"zenith_color": C("#6a5cb4"), "sky_color": C("#c6a0d6"), "horizon_color": C("#ffd8d0"),
			"horizon_band": 0.2, "zenith_start": 0.05, "zenith_end": 0.6, "zenith_power": 1.0,
			"sun_color": C("#ffe6c4"), "sun_disc": 2.2, "sun_radius": 0.05, "sun_glow": 0.3, "sun_glow_power": 8.0,
			"sun2_amount": 1.0, "sun2_dir": Vector3(0.62, 0.22, -0.75), "sun2_color": C("#9ee4ff"),
			"shapes_amount": 1.0, "shapes_color": C("#f6eeff"),
			"mirror_amount": 0.9, "mirror_line": 0.72, "mirror_color": C("#b49cd6"),
			"glow_color": C("#ffe0f0"), "glow_amount": 0.15,
			"orbit_amount": 0.6, "orbit_color": C("#fff1dc"),
			"streak_amount": 0.4, "streak_color": C("#fff4fa"),
			"floor_mode": 1, "sea_height": -30.0, "sea_lit": C("#fff0f4"), "sea_shade": C("#bca6dc"),
			"silhouette_mode": 3, "silhouette_color": C("#8e78b4"), "silhouette_height": 0.05, "silhouette_haze": 0.5,
			"light_sun_color": C("#ffeedc"), "light_sun_energy": 1.0,
			"light_ambient_color": C("#dccbf0"), "light_ambient_energy": 0.7,
		},
		# Abstract silk (the Silk layer): folded colour all round, no sun disc, nothing else.
		"ember": _silk(0, "#2a1030", "#4a1c48", ["#ff8a3c", "#ff8a9e", "#ffc857", "#c0487a"],
			{"silk_count": 4.0, "silk_tilt": 0.25, "silk_sheen": 0.8, "silk_shadow": 0.95, "sun_color": C("#ffd2a0"),
			"light_sun_color": C("#ffd8b4"), "light_sun_energy": 1.0, "light_ambient_color": C("#dcbcc8"), "light_ambient_energy": 0.72}),
		"ember_dark": _silk(0, "#0e040e", "#220a24", ["#9a3e16", "#8e2e52", "#9a6418", "#48143a"],
			{"silk_count": 4.0, "silk_tilt": 0.25, "silk_sheen": 0.3, "silk_edge_glow": 0.6, "sky_energy": 0.8,
			"silk_edge_color": C("#ffb066"), "silk_edge_color_b": C("#ff8ab4"), "sun_color": C("#ffb880"),
			"light_sun_color": C("#ffc09a"), "light_sun_energy": 0.7, "light_ambient_color": C("#9a7290"), "light_ambient_energy": 0.62}),
		"tide": _silk(1, "#0d1640", "#1b2a6b", ["#2f6fe0", "#1fb3b8", "#6a5ad8", "#3aa0e8"],
			{"silk_count": 5.0, "silk_tilt": 0.12, "silk_sheen": 0.55, "sun_color": C("#d8ecff"),
			"light_sun_color": C("#e4f2ff"), "light_sun_energy": 1.0, "light_ambient_color": C("#aec4ea"), "light_ambient_energy": 0.72}),
		"tide_dark": _silk(1, "#040818", "#070c26", ["#173a8a", "#0d6a72", "#36287a", "#1a5490"],
			{"silk_count": 5.0, "silk_tilt": 0.12, "silk_sheen": 0.4, "silk_edge_glow": 0.5,
			"silk_edge_color": C("#5ce8ff"), "silk_edge_color_b": C("#9a8aff"), "sun_color": C("#a8c8ff"),
			"light_sun_color": C("#bcd2ff"), "light_sun_energy": 0.62, "light_ambient_color": C("#5e6ea4"), "light_ambient_energy": 0.62}),
		"sorbet": _silk(2, "#e6cfe0", "#d6dcf2", ["#ffa98a", "#b296f0", "#86e2c0", "#88c2ff"],
			{"silk_count": 4.0, "silk_scale": 0.85, "silk_sheen": 0.5, "silk_shadow": 0.5, "sun_color": C("#fff2e6"), "horizon_cap": 2.0,
			"light_sun_color": C("#fff2e8"), "light_sun_energy": 1.0, "light_ambient_color": C("#e6def2"), "light_ambient_energy": 0.82}),
		"sorbet_dark": _silk(2, "#1a1628", "#262038", ["#b8705a", "#6e52a8", "#3c9078", "#3c6ea8"],
			{"silk_count": 4.0, "silk_sheen": 0.45, "silk_shadow": 0.4, "sun_color": C("#e6d6ff"),
			"light_sun_color": C("#e2d4ff"), "light_sun_energy": 0.62, "light_ambient_color": C("#7c709c"), "light_ambient_energy": 0.62}),
		"abyss": _silk(0, "#141c4a", "#24327a", ["#3a5ad0", "#7a3ab8", "#2a7ad0", "#5a3ac0"],
			{"silk_count": 5.0, "silk_tilt": 0.3, "silk_scale": 0.85, "silk_sheen": 0.55, "silk_edge_glow": 0.5,
			"silk_edge_color": C("#4af0ff"), "silk_edge_color_b": C("#ff5ae6"), "sun_color": C("#c8d8ff"),
			"light_sun_color": C("#d0dcff"), "light_sun_energy": 0.9, "light_ambient_color": C("#8a90c8"), "light_ambient_energy": 0.7}),
		"abyss_dark": _silk(0, "#02030c", "#050822", ["#10183e", "#2a0e3a", "#0a1c40", "#1c0e44"],
			{"silk_count": 5.0, "silk_tilt": 0.3, "silk_scale": 0.85, "silk_sheen": 0.45, "silk_edge_glow": 1.0,
			"silk_edge_color": C("#4af0ff"), "silk_edge_color_b": C("#ff5ae6"), "sun_color": C("#a0b4ff"),
			"light_sun_color": C("#aebcff"), "light_sun_energy": 0.55, "light_ambient_color": C("#565c94"), "light_ambient_energy": 0.6}),
	}


## A Silk look: style (0 ribbons, 1 waves, 2 colour fields), the colours low and high
## behind it, its four colours, and the rest.
static func _silk(style: int, base: String, top: String, colours: Array, more: Dictionary) -> Dictionary:
	var out := {
		"floor_mode": 3, "silk_amount": 1.0, "silk_style": style, "silk_seed": float(style) + colours.size(),
		"silk_base": C(base), "silk_base_top": C(top), "horizon_color": C(base), "sky_color": C(top), "zenith_color": C(top),
		"silk_color_a": C(colours[0]), "silk_color_b": C(colours[1]), "silk_color_c": C(colours[2]), "silk_color_d": C(colours[3]),
		"sun_disc": 0.0, "sun_glow": 0.2, "sun_glow_power": 6.0, "sun_core": 0.0,
	}
	out.merge(more, true)
	return out


## Each map: [base look, changes]. Maps whose sky was made by hand keep their own
## lighting (KEEP_LIGHTING) and rebuild that sky from the engine's layers, starting
## blank ("": every layer off).
func maps() -> Dictionary:
	var cirrus := {
		"zenith_color": L(0.3, 0.52, 0.86), "sky_color": L(0.96, 0.8, 0.56), "horizon_color": L(1.0, 0.9, 0.7),
		"horizon_band": 0.16, "zenith_start": 0.1, "zenith_end": 0.75, "zenith_power": 1.0,
		"sun_color": L(1.0, 0.93, 0.74), "sun_disc": 3.0, "sun_radius": 0.0424, "sun_glow": 0.32, "sun_glow_power": 9.0,
		"sun_core": 0.7, "sun_core_power": 90.0,
		"puff_amount": 0.0, "haze_amount": 0.0, "silhouette_mode": 0,
		"streak_amount": 1.0, "streak_color": L(1.0, 0.97, 0.9),
		"planet_amount": 1.0, "planet_dir": Vector3(-0.52, 0.2, 0.83), "planet_radius": 0.34, "planet_style": 0,
		"planet_color_a": L(0.86, 0.6, 0.42), "planet_color_b": L(0.96, 0.82, 0.62), "planet_color_c": L(0.7, 0.4, 0.36),
		"planet_haze": 1.0, "planet_haze_color": L(0.98, 0.86, 0.7), "planet_ambient": 0.25, "planet_wrap": 0.3,
		"planet_tilt": 0.347, "planet_spin": 0.002, "ring_amount": 1.0, "ring_color": L(0.98, 0.9, 0.76),
		"floor_mode": 1, "sea_height": -30.0, "sea_lit": L(1.0, 0.95, 0.84), "sea_shade": L(0.8, 0.68, 0.62), "sea_bumps": 0.34,
		"horizon_cap": 2.2,
	}
	var cirrus_sunset := cirrus.duplicate()
	cirrus_sunset.merge({
		"zenith_color": L(0.2, 0.2, 0.46), "sky_color": L(0.95, 0.42, 0.3), "horizon_color": L(1.0, 0.62, 0.3),
		"sun_color": L(1.0, 0.56, 0.24), "streak_color": L(1.0, 0.66, 0.5), "planet_haze_color": L(0.9, 0.5, 0.42),
		"sea_lit": L(1.0, 0.68, 0.5), "sea_shade": L(0.42, 0.3, 0.46),
	}, true)
	var halcyon := {
		"zenith_color": L(0.004, 0.006, 0.014), "sky_color": L(0.004, 0.006, 0.014), "horizon_color": L(0.004, 0.006, 0.014),
		"floor_mode": 3, "sun_disc": 0.0, "sun_glow": 0.0, "sun_core": 0.0,
		"star_amount": 1.0, "star_density": 0.012, "star_scale": 190.0, "star_tint_a": L(0.75, 0.85, 1.0), "star_tint_b": L(1.0, 0.92, 0.8),
		"star_twinkle": 0.25,
		"nebula_amount": 1.0, "nebula_color_a": L(0.1, 0.045, 0.16), "nebula_color_b": L(0.02, 0.085, 0.12), "nebula_scale": 2.2,
		"planet_amount": 1.0, "planet_dir": Vector3(0.16, 0.3, -0.94), "planet_radius": 0.21, "planet_style": 1,
		"planet_color_a": L(0.06, 0.24, 0.5), "planet_color_b": L(0.16, 0.42, 0.24), "planet_color_c": L(0.9, 0.94, 0.97),
		"planet_rim": L(0.2, 0.5, 0.9), "planet_ambient": 0.03, "planet_wrap": 0.12, "planet_light_dir": Vector3(0.75, 0.45, -0.3),
		"planet_spin": 0.002, "ring_amount": 0.0,
	}
	var halcyon_deep := halcyon.duplicate()
	halcyon_deep.merge({"tint_mul": Vector3(0.45, 0.7, 1.7), "tint_add": Vector3(0.0, 0.006, 0.04)}, true)
	var empyrean := {
		"zenith_color": L(0.025, 0.018, 0.06), "sky_color": L(0.34, 0.2, 0.52), "horizon_color": L(0.586, 0.332, 0.58),
		"horizon_band": 0.35, "zenith_start": 0.0, "zenith_end": 0.75, "zenith_power": 1.0,
		"floor_mode": 2, "limb": 0.06,
		"limb_color_a": L(0.05, 0.36, 0.4), "limb_color_b": L(0.34, 0.14, 0.5), "limb_color_c": L(0.16, 0.62, 0.6),
		"limb_air": L(0.38, 0.8, 0.84), "limb_air_2": L(0.6, 0.4, 0.9),
		"sun_disc": 0.0, "sun_glow": 0.0, "sun_core": 0.0,
		"star_amount": 1.0, "star_density": 0.014, "star_scale": 90.0, "star_tint_a": L(0.78, 0.8, 1.0), "star_tint_b": L(1.0, 0.86, 0.95),
		"star_fade": 0.4, "star_twinkle": 0.25,
		"aurora_amount": 1.0, "aurora_color_a": L(0.2, 0.9, 0.6), "aurora_color_b": L(0.6, 0.35, 1.0),
		"meteor_amount": 1.0, "ribbon_amount": 1.0,
	}
	var sky_island := {
		"zenith_color": L(0.05, 0.26, 0.78), "sky_color": L(0.36, 0.64, 0.97), "horizon_color": L(0.36, 0.64, 0.97),
		"horizon_band": 0.01, "zenith_start": 0.0, "zenith_end": 0.85, "zenith_power": 0.6,
		"sun_color": L(1.0, 0.95, 0.82), "sun_disc": 2.5, "sun_radius": 0.0387, "sun_glow": 0.22, "sun_glow_power": 12.0,
		"sun_core": 0.6, "sun_core_power": 200.0,
		"puff_amount": 1.0, "puff_color": L(1.0, 0.99, 0.97), "puff_shade": L(0.86, 0.9, 0.96), "puff_top": 0.6,
		"haze_amount": 0.0, "silhouette_mode": 0,
		"floor_mode": 1, "sea_height": -30.0, "sea_lit": L(1.0, 1.0, 0.98), "sea_shade": L(0.44, 0.68, 1.0), "sea_bumps": 0.42,
		"horizon_cap": 2.0, "sky_energy": 1.1,
	}
	return {
		# Made by hand before; rebuilt on the engine.
		"cirrus": ["", cirrus.merged(KEEP_LIGHTING)],
		"cirrus_sunset": ["", cirrus_sunset.merged(KEEP_LIGHTING)],
		"halcyon": ["", halcyon.merged(KEEP_LIGHTING)],
		"halcyon_deep": ["", halcyon_deep.merged(KEEP_LIGHTING)],
		"empyrean": ["", empyrean.merged(KEEP_LIGHTING)],
		"sky_island": ["", sky_island.merged(KEEP_LIGHTING)],
		# Plain skies before.
		"construction_site": ["hazy_overcast", {
			# A warm, dusty summer haze: blue overhead, never grey (the site is busy enough).
			"zenith_color": C("#3f7cc4"), "sky_color": C("#8fb0cc"), "overcast_amount": 0.1, "haze_amount": 0.32,
			"silhouette_height": 0.055, "silhouette_seed": 1.0,
			"light_sun_color": C("#fff1da"), "light_sun_energy": 0.92,
			"light_ambient_color": C("#c4c8d6"), "light_ambient_energy": 0.6,
			"light_fog": false,
		}],
		"office": ["clear_day", {
			"silhouette_mode": 1, "silhouette_color": C("#8a99a8"), "silhouette_height": 0.07, "silhouette_haze": 0.5, "silhouette_seed": 4.0,
			"light_sun_color": C("#fff5e0"), "light_sun_energy": 0.95,
			"light_ambient_color": C("#d0d8ec"), "light_ambient_energy": 0.9,
		}],
		"kilnworks": ["hazy_overcast", {
			"zenith_color": C("#9aa3ad"), "overcast_amount": 0.75, "overcast_color": C("#d4c6b2"), "horizon_color": C("#e2cdae"),
			"haze_amount": 0.7, "silhouette_color": C("#7c7168"), "silhouette_seed": 2.0,
			"light_sun_color": C("#ffeccc"), "light_sun_energy": 0.95,
			"light_ambient_color": C("#dacbb6"), "light_ambient_energy": 0.88,
			"light_fog": true, "light_fog_color": C("#d8c3a6"), "light_fog_density": 0.0035,
		}],
		"rail_yard": ["hazy_overcast", {
			"silhouette_mode": 2, "silhouette_color": C("#8c8a80"), "silhouette_height": 0.04,
			"overcast_amount": 0.45,
			"light_sun_color": C("#ffedd4"), "light_sun_energy": 1.0,
			"light_ambient_color": C("#cccdd6"), "light_ambient_energy": 0.74,
		}],
		"lost_temple": ["clear_day", {
			"horizon_color": C("#d6e8dc"), "haze_amount": 0.45, "haze_height": 0.1, "puff_amount": 0.85,
			"silhouette_color": C("#5f7a66"), "silhouette_height": 0.05, "silhouette_haze": 0.45,
			"ground_color": C("#71806a"),
			"light_sun_color": C("#ffecc8"), "light_sun_energy": 1.08,
			"light_ambient_color": C("#c0d6cc"), "light_ambient_energy": 0.66,
		}],
		"neon_arcade": ["night_city", {
			"silhouette_seed": 5.0, "city_glow_color": C("#ff7ad0"), "city_glow": 0.6, "silhouette_light_color": C("#9ee8ff"),
			"light_sun_color": C("#ffb8a0"), "light_sun_energy": 0.8,
			"light_ambient_color": C("#c4baf0"), "light_ambient_energy": 1.0,
		}],
		"haunted_house": ["night_city", {
			# Its thick fog (kept) lies over the sky too, as it always has.
			"zenith_color": C("#07081a"), "sky_color": C("#14152c"), "horizon_color": C("#2a2c44"),
			"city_glow": 0.0, "silhouette_lights": 0.0, "silhouette_mode": 2, "silhouette_color": C("#0a0a12"),
			"silhouette_height": 0.05, "silhouette_haze": 0.15,
			"moon_amount": 1.0, "moon_radius": 0.11, "moon_phase": 0.12, "moon_glow": 0.45, "moon_dir": Vector3(0.36, 0.5, -0.78),
			"moon_color": C("#e8ecff"), "star_amount": 0.9, "star_density": 0.01,
			"ground_color": C("#06060a"),
			"light_sun_color": C("#a2b4ff"), "light_sun_energy": 0.75,
			"light_ambient_color": C("#817ba8"), "light_ambient_energy": 0.62,
		}],
		"castle_v2": ["ember", {
			# Its distance fog takes the sky's warm colour, so far mountains melt into it.
			"light_fog": true, "light_fog_color": C("#d8bcaa"), "light_fog_density": 0.0012,
		}],
		"testing_grounds": ["clear_day", {
			"silhouette_mode": 0,
			"light_sun": false, "light_ambient": false,
		}],
		"rooftop_run": ["golden_hour", {
			"silhouette_mode": 1, "silhouette_color": C("#5e4c56"), "silhouette_height": 0.07, "silhouette_haze": 0.45,
			"silhouette_lights": 0.5, "silhouette_seed": 6.0, "glow_amount": 0.55, "sun_color": C("#ffc47e"),
			"horizon_color": C("#ffc489"),
			"light_sun_color": C("#ffcc94"), "light_sun_energy": 1.15,
			"light_ambient_color": C("#dcc6b8"), "light_ambient_energy": 0.82,
		}],
		"foundry": ["hazy_overcast", {
			"zenith_color": C("#14141f"), "sky_color": C("#2a2026"), "horizon_color": C("#5a3424"),
			"overcast_amount": 0.55, "overcast_color": C("#3a2c2a"), "haze_amount": 0.35,
			"glow_color": C("#ff8a3c"), "glow_amount": 0.35, "glow_falloff": 10.0,
			"sun_disc": 0.0, "sun_glow": 0.05, "sun_core": 0.0,
			"silhouette_color": C("#151215"), "silhouette_haze": 0.15, "silhouette_lights": 0.6,
			"silhouette_light_color": C("#ff9a4a"), "silhouette_seed": 7.0,
			"ground_color": C("#18120f"),
			"light_sun_color": C("#c4ccff"), "light_sun_energy": 0.55,
			"light_ambient_color": C("#9c8c96"), "light_ambient_energy": 0.75,
			"light_fog": false,
		}],
		"sky_ruins": ["clear_day", {
			"silhouette_mode": 0, "floor_mode": 1, "sea_height": -45.0, "sea_lit": C("#ffffff"), "sea_shade": C("#bcd4f2"),
			"light_sun_color": C("#fff5e0"), "light_sun_energy": 1.1,
			"light_ambient_color": C("#d0daf0"), "light_ambient_energy": 0.92,
		}],
		"summit_plunge": ["clear_day", {
			"silhouette_mode": 3, "silhouette_color": C("#a2b4cc"), "silhouette_height": 0.08, "silhouette_haze": 0.45,
			"floor_mode": 1, "sea_height": -125.0, "sea_lit": C("#ffffff"), "sea_shade": C("#c4d6ee"),
			"light_sun_color": C("#fff2db"), "light_sun_energy": 1.22,
			"light_ambient_color": C("#cad9f2"), "light_ambient_energy": 0.88,
		}],
	}


func _initialize() -> void:
	_force = "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_DIR))
	var bases := base_looks()
	for name in bases:
		_write(BASE_DIR + name + ".tres", _make(bases[name]))
	var all := maps()
	for name in all:
		var entry: Array = all[name]
		var values: Dictionary = (bases[entry[0]] as Dictionary).duplicate() if entry[0] != "" else {}
		values.merge(entry[1], true)
		_write(MAP_DIR + name + ".tres", _make(values))
	quit()


func _make(values: Dictionary) -> SkyPreset:
	var p := SkyPreset.new()
	for k in values:
		if not k in p:
			push_error("make_sky_presets: no setting called " + k)
			continue
		p.set(k, values[k])
	return p


func _write(path: String, p: SkyPreset) -> void:
	if ResourceLoader.exists(path) and not _force:
		print("kept ", path)
		return
	var err := ResourceSaver.save(p, path)
	print("wrote " if err == OK else "FAILED ", path)
