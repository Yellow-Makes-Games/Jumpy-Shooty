class_name LayoutEvent
extends MapEvent
## A map with two layouts changes from one to the other on a timer (Cirrus: the
## building islands swing round the quad, between Hub and Ring). Put one in a map
## scene. It needs no terminal: it runs by itself for as long as a match does.
##
## One turn of its clock:
##  - `hold_time` seconds in the layout the map is in. A clock ticks once a second,
##    softly, all over the map and a little louder near `tick_from` (the clock tower).
##  - A bell tolls, and for `windup_time` seconds the move builds up, slowly and then
##    fast: a rising tone, a growing rumble, the engines (Flare Kinds) spooling up, and
##    the walkways that are about to go flashing their lights. Nothing moves yet: this
##    is the time to get off a walkway.
##  - The parts move for `move_time` seconds, slowly at first and then fast, and lock
##    with a clunk.
## Then the next turn begins, in the other layout. `state` is the layout a turn begins
## in: 0 = the first (how the scene is laid out), 1 = the second.
##
## What moves: every MapIsland in the map (to its second place and back), every
## MapSpan (out in one layout, drawn in in the other), and the look of the whole
## map, which has a second version too: the sky, the sun, the ambient light and the
## kinds listed in Lit Kinds (windows and lamps that come on). During the wind-up and
## the move the clouds below swirl and paper and leaves blow about. All of it is in
## the world, none on the HUD. MapSpinners set to Countdown are the hands of a clock:
## once round per turn, at twelve when the bell goes. One set to Swing is the bell.
##
## The host owns it, like every MapEvent: it keeps the clock and says which layout a
## turn began in, and every copy places everything from those two numbers, so islands
## and walkways are in the same place for everyone, also for someone who joins
## part-way. A new match always begins in the first layout. In a team mode (Search and
## Destroy, Capture the Flag) it does not run at all: their bomb sites and flag stands
## are fixed spots worked out when the map loads, and would be left in mid-air.

## What the two layouts are called (for the log and the tests).
@export var layouts: PackedStringArray = ["Hub", "Ring"]
## Seconds the map stays in a layout before the bell goes.
@export var hold_time := 60.0
## Seconds from the bell to the move: the warning.
@export var windup_time := 5.0
## Seconds a move takes, each way.
@export var move_time := 4.0
## Where the clock's tick comes from (in the map's frame): it is a little louder near here.
@export var tick_from := Vector3(0, 24, 0)

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
## Kinds that burn bright as the move builds and goes (the islands' engines), and how
## many times brighter.
@export var flare_kinds: PackedStringArray = []
@export var flare_gain := 3.5
## Scraps of paper and leaves blown about during a move: how many (0 = none), and the
## box (in the map's frame) they blow through.
@export var scraps := 260
@export var scrap_volume := AABB(Vector3(-44, -18, -44), Vector3(88, 44, 88))

## Something to hear is due: "tick", "tock", "toll" (the bell: the warning begins),
## "move" (the islands go) or "lock" (they have arrived).
signal cue(what: String)

const TICK_SOUND := "clock_tick"
const TOCK_SOUND := "clock_tock"
const TOLL_SOUND := "bell_toll"
const RISE_SOUND := "layout_rise"
const MOVE_SOUND := "island_move"
const LOCK_SOUND := "bridge_lock"
const RISE_LENGTH := 5.0      ## seconds the rising tone lasts as recorded
const TICK_QUIET := -7.0      ## dB: the tick heard everywhere, under the one from the tower
const SWING := 0.5            ## radians the bell swings at first
const SWING_RATE := 0.55      ## swings per second
const SWING_FADE := 3.2       ## seconds for the swing to die down to about a third

## 0..1: where the parts are right now (0 = first layout, 1 = second).
var blend := 0.0
## 0..1: how far through a move it is (0 when nothing moves).
var progress := 0.0
## 0..1: how far through the warning before a move it is (0 at any other time).
var windup := 0.0

var _map: MapRoot
var _islands: Array = []
var _spans: Array = []
var _hands: Array = []     # MapSpinners that are clock hands
var _bells: Array = []     # MapSpinners that swing when the bell goes
var _found := false
var _looks := false
var _env: Environment
var _env_base := {}
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _sun_base := {}
var _lit: Array = []      # [StandardMaterial3D, base energy, had emission]
var _flare: Array = []    # [StandardMaterial3D, base energy]
var _scraps: MultiMeshInstance3D
var _scrap_mat: ShaderMaterial
var _shown := -1.0
var _shown_flare := -1.0
var _shake_wait := 0.0
var _tolled := -1.0       # seconds since the bell last went on this copy (-1 = it has not)
var _turn_due := false


func _ready() -> void:
	super()
	_place.call_deferred()   # spans drawn in, islands home, once the map is built


func team_mode() -> bool:
	var teams := autoload("Teams")
	return teams != null and teams.active()


## One whole turn: the wait, the warning and the move.
func length() -> float:
	return hold_time + windup_time + move_time


## The name of the layout this turn began in.
func layout_name() -> String:
	return layouts[state] if state >= 0 and state < layouts.size() else str(state)


## Are the islands on the move right now?
func moving() -> bool:
	return running and elapsed >= hold_time + windup_time


## Has the bell gone, with the move still to come?
func warning() -> bool:
	return running and elapsed >= hold_time and elapsed < hold_time + windup_time


## Seconds until the bell (0 once it has gone, or when the clock is not running).
func time_to_bell() -> float:
	return maxf(hold_time - elapsed, 0.0) if running else 0.0


## Host: start the clock (a match has begun). Never in a team mode.
func host_start(by: int = 0) -> void:
	if team_mode():
		return
	super(by)


## Should the clock be running? (The host asks.) Only while a match is being played.
func _wanted() -> bool:
	var rules := autoload("Match")
	return rules != null and rules.running and not team_mode()


func take_state(value: int) -> void:
	# The host says the turn is over before this copy's own clock got there: the clunk is due.
	if value != state and running and elapsed > length() - 1.0:
		_turn_due = true
	super(value)


func apply_state(now_running: bool, at: float) -> void:
	super(now_running, at)
	if _turn_due:
		_turn_due = false
		_locked()
	_place()


## A new match: back to the first layout at once, the clock at nought.
func _on_match_started() -> void:
	state = 0
	_tolled = -1.0
	if running:
		stop()
	_place()


## The match is over: the clock runs on while the scores are up. The next match puts it back.
func _on_match_over(_results: Array) -> void:
	pass


func _update(_delta: float) -> void:
	_place()


func _physics_process(delta: float) -> void:
	if not running:
		if is_host() and _wanted():
			host_start()
		return
	var before := elapsed
	elapsed += delta
	if elapsed >= length():
		# The move is done: the next turn begins, in the other layout.
		elapsed -= length()
		state = 1 - state
		before = -1.0
		_locked()
		if is_host():
			print("[map] %s: %s" % [name, layout_name()])
			_resync = 0.0   # (everyone is told at once)
	_cues(before, elapsed)
	_place()
	var net := autoload("Net")
	if net and net.is_host() and net.is_online:
		_resync -= delta
		if _resync <= 0.0:
			_resync = RESYNC
			net.send_map_event_state(index(), true, elapsed)


## How far the islands have got, `p` of the way (0..1) through a move's time: slowly at
## first, then fast, and gently to a stop.
static func ease_in(p: float) -> float:
	return smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), 1.6))


## Where the parts are `t` seconds into a turn that began in layout `from`.
func blend_at(t: float, from: int) -> float:
	var p := clampf((t - hold_time - windup_time) / maxf(move_time, 0.01), 0.0, 1.0)
	return lerpf(float(from), float(1 - from), ease_in(p))


## How much of a span is out, `p` of the way (0..1) through a move toward layout `to`.
static func span_extent(out_in: int, to: int, p: float) -> float:
	if out_in == to:
		return smoothstep(0.35, 1.0, p)   # coming out: it arrives as the islands do
	return 1.0 - smoothstep(0.1, 0.7, p)   # going in: gone before the islands have got far


## Puts every part where the state and the clock say.
func _place() -> void:
	if not is_inside_tree():
		return
	if not _found:
		_find_parts()
	var now_moving := moving()
	var now_warning := warning()
	var to := 1 - state
	progress = clampf((elapsed - hold_time - windup_time) / maxf(move_time, 0.01), 0.0, 1.0) if now_moving else 0.0
	windup = clampf((elapsed - hold_time) / maxf(windup_time, 0.01), 0.0, 1.0) if now_warning else 0.0
	blend = blend_at(elapsed, state) if now_moving else float(state)
	for island in _islands:
		(island as MapIsland).blend = blend
	for s in _spans:
		var span := s as MapSpan
		# Flashing: everything while it moves; before that, the ones about to be drawn in.
		span.racing = now_moving or (now_warning and span.out_in == state)
		span.extent = span_extent(span.out_in, to, progress) if now_moving else (1.0 if span.out_in == state else 0.0)
	if _map:
		_map.layout_state = state
		_map.warning = now_warning
		_map.shifting = now_moving
	var flare := 0.0
	if now_warning:
		flare = 0.6 * windup * windup
	elif now_moving:
		flare = lerpf(0.6, 1.0, sin(progress * PI)) if progress < 0.5 else sin(progress * PI)
	_show(flare)


func _find_parts() -> void:
	_map = MapRoot.of(self)
	if _map == null:
		return
	_found = true
	var all := _map.find_children("*", "", true, false)
	_islands = all.filter(func(n): return n is MapIsland)
	_spans = all.filter(func(n): return n is MapSpan)
	_hands = all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.COUNTDOWN)
	_bells = all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.SWING)


# ---------------------------------------------------------------------------
# What you hear and feel: the tick, the bell, the build-up, the clunk

## The sounds due between two moments of a turn (`before` is -1 just after a turn began).
func _cues(before: float, now: float) -> void:
	if now - before > 0.5 and before >= 0.0:
		return   # the clock was put right, not run: nothing is due
	if now < hold_time:
		var second := int(now)
		if before >= 0.0 and second > int(before):
			cue.emit("tick" if second % 2 == 1 else "tock")
			_tick(TICK_SOUND if second % 2 == 1 else TOCK_SOUND)
	if before < hold_time and now >= hold_time:
		_tolled = now - hold_time
		cue.emit("toll")
		_sound(TOLL_SOUND)
		_sound(RISE_SOUND, RISE_LENGTH / maxf(windup_time, 0.5))
	if before < hold_time + windup_time and now >= hold_time + windup_time:
		cue.emit("move")
		_sound(MOVE_SOUND)


## The move is over: the walkways lock.
func _locked() -> void:
	cue.emit("lock")
	_sound(LOCK_SOUND)
	_shake(0.5)


## Heard all over the map: not placed in the world.
func _sound(which: String, pitch: float = 1.0) -> void:
	var sound := autoload("Sound")
	if sound == null:
		return
	var player: AudioStreamPlayer = sound.play(which)
	if player and not is_equal_approx(pitch, 1.0):
		player.pitch_scale = pitch


## The clock: quiet everywhere, and once more from the tower for whoever is near it.
func _tick(which: String) -> void:
	var sound := autoload("Sound")
	if sound == null:
		return
	sound.play(which, TICK_QUIET)
	if _map:
		sound.play_at(which, _map.global_transform * tick_from, "body")


func _shake(amount: float) -> void:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return
	var player: Node = arena.get("local_player")
	if player != null and is_instance_valid(player) and player.get("rig") != null:
		player.shake(amount)


func _process(delta: float) -> void:
	if _tolled >= 0.0:
		_tolled += delta
	# A rumble that grows through the warning, and carries on while the islands go.
	var rumble := 0.0
	if warning():
		rumble = 0.04 + 0.26 * windup * windup
	elif moving():
		rumble = 0.3 * (1.0 - 0.5 * progress)
	if rumble > 0.0:
		_shake_wait -= delta
		if _shake_wait <= 0.0:
			_shake_wait = 0.07
			_shake(rumble)
	# The clock's hands: a step each second, at twelve when the bell goes.
	var turn := 0.0
	if running and elapsed < hold_time:
		turn = floorf(elapsed) / maxf(hold_time, 1.0)
	for hand in _hands:
		(hand as MapSpinner).angle = -TAU * turn
	var swing := 0.0
	if _tolled >= 0.0 and _tolled < SWING_FADE * 5.0:
		swing = SWING * sin(TAU * SWING_RATE * _tolled) * exp(-_tolled / SWING_FADE)
	for bell in _bells:
		(bell as MapSpinner).angle = swing


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
