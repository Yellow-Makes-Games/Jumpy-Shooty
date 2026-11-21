class_name GraphicsQuality
extends RefCounted
## The graphics quality presets and what each setting does to the renderer. Settings
## keeps the player's picks (see Settings.graphics()); this puts them on the window,
## the renderer and each map's Environment.
##
## A map's Environment is its best look: ambient occlusion, glow and so on as the map
## was tuned. Lower settings only turn things off; they never add to a map. The first
## time a setting touches an Environment it notes the map's own values in its metadata,
## so they come back when the setting goes up again (copies made by map events keep
## that metadata).
##
## Nothing here blurs or smears the picture: no TAA or FSR 2 (both trail behind fast
## movers), no motion blur, no depth of field.

## Picks: msaa (0, 2, 4, 8), screen_aa ("off", "fxaa", "smaa"), render_scale (0.5..1),
## fsr_sharpness (0 sharpest..2 softest), shadows ("low".."ultra"), ao ("off", "on",
## "high"), glow (bool), sky_motion (bool: the moving sky; off, the sky engine shows a
## still picture of it, see SkyRig).
const PRESETS := {
	"low": {"msaa": 0, "screen_aa": "fxaa", "render_scale": 1.0, "fsr_sharpness": 0.2, "shadows": "low", "ao": "off", "glow": true, "sky_motion": false},
	"medium": {"msaa": 2, "screen_aa": "smaa", "render_scale": 1.0, "fsr_sharpness": 0.2, "shadows": "medium", "ao": "on", "glow": true, "sky_motion": true},
	"high": {"msaa": 4, "screen_aa": "smaa", "render_scale": 1.0, "fsr_sharpness": 0.2, "shadows": "high", "ao": "high", "glow": true, "sky_motion": true},
}
const QUALITY_NAMES := {"low": "Low", "medium": "Medium", "high": "High", "custom": "Custom"}

const MSAA_NAMES := {0: "Off", 2: "2x", 4: "4x", 8: "8x"}
const SCREEN_AA_NAMES := {"off": "Off", "fxaa": "FXAA (fast, a little soft)", "smaa": "SMAA (sharper)"}
const SHADOW_NAMES := {"low": "Low", "medium": "Medium", "high": "High", "ultra": "Ultra"}
const AO_NAMES := {"off": "Off", "on": "On", "high": "High (with light bounce)"}

## Shadow quality: [sun shadow map size, soft-edge filter, lamp shadow atlas size].
const SHADOWS := {
	"low": [1024, RenderingServer.SHADOW_QUALITY_HARD, 1024],
	"medium": [2048, RenderingServer.SHADOW_QUALITY_SOFT_LOW, 2048],
	"high": [4096, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, 4096],
	"ultra": [4096, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, 4096],
}

const MSAA := {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}
const SCREEN_AA := {"off": Viewport.SCREEN_SPACE_AA_DISABLED, "fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}

## Specular anti-aliasing: keeps shiny edges from sparkling as you move (every preset).
const ROUGHNESS_LIMIT_AMOUNT := 0.4
const ROUGHNESS_LIMIT := 0.25


static func preset(id: String) -> Dictionary:
	return (PRESETS.get(id, PRESETS.high) as Dictionary).duplicate()


## The preset these picks are exactly, or "custom".
static func matching(picks: Dictionary) -> String:
	for id in PRESETS:
		var same := true
		for k in PRESETS[id]:
			var want = PRESETS[id][k]
			var have = picks.get(k)
			if want is float:
				same = same and have != null and is_equal_approx(float(have), want)
			else:
				same = same and have == want
		if same:
			return id
	return "custom"


## The preset a computer starts on: High, or Low on integrated graphics.
static func first_launch() -> String:
	if DisplayServer.get_name() == "headless":
		return "high"
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return "low"
	return "high"


## Each pick made valid (an old or hand-edited settings file can hold anything).
static func clean(picks: Dictionary) -> Dictionary:
	var out := preset("high")
	var m := int(picks.get("msaa", out.msaa))
	out.msaa = m if MSAA.has(m) else out.msaa
	var s := str(picks.get("screen_aa", out.screen_aa))
	out.screen_aa = s if SCREEN_AA.has(s) else out.screen_aa
	out.render_scale = clampf(float(picks.get("render_scale", out.render_scale)), 0.5, 1.0)
	out.fsr_sharpness = clampf(float(picks.get("fsr_sharpness", out.fsr_sharpness)), 0.0, 2.0)
	var sh := str(picks.get("shadows", out.shadows))
	out.shadows = sh if SHADOWS.has(sh) else out.shadows
	var a := str(picks.get("ao", out.ao))
	out.ao = a if AO_NAMES.has(a) else out.ao
	out.glow = bool(picks.get("glow", out.glow))
	out.sky_motion = bool(picks.get("sky_motion", out.sky_motion))
	return out


## Anti-aliasing and debanding on a viewport (the game window, or the killcam's).
## `scale`: how much of the screen's resolution 3D is drawn at before this setting's
## own render scale (the fullscreen Resolution setting); < 0 leaves scaling alone.
static func apply_viewport(view: Viewport, picks: Dictionary, scale: float = 1.0) -> void:
	view.msaa_3d = MSAA.get(int(picks.msaa), Viewport.MSAA_4X)
	view.screen_space_aa = SCREEN_AA.get(str(picks.screen_aa), Viewport.SCREEN_SPACE_AA_SMAA)
	view.use_debanding = true
	if scale >= 0.0:
		var total := clampf(scale * float(picks.render_scale), 0.25, 1.0)
		view.scaling_3d_scale = total
		# FSR 1 sharpens what it stretches; at full size there is nothing to stretch.
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if total < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		view.fsr_sharpness = float(picks.fsr_sharpness)
	var shadow: Array = SHADOWS.get(str(picks.shadows), SHADOWS.high)
	view.positional_shadow_atlas_size = shadow[2]


## Settings the renderer keeps for every viewport: shadow detail, ambient occlusion
## quality, specular anti-aliasing.
static func apply_global(picks: Dictionary) -> void:
	var shadow: Array = SHADOWS.get(str(picks.shadows), SHADOWS.high)
	RenderingServer.directional_shadow_atlas_set_size(shadow[0], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow[1])
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow[1])
	RenderingServer.screen_space_roughness_limiter_set_active(true, ROUGHNESS_LIMIT_AMOUNT, ROUGHNESS_LIMIT)
	var high := str(picks.ao) == "high"
	# Full resolution: at half size the shading steps into blocks along edges.
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if high else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, false, 0.5, 3, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, false, 0.5, 4, 50.0, 300.0)


## A map's Environment with these picks: what the map has, minus what the picks turn off.
## Light bounce (SSIL) only comes with "high", and only where the map has AO.
static func apply_environment(env: Environment, picks: Dictionary) -> void:
	if env == null:
		return
	if not env.has_meta("gq_ssao"):
		env.set_meta("gq_ssao", env.ssao_enabled)
		env.set_meta("gq_ssil", env.ssil_enabled)
		env.set_meta("gq_glow", env.glow_enabled)
	var ao := str(picks.ao)
	var map_ao: bool = env.get_meta("gq_ssao")
	env.ssao_enabled = map_ao and ao != "off"
	env.ssil_enabled = (map_ao or env.get_meta("gq_ssil")) and ao == "high"
	env.glow_enabled = env.get_meta("gq_glow") and bool(picks.glow)


## Every WorldEnvironment under `node` (a map, or the whole tree).
static func apply_environments(node: Node, picks: Dictionary) -> void:
	if node == null:
		return
	for world in node.find_children("*", "WorldEnvironment", true, false):
		apply_environment((world as WorldEnvironment).environment, picks)
	if node is WorldEnvironment:
		apply_environment((node as WorldEnvironment).environment, picks)
	if node.is_inside_tree():
		for rig in node.get_tree().get_nodes_in_group(SkyRig.GROUP):
			if node == rig or node.is_ancestor_of(rig):
				(rig as SkyRig).motion = bool(picks.get("sky_motion", true))
