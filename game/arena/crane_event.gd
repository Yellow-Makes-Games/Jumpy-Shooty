class_name CraneEvent
extends MapEvent
## A tower crane that works when someone throws the lever in its cab (the Construction
## Site). Put one in a map scene, point a MapLever's (or any MapTerminal's) Event at it,
## and point Jib and Hook at two MapIslands whose Pivot is the middle of the mast:
##  - Jib: everything that turns on top of the mast (the jib, the counter-jib and its
##    weights, the deck round the mast head, the cab and the lever in it);
##  - Hook: what hangs from the hook (the hook block, the slings, a slab to stand on).
##
## The crane has a few stops (Turns and Heights, one of each for every stop) and goes
## round them in the order Route gives, one move for each pull of the lever. A move:
## the load is hoisted to Carry Height, the jib turns to the next stop taking the load
## with it, and the load is lowered to that stop's height. Whoever stands on the load or
## on the jib rides along. Then the lever stays locked for Cooldown seconds.
##
## Both islands are solid and both carry people, so keep everything the load passes
## clear: Carry Height must lift it over whatever stands under the arc, and a stop must
## leave standing room under the load (it is not a hazard, and must not squash anyone).
##
## The hoist rope is drawn by this node, from Rope Top (a marker inside the jib, under
## the trolley) to Rope Bottom (a marker inside the load, on the hook block), because
## its length changes. The editor does not show it.
##
## The host owns it, like every MapEvent: it keeps the clock and counts the moves.
## `state` is how far round the route the crane has got (0 until the lever is first
## pulled), so every copy places the jib and the load from the clock and that number
## alone: they are in the same place for everyone, also for someone who joins part-way.
## A new match puts the crane back at the first stop of its route.

## The MapIsland that turns: its Pivot is the middle of the mast.
@export_node_path("Node3D") var jib: NodePath
## The MapIsland that hangs from the hook (the same Pivot): the load.
@export_node_path("Node3D") var hook: NodePath
## Where the hoist rope leaves the trolley: a marker inside the jib.
@export_node_path("Node3D") var rope_top: NodePath
## Where it meets the hook block: a marker inside the Hook island.
@export_node_path("Node3D") var rope_bottom: NodePath

# (Turns, Heights and Route are typed arrays, not packed ones. An export drops a packed
# array from a node whose script does not run in the editor, as this one does not: the
# exported game then had a crane with no stops, and its lever did nothing.)
@export_group("Stops")
## For each stop: degrees the jib is turned from where the scene has it (positive is
## anticlockwise seen from above).
@export var turns: Array[float] = [0.0]
## For each stop: metres the load hangs above (or, negative, below) where the scene has it.
@export var heights: Array[float] = [0.0]
## The stops in the order the crane visits them, round and round (numbers into Turns
## and Heights, from 0). It starts a match at the first.
@export var route: Array[int] = [0]
## Metres above where the scene has it that the load is hoisted to before the jib turns.
@export var carry_height := 12.0

@export_group("Speed")
## The fastest the hook goes up and down, metres a second.
@export var hoist_speed := 6.0
## The fastest the jib turns, degrees a second.
@export var slew_speed := 9.0
## Seconds it rests between hoisting, turning and lowering.
@export var pause := 0.25
## Seconds after it has arrived before the lever can be thrown again.
@export var cooldown := 3.0

@export_group("Look and sound")
## The palette kind the hoist rope is drawn with, and how thick it is (metres).
@export var rope_kind := "cable"
@export var rope_width := 0.09

const START_SOUND := "crane_start"
const MOTOR_SOUND := "crane_motor"
const STOP_SOUND := "crane_stop"
const HEARD_FROM := 26.0     ## the motor is this loud a long way off (AudioStreamPlayer3D.unit_size)
const HEARD_TO := 170.0
const EASE := 1.5            ## a move that eases in and out takes this many times as long as one at full speed

var _jib: MapIsland
var _hook: MapIsland
var _top: Node3D
var _bottom: Node3D
var _found := false
var _rope: MeshInstance3D
var _motor: AudioStreamPlayer3D
var _was_moving := false


func _ready() -> void:
	super()
	set_process(DisplayServer.get_name() != "headless")
	_place.call_deferred()


# ---------------------------------------------------------------------------
# Where it is

## How many moves the route has.
func steps() -> int:
	return maxi(route.size(), 1)


## The stop the crane stands at when it is not moving, and is on its way to when it is.
func stop_now() -> int:
	return _stop(state)


## The stop it is coming from, while it moves.
func stop_before() -> int:
	return _stop(state - 1) if state > 0 else _stop(0)


func _stop(step: int) -> int:
	if route.is_empty():
		return 0
	return clampi(route[posmod(step, route.size())], 0, maxi(turns.size() - 1, 0))


func _turn(stop: int) -> float:
	return turns[stop] if stop < turns.size() else 0.0


func _height(stop: int) -> float:
	return heights[stop] if stop < heights.size() else 0.0


## Seconds each part of a move from stop `a` to stop `b` takes: hoisting, turning, lowering.
func _parts(a: int, b: int) -> Vector3:
	var top := maxf(carry_height, maxf(_height(a), _height(b)))
	return Vector3(
		(top - _height(a)) / maxf(hoist_speed, 0.1) * EASE,
		absf(_turn(b) - _turn(a)) / maxf(slew_speed, 0.1) * EASE,
		(top - _height(b)) / maxf(hoist_speed, 0.1) * EASE)


## Seconds the move it is making (or last made) takes, from the lever to the load at rest.
func move_time() -> float:
	var p := _parts(stop_before(), stop_now())
	return p.x + p.y + p.z + pause * 2.0


func length() -> float:
	return move_time() + cooldown


## Is the crane itself moving right now (not the wait after it)?
func moving() -> bool:
	return running and elapsed < move_time()


## Where the crane is `t` seconds into a move from stop `a` to stop `b`: (degrees the
## jib is turned, metres the load is above where the scene has it).
func pose_between(a: int, b: int, t: float) -> Vector2:
	var p := _parts(a, b)
	var top := maxf(carry_height, maxf(_height(a), _height(b)))
	if t <= p.x:
		return Vector2(_turn(a), lerpf(_height(a), top, _ease(t / p.x) if p.x > 0.0 else 1.0))
	t -= p.x + pause
	if t <= p.y:
		return Vector2(lerpf(_turn(a), _turn(b), _ease(t / p.y) if p.y > 0.0 else 1.0), top)
	t -= p.y + pause
	return Vector2(_turn(b), lerpf(top, _height(b), _ease(t / p.z) if p.z > 0.0 else 1.0))


## Where the crane is right now.
func pose_now() -> Vector2:
	if running:
		return pose_between(stop_before(), stop_now(), elapsed)
	var at := stop_now()
	return Vector2(_turn(at), _height(at))


## Which part of the move it is in: 0 hoisting, 1 turning, 2 lowering, -1 not moving.
func part_now() -> int:
	if not moving():
		return -1
	var p := _parts(stop_before(), stop_now())
	return 0 if elapsed <= p.x + pause * 0.5 else (1 if elapsed <= p.x + p.y + pause * 1.5 else 2)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


# ---------------------------------------------------------------------------
# The host's part: counting the moves

func host_start(by: int = 0) -> void:
	if running or not is_host() or route.size() < 2:
		return
	state = posmod(state, route.size()) + 1   # (1..: never 0 again, so a late joiner is told)
	super(by)


func _on_match_started() -> void:
	super()
	state = 0
	_place()


func apply_state(now_running: bool, at: float) -> void:
	var was := running
	super(now_running, at)
	if running and not was and elapsed < 0.5:
		_play(START_SOUND)
	_place()


func _update(_delta: float) -> void:
	_place()
	var now := moving()
	if _was_moving and not now and running:
		_play(STOP_SOUND)   # (not when a match's end cuts it short)
	_was_moving = now


# ---------------------------------------------------------------------------
# Putting the jib and the load where they are

func _find() -> void:
	if _found or not is_inside_tree():
		return
	_found = true
	_jib = get_node_or_null(jib) as MapIsland
	_hook = get_node_or_null(hook) as MapIsland
	_top = get_node_or_null(rope_top) as Node3D
	_bottom = get_node_or_null(rope_bottom) as Node3D


func _place() -> void:
	_find()
	var p := pose_now()
	if _jib:
		_jib.pose_a = Vector3(p.x, 0.0, 0.0)
		_jib.pose_b = _jib.pose_a
		_jib.blend = 0.0
	if _hook:
		_hook.pose_a = Vector3(p.x, p.y, 0.0)
		_hook.pose_b = _hook.pose_a
		_hook.blend = 0.0


# ---------------------------------------------------------------------------
# What you see and hear: the hoist rope, the motor

func _process(delta: float) -> void:
	_find()
	if _top != null and _bottom != null and _top.is_inside_tree() and _bottom.is_inside_tree():
		if _rope == null:
			_build_rope()
		var a := _top.global_position
		var b := _bottom.global_position
		var between := a.distance_to(b)
		_rope.visible = between > 0.05
		if _rope.visible:
			var up := (a - b) / between
			var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
			_rope.global_transform = Transform3D(Basis(side, up * between, side.cross(up)), (a + b) * 0.5)
	_sound(delta)


func _build_rope() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(rope_width, 1.0, rope_width)
	_rope = MeshInstance3D.new()
	_rope.name = "HoistRope"
	_rope.mesh = box
	_rope.top_level = true
	var map := MapRoot.of(self)
	if map:
		_rope.material_override = map.material_for(rope_kind)
	add_child(_rope)


func _sound(delta: float) -> void:
	var now := moving()
	if now and (_motor == null or not _motor.playing):
		_start_motor()
	if _motor != null and _motor.playing:
		if now:
			_motor.volume_db = move_toward(_motor.volume_db, SfxList.VOLUME.get(MOTOR_SOUND, -12.0), delta * 60.0)
			# The winch runs faster than the slew ring: a higher note while the hook moves.
			_motor.pitch_scale = move_toward(_motor.pitch_scale, 1.0 if part_now() == 1 else 1.26, delta * 1.2)
			if _jib:
				_motor.global_position = _jib.global_position
		else:
			_motor.volume_db -= delta * 90.0
			if _motor.volume_db < -50.0:
				_motor.stop()


func _start_motor() -> void:
	var sound := autoload("Sound")
	var dev := autoload("DevArgs")
	if dev and dev.sound_log:
		print("SFX3D %s" % MOTOR_SOUND)
	if sound == null or sound.silent:
		return
	if _motor == null:
		var stream: AudioStream = sound.stream(MOTOR_SOUND)
		if stream == null:
			return
		stream = stream.duplicate()
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_motor = AudioStreamPlayer3D.new()
		_motor.stream = stream
		_motor.bus = sound.BUS_SFX
		_motor.unit_size = HEARD_FROM
		_motor.max_distance = HEARD_TO
		_motor.top_level = true
		add_child(_motor)
	_motor.volume_db = -30.0
	_motor.pitch_scale = 1.26
	_motor.play()


## A one-off sound from the top of the mast, heard all over the site.
func _play(which: String) -> void:
	_find()
	var dev := autoload("DevArgs")
	var sound := autoload("Sound")
	if dev and dev.sound_log:
		print("SFX3D %s" % which)
	if sound == null or sound.silent or _jib == null or not _jib.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = sound.play_at(which, _jib.global_position, "body")
	if player:
		player.unit_size = HEARD_FROM
		player.max_distance = HEARD_TO
