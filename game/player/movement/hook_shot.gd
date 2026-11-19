class_name HookShot
extends Grapple
## Grappling Hook 2: the same rope as the grappling hook (see Grapple), but the hook
## is a projectile, not an instant hit.
##
##  1. Fire: the hook leaves at HookLine.SPEED along your aim, paying out rope with
##     slack in it. You are free to run, jump and shoot while it flies. It catches
##     the first surface (or player) on its way; with nothing within the grapple's
##     range it comes back and the cooldown starts. Letting go of the button calls
##     it back early.
##  2. Bite: the hook has caught, but the rope is still loose, so nothing pulls yet.
##     The winch takes the slack in, faster and faster (HookLine.reeled). Moving
##     away from the hook uses the slack up sooner; moving toward it, later.
##  3. Taut: the moment the rope is as short as the distance to the hook it snaps
##     tight: a harder yank than the first hook's (the winch is already spinning),
##     then exactly its pull, swing and release. From here on it IS a Grapple.
##  4. Back: let go (or a miss), the hook comes back to the wrist, straight at you
##     wherever you have got to. While you hold the button it catches the first
##     surface in its way (2. again): miss, and it can still snag the ledge you have
##     dropped behind; let go, then press again as it comes back, for the same.
##     A jump off the rope does not count as holding on: the hook just comes back.
##
## Because the hook takes time to arrive, you lead a moving target and commit a
## moment before the pull; the harder yank is what you get for it.
##
## Aim magnets still help, at the moment of firing: a grapple point near the
## crosshair is flown to, and a player near it is led by their speed. In flight the
## hook also catches a player it passes within PLAYER_ASSIST of.
##
## Everything that happens is written into `line` (HookLine) as it happens, on
## `clock` (seconds of this body's movement). The rope and hook are drawn from that
## record alone, here and on every other copy of the game (see HookLine).

const YANK := 1.4             ## the snap as the rope pulls tight, against the first hook's yank
const PLAYER_ASSIST := 0.7    ## the hook catches a player whose chest it passes this close to (metres)
const BACK_CATCH_MIN := 2.5   ## coming back, it catches nothing nearer to you than this (metres)
const BACK_SLACK_MIN := 0.6   ## a hook that catches on its way back has at least this much slack to take in (metres)

var flying := false           ## the hook is on its way
var biting := false           ## it has caught; the slack is coming in
var returning := false        ## let go: it is on its way back
var clock := 0.0              ## seconds this hook's body has been simulated
var line := HookLine.new()    ## this shot (or the last one)
var shots := 0

var _dir := Vector3.FORWARD
var _reach := 0.0             # the flight ends this far out
var _goal: MapGrapplePoint    # flying to a grapple point (it needs nothing solid to hit)
var _bite_at := 0.0           # clock when it bit
var _rope := 0.0              # rope out when it bit
var _just_taut := false
var _chest := Vector3.ZERO    # where the rope met the body, at the last step
var _snag := false            # on its way back the hook may catch (while the button is held: see release)
var _back_from := Vector3.ZERO   # the way back: from here...
var _back_at := 0.0           # ...setting off at this clock...
var _back_time := 0.0         # ...and due at the wrist this long after
var _back_prev := Vector3.ZERO   # where the hook was a step ago


func update(delta: float) -> void:
	clock += delta
	super.update(delta)


func ready_to_fire() -> bool:
	return super.ready_to_fire() and not flying and not biting and not returning


func busy() -> bool:
	return flying or biting


func rope_out() -> bool:
	return attached or flying or biting or returning


func rope_end() -> Vector3:
	if flying:
		return line.flight_pos(clock)
	return _back_prev if returning else anchor


## Fires the hook. Never attached at once (returns false): see take_hooked.
func try_attach(body: CollisionObject3D, input: PlayerInput) -> bool:
	if returning:
		_snag = true   # pressed again as the hook comes back: held, it may catch on the way
	if not ready_to_fire():
		return false
	var eye := body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	var space := body.get_world_3d().direct_space_state
	var exclude := [body.get_rid()]
	var aim := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD
	_reach = tuning.grapple_range
	_goal = null
	var snap := _magnet_target(body, input, space, eye, exclude)
	if not snap.is_empty():
		var at: Vector3 = snap.point
		if snap.collider is MapGrapplePoint:
			_goal = snap.collider
			_reach = eye.distance_to(at)   # (a grapple point's reach can be longer than the hook's)
		else:   # a player: aim where they will be when the hook gets there
			var their_speed: Vector3 = snap.collider.get("velocity")
			at += their_speed * (eye.distance_to(at) / HookLine.SPEED)
		if eye.distance_to(at) > 0.1:
			aim = (at - eye).normalized()
	elif input.aim_dir != Vector3.ZERO:
		# Third person: at whatever is under the crosshair, from the eyes.
		var far := input.aim_origin + input.aim_dir * (_reach + 6.0)
		var q := PhysicsRayQueryParameters3D.create(input.aim_origin, far, _mask(), exclude)
		var hit := space.intersect_ray(q)
		var to: Vector3 = (hit.position if not hit.is_empty() else far) - eye
		aim = to.normalized() if to.length() > 0.5 and to.normalized().dot(input.aim_dir) > 0.2 else input.aim_dir
	_dir = aim
	flying = true
	shots = shots % 250 + 1
	line.launch(shots, clock, eye, aim * HookLine.SPEED)
	return false


## Every step: the hook flies, the slack comes in. (The movement code calls this with
## the body, right after update.)
func follow_target(body: Node3D, delta: float) -> void:
	super.follow_target(body, delta)
	_chest = rope_origin(body)
	if flying:
		_fly(body as CollisionObject3D, delta)
	elif biting:
		_take_in_slack(body)
	elif returning:
		_come_back(body as CollisionObject3D)
	if attached and (target != null or carrier != null):
		line.anchor = anchor   # it rides on what it is hooked to


## Has the rope just pulled tight? True once, on the step it did: the movement code
## gives the yank then.
func take_hooked() -> bool:
	var was := _just_taut
	_just_taut = false
	return was


## Lets go: the hook sets off back to the wrist (see _come_back).
func release() -> void:
	var out := flying or biting or attached
	var at := anchor
	var slack := 0.0   # in the rope as it is let go
	if flying:
		slack = HookLine.flight_slack(line.travel(clock))
	elif biting:
		slack = maxf(_rope - HookLine.reeled(clock - _bite_at) - _chest.distance_to(anchor), 0.0)
	if flying or biting:
		flying = false
		biting = false
		target = null
		carrier = null
		cooldown_left = tuning.grapple_cooldown
	super.release()
	_just_taut = false
	if not out:
		return
	line.t_stop = minf(line.t_stop, clock)
	_back_from = line.back_from(at)
	var dist := _back_from.distance_to(_chest)
	_back_time = HookLine.back_time_for(dist)
	_back_at = clock
	_back_prev = _back_from
	returning = true
	# Let go of the button: it may catch again once the button is pressed again. Let
	# go any other way with the button still down (a jump off the rope, a slam): not
	# until a new press (try_attach), or every jump off would hook the next thing.
	_snag = not held
	line.let_go(clock, _back_time, slack + HookLine.LIMP * dist)


func reset() -> void:
	super.reset()
	flying = false
	biting = false
	returning = false
	_snag = false
	_just_taut = false
	line.drop(clock)


func yank(body: Node3D, vel: Vector3) -> Vector3:
	speed_cap = maxf(vel.length(), tuning.grapple_pull_speed)
	return _add_toward(body, vel, tuning.grapple_yank * YANK)


func _mask() -> int:
	return 1 | (1 << 1) if hook_players else 1   # the level, and other players


## One step of flight: from where the hook was to where it is now, catching the first
## thing on the way.
func _fly(body: CollisionObject3D, delta: float) -> void:
	var gone := HookLine.SPEED * (clock - line.t_launch)   # how far out it is by now...
	var before := maxf(gone - HookLine.SPEED * delta, 0.0)    # ...and was a step ago
	var upto := minf(gone, _reach)
	var from := line.origin + _dir * before
	var to := line.origin + _dir * upto
	var hit := {}
	if upto > before:
		var q := PhysicsRayQueryParameters3D.create(from, to, _mask(), [body.get_rid()])
		hit = body.get_world_3d().direct_space_state.intersect_ray(q)
	var stop := upto if hit.is_empty() else before + from.distance_to(hit.position)
	var caught: Node3D = hit_player(hit)
	if hook_players:
		# A near miss still catches: the first player whose chest the hook passes close to.
		var near := _player_near(body, from, _dir, stop - before)
		if not near.is_empty():
			caught = near.player
			stop = before + float(near.along)
			hit = {"collider": caught, "position": from + _dir * float(near.along)}
	if hit.is_empty() and _goal != null and upto >= _reach - 0.001 and is_instance_valid(_goal) and _goal.is_visible_in_tree():
		hit = {"collider": _goal, "point": _goal.global_position}   # arrived at the grapple point
	if hit.is_empty():
		if upto >= _reach - 0.001:
			line.t_stop = line.t_launch + _reach / HookLine.SPEED
			release()   # ran out of rope with nothing caught...
			_snag = true   # ...but held, it can still catch something on its way back
		return
	_bite(body, hit, caught, line.t_launch + stop / HookLine.SPEED)


## The player (not `body`) whose chest is nearest the start of the stretch from
## `from` along `dir` for `length` metres, and within PLAYER_ASSIST of it, with no
## wall between. Empty if none: otherwise {player, along (metres from `from`)}.
func _player_near(body: CollisionObject3D, from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var best := {}
	if body.get_parent() == null:
		return best
	var space := body.get_world_3d().direct_space_state
	for other in body.get_parent().get_children():
		if other == body or not (other is CharacterBody3D) or other.get("alive") != true \
				or not other.has_method("visible_in_world") or not other.visible_in_world():
			continue
		var chest := target_point(other)
		var along := (chest - from).dot(dir)
		if along < 0.0 or along > length or (not best.is_empty() and along >= float(best.along)):
			continue
		var closest := from + dir * along
		if closest.distance_to(chest) > PLAYER_ASSIST:
			continue
		var q := PhysicsRayQueryParameters3D.create(closest, chest, 1, [body.get_rid()])
		if not space.intersect_ray(q).is_empty():
			continue   # round a corner from the hook
		best = {"player": other, "along": along}
	return best


## The hook has caught: the rope is still loose (see _take_in_slack).
func _bite(body: Node3D, hit: Dictionary, player: Node3D, when: float) -> void:
	flying = false
	biting = true
	target = player
	carrier = null
	anchor = target_point(target) if target else hit.get("point", hit.get("position"))
	var on = hit.get("collider")
	if target == null and (on is AnimatableBody3D or on is MapGrapplePoint):
		carrier = on
		_anchor_on_carrier = (on as Node3D).global_transform.affine_inverse() * anchor
	_bite_at = when
	_rope = rope_origin(body).distance_to(anchor) + HookLine.flight_slack(line.travel(when))
	line.bite(when, anchor, _rope, int(target.get("peer_id")) if target and target.get("peer_id") != null else 0)
	_take_in_slack(body)   # (the rest of this step counts)


## The winch takes the slack in. The moment the rope is no longer than the distance
## to the hook, it is tight: from here it is the grapple's rope.
func _take_in_slack(body: Node3D) -> void:
	if target != null:
		if not is_instance_valid(target) or not target.is_inside_tree() or not target.get("alive") or not target.visible_in_world():
			release()   # they died or left before the rope pulled tight
			return
		anchor = target_point(target)
	elif carrier != null:
		if not is_instance_valid(carrier) or not carrier.is_inside_tree() or carrier.get_meta("unhookable", false):
			release()   # what it bit has gone
			return
		anchor = carrier.global_transform * _anchor_on_carrier
	line.anchor = anchor
	var dist := rope_origin(body).distance_to(anchor)
	if _rope - HookLine.reeled(clock - _bite_at) > dist:
		return
	biting = false
	attached = true
	length = maxf(dist, tuning.grapple_min_length)
	_tether_time = 0.0
	_just_taut = true
	line.pull_taut(clock)


## One step of the hook's way back: straight at where the rope meets you now, from
## where it set off, so far along as its time says (HookLine.back_share). While the
## button is held it catches the first surface on the way.
func _come_back(body: CollisionObject3D) -> void:
	var s := (clock - _back_at) / _back_time
	if s >= 1.0:
		returning = false
		return
	var from := _back_prev
	var to := _back_from.lerp(_chest, HookLine.back_share(s))
	_back_prev = to
	if not (held and _snag) or from.distance_squared_to(to) < 0.0001:
		return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var at: Vector3 = hit.position
	if at.distance_to(_back_from) < 0.3 or at.distance_to(_chest) < BACK_CATCH_MIN:
		return   # what it has just let go of, or right beside you: nothing to swing on
	if (hit.collider as Object).get_meta("unhookable", false):
		return
	_catch_back(body, hit, s)


## The hook has caught something on its way back: the rope is loose (it was limp),
## the winch takes the slack in, and it pulls tight as after any bite. For every
## other copy this is a new shot, whose record starts where the way back did.
func _catch_back(body: Node3D, hit: Dictionary, s: float) -> void:
	var slack := maxf(line.back_slack * (1.0 - HookLine.back_share(s)), BACK_SLACK_MIN)
	var set_off_slack := line.back_slack
	var set_off_age := line.age(_back_at)
	returning = false
	biting = true
	target = null
	carrier = null
	anchor = hit.position
	var on = hit.collider
	if on is AnimatableBody3D:
		carrier = on
		_anchor_on_carrier = (on as Node3D).global_transform.affine_inverse() * anchor
	shots = shots % 250 + 1
	line = HookLine.new()   # (the shot it came back from stays as it was, for whoever still holds it)
	line.launch_back(shots, _back_at, _back_from, _back_time, set_off_slack, set_off_age)
	_bite_at = clock
	_rope = _chest.distance_to(anchor) + slack
	line.bite(clock, anchor, _rope)
	_take_in_slack(body)
