class_name HauntEvent
extends MapEvent
## The haunting of a house (the Haunted House): a clock that runs for as long as a match
## does, in every kind of game. Put one in a map scene; no terminal needed.
##
## All the time: every HauntProp in the map floats (its Bob, Sway and Twirl), the map's
## MapGhosts fly their rounds, and the candles in Lights flicker.
##
## Every turn the house shifts. Hold Time seconds of quiet; then Warn Time seconds of
## warning (a moan through the house, the lights stutter, the furniture that is about to
## go rattles where it floats and a doorway that is coming back shows as a faint glow in
## its wall); then Move Time seconds in which the furniture glides to where the next
## layout has it, doorways that go fade out at once and doorways that come fade in, and
## turn solid when they are all there. Whoever stands in one then is put out of it, and
## anyone a piece of furniture came to rest on is moved off.
##
## There are Layouts layouts (0 is the scene as it is). A match starts in layout 0; after
## that the order is drawn from `state`, a number the host picks when the clock starts, so
## every copy of the game works out the same order and places everything from the clock
## and that number alone: the same for everyone, also for someone who joins part-way.
## Never the same layout twice running.
##
## While the furniture moves the bots stand still (MapRoot.shifting), and the bots'
## navigation mesh is baked once for each layout (MapRoot.layout_state).

## How many layouts the house has (every HauntProp's Moves, Turns and Shown are read
## with this many in mind).
@export var layouts := 4
## Seconds of quiet between shifts.
@export var hold_time := 22.0
## Seconds of warning before a shift.
@export var warn_time := 3.0
## Seconds the furniture takes to glide to its new place.
@export var move_time := 2.5
## A node whose OmniLight3D children are the house's candles and fires: they flicker, and
## stutter through the warning.
@export_node_path("Node3D") var lights: NodePath

const WARN_SOUND := "haunt_warn"
const SHIFT_SOUND := "haunt_shift"
const SETTLE_SOUND := "haunt_settle"
const BITS := 16

var _props: Array = []
var _ghosts: Array = []
var _lights: Array = []    # [OmniLight3D, its own energy, a seed]
var _found := false
var _map: MapRoot
var _sequence: Array = [0]   # the layout of each turn, from `state`
var _seeded := -1
var _was_moving := false
var _was_warning := false
var _shake_wait := 0.0
var _time := 0.0


func _ready() -> void:
	super()
	_place.call_deferred()


## It never ends by itself (and the match's end does not stop it: the house is haunted).
func length() -> float:
	return INF


## Terminals have nothing to do with it.
func busy() -> bool:
	return false


func _on_match_over(_results: Array) -> void:
	pass


## A new match: everything home, the clock at nought (the host starts it again).
func _on_match_started() -> void:
	if running:
		stop()
	state = 0
	_place()


func _wanted() -> bool:
	var rules := autoload("Match")
	return rules != null and rules.running


## Host: start the clock, with a fresh order of layouts.
func host_start(by: int = 0) -> void:
	if running or not is_host():
		return
	state = 1 + randi() % ((1 << BITS) - 1)
	super(by)


func apply_state(now_running: bool, at: float) -> void:
	super(now_running, at)
	_place()


func _physics_process(delta: float) -> void:
	if not running:
		if is_host() and _wanted():
			host_start()
		return
	super(delta)


func _update(_delta: float) -> void:
	_place()


# ---------------------------------------------------------------------------
# The clock

## Seconds of one turn: the quiet, the warning and the move.
func turn_length() -> float:
	return hold_time + warn_time + move_time


## Seconds into the haunting (0 while the clock is stopped).
func clock() -> float:
	return elapsed if running else 0.0


## How many shifts have begun (the turn the clock is in, from 0).
func turn_at(t: float) -> int:
	return int(floorf(maxf(t, 0.0) / maxf(turn_length(), 0.1)))


## The layout the house is in through turn `n`'s quiet and warning (and leaves in its move).
func layout_of_turn(n: int) -> int:
	if n <= 0 or layouts < 2:
		return 0
	if _seeded != state:
		_seeded = state
		_sequence = [0]
	while _sequence.size() <= n:
		var k := _sequence.size()
		var before: int = _sequence[k - 1]
		var roll := hash(Vector2i(state, k)) & 0xffff
		_sequence.append((before + 1 + roll % (layouts - 1)) % layouts)
	return _sequence[n]


## The layout it is in now (while moving: the one it is leaving).
func now() -> int:
	return layout_of_turn(turn_at(clock()))


## The layout the next shift takes it to.
func next() -> int:
	return layout_of_turn(turn_at(clock()) + 1)


func _into_turn() -> float:
	return clock() - float(turn_at(clock())) * turn_length()


## Is the warning on (a shift is coming)?
func warning() -> bool:
	var t := _into_turn()
	return running and t >= hold_time and t < hold_time + warn_time


## Is the furniture on the move?
func moving() -> bool:
	return running and _into_turn() >= hold_time + warn_time


## 0..1 through the warning (0 at any other time).
func windup() -> float:
	return clampf((_into_turn() - hold_time) / maxf(warn_time, 0.01), 0.0, 1.0) if warning() else 0.0


## 0..1 through the move (0 at any other time).
func progress() -> float:
	return clampf((_into_turn() - hold_time - warn_time) / maxf(move_time, 0.01), 0.0, 1.0) if moving() else 0.0


## Seconds until the next warning begins.
func time_to_warning() -> float:
	var t := _into_turn()
	return maxf(hold_time - t, 0.0) if running else hold_time


# ---------------------------------------------------------------------------
# Where everything is

func _find_parts() -> void:
	if _found or not is_inside_tree():
		return
	_found = true
	_map = MapRoot.of(self)
	for n in get_tree().get_nodes_in_group(MapIsland.GROUP):
		if n is HauntProp and (_map == null or MapRoot.of(n) == _map):
			_props.append(n)
	for n in get_tree().get_nodes_in_group(MapGhost.GROUP):
		if _map == null or MapRoot.of(n) == _map:
			_ghosts.append(n)
	var holder := get_node_or_null(lights)
	if holder:
		var i := 0
		for light in holder.find_children("*", "OmniLight3D", true, false):
			_lights.append([light, (light as OmniLight3D).light_energy, float(i) * 1.7 + 0.3])
			i += 1


## Puts every prop where the clock says, and tells the map whether it is shifting.
func _place() -> void:
	if not is_inside_tree():
		return
	_find_parts()
	var t := clock()
	var a := now()
	var b := next()
	var is_moving := moving()
	var is_warning := warning()
	var p := progress()
	var w := windup()
	var glide := smoothstep(0.0, 1.0, p)
	for prop in _props:
		_pose(prop as HauntProp, t, a, b, is_moving, is_warning, p, glide, w)
	for g in _ghosts:
		(g as MapGhost).drive(t)
		(g as MapGhost).stir = w if is_warning else (1.0 - p if is_moving else 0.0)
	if _map:
		_map.layout_state = a
		_map.warning = is_warning
		_map.shifting = is_moving
	if running and _was_moving and not is_moving:
		_settled.call_deferred()
	if running and is_warning and not _was_warning:
		_sound(WARN_SOUND)
	if running and is_moving and not _was_moving and p < 0.5:
		_sound(SHIFT_SOUND)
	_was_moving = is_moving
	_was_warning = is_warning


func _pose(prop: HauntProp, t: float, a: int, b: int, is_moving: bool, is_warning: bool, p: float, glide: float, w: float) -> void:
	var at := prop.spot(a)
	var turn := prop.turn(a)
	var there := prop.is_shown(a)
	var presence := 1.0 if there else 0.0
	var solid := there
	if is_moving:
		at = at.lerp(prop.spot(b), glide)
		turn = lerpf(turn, prop.turn(b), glide)
		var comes := prop.is_shown(b)
		if there and not comes:
			presence = 1.0 - smoothstep(0.0, 0.45, p)   # gone at once (not solid), fading
			solid = false
		elif comes and not there:
			presence = smoothstep(0.35, 1.0, p) * 0.999   # solid only once the move is over
			solid = false
	elif is_warning and prop.changes(a, b):
		if prop.is_shown(b) and not there:
			# The doorway's ghost: a faint shimmer where the wall will be.
			presence = (0.08 + 0.1 * (0.5 + 0.5 * sin(t * 9.0 + prop.bob_phase * 20.0))) * w
		elif there:
			# The furniture that is about to go rattles where it floats.
			var shake := 0.035 * w * (0.6 + 0.4 * sin(t * 13.0))
			at += Vector3(sin(t * 41.0 + prop.bob_phase * 7.0), 0.0, cos(t * 37.0 + prop.bob_phase * 5.0)) * shake
			turn += sin(t * 29.0 + prop.bob_phase * 3.0) * 1.6 * w
	var phase := prop.bob_phase * TAU
	if prop.bob != 0.0 and prop.bob_period > 0.0:
		at.y += prop.bob * sin(TAU * t / prop.bob_period + phase)
	if prop.sway != 0.0 and prop.bob_period > 0.0:
		turn += prop.sway * sin(TAU * t / (prop.bob_period * 1.7) + phase * 1.3)
	if prop.twirl != 0.0:
		turn += prop.twirl * t
	prop.haunt = Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	prop.set_presence(presence, solid)


# ---------------------------------------------------------------------------
# After a shift: nobody left inside a wall or a wardrobe

## The move is over: whoever this copy plays (its own player, and on the host the bots)
## and is standing in a doorway that has closed, or inside furniture that came to rest
## on them, is put somewhere free beside it.
func _settled() -> void:
	_sound(SETTLE_SOUND)
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return
	var root: Node = arena.get("players_root")
	if root == null:
		return
	for p in root.get_children():
		if p.get("is_local") and p.get("alive"):
			free_player(p as Node3D)


## Puts `player` out of any door panel it stands in (to the nearer side) and off any
## piece of furniture it is caught inside. Returns true if it moved them.
func free_player(player: Node3D) -> bool:
	_find_parts()
	var feet := player.global_position
	for prop in _props:
		var hp := prop as HauntProp
		if not hp.door or not hp.solid_now:
			continue
		var box := hp.door_box()
		if not box.has_volume():
			continue
		var grown := box.grow(0.42)
		if feet.x < grown.position.x or feet.x > grown.end.x or feet.z < grown.position.z or feet.z > grown.end.z \
				or feet.y < box.position.y - 1.7 or feet.y > box.end.y:
			continue
		# Out through the thin side of the panel, to the nearer face.
		var middle := box.get_center()
		var out := feet
		if box.size.x < box.size.z:
			out.x = grown.end.x + 0.05 if feet.x >= middle.x else grown.position.x - 0.05
		else:
			out.z = grown.end.z + 0.05 if feet.z >= middle.z else grown.position.z - 0.05
		player.global_position = out
		return true
	if not _caught(player, feet):
		return false
	for r in [0.6, 1.0, 1.5, 2.1, 2.8]:
		for i in 12:
			var a := TAU * float(i) / 12.0
			for up in [0.0, 0.6]:
				var spot := feet + Vector3(sin(a) * r, up, cos(a) * r)
				if not _caught(player, spot) and _floor_under(player, spot):
					player.global_position = spot
					return true
	return false


func _caught(player: Node3D, feet: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3(0, 0.92, 0))
	q.collision_mask = 1
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	return not space.intersect_shape(q, 1).is_empty()


func _floor_under(player: Node3D, feet: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.4, 0), feet - Vector3(0, 1.6, 0), 1)
	if player is CollisionObject3D:
		ray.exclude = [(player as CollisionObject3D).get_rid()]
	return not space.intersect_ray(ray).is_empty()


# ---------------------------------------------------------------------------
# What you see, hear and feel

func _process(delta: float) -> void:
	_time += delta
	_flicker()
	var rumble := 0.0
	if warning():
		rumble = 0.05 + 0.12 * windup()
	elif moving():
		rumble = 0.22 * (1.0 - 0.6 * progress())
	if rumble > 0.0:
		_shake_wait -= delta
		if _shake_wait <= 0.0:
			_shake_wait = 0.08
			_shake(rumble)


## Candles flicker all the time; through the warning they stutter and gutter, and while
## the house moves they burn low.
func _flicker() -> void:
	if _lights.is_empty():
		_find_parts()
	var t := clock() if running else _time
	var w := windup()
	var p := progress()
	for l in _lights:
		var light := l[0] as OmniLight3D
		if not is_instance_valid(light):
			continue
		var s: float = l[2]
		var calm := 0.9 + 0.06 * sin(t * 7.1 + s) + 0.04 * sin(t * 17.3 + s * 3.0)
		var level := calm
		if warning():
			var stutter := 1.0 if fposmod(t * (6.0 + s) + s, 1.0) > 0.35 * w else 0.15
			level = lerpf(calm, calm * stutter, w)
		elif moving():
			level = calm * lerpf(0.3, 1.0, smoothstep(0.6, 1.0, p))
		light.light_energy = float(l[1]) * level


func _shake(amount: float) -> void:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return
	var player: Node = arena.get("local_player")
	if player != null and is_instance_valid(player) and player.get("rig") != null and player.get("alive"):
		player.shake(amount)


## Heard all through the house: not placed in the world.
func _sound(which: String) -> void:
	var dev := autoload("DevArgs")
	if dev and dev.sound_log:
		print("SFX %s" % which)
	var sound := autoload("Sound")
	if sound == null or sound.silent:
		return
	sound.play(which)
