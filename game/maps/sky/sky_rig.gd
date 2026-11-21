@tool
class_name SkyRig
extends Node3D
## Draws a map's sky from its SkyPreset (MapRoot.sky). MapRoot makes one for itself; it
## is not saved in the scene.
##
## Two copies of the sky (game/maps/sky/sky_engine.gdshaderinc):
##  - the Environment's sky, a still picture. The map's lighting (ambient light and
##    reflections) is captured from it once, and again only when something changes it,
##    never more than about once a second. A sky shader that uses TIME, or any setting
##    changed every frame, makes Godot capture it every frame, which is costly.
##  - a backdrop locked to the camera with the moving sky on it (clouds drifting,
##    stars twinkling and so on), drawn behind everything, only where sky shows. On the
##    Low graphics preset there is no backdrop: the still sky is the background.
##
## The sun in the sky always follows the map's Sun light (events that move the Sun move
## it too). Events change the sky by blending to a second preset (blend()) and can push
## single settings (set_live(), e.g. the cloud sea's churn).

const GROUP := "sky_rig"
const STILL_SHADER := preload("res://game/maps/sky/sky_engine.gdshader")
const DOME_SHADER := preload("res://game/maps/sky/sky_dome.gdshader")
## How long the still sky waits between captures while something keeps changing it.
const RECAPTURE_WAIT := 1.0

var preset: SkyPreset:
	set(value):
		if preset and preset.changed.is_connected(_on_preset_changed):
			preset.changed.disconnect(_on_preset_changed)
		preset = value
		if preset and Engine.is_editor_hint():
			preset.changed.connect(_on_preset_changed)
		_blend_to = null
		_blend = 0.0
		if is_inside_tree():
			refresh()

## false: no moving backdrop, the still sky is the background (Low graphics).
var motion := true:
	set(value):
		motion = value
		if is_inside_tree():
			_apply_background()

var _map: Node3D
var _still: ShaderMaterial
var _dome_mat: ShaderMaterial
var _dome: MeshInstance3D
var _sky: Sky
var _blend_to: SkyPreset
var _blend := 0.0
var _live := {}
var _params := {}
var _sun_dir := Vector3.ZERO
var _still_dirty := false
var _still_wait := 0.0


func _init() -> void:
	name = "SkyRig"


func _enter_tree() -> void:
	add_to_group(GROUP)
	_map = get_parent() as Node3D


func _ready() -> void:
	refresh()


## Builds everything from the preset: both skies, the lighting, the background.
func refresh() -> void:
	if preset == null or _map == null:
		return
	if _still == null:
		_still = ShaderMaterial.new()
		_still.shader = STILL_SHADER
		_dome_mat = ShaderMaterial.new()
		_dome_mat.shader = DOME_SHADER
		# Writes no depth, so Godot draws it with the see-through things: first of all,
		# so see-through things far out (Empyrean's burn layer) still show over it.
		_dome_mat.render_priority = Material.RENDER_PRIORITY_MIN
		_dome = MeshInstance3D.new()
		_dome.name = "Backdrop"
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 48
		ball.rings = 24
		_dome.mesh = ball
		_dome.material_override = _dome_mat
		_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_dome.extra_cull_margin = 16384.0   # it is wherever the camera is: never culled
		_dome.ignore_occlusion_culling = true
		add_child(_dome)
		_sky = Sky.new()
		_sky.sky_material = _still
		_sky.radiance_size = Sky.RADIANCE_SIZE_128
		_sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_still.set_shader_parameter("eye_origin", _eye_origin())
	_sun_dir = _sun_direction()
	_params = _current()
	_push(_dome_mat)
	_push(_still)
	var env := environment()
	if env:
		env.sky = _sky
		_apply_lighting(env)
		_apply_fog(env)
	_apply_background()


## The map's Environment (events swap in their own copies, so it is looked up each time).
func environment() -> Environment:
	if _map == null:
		return null
	var world := _map.get_node_or_null("Environment") as WorldEnvironment
	return world.environment if world else null


## Blends the sky `k` of the way (0..1) to `other` (an event's second look). Lighting is
## left to the event.
func blend(other: SkyPreset, k: float) -> void:
	if other == _blend_to and is_equal_approx(k, _blend):
		return
	_blend_to = other
	_blend = clampf(k, 0.0, 1.0)
	_changed()


## Overrides one sky setting until it is cleared (null), on top of any blend.
func set_live(param: String, value) -> void:
	if value == null:
		_live.erase(param)
	elif _live.get(param) == value:
		return
	else:
		_live[param] = value
	_changed()


## The sky settings as they are drawn right now.
func current_params() -> Dictionary:
	return _params


func _process(delta: float) -> void:
	if preset == null:
		return
	var sun := _sun_direction()
	if not sun.is_equal_approx(_sun_dir):
		_sun_dir = sun
		_params.sun_dir = sun
		_dome_mat.set_shader_parameter("sun_dir", sun)
		_still_dirty = true
	_still_wait -= delta
	if _still_dirty and _still_wait <= 0.0:
		_push(_still)
		_still_dirty = false
		_still_wait = RECAPTURE_WAIT


func _changed() -> void:
	if preset == null or _dome_mat == null:
		return
	_params = _current()
	_push(_dome_mat)
	_still_dirty = true


func _current() -> Dictionary:
	var p := preset.params()
	if _blend_to and _blend > 0.0:
		p = SkyPreset.mix_params(p, _blend_to.params(), _blend)
	for k in _live:
		p[k] = _live[k]
	p.sun_dir = _sun_dir if _sun_dir != Vector3.ZERO else Vector3(0.35, 0.79, 0.5)
	return p


func _push(mat: ShaderMaterial) -> void:
	for k in _params:
		mat.set_shader_parameter(k, _params[k])


func _sun() -> DirectionalLight3D:
	return _map.get_node_or_null("Sun") as DirectionalLight3D if _map else null


## Toward the sun: the light shines along its own -Z.
func _sun_direction() -> Vector3:
	var sun := _sun()
	if sun == null or not sun.is_inside_tree():
		return Vector3(0.35, 0.79, 0.5)
	return sun.global_basis.z.normalized()


## Where the still sky's cloud sea is seen from: the middle of the map, a little up.
func _eye_origin() -> Vector3:
	var origin := Vector3(0.0, 2.0, 0.0)
	if _map and "swing_point" in _map:
		var swing: Vector3 = _map.swing_point
		origin = Vector3(swing.x, maxf(swing.y * 0.5, 2.0), swing.z)
	return origin


func _apply_lighting(env: Environment) -> void:
	if preset.light_ambient:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = preset.light_ambient_color
		env.ambient_light_energy = preset.light_ambient_energy
	if preset.light_fog:
		env.fog_enabled = preset.light_fog_density > 0.0
		env.fog_light_color = preset.light_fog_color
		env.fog_density = preset.light_fog_density
		env.fog_sky_affect = preset.light_fog_sky_affect
	var sun := _sun()
	if sun and preset.light_sun:
		sun.light_color = preset.light_sun_color
		sun.light_energy = preset.light_sun_energy


## The map's fog on the sky: the moving sky takes the Environment's Sky Affect as the
## still one does (Godot fogs that one itself), and where there is distance fog, the
## far ground below the horizon is the fog colour on both.
func _apply_fog(env: Environment) -> void:
	var fogged := env.fog_enabled and env.fog_density > 0.0
	var colour := env.fog_light_color
	for mat in [_dome_mat, _still]:
		mat.set_shader_parameter("fog_color", colour)
		mat.set_shader_parameter("fog_floor", 1.0 if fogged else 0.0)
	_dome_mat.set_shader_parameter("fog_affect", env.fog_sky_affect if fogged else 0.0)
	_still.set_shader_parameter("fog_affect", 0.0)


func _apply_background() -> void:
	var env := environment()
	var moving := motion and preset != null
	if _dome:
		_dome.visible = moving
	if env == null or preset == null:
		return
	if moving:
		# The backdrop covers the whole view; the background is only a fallback colour.
		env.background_mode = Environment.BG_COLOR
		env.background_color = preset.horizon_color
	else:
		env.background_mode = Environment.BG_SKY
	# Light that came "from the background" now comes from the still sky (with a colour
	# background it would be one flat colour). A map that turned reflections off keeps that.
	if env.ambient_light_source == Environment.AMBIENT_SOURCE_BG:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if env.reflected_light_source == Environment.REFLECTION_SOURCE_BG:
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _on_preset_changed() -> void:
	refresh()
