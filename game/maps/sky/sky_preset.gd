@tool
class_name SkyPreset
extends Resource
## One look for the sky engine (game/maps/sky/sky_engine.gdshaderinc): which layers are
## on and how each is tuned, plus the lighting that goes with it. A map points at one
## (MapRoot.sky) and SkyRig draws it.
##
## The base looks are in game/maps/sky/presets/ (Clear Day, Golden Hour, ...). Each map
## has its own tuned copy in game/maps/sky/maps/, made from a base look by
## tools/sky/make_sky_presets.gd. Open one in the inspector and drag the sliders: an open
## map redraws as you go.
##
## Every sky setting is named after the shader uniform it sets. Amounts of 0 switch a
## layer off. Colours are as they look in the colour picker.

# -- Gradient --
@export_group("Gradient")
@export var zenith_color := Color(0.35, 0.58, 0.88)
@export var sky_color := Color(0.58, 0.77, 0.95)
@export var horizon_color := Color(0.88, 0.93, 0.98)
@export_range(0.0, 1.0) var horizon_band := 0.16
@export_range(0.0, 1.0) var zenith_start := 0.1
@export_range(0.0, 1.0) var zenith_end := 0.75
@export_range(0.2, 3.0) var zenith_power := 1.0
@export var ground_color := Color(0.62, 0.63, 0.65)
@export_range(0.0, 3.0) var sky_energy := 1.0
@export var glow_color := Color(1.0, 0.85, 0.66)
@export_range(0.0, 2.0) var glow_amount := 0.0
@export_range(1.0, 60.0) var glow_falloff := 12.0

@export_group("Sun")
@export var sun_color := Color(1.0, 0.98, 0.92)
@export_range(0.0, 5.0) var sun_disc := 2.5
@export_range(0.005, 0.2) var sun_radius := 0.04
@export_range(0.0, 2.0) var sun_glow := 0.22
@export_range(1.0, 60.0) var sun_glow_power := 12.0
@export_range(0.0, 2.0) var sun_core := 0.6
@export_range(10.0, 600.0) var sun_core_power := 200.0

@export_group("Moon")
@export_range(0.0, 1.0) var moon_amount := 0.0
@export var moon_dir := Vector3(-0.4, 0.5, -0.75)
@export_range(0.01, 0.3) var moon_radius := 0.06
@export var moon_color := Color(0.94, 0.95, 0.98)
@export_range(-1.0, 1.0) var moon_phase := 0.25
@export_range(0.0, 2.0) var moon_glow := 0.25

@export_group("Stars")
@export_range(0.0, 3.0) var star_amount := 0.0
@export_range(0.0, 0.06) var star_density := 0.012
@export_range(20.0, 400.0) var star_scale := 190.0
@export var star_tint_a := Color(0.95, 0.97, 1.0)
@export var star_tint_b := Color(1.0, 0.98, 0.95)
@export_range(0.0, 1.0) var star_fade := 0.0
@export_range(0.0, 1.0) var star_twinkle := 0.3

@export_group("Nebula")
@export_range(0.0, 3.0) var nebula_amount := 0.0
@export var nebula_color_a := Color(0.35, 0.24, 0.44)
@export var nebula_color_b := Color(0.15, 0.32, 0.38)
@export_range(0.5, 8.0) var nebula_scale := 2.2

@export_group("Aurora, Meteors, Ribbon")
@export_range(0.0, 3.0) var aurora_amount := 0.0
@export var aurora_color_a := Color(0.48, 0.97, 0.8)
@export var aurora_color_b := Color(0.8, 0.63, 1.0)
@export_range(0.0, 2.0) var meteor_amount := 0.0
@export_range(0.0, 2.0) var ribbon_amount := 0.0

@export_group("Clouds")
@export_range(0.0, 1.0) var streak_amount := 0.0
@export var streak_color := Color(1.0, 0.99, 0.97)
@export_range(0.0, 1.0) var puff_amount := 0.0
@export var puff_color := Color(1.0, 1.0, 0.99)
@export var puff_shade := Color(0.9, 0.92, 0.95)
@export_range(0.1, 1.0) var puff_top := 0.6
@export_range(0.0, 1.0) var overcast_amount := 0.0
@export var overcast_color := Color(0.89, 0.88, 0.86)
@export_range(0.0, 1.0) var haze_amount := 0.0
@export_range(0.01, 0.5) var haze_height := 0.12

@export_group("Planet")
@export_range(0.0, 1.0) var planet_amount := 0.0
@export var planet_dir := Vector3(-0.52, 0.2, 0.83)
@export_range(0.02, 0.8) var planet_radius := 0.34
## 0 banded (a gas giant), 1 seas, land and cloud.
@export_enum("Banded", "Seas and land") var planet_style := 0
@export var planet_color_a := Color(0.93, 0.79, 0.68)
@export var planet_color_b := Color(0.98, 0.92, 0.82)
@export var planet_color_c := Color(0.86, 0.67, 0.64)
@export var planet_rim := Color(0.48, 0.74, 0.95)
@export_range(0.0, 1.0) var planet_haze := 0.0
@export var planet_haze_color := Color(0.99, 0.94, 0.86)
@export_range(0.0, 1.0) var planet_ambient := 0.25
@export_range(0.0, 1.0) var planet_wrap := 0.35
## What lights the planet; zero means the sun.
@export var planet_light_dir := Vector3.ZERO
@export_range(-1.5, 1.5) var planet_tilt := 0.35
@export_range(0.0, 1.0) var ring_amount := 0.0
@export var ring_color := Color(0.99, 0.95, 0.88)
@export_range(0.0, 0.05) var planet_spin := 0.004

@export_group("Below the Horizon")
## Ground, a sea of cloud, a planet seen from low orbit, or open space all round.
@export_enum("Ground", "Cloud sea", "Planet below", "Open space") var floor_mode := 0
@export var sea_height := -30.0
@export var sea_lit := Color(1.0, 1.0, 0.99)
@export var sea_shade := Color(0.7, 0.85, 1.0)
@export_range(0.0, 1.0) var sea_churn := 0.0
@export_range(0.2, 0.6) var sea_bumps := 0.36
@export_range(-0.5, 0.5) var limb := 0.06
@export var limb_color_a := Color(0.25, 0.63, 0.67)
@export var limb_color_b := Color(0.62, 0.41, 0.74)
@export var limb_color_c := Color(0.44, 0.81, 0.79)
@export var limb_air := Color(0.6, 0.89, 0.92)
@export var limb_air_2 := Color(0.74, 0.58, 0.9)

@export_group("Silhouettes")
@export_enum("None", "City skyline", "Hills", "Mountains") var silhouette_mode := 0
@export var silhouette_color := Color(0.62, 0.64, 0.68)
@export_range(0.0, 0.25) var silhouette_height := 0.06
@export_range(0.0, 1.0) var silhouette_haze := 0.35
@export_range(0.0, 3.0) var silhouette_lights := 0.0
@export var silhouette_light_color := Color(1.0, 0.92, 0.74)
@export var silhouette_seed := 0.0
@export_range(0.0, 2.0) var city_glow := 0.0
@export var city_glow_color := Color(1.0, 0.8, 0.62)

@export_group("Psychedelic")
@export_range(0.0, 1.0) var psy_amount := 0.0
@export_range(0.0, 4.0) var psy_speed := 1.0
@export_range(1.0, 16.0) var psy_segments := 6.0
@export_range(0.2, 4.0) var psy_scale := 1.4
@export_range(0.0, 4.0) var psy_hue_drift := 1.0
@export var psy_color_a := Color(0.99, 0.62, 0.9)
@export var psy_color_b := Color(0.58, 0.93, 0.98)
@export var psy_color_c := Color(1.0, 0.92, 0.58)

@export_group("Silk")
@export_range(0.0, 1.0) var silk_amount := 0.0
## Folded ribbons, layered waves or blurred colour fields.
@export_enum("Ribbons", "Waves", "Colour fields") var silk_style := 0
@export var silk_base := Color(0.38, 0.31, 0.49)
@export var silk_base_top := Color(0.54, 0.42, 0.63)
@export var silk_color_a := Color(1.0, 0.77, 0.54)
@export var silk_color_b := Color(1.0, 0.67, 0.7)
@export var silk_color_c := Color(1.0, 0.91, 0.67)
@export var silk_color_d := Color(0.8, 0.58, 0.8)
@export_range(1.0, 5.0, 1.0) var silk_count := 4.0
@export_range(0.3, 2.0) var silk_scale := 1.0
@export_range(-0.6, 0.6) var silk_tilt := 0.25
@export_range(0.0, 4.0) var silk_speed := 1.0
@export_range(0.0, 2.0) var silk_sheen := 0.6
@export_range(0.0, 1.0) var silk_shadow := 0.6
@export_range(0.0, 2.0) var silk_edge_glow := 0.0
@export var silk_edge_color := Color(0.67, 0.95, 1.0)
@export var silk_edge_color_b := Color(0.95, 0.63, 0.95)
@export var silk_seed := 0.0

@export_group("Surreal")
@export_range(0.0, 1.0) var sun2_amount := 0.0
@export var sun2_dir := Vector3(0.6, 0.25, -0.75)
@export var sun2_color := Color(0.8, 0.93, 1.0)
@export_range(0.0, 1.0) var shapes_amount := 0.0
@export var shapes_color := Color(0.97, 0.94, 1.0)
@export_range(0.0, 1.0) var mirror_amount := 0.0
@export_range(0.2, 0.95) var mirror_line := 0.62
@export var mirror_color := Color(0.77, 0.7, 0.85)
@export_range(0.0, 1.0) var orbit_amount := 0.0
@export var orbit_color := Color(1.0, 0.97, 0.9)

@export_group("Finish")
@export var tint_mul := Vector3.ONE
@export var tint_add := Vector3.ZERO
@export_range(0.2, 4.0) var horizon_cap := 1.6

# -- The lighting that goes with this sky --
@export_group("Lighting", "light_")
## Sets the map's Sun colour and brightness (its direction is the map's own).
@export var light_sun := true
@export var light_sun_color := Color(1.0, 0.96, 0.88)
@export_range(0.0, 4.0) var light_sun_energy := 1.0
## Sets the map's ambient light.
@export var light_ambient := true
@export var light_ambient_color := Color(0.72, 0.78, 0.9)
@export_range(0.0, 4.0) var light_ambient_energy := 0.6
## Sets the map's distance fog (off leaves the map's own fog alone).
@export var light_fog := false
@export var light_fog_color := Color(0.8, 0.85, 0.92)
@export_range(0.0, 0.1, 0.0005) var light_fog_density := 0.004
@export_range(0.0, 1.0) var light_fog_sky_affect := 0.0

## Names of every sky setting (the shader uniforms), in order.
static var _names: PackedStringArray = []


## The sky settings as shader uniform values.
func params() -> Dictionary:
	var out := {}
	for n in names():
		out[n] = get(n)
	return out


static func names() -> PackedStringArray:
	if _names.is_empty():
		var probe := SkyPreset.new()
		for p in probe.get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE and not str(p.name).begins_with("light_"):
				_names.append(p.name)
	return _names


## The sky settings part of the way from `a` to `b` (0..1). Colours blend as light does;
## whole numbers (which layers are on) switch half way.
static func mix_params(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a.duplicate()
	if k >= 1.0:
		return b.duplicate()
	var out := {}
	for n in a:
		var x = a[n]
		var y = b.get(n, x)
		if x is Color:
			out[n] = (x as Color).srgb_to_linear().lerp((y as Color).srgb_to_linear(), k).linear_to_srgb()
		elif x is float or x is Vector3:
			out[n] = lerp(x, y, k)
		else:
			out[n] = y if k >= 0.5 else x
	return out
