class_name GravityEvent
extends MapEvent
## A map-wide spell of low gravity (Halcyon: the centrifuge slows down). Put one in
## a map scene and point a MapTerminal's Event at it.
##
## Once started, gravity eases down to `gravity_scale` of normal over `ease_time`
## seconds, stays there for `duration`, eases back, and then the terminal stays
## locked for `cooldown`. It changes WorldGravity.scale, which all player movement
## reads, so jumps, falls, swings and slides all go light together. Bullets, rockets
## and grenades are not touched.
##
## The feel is meant to be blissful, not an alarm, and it is all in the world (no
## HUD): every light in the map fades to a deep blue, a soft chord swells in and
## holds, slow motes of light drift through the big rooms, and the map's MapSpinners
## (the centrifuge) ease down to half speed. All of it follows the same curve as the
## gravity, on every copy of the game.

## Seconds gravity takes to ease down, and to ease back.
@export var ease_time := 2.0
## Seconds it stays low in between.
@export var duration := 30.0
## Seconds after gravity is back before a terminal can start it again.
@export var cooldown := 60.0
## Gravity while it is low, as a share of normal (0.3: a jump reaches about 4 m).
@export_range(0.05, 1.0) var gravity_scale := 0.3

@export_group("Look and sound")
## The colour the map's light fades to.
@export var light_color := Color(0.1, 0.24, 1.0)
## MapSpinners turn at this share of their speed while gravity is low.
@export_range(0.0, 1.0) var spinner_speed := 0.5
## Where the motes of light drift: boxes (in the map's frame) round the big rooms.
@export var mote_volumes: Array[AABB] = []
## One mote for about this many cubic metres (fewer if that would be too many in all).
@export var mote_spacing := 80.0

const MAX_MOTES := 2400
const PAD_SOUND := "gravity_pad"

## 0..1: how far into low gravity it is right now (0 = normal).
var level := 0.0

var _map: MapRoot
var _env: Environment
var _env_base := {}
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _sun_base := {}
var _mats: Array = []      # [material, albedo, emission, has emission]
var _motes: MultiMeshInstance3D
var _mote_mat: ShaderMaterial
var _pad: AudioStreamPlayer
var _shown := -1.0
var _looks := false


func _ready() -> void:
	super()
	WorldGravity.reset()


func _exit_tree() -> void:
	super()
	WorldGravity.reset()


func length() -> float:
	return ease_time * 2.0 + duration + cooldown


## How far into low gravity the event is `t` seconds after it started: 0 (normal)
## easing to 1 (fully low) and back, then 0 through the cooldown.
func level_at(t: float) -> float:
	if t <= 0.0 or t >= ease_time * 2.0 + duration:
		return 0.0
	if t < ease_time:
		return smoothstep(0.0, 1.0, t / ease_time)
	if t <= ease_time + duration:
		return 1.0
	return smoothstep(0.0, 1.0, (ease_time * 2.0 + duration - t) / ease_time)


## What gravity is multiplied by `t` seconds after the event started.
func multiplier_at(t: float) -> float:
	return lerpf(1.0, gravity_scale, level_at(t))


## Is gravity low (or on its way down or back up) right now? False in the cooldown.
func active() -> bool:
	return running and elapsed < ease_time * 2.0 + duration


func _update(_delta: float) -> void:
	level = level_at(elapsed) if running else 0.0
	WorldGravity.scale = lerpf(1.0, gravity_scale, level)
	_show()


func apply_state(now_running: bool, at: float) -> void:
	var was := running
	super(now_running, at)
	if running and not was:
		_start_sound()
	if running:
		_update(0.0)


# ---------------------------------------------------------------------------
# The look: lights to blue, motes, the centrifuge slowing

func _show() -> void:
	if is_equal_approx(level, _shown) or not is_inside_tree():
		return
	_shown = level
	if not _looks:
		_find_looks()
	for s in _map.spinners if _map else []:
		(s as MapSpinner).speed_scale = lerpf(1.0, spinner_speed, level)
	if _env:
		# Deep blue, and a little dimmer, so floors, walls and trim still read apart.
		_env.ambient_light_color = (_env_base.color as Color).lerp(light_color, level * 0.9)
		_env.ambient_light_energy = lerpf(_env_base.energy, _env_base.energy * 0.72, level)
		_env.glow_intensity = lerpf(_env_base.glow, _env_base.glow * 1.35, level)
	if _sky:
		_sky.set_shader_parameter("deepen", level)
	if _sun:
		_sun.light_color = (_sun_base.color as Color).lerp(light_color.lerp(Color.WHITE, 0.15), level)
		_sun.light_energy = lerpf(_sun_base.energy, _sun_base.energy * 0.9, level)
	var glow_to := light_color.lerp(Color(0.45, 0.7, 1.0), 0.25)
	for m in _mats:
		var base: Color = m[1]
		var cool := Color(base.r * 0.6, base.g * 0.75, minf(base.b * 1.1 + 0.05, 1.0), base.a)
		if m[0] is ShaderMaterial:   # a patterned kind (see MapPalette.surface)
			(m[0] as ShaderMaterial).set_shader_parameter("albedo", base.lerp(cool, level * 0.5))
			continue
		var mat: StandardMaterial3D = m[0]
		mat.albedo_color = base.lerp(cool, level * 0.5)
		if m[3]:
			mat.emission = (m[2] as Color).lerp(glow_to, level * 0.9)
	if level > 0.0 and _motes == null and not mote_volumes.is_empty() and DisplayServer.get_name() != "headless":
		_build_motes()
	if _motes:
		_motes.visible = level > 0.001
		_mote_mat.set_shader_parameter("fade", level)
	if _pad and _pad.playing:
		# The chord swells in with the drop, holds, and fades as gravity comes back.
		_pad.volume_db = lerpf(-46.0, SfxList.VOLUME.get(PAD_SOUND, -15.0), sqrt(level))
		if level <= 0.0:
			_pad.stop()


func _find_looks() -> void:
	_looks = true
	_map = MapRoot.of(self)
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
		_sun_base = {"color": _sun.light_color, "energy": _sun.light_energy}
	if _map.palette:
		for kind in _map.palette.colors:
			var any := _map.material_for(kind)
			var mat := any as StandardMaterial3D
			if mat:
				_mats.append([mat, mat.albedo_color, mat.emission, mat.emission_enabled])
			elif any is ShaderMaterial and (any as ShaderMaterial).get_shader_parameter("albedo") is Color:
				_mats.append([any, (any as ShaderMaterial).get_shader_parameter("albedo"), Color.BLACK, false])


const MOTE_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float fade = 0.0;
varying float twinkle;
void vertex() {
	// INSTANCE_CUSTOM: a random number per mote (x, y), its size (z) and its speed (w).
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * INSTANCE_CUSTOM.w;
	centre += vec3(sin(t * 0.31 + INSTANCE_CUSTOM.x * 40.0), sin(t * 0.23 + INSTANCE_CUSTOM.y * 40.0) * 0.8,
		cos(t * 0.27 + INSTANCE_CUSTOM.x * 23.0)) * 1.6;
	float life = fract(t * 0.02 + INSTANCE_CUSTOM.y);   // drifts up 6 m, fading in and out, then starts again
	centre.y += (life - 0.5) * 6.0;
	twinkle = (0.55 + 0.45 * sin(TIME * (0.6 + INSTANCE_CUSTOM.x) + INSTANCE_CUSTOM.y * 30.0)) * sin(life * PI);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * INSTANCE_CUSTOM.z;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float halo = smoothstep(1.0, 0.0, d);
	float core = smoothstep(0.22, 0.0, d);
	ALBEDO = vec3(0.8, 0.9, 1.0) * (halo * halo * 0.55 + core * 1.1) * fade * twinkle;
}
"


func _build_motes() -> void:
	var total := 0.0
	for box in mote_volumes:
		total += box.get_volume()
	var count := clampi(int(total / maxf(mote_spacing, 1.0)), 1, MAX_MOTES)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var shader := Shader.new()
	shader.code = MOTE_SHADER
	_mote_mat = ShaderMaterial.new()
	_mote_mat.shader = shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var i := 0
	for b in mote_volumes.size():
		var box := mote_volumes[b]
		var share := int(round(count * box.get_volume() / total)) if b < mote_volumes.size() - 1 else count - i
		for n in mini(share, count - i):
			var at := box.position + Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
			mm.set_instance_transform(i, Transform3D(Basis(), at))
			mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf_range(0.22, 0.6), rng.randf_range(0.5, 1.2)))
			i += 1
	mm.visible_instance_count = i
	_motes = MultiMeshInstance3D.new()
	_motes.name = "Motes"
	_motes.multimesh = mm
	_motes.material_override = _mote_mat
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.extra_cull_margin = 16384.0   # they are drawn all over the map from one node
	(_map if _map else self).add_child(_motes)


# ---------------------------------------------------------------------------
# The sound: one soft chord, heard everywhere, kept under the fighting

func _start_sound() -> void:
	var dev := autoload("DevArgs")
	var sound := autoload("Sound")
	if dev and dev.sound_log:
		print("SFX %s" % PAD_SOUND)
	if sound == null or sound.silent:
		return
	if _pad == null:
		var stream: AudioStream = sound.stream(PAD_SOUND)
		if stream == null:
			return
		stream = stream.duplicate()
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_pad = AudioStreamPlayer.new()
		_pad.stream = stream
		_pad.bus = sound.BUS_SFX
		add_child(_pad)
	_pad.volume_db = -46.0
	_pad.play(fmod(maxf(elapsed, 0.0), maxf(_pad.stream.get_length(), 0.1)))
