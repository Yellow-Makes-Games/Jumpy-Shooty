class_name LayoutEvent
extends MapEvent
## A map with two layouts flips from one to the other (Cirrus: ringing the bell
## swings the building islands round the quad, between Hub and Ring). Put one in a
## map scene and point a MapTerminal's Event at it.
##
## Every time it is started the map moves to its other layout over `move_time`
## seconds, and stays there: nothing brings it back but starting it again. After a
## move the terminal stays locked for `cooldown`. `state` is the layout the map is in,
## or on its way to: 0 = the first (how the scene is laid out), 1 = the second.
##
## What moves: every MapIsland in the map (to its second place and back), every
## MapSpan (out in one layout, drawn in in the other), and the look of the whole
## map, which has a second version too: the sky, the sun, the ambient light and the
## kinds listed in Lit Kinds (windows and lamps that come on). It is meant to feel
## like an occasion, and all of it is in the world, none on the HUD: a bell tolls
## across the map, the camera rumbles, a fanfare plays as the islands go, the kinds
## in Flare Kinds (their engines) burn bright, the clouds below swirl, paper and
## leaves blow about, and the walkways lock with a clunk at the end. The kinds in
## Ready Kinds (the bell) glow and pulse gently while it can be started and sit dim
## while it cannot, to be read from across the map.
##
## The host owns it, like every MapEvent: it flips `state` and keeps the clock, and
## every copy places everything from those two numbers, so islands and walkways are
## in the same place for everyone, also for someone who joins mid-move or after it.
## A new match always begins in the first layout.

## What the two layouts are called (for the log and the tests).
@export var layouts: PackedStringArray = ["Hub", "Ring"]
## Seconds a move takes, each way.
@export var move_time := 4.0
## Seconds after a move before a terminal can start the next.
@export var cooldown := 60.0

@export_group("Second layout's look")
## The way to the sun in the second layout (the first is the scene's Sun as it stands).
@export var sun_direction := Vector3(-0.8, 0.22, 0.55)
@export var sun_color := Color(1.0, 0.56, 0.32)
@export var sun_energy := 0.9
@export var ambient_color := Color(0.62, 0.5, 0.66)
@export var ambient_energy := 0.75
## Kinds that light up in the second layout (windows, lamps, light strips), and how bright.
@export var lit_kinds: PackedStringArray = []
@export var lit_glow := 2.4

@export_group("The move")
## Kinds that burn bright while the islands move (their engines), and how many times brighter.
@export var flare_kinds: PackedStringArray = []
@export var flare_gain := 3.5
## Kinds that show whether it can be started (the bell): pulsing when ready, dim when not.
@export var ready_kinds: PackedStringArray = []
@export var ready_glow := 2.2
## Scraps of paper and leaves blown about during a move: how many (0 = none), and the
## box (in the map's frame) they blow through.
@export var scraps := 260
@export var scrap_volume := AABB(Vector3(-44, -18, -44), Vector3(88, 44, 88))

const TOLL_SOUND := "bell_toll"
const FANFARE_SOUND := "campus_fanfare"
const MOVE_SOUND := "island_move"
const LOCK_SOUND := "bridge_lock"
const RUMBLE_TIME := 0.9

## 0..1: where the parts are right now (0 = first layout, 1 = second).
var blend := 0.0
## 0..1: how far through a move it is (0 when nothing moves).
var progress := 0.0

var _map: MapRoot
var _islands: Array = []
var _spans: Array = []
var _found := false
var _looks := false
var _env: Environment
var _env_base := {}
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _sun_base := {}
var _lit: Array = []      # [StandardMaterial3D, base energy, had emission]
var _flare: Array = []    # [StandardMaterial3D, base energy]
var _ready_mats: Array = []
var _scraps: MultiMeshInstance3D
var _scrap_mat: ShaderMaterial
var _shown := -1.0
var _shown_flare := -1.0
var _time := 0.0
var _rumble := 0.0
var _was_moving := false


func _ready() -> void:
	super()
	_place.call_deferred()   # spans drawn in, islands home, once the map is built


## Locked for the whole match in a team mode (Search and Destroy, Capture the Flag):
## their bomb sites and flag stands are fixed spots worked out when the map loads, and
## would be left in mid-air when the islands move. So the map stays in its first layout.
func busy() -> bool:
	return running or team_mode()


func team_mode() -> bool:
	var teams := autoload("Teams")
	return teams != null and teams.active()


func length() -> float:
	return move_time + cooldown


## The name of the layout the map is in (or on its way to).
func layout_name() -> String:
	return layouts[state] if state >= 0 and state < layouts.size() else str(state)


## Are the islands on the move right now? (False in the cooldown.)
func moving() -> bool:
	return running and elapsed < move_time


## Host: start the move to the other layout. `by` is who set it off (0 = nobody).
func host_start(by: int = 0) -> void:
	if running or not is_host():
		return
	state = 1 - state
	print("[map] %s: to %s" % [name, layout_name()])
	super(by)


func apply_state(now_running: bool, at: float) -> void:
	var was := running
	super(now_running, at)
	if running and not was and elapsed < 0.5:   # (not for someone who joins part-way through)
		_announce()
	_place()


## A new match: back to the first layout at once, whatever happened in the last one.
func _on_match_started() -> void:
	state = 0
	if running:
		stop()
	_place()


## The match is over: whatever layout it is in, it stays (a move under way finishes).
func _on_match_over(_results: Array) -> void:
	pass


func _update(_delta: float) -> void:
	_place()


## Where the parts are `t` seconds into a move toward layout `to`.
func blend_at(t: float, to: int) -> float:
	var p := clampf(t / maxf(move_time, 0.01), 0.0, 1.0)
	return lerpf(float(1 - to), float(to), smoothstep(0.0, 1.0, p))


## How much of a span is out, `p` of the way (0..1) through a move toward layout `to`.
static func span_extent(out_in: int, to: int, p: float) -> float:
	if out_in == to:
		return smoothstep(0.35, 1.0, p)   # coming out: it arrives as the islands do
	return 1.0 - smoothstep(0.15, 0.85, p)   # going in: the lights warn first


## Puts every part where the state and the clock say.
func _place() -> void:
	if not is_inside_tree():
		return
	if not _found:
		_find_parts()
	var now_moving := moving()
	progress = clampf(elapsed / maxf(move_time, 0.01), 0.0, 1.0) if now_moving else 0.0
	blend = blend_at(elapsed, state) if now_moving else float(state)
	for island in _islands:
		(island as MapIsland).blend = blend
	for s in _spans:
		var span := s as MapSpan
		span.racing = now_moving
		span.extent = span_extent(span.out_in, state, progress) if now_moving else (1.0 if span.out_in == state else 0.0)
	if _map:
		_map.layout_state = state
		_map.shifting = now_moving
	if _was_moving and not now_moving and running:
		_locked()
	_was_moving = now_moving
	_show(sin(progress * PI) if now_moving else 0.0)


func _find_parts() -> void:
	_map = MapRoot.of(self)
	if _map == null:
		return
	_found = true
	_islands = _map.find_children("*", "", true, false).filter(func(n): return n is MapIsland)
	_spans = _map.find_children("*", "", true, false).filter(func(n): return n is MapSpan)


# ---------------------------------------------------------------------------
# The occasion: bell, rumble, fanfare, and the clunk at the end

func _announce() -> void:
	_rumble = RUMBLE_TIME
	_sound(TOLL_SOUND)
	_sound(FANFARE_SOUND)
	_sound(MOVE_SOUND)


func _locked() -> void:
	_sound(LOCK_SOUND)
	_shake(0.5)


func _sound(which: String) -> void:
	var dev := autoload("DevArgs")
	var sound := autoload("Sound")
	if dev and dev.sound_log:
		print("SFX %s" % which)
	if sound == null or sound.silent:
		return
	sound.play(which)   # heard all over the map: not placed in the world


func _shake(amount: float) -> void:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return
	var player: Node = arena.get("local_player")
	if player != null and is_instance_valid(player) and player.get("rig") != null:
		player.shake(amount)


func _process(delta: float) -> void:
	_time += delta
	if _rumble > 0.0:
		# A short rumble for everyone as the bell goes: strongest at once, gone in under a second.
		var before := _rumble
		_rumble = maxf(_rumble - delta, 0.0)
		if int(before / 0.06) != int(_rumble / 0.06):
			_shake(0.55 * _rumble / RUMBLE_TIME)
	if not _ready_mats.is_empty():
		var can := not busy()
		var want := ready_glow * (0.72 + 0.28 * sin(_time * 2.2)) if can else ready_glow * 0.07
		for m in _ready_mats:
			var mat: StandardMaterial3D = m
			mat.emission_energy_multiplier = move_toward(mat.emission_energy_multiplier, want, delta * ready_glow * 1.5)


# ---------------------------------------------------------------------------
# The look: afternoon to sunset, lamps on, engines flaring, clouds and scraps

func _show(flare: float) -> void:
	if is_equal_approx(blend, _shown) and is_equal_approx(flare, _shown_flare):
		return
	_shown = blend
	_shown_flare = flare
	if not _looks:
		_find_looks()
	var k := blend
	if _env:
		_env.ambient_light_color = (_env_base.color as Color).lerp(ambient_color, k)
		_env.ambient_light_energy = lerpf(_env_base.energy, ambient_energy, k)
		_env.glow_intensity = lerpf(_env_base.glow, _env_base.glow * 1.3, maxf(k, flare))
	if _sky:
		_sky.set_shader_parameter("sunset", k)
		_sky.set_shader_parameter("swirl", flare)
		_sky.set_shader_parameter("sun_dir", (_sun_base.dir as Vector3).slerp(sun_direction.normalized(), k) if _sun else sun_direction.normalized())
	if _sun:
		var dir: Vector3 = (_sun_base.dir as Vector3).slerp(sun_direction.normalized(), k)
		_sun.basis = _facing(dir)
		_sun.light_color = (_sun_base.color as Color).lerp(sun_color, k)
		_sun.light_energy = lerpf(_sun_base.energy, sun_energy, k)
	for m in _lit:
		var mat: StandardMaterial3D = m[0]
		mat.emission_energy_multiplier = lerpf(m[1], lit_glow, k)
	for m in _flare:
		var mat: StandardMaterial3D = m[0]
		mat.emission_energy_multiplier = m[1] * (1.0 + flare_gain * flare)
	if flare > 0.0 and _scraps == null and scraps > 0 and _map and _map.has_meshes and DisplayServer.get_name() != "headless":
		_build_scraps()
	if _scraps:
		_scraps.visible = flare > 0.002
		_scrap_mat.set_shader_parameter("fade", flare)


## A light's basis shining from `to_sun` (it shines along its own -z).
static func _facing(to_sun: Vector3) -> Basis:
	var z := to_sun.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


func _find_looks() -> void:
	_looks = true
	if _map == null or not _map.has_meshes or DisplayServer.get_name() == "headless":
		return
	var found := _map.find_children("*", "WorldEnvironment", true, false)
	if not found.is_empty() and (found[0] as WorldEnvironment).environment:
		var world := found[0] as WorldEnvironment
		# Our own copy, so the scene's shared Environment is never left changed.
		_env = world.environment.duplicate()
		world.environment = _env
		_env_base = {"color": _env.ambient_light_color, "energy": _env.ambient_light_energy, "glow": _env.glow_intensity}
		if _env.sky and _env.sky.sky_material is ShaderMaterial:
			_env.sky = _env.sky.duplicate()
			_sky = _env.sky.sky_material.duplicate()
			_env.sky.sky_material = _sky
	_sun = _map.get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_sun_base = {"color": _sun.light_color, "energy": _sun.light_energy, "dir": _sun.basis.z.normalized()}
	for kind in lit_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat:
			if not mat.emission_enabled:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 0.0
			_lit.append([mat, mat.emission_energy_multiplier])
	for kind in flare_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat and mat.emission_enabled:
			_flare.append([mat, mat.emission_energy_multiplier])
	for kind in ready_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			_ready_mats.append(mat)


const SCRAP_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float fade = 0.0;
varying vec3 tint;
varying float show;
void vertex() {
	// INSTANCE_CUSTOM: two random numbers (x, y), a size (z) and a speed (w). Each scrap
	// circles the middle of the map on the wind, bobbing and tumbling as it goes.
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * INSTANCE_CUSTOM.w;
	float turn = t * 0.55 + INSTANCE_CUSTOM.x * 6.283;
	float c = cos(turn * 0.35);
	float s = sin(turn * 0.35);
	centre = vec3(centre.x * c - centre.z * s, centre.y + sin(t * 1.3 + INSTANCE_CUSTOM.y * 40.0) * 1.6, centre.x * s + centre.z * c);
	float spin = t * 5.0 + INSTANCE_CUSTOM.y * 20.0;
	vec3 right = normalize(vec3(cos(spin), sin(spin * 0.7) * 0.6, sin(spin)));
	vec3 up = normalize(cross(right, vec3(sin(spin * 0.5), 1.0, cos(spin * 0.5))));
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * INSTANCE_CUSTOM.z;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// Paper (cream), or a leaf (green to gold).
	tint = INSTANCE_CUSTOM.x < 0.55 ? vec3(0.97, 0.94, 0.86) : mix(vec3(0.42, 0.62, 0.2), vec3(0.9, 0.62, 0.16), INSTANCE_CUSTOM.y);
	show = step(1.0 - fade, 0.25 + 0.75 * fract(INSTANCE_CUSTOM.x * 7.31 + INSTANCE_CUSTOM.y * 3.17));
}
void fragment() {
	if (show < 0.5) {
		discard;
	}
	ALBEDO = tint;
}
"


func _build_scraps() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.7)
	var shader := Shader.new()
	shader.code = SCRAP_SHADER
	_scrap_mat = ShaderMaterial.new()
	_scrap_mat.shader = shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = scraps
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var box := scrap_volume
	for i in scraps:
		var at := box.position + Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
		mm.set_instance_transform(i, Transform3D(Basis(), at))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf_range(0.22, 0.42), rng.randf_range(0.7, 1.5)))
	_scraps = MultiMeshInstance3D.new()
	_scraps.name = "Scraps"
	_scraps.multimesh = mm
	_scraps.material_override = _scrap_mat
	_scraps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scraps.extra_cull_margin = 16384.0   # they are drawn all over the map from one node
	_map.add_child(_scraps)
