class_name RaceBrain
extends RefCounted
## A computer racer. Like BotBrain it only fills in the racer's PlayerInput, so it
## moves by exactly the same rules as you do.
##
## It follows the map's bot route (MapRoutePoint nodes under "BotRoute"): it runs
## to each point in turn and, on reaching one, does that point's action (jump,
## slide, wall-run, grapple...) on its way to the next. When it is sent back to a
## checkpoint it picks the route up again from there. If it gets nowhere for a
## while, it presses R like a person would.
##
## Difficulty: Expert never hesitates; easier bots pause before the hard bits, and
## Normal and Easy sometimes fluff a trick (a flip too late, a jump too early), so
## they fall and lose time at their checkpoint.

const A := MapRoutePoint.Action
const TURN := 14.0           ## how quickly it turns to face where it runs (per second)
const STUCK_TIME := 5.0      ## seconds without getting closer to its next point before it resets
const LOST_DROP := 4.0       ## standing this far below its next point (and not on its way down to it): it fell
## [hesitation before a hard move (s), chance to fluff a trick] for Easy .. Expert
const JUMPS := [A.JUMP, A.LONG_JUMP, A.DIVE_JUMP, A.FLIP_DIVE, A.BOOST_JUMP, A.FLOAT_JUMP]
## How far up a BOOST_JUMP tips the rocket boots (1 = as far up as forward).
const BOOST_TILT := 0.45
## Speed on the plain stretches between obstacles (run-ups to jumps stay flat out).
const PACE := [0.72, 0.82, 0.92, 1.0]
const SKILL := [[0.7, 0.12], [0.35, 0.05], [0.12, 0.0], [0.0, 0.0]]

var me: Player
var input: PlayerInput
var level := 3

var _rng := RandomNumberGenerator.new()
var _route: Array = []
var _gate_index: Array = []   # gates passed -> the route point to head for after coming back there
var _idx := 0                 # the point it is running to
var _act := A.RUN             # the action of the point it last reached
var _act_from := -1           # ...and that point's index
var _act_time := 0.0
var _phase := 0               # step within the action (jumped, flipped, hooked...)
var _wait := 0.0              # hesitation left before the action starts
var _fluff := false           # this time it gets the trick wrong
var _seen_blocked := false
var _last_jump := 0.0
var _best := INF              # closest it has been to its next point
var _stall := 0.0
var _low := 0.0
var _hook := Vector3.ZERO
var _log_time := 0.0
var _last_dive := 0.0
var _pace := 1.0              # how hard it runs the plain stretches (lower levels, and each bot a bit different)


func _init(player: Player, difficulty: int) -> void:
	me = player
	input = player.input
	level = clampi(difficulty, 0, 3)
	_rng.randomize()
	Race.sent_back.connect(_on_sent_back)


func _setup() -> void:
	var layout: MapRoot = Net.arena.layout
	_pace = minf(PACE[level] * _rng.randf_range(0.96, 1.04), 1.0)
	_route = layout.route
	_gate_index = [0]
	for c in layout.checkpoints:
		var beyond: Vector3 = (c.xf as Transform3D) * Vector3(0, 0, -4)
		var best := 0
		var best_d := INF
		for i in _route.size():
			var d := (_route[i].pos as Vector3).distance_to(beyond)
			if d < best_d:
				best_d = d
				best = i
		_gate_index.append(best)
	_idx = _nearest_ahead(0)
	if me.is_local and not me.is_bot and not DevArgs.spawn.is_empty():
		_idx = _nearest_to_here()   # autopilot from a --spawn part way round (screenshots)


func update(delta: float) -> void:
	input.move = Vector2.ZERO
	input.sprint = false
	input.crouch = false
	input.dive = false
	input.grapple = false
	input.aim_origin = Vector3.ZERO
	input.aim_dir = Vector3.ZERO
	if _route.is_empty():
		if Net.arena == null or not is_instance_valid(Net.arena) or Net.arena.layout.route.is_empty():
			return
		_setup()
	if not me.alive or Race.finished(me.peer_id) or _idx >= _route.size():
		_coast(delta)
		return
	if Race.frozen():
		_face((_route[_idx].pos as Vector3) - me.global_position, delta, 1.0)
		return
	_act_time += delta
	_last_jump += delta
	_check_reached()
	if _idx >= _route.size():
		return
	var target: Dictionary = _route[_idx]
	var dir := _pursue(target.pos)
	_do_action(delta, dir, target)
	_watch_progress(delta, target)
	if DevArgs.sync_log:
		_log_time -= delta
		if _log_time <= 0.0:
			_log_time = 0.5
			var p := me.global_position
			print("RACER %d t=%.1f %.1f %.1f %.1f v=%.1f %s idx=%d act=%s ph=%d" % [me.peer_id, Race.time, p.x, p.y, p.z,
				Vector2(me.velocity.x, me.velocity.z).length(), MovementController.State.keys()[me.motor.state] + ("+rope" if me.motor.grapple.attached else ""), _idx,
				A.keys()[_act], _phase] + ((" hit=%s %s %s" % [me.get_last_slide_collision().get_collider().name, me.get_last_slide_collision().get_position(), me.get_last_slide_collision().get_collider_shape().transform.origin if me.get_last_slide_collision().get_collider_shape() else ""]) if me.get_last_slide_collision() else ""))


## After the finish (or with nowhere to go): ease to a stop.
func _coast(_delta: float) -> void:
	input.move = Vector2.ZERO


# ---------------------------------------------------------------------------
# The route

func _check_reached() -> void:
	if _act == A.GRAPPLE and _phase in [1, 2] and not me.is_on_floor():
		return   # still swinging: the next point counts once it lets go
	if _act in [A.WAIT_GROUND, A.WAIT_CLEAR] and _phase == 0:
		return   # still waiting for its moment
	if _act in [A.BOOST_JUMP, A.BOOST_UP] and _phase == 0:
		return   # waiting for its boots to charge
	var guard := 0
	while _idx < _route.size() and guard < 4 and _reached(_idx):
		guard += 1
		_start_action(_idx)
		_idx += 1
		_best = INF
		_stall = 0.0


## Close enough, or gone past it (a fast racer, or one in the air, does not have
## to touch it).
func _reached(i: int) -> bool:
	var p: Dictionary = _route[i]
	var pos := me.global_position
	var point: Vector3 = p.pos
	var dy := pos.y - point.y
	if dy < -3.0 or dy > 6.0:
		return false
	if _flat(pos, point) < float(p.radius):
		return true
	if i == 0:
		return false
	var along: Vector3 = point - (_route[i - 1].pos as Vector3)
	along.y = 0.0
	if along.length() < 0.1:
		return false
	var past := pos - point
	past.y = 0.0
	var side := past - along.normalized() * past.dot(along.normalized())
	return past.dot(along) > 0.0 and side.length() < maxf(float(p.radius) * 2.5, 2.5)


## The first point at or after `from` that it has not gone past.
func _nearest_ahead(from: int) -> int:
	return clampi(from, 0, maxi(_route.size() - 1, 0))


## The route point to head for from where it stands: the closest one, or the one after
## it if it is already past that.
func _nearest_to_here() -> int:
	var pos := me.global_position
	var best := 0
	var best_d := INF
	for i in _route.size():
		var d := pos.distance_to(_route[i].pos)
		if d < best_d:
			best_d = d
			best = i
	if best + 1 < _route.size():
		var a: Vector3 = _route[best].pos
		var b: Vector3 = _route[best + 1].pos
		if (pos - a).dot(b - a) > 0.0:
			best += 1
	return best


func _on_sent_back(id: int, _reason: String) -> void:
	if id != me.peer_id or _route.is_empty():
		return
	var n := clampi(Race.gates_passed(id), 0, _gate_index.size() - 1)
	_idx = _gate_index[n]
	# Coming back to a gate, the point right by it counts as reached.
	_act = A.RUN
	_act_from = -1
	_phase = 0
	_best = INF
	_stall = 0.0
	_low = 0.0


func _start_action(i: int) -> void:
	var p: Dictionary = _route[i]
	_act = p.action
	_act_from = i
	_act_time = 0.0
	if DevArgs.sync_log:
		print("RACER %d reached %d %s at %s" % [me.peer_id, i, A.keys()[p.action], me.global_position.snappedf(0.1)])
	_phase = 0
	_seen_blocked = false
	var hard: bool = _act in [A.LONG_JUMP, A.DIVE_JUMP, A.FLIP_DIVE, A.WALL_RUN, A.CHIMNEY, A.GRAPPLE, A.WAIT_GROUND,
		A.BOOST_JUMP, A.BOOST_UP, A.FLOAT_JUMP]
	# It sizes up standing starts (a chimney, a moving platform); a running jump
	# keeps its run-up.
	_wait = SKILL[level][0] * _rng.randf_range(0.5, 1.0) if _act in [A.CHIMNEY, A.WAIT_GROUND] and me.is_on_floor() else 0.0
	_fluff = _rng.randf() < SKILL[level][1] and hard


# ---------------------------------------------------------------------------
# Doing it

func _do_action(delta: float, dir: Vector3, target: Dictionary) -> void:
	var grounded := me.is_on_floor()
	var vy := me.velocity.y
	input.sprint = _act != A.WALK
	if _wait > 0.0 and grounded:
		_wait -= delta   # sizing it up
		_face(dir, delta, 1.0)
		return
	var move := dir
	var look := dir
	match _act:
		A.JUMP, A.LONG_JUMP, A.DIVE_JUMP, A.FLIP_DIVE:
			if _phase == 0:
				# Square up first: on the ground it turns in a frame or two, and a
				# take-off at an angle carries it off the side of a narrow landing.
				move = _line_dir(target.pos)
				look = move
				var hvel := Vector3(me.velocity.x, 0.0, me.velocity.z)
				if grounded and _act_time < 0.1 and hvel.length() > 1.0 and hvel.normalized().dot(move) < 0.985:
					pass
				else:
					if grounded or _act_time < 0.15:
						_jump()
					_phase = 1
			elif _act != A.JUMP and _phase == 1 and not grounded and vy < (2.5 if _fluff else 1.0) and _last_jump > 0.15:
				# Tricks go straight down the course (not wherever it was drifting).
				move = _line_dir(target.pos)
				look = move
				if _carries_to(target.pos) and not _fluff:
					_phase = 4   # going fast enough already: a trick would overshoot the landing
				elif _act == A.DIVE_JUMP:
					input.dive_pressed = true
					_phase = 3
				else:
					_jump()   # in the air: a flip forward
					_phase = 2
			elif _phase == 2 and _act == A.FLIP_DIVE and not grounded and _last_jump > 0.3 and vy < 1.0:
				input.dive_pressed = true
				_phase = 3
		A.BOOST_JUMP:
			move = _line_dir(target.pos)
			look = move
			if _phase == 0:
				# Boots still charging: wait at the edge rather than jump short.
				if me.motor.boost_readiness() < 1.0 and grounded:
					_hold_at(_route[_act_from].pos, target.pos, delta)
					return
				var hvel := Vector3(me.velocity.x, 0.0, me.velocity.z)
				if not (grounded and _act_time < 0.1 and hvel.length() > 1.0 and hvel.normalized().dot(move) < 0.985):
					if grounded or _act_time < 0.15:
						_jump()
					_phase = 1
			elif _phase == 1 and not grounded and _last_jump > (0.25 if _fluff else 0.08):
				input.boost_pressed = true
				input.boost_dir = (move + Vector3.UP * BOOST_TILT).normalized()
				_phase = 2
			elif _phase == 2 and not grounded and vy < 0.5 and not _carries_to(target.pos) and me.motor.dive_readiness() >= 1.0:
				input.dive_pressed = true   # still short: stretch it with a dive
				_phase = 3
		A.BOOST_UP:
			move = dir
			if _phase == 0:
				if me.motor.boost_readiness() < 1.0 and grounded:
					_hold_at(_route[_act_from].pos, target.pos, delta)
					return
				if grounded or _act_time < 0.15:
					_jump()
				_phase = 1
			elif _phase == 1 and not grounded and _last_jump > 0.06:
				input.boost_pressed = true
				input.boost_dir = (Vector3(dir.x, 0.0, dir.z) * 0.25 + Vector3.UP).normalized()
				_phase = 2
		A.FLOAT_JUMP:
			move = _line_dir(target.pos)
			look = move
			if _phase == 0:
				var hvel := Vector3(me.velocity.x, 0.0, me.velocity.z)
				if not (grounded and _act_time < 0.1 and hvel.length() > 1.0 and hvel.normalized().dot(move) < 0.985):
					if grounded or _act_time < 0.15:
						_jump()
					_phase = 1
			elif _phase == 1 and not grounded and vy < (-1.5 if _fluff else 0.6) and _last_jump > 0.15:
				if _carries_to(target.pos) and not _route_boost():
					_phase = 4
				else:
					input.yaw = atan2(-move.x, -move.z)   # floats go the way it faces: face down the course first
					input.float_pressed = true
					_phase = 2
			elif _phase == 2 and _route_boost() and _act_time > 0.2 and me.motor.state == MovementController.State.FLOAT \
					and me.motor.boost_readiness() >= 1.0:
				input.boost_pressed = true
				input.boost_dir = move
				_phase = 3
			if _phase in [2, 3] and me.motor.state == MovementController.State.FLOAT:
				move = Vector3.ZERO   # no steering while floating anyway
		A.SLIDE:
			input.crouch = true
			if _phase == 0:
				input.crouch_pressed = true
				_phase = 1
		A.CRAWL:
			input.dive = true
			var down: bool = me.motor.state in [MovementController.State.DIVE, MovementController.State.BELLY_SLIDE]
			if _phase == 0 or (not down and grounded and _act_time - _last_dive > 0.5):
				input.dive_pressed = true   # (again, if the first one did not take)
				_last_dive = _act_time
				_phase = 1
		A.WALL_RUN:
			if _phase == 0:
				_jump()
				_phase = 1
		A.WALL_JUMP:
			if _phase == 0:
				if me.motor.state == MovementController.State.WALL_RUN or not grounded:
					_jump()
				_phase = 1
		A.CHIMNEY:
			var top: float = (target.pos as Vector3).y
			move = Vector3.ZERO
			if _phase == 0:
				# Stop right by one wall first (running in, a jump would carry it out).
				var spot: Vector3 = _route[_act_from].pos
				var off := spot - me.global_position
				off.y = 0.0
				var speed := Vector2(me.velocity.x, me.velocity.z).length()
				input.sprint = false
				if grounded and off.length() < 0.45 and speed < 0.6:
					_jump()
					_phase = 1
				else:
					move = off.normalized() * clampf(off.length() * 2.0, 0.0, 1.0) if off.length() > 0.1 else Vector3.ZERO
					if speed > 4.0 and off.dot(me.velocity) < 0.0:
						move = -me.velocity.normalized()   # ran past: brake hard
			else:
				# Keep level with its spot along the shaft (drifting along it carries it out).
				var spot: Vector3 = _route[_act_from].pos
				var along := (target.pos as Vector3) - spot
				along.y = 0.0
				along = along.normalized()
				var drift := (spot - me.global_position).dot(along)
				move = along * clampf(drift, -1.0, 1.0) * 0.6
				var side_wall := absf(me.motor.last_wall().dot(along)) < 0.5
				if me.global_position.y > top - 2.8:
					move = dir   # nearly level with the top: reach for the ledge
				if not grounded and _last_jump > 0.1 and me.motor.can_wall_jump() and side_wall \
						and me.global_position.y < top - 1.2:
					_jump()   # off the wall it is touching, across to the other
				elif grounded and _act_time > 0.3 and _last_jump > 0.3:
					_jump()
		A.GRAPPLE:
			var g := me.motor.grapple
			var p: Dictionary = _route[_act_from]
			var anchor: Vector3 = (p.pos as Vector3) + (p.aim as Vector3)
			var swing := Vector3(p.aim.x, 0.0, p.aim.z).normalized()   # the way it swings: on, past the anchor
			if _phase == 0:
				if grounded:
					_jump()
				_phase = 1
			if _phase == 1:
				_look_at(anchor)
				if not grounded and g.ready_to_fire() and _last_jump > 0.08:
					input.grapple = true
					input.grapple_pressed = true
				if g.attached:
					input.grapple = true
					_phase = 2
				_steer(swing)
				return
			if _phase == 2:
				if g.attached:
					input.grapple = true
					_look_at(anchor)
					var past := (me.global_position - anchor).dot(swing)
					var hv := Vector2(me.velocity.x, me.velocity.z).length()
					if past > 1.0 and (vy >= 0.8 * hv or vy < 0.0):
						input.grapple = false
						_phase = 3
						if _route_boost() and me.motor.boost_readiness() >= 1.0:
							# Let go with a rocket burst on toward the next point.
							var on := Vector3(dir.x, 0.0, dir.z).normalized()
							input.boost_pressed = true
							input.boost_dir = (on + Vector3.UP * 0.35).normalized()
					elif _act_time > 4.0:
						input.grapple = false
						_phase = 3
					_steer(swing)
					return
				_phase = 3
		A.WAIT_GROUND:
			var p: Dictionary = _route[_act_from]
			var spot: Vector3 = (p.pos as Vector3) + (p.aim as Vector3)
			if _phase == 0:
				# From solid ground it waits for the platform to come round (so it has
				# the whole time it is up); from another moving platform it goes as soon
				# as the next is there (its own is about to sink).
				var there := _ground_at(spot)
				var layout: MapRoot = Net.arena.layout
				# When will it get there (run, jump, land)? Go only if the platform is up
				# then and stays up a while after.
				var arrive := layout.clock + me.global_position.distance_to(spot) / 11.0 + 0.45
				var later := layout.mover_ground_at(spot, arrive)
				var ok := there and (_seen_blocked or _on_mover())
				if later >= 0:
					ok = later == 1 and layout.mover_ground_at(spot, arrive + 0.9) == 1
				if not there:
					_seen_blocked = true
				if (ok and grounded) or _act_time > 12.0:
					_phase = 1
				else:
					_hold_at(p.pos, spot, delta)
					return
		A.WAIT_CLEAR:
			var p: Dictionary = _route[_act_from]
			var spot: Vector3 = (p.pos as Vector3) + (p.aim as Vector3)
			if _phase == 0:
				if _path_clear(target.pos) or _act_time > 15.0:
					_phase = 1
					if DevArgs.sync_log:
						print("RACER %d go at clock %.2f from %s to %s v=%.1f" % [me.peer_id, Net.arena.layout.clock, me.global_position, target.pos, me.velocity.length()])
				else:
					_hold_at(p.pos, spot, delta)
					return
	_face(look, delta, 1.0)
	# Too fast and already heading the right way: let go rather than strafe it faster
	# still (bunny-hops off the strips would carry it past the next landing). Off
	# line it keeps steering, whatever the speed.
	var hvel := Vector3(me.velocity.x, 0.0, me.velocity.z)
	var flat_move := Vector3(move.x, 0.0, move.z)
	var on_line := hvel.length() > 12.5 and flat_move.length() > 0.01 and hvel.normalized().dot(flat_move.normalized()) > 0.97
	if on_line and not grounded and (_act == A.JUMP or _phase == 4 or (_act == A.BOOST_JUMP and _phase >= 2)):
		move = Vector3.ZERO
	elif grounded and _act == A.RUN and int(target.action) not in JUMPS and int(target.action) != A.WALL_RUN and _pace < 1.0:
		move = move.normalized() * _pace
	elif grounded and hvel.length() > 12.0 and flat_move.length() > 0.01 and _act not in [A.SLIDE, A.CRAWL]:
		# Ask for no more than it already has along the new heading, so turning at
		# speed bleeds it off (friction) instead of strafing it up.
		var cos_a := hvel.normalized().dot(flat_move.normalized())
		move = move.normalized() * clampf(hvel.length() * cos_a / 11.5 - 0.1, 0.3, 0.9)
	_steer(move)


## Does the point it is acting on ask for the rocket boots too?
func _route_boost() -> bool:
	return _act_from >= 0 and bool((_route[_act_from] as Dictionary).get("boost", false))


## Which way to run for `goal`: along the line from the last point to it, aiming a
## few metres ahead on that line (so it runs down the middle of the course, not
## cutting across at an angle from wherever it happens to be).
func _pursue(goal: Vector3) -> Vector3:
	var pos := me.global_position
	var to := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
	if _idx == 0 or _act not in [A.RUN, A.JUMP, A.LONG_JUMP, A.DIVE_JUMP, A.FLIP_DIVE, A.SLIDE, A.WALK]:
		return to.normalized()   # wall runs, swings and climbs aim straight at their marks
	var a: Vector3 = _route[_idx - 1].pos
	var line := Vector3(goal.x - a.x, 0.0, goal.z - a.z)
	var length := line.length()
	if length < 3.0:
		return to.normalized()
	var along := line / length
	var rel := Vector3(pos.x - a.x, 0.0, pos.z - a.z)
	var s := rel.dot(along)
	var off := absf(rel.dot(along.cross(Vector3.UP)))
	if off > 6.0 or s > length:
		return to.normalized()
	# Close to a take-off: run parallel to the line, so it leaves the edge going
	# straight (sideways speed only bleeds off with friction, which takes a moment).
	if int(_route[_idx].action) in JUMPS and length - s < 4.5:
		return _against_drift(along)
	var ahead := a + along * minf(maxf(s, 0.0) + 7.0, length)
	return _against_drift(Vector3(ahead.x - pos.x, 0.0, ahead.z - pos.z).normalized())


## On the ground, lean against sideways speed (left over from a wall kick or a
## swing) so it bleeds off quickly: when you are faster than you can run, steering
## straight ahead adds nothing, and only friction would take it away.
func _against_drift(d: Vector3) -> Vector3:
	if not me.is_on_floor():
		return d
	var h := Vector3(me.velocity.x, 0.0, me.velocity.z)
	var side := h - d * h.dot(d)
	if side.length() < 1.0:
		return d
	return (d - side.normalized() * minf(side.length() / 4.0, 1.0)).normalized()


## The way the route runs into `goal` (from the point before it).
func _line_dir(goal: Vector3) -> Vector3:
	var a: Vector3 = _route[maxi(_idx - 1, 0)].pos
	var line := Vector3(goal.x - a.x, 0.0, goal.z - a.z)
	if line.length() < 0.5:
		line = Vector3(goal.x - me.global_position.x, 0.0, goal.z - me.global_position.z)
	return line.normalized()


## Will a plain fall from here (no trick) reach `land`?
func _carries_to(land: Vector3) -> bool:
	var h := me.global_position.y - land.y
	var vy := me.velocity.y
	var g := 22.0
	var disc := vy * vy + 2.0 * g * h
	if disc < 0.0:
		return false
	var t := (vy + sqrt(disc)) / g
	var hv := Vector2(me.velocity.x, me.velocity.z).length()
	return hv * t >= _flat(me.global_position, land) - 1.0


## Waiting: stand on `point` (braking back to it if it ran past), looking at `spot`.
func _hold_at(point: Vector3, spot: Vector3, delta: float) -> void:
	_face(spot - me.global_position, delta, 1.0)
	input.sprint = false
	var back := point - me.global_position
	back.y = 0.0
	if back.length() > 0.25:
		_steer(back.normalized() * clampf(back.length(), 0.3, 1.0))


func _jump() -> void:
	input.jump_pressed = true
	input.jump_held = true
	_last_jump = 0.0


## Will the way to `to` stay clear of every hazard if it sets off now? It looks
## ahead at where the moving hazards will be as it runs (from a standstill, at
## sprint speed), with a little room to spare.
func _path_clear(to: Vector3) -> bool:
	var layout: MapRoot = Net.arena.layout
	var from := me.global_position + Vector3(0, 0.9, 0)
	var end := to + Vector3(0, 0.9, 0)
	var length := from.distance_to(end)
	var t := 0.0
	var margin := 0.7 + 0.1 * (3 - level)
	var v := Vector2(me.velocity.x, me.velocity.z).length()
	var d := 0.0
	while t < 3.0:
		t += 0.025
		v = minf(v + 120.0 * 0.025, 11.0)   # it gets up to speed in a moment
		d += v * 0.025
		var at := from.lerp(end, minf(d / maxf(length, 0.1), 1.0))
		for y in [-0.6, 0.0, 0.4]:   # feet to head; the margin is mostly for timing
			if layout.hazard_at(at + Vector3(0, y, 0), margin, layout.clock + t):
				return false
		if d >= length:
			return true
	return true


## Standing on something that moves?
func _on_mover() -> bool:
	var from := me.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 1.0, 0), 1, [me.get_rid()])
	var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider is AnimatableBody3D


## Is there something to stand on at `spot` (a moving platform that has come round)?
func _ground_at(spot: Vector3) -> bool:
	var from := spot + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, spot - Vector3(0, 0.6, 0), 1, [me.get_rid()])
	return not me.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Not getting anywhere: back to the checkpoint, like pressing R.
func _watch_progress(delta: float, target: Dictionary) -> void:
	var d := me.global_position.distance_to(target.pos)
	if d < _best - 0.5:
		_best = d
		_stall = 0.0
	else:
		_stall += delta
	var below: float = (target.pos as Vector3).y - me.global_position.y
	if below > LOST_DROP and me.is_on_floor() and _act not in [A.CHIMNEY]:
		_low += delta
	else:
		_low = 0.0
	var waiting: bool = _act in [A.WAIT_CLEAR, A.WAIT_GROUND] and _phase == 0
	if waiting:
		_stall = 0.0   # standing still on purpose
	if (_stall > STUCK_TIME and not waiting) or _low > 1.0:
		_stall = 0.0
		_low = 0.0
		Race.send_back(me, "reset")


func _face(dir: Vector3, delta: float, _rate: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	var want := atan2(-flat.x, -flat.z)
	input.yaw += wrapf(want - input.yaw, -PI, PI) * minf(TURN * delta, 1.0)
	input.pitch = lerpf(input.pitch, 0.0, minf(TURN * delta, 1.0))


func _look_at(point: Vector3) -> void:
	var to := point - me.eye_position()
	input.yaw = atan2(-to.x, -to.z)
	input.pitch = atan2(to.y, Vector2(to.x, to.z).length())


## Push toward `world_dir`, whichever way it is looking.
func _steer(world_dir: Vector3) -> void:
	if world_dir.length() < 0.01:
		input.move = Vector2.ZERO
		return
	var local := world_dir.rotated(Vector3.UP, -input.yaw)
	input.move = Vector2(local.x, -local.z).limit_length(1.0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
