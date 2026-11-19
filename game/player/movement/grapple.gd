class_name Grapple
extends RefCounted
## The grappling hook. The hook is a projectile, not an instant hit:
##
##  1. Fire: the hook leaves at HookLine.SPEED along your aim, paying out rope with
##     slack in it. You are free to run, jump and shoot while it flies. It catches
##     the first surface (or player) on its way; with nothing within grapple_range
##     it comes back and the cooldown starts. Letting go of the button calls it
##     back early.
##  2. Bite: the hook has caught, but the rope is still loose, so nothing pulls yet.
##     The winch takes the slack in, faster and faster (HookLine.reeled). Moving
##     away from the hook uses the slack up sooner; moving toward it, later.
##  3. Taut: the moment the rope is as short as the distance to the hook it snaps
##     tight with a yank (the winch is already spinning), then the rope pulls,
##     swings and lets go as below.
##  4. Back: let go (or a miss), the hook comes back to the wrist, straight at you
##     wherever you have got to. While you hold the button it catches the first
##     surface in its way (2. again): miss, and it can still snag the ledge you have
##     dropped behind; let go, then press again as it comes back, for the same.
##     A jump off the rope does not count as holding on: the hook just comes back.
##
## Because the hook takes time to arrive, you lead a moving target and commit a
## moment before the pull.
##
## Once tight, it is momentum-based: it reels you in, speeding you up toward the
## hook (up to grapple_pull_speed). The pull only adds speed along the rope: whatever
## sideways speed you had is kept, so hooking a point off to one side while running
## pulls you into a fast, tightening swing. Close to the hook the pull stops and you
## coast in on your own momentum. It is also a rope: it never lets you move further
## away than its length, and takes up slack as you get closer. Gravity and your
## speed do the rest:
##  - swinging down converts height into speed;
##  - steering in the air (WASD) at the right moment pumps the swing higher;
##  - letting go keeps all your velocity, so releasing at the bottom or on the
##    upswing launches you;
##  - jumping while attached lets go with an extra upward kick.
## It has a short cooldown after you let go.
##
## It also catches other players. Then the anchor rides on them, there is no rope
## length to swing on, and the pull reels you in harder until you meet (they are
## dragged toward you too: see Player.tug). While you have someone hooked you can
## flying-kick them (see Kick).
##
## Aim magnets help, at the moment of firing: a grapple point near the crosshair is
## flown to, and a player near it is led by their speed. In flight the hook also
## catches a player it passes within PLAYER_ASSIST of.
##
## Everything that happens is written into `line` (HookLine) as it happens, on
## `clock` (seconds of this body's movement). The rope and hook are drawn from that
## record alone, here and on every other copy of the game (see HookLine).

const PLAYER_ASSIST := 0.7    ## the hook catches a player whose chest it passes this close to (metres)
const BACK_CATCH_MIN := 2.5   ## coming back, it catches nothing nearer to you than this (metres)
const BACK_SLACK_MIN := 0.6   ## a hook that catches on its way back has at least this much slack to take in (metres)

var tuning: MovementTuning
var attached := false
var anchor := Vector3.ZERO
var length := 0.0
var cooldown_left := 0.0
## The pull never takes you faster than this: the pull's top speed, or the speed you
## hooked on at if that was faster. Past it, the pull turns your speed toward the
## hook instead of adding to it, so hooking a nearby point at speed doesn't spin
## you round it ever faster. Gravity can still add speed on a swing.
var speed_cap := 0.0
## The player you have hooked (null when hooked to a wall or not hooked).
var target: Node3D = null
## Hooked to something that can move (an island under way, a grapple point riding
## one): the anchor rides it, kept at the same spot on it.
var carrier: Node3D = null
var _anchor_on_carrier := Vector3.ZERO
## Can the hook catch players? (Not in a race.)
var hook_players := true
var _tether_time := 0.0
## The body's gravity as a share of normal (its MovementController sets it every step:
## see MovementController.gravity_scale).
var gravity_scale := 1.0
## Is the button down? The movement code says so every step: the hook only catches
## on the way back while you hold on.
var held := false
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


func _init(t: MovementTuning) -> void:
	tuning = t


func update(delta: float) -> void:
	clock += delta
	cooldown_left = max(cooldown_left - delta, 0.0)
	if attached and carrier != null:
		if not is_instance_valid(carrier) or not carrier.is_inside_tree() or carrier.get_meta("unhookable", false):
			release()   # what it was hooked on has gone (a walkway drawn in)
		else:
			anchor = carrier.global_transform * _anchor_on_carrier


## Every step: the hook flies, the slack comes in. (The movement code calls this with
## the body, right after update.)
func follow_target(body: Node3D, delta: float) -> void:
	_follow_player(body, delta)
	_chest = rope_origin(body)
	if flying:
		_fly(body as CollisionObject3D, delta)
	elif biting:
		_take_in_slack(body)
	elif returning:
		_come_back(body as CollisionObject3D)
	if attached and (target != null or carrier != null):
		line.anchor = anchor   # it rides on what it is hooked to


## Hooked to a player: the anchor follows their chest. Lets go if they died or
## left, once you meet, or after tether_time.
func _follow_player(body: Node3D, delta: float) -> void:
	if not attached or target == null:
		return
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.get("alive") or not target.visible_in_world():
		release()
		return
	anchor = target_point(target)
	_tether_time += delta
	if _tether_time > tuning.tether_time or rope_origin(body).distance_to(anchor) < tuning.tether_meet:
		release()


## Where the hook sits on a player: their chest.
static func target_point(p: Node3D) -> Vector3:
	return p.global_position + Vector3(0, 1.15, 0)


func hooked_player() -> bool:
	return attached and target != null


func ready_to_fire() -> bool:
	return not attached and cooldown_left <= 0.0 and not flying and not biting and not returning


## Fired but not pulling yet: the hook is on its way, or the slack is coming in.
func busy() -> bool:
	return flying or biting


## Is there rope out of the launcher (the arm points along it), and where does it end?
func rope_out() -> bool:
	return attached or flying or biting or returning


func rope_end() -> Vector3:
	if flying:
		return line.flight_pos(clock)
	return _back_prev if returning else anchor


## Has the rope just pulled tight? True once, on the step it did: the movement code
## gives the yank then.
func take_hooked() -> bool:
	var was := _just_taut
	_just_taut = false
	return was


## Where the rope meets the player's body (around the chest).
func rope_origin(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0, tuning.grapple_attach_height, 0)


## What the hook would be fired at, if it is in range (the HUD shows it). Any surface counts.
## Aim magnets come first: a grapple point (MapGrapplePoint) or another player near
## the crosshair is caught even without an exact hit. Such a result carries "point"
## (the spot to hook) in place of "position".
func find_target(body: CollisionObject3D, input: PlayerInput) -> Dictionary:
	var eye := body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	var space := body.get_world_3d().direct_space_state
	var exclude := [body.get_rid()]
	var mask := 1 | (1 << 1) if hook_players else 1   # the level, and other players
	var snap := _magnet_target(body, input, space, eye, exclude)
	if not snap.is_empty():
		return snap
	if input.aim_dir != Vector3.ZERO:
		# Third person: what is under the crosshair, as long as the eyes can see it too.
		var from := input.aim_origin
		var q := PhysicsRayQueryParameters3D.create(from, from + input.aim_dir * (tuning.grapple_range + 6.0), mask, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or eye.distance_to(hit.position) > tuning.grapple_range:
			return {}
		var check := PhysicsRayQueryParameters3D.create(eye, hit.position, mask, exclude)
		var block := space.intersect_ray(check)
		if not block.is_empty() and block.position.distance_to(hit.position) > 0.3:
			return block  # something between you and the crosshair point: hook that instead
		return hit
	var aim := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD
	var query := PhysicsRayQueryParameters3D.create(eye, eye + aim * tuning.grapple_range, mask, exclude)
	return space.intersect_ray(query)


## The magnet target nearest the crosshair: a grapple point inside its own cone and
## reach, or another player inside player_magnet degrees and grapple_range, with
## nothing solid in the way. Empty if none. The aim ray is the one find_target
## uses (third person: camera along the crosshair; first person: the eyes).
func _magnet_target(body: CollisionObject3D, input: PlayerInput, space: PhysicsDirectSpaceState3D,
		eye: Vector3, exclude: Array) -> Dictionary:
	var from := eye
	var dir := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD
	if input.aim_dir != Vector3.ZERO:
		from = input.aim_origin
		dir = input.aim_dir
	var best := {}
	var best_angle := INF
	var point := MapGrapplePoint.pick(body.get_tree(), space, eye, from, dir, exclude)
	if point:
		best = {"collider": point, "point": point.global_position}
		best_angle = dir.angle_to(point.global_position - from)
	if hook_players and tuning.player_magnet > 0.0 and body.get_parent():
		for other in body.get_parent().get_children():
			if other == body or not (other is CharacterBody3D) or other.get("alive") != true \
					or not other.has_method("visible_in_world") or not other.visible_in_world():
				continue
			var at := target_point(other)
			if eye.distance_to(at) > tuning.grapple_range:
				continue
			var angle := dir.angle_to(at - from)
			if rad_to_deg(angle) > tuning.player_magnet or angle >= best_angle:
				continue
			var q := PhysicsRayQueryParameters3D.create(eye, at, 1, exclude + [other.get_rid()])
			if not space.intersect_ray(q).is_empty():
				continue   # behind a wall
			best = {"collider": other, "point": at}
			best_angle = angle
	return best


## Does this ray hit (find_target's result) land on a player we can hook?
static func hit_player(hit: Dictionary) -> Node3D:
	if hit.is_empty():
		return null
	var c = hit.collider
	if c is CharacterBody3D and c.get("alive") == true and c.has_method("visible_in_world") and c.visible_in_world():
		return c
	return null


## Lets go without starting the cooldown (death, respawn).
func reset() -> void:
	attached = false
	target = null
	carrier = null
	cooldown_left = 0.0
	flying = false
	biting = false
	returning = false
	_snag = false
	_just_taut = false
	line.drop(clock)


## Fires the hook. It never catches at once: see take_hooked.
func fire(body: CollisionObject3D, input: PlayerInput) -> void:
	if returning:
		_snag = true   # pressed again as the hook comes back: held, it may catch on the way
	if not ready_to_fire():
		return
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


## Lets go: the hook sets off back to the wrist (see _come_back).
func release() -> void:
	var out := flying or biting or attached
	var at := anchor
	var slack := 0.0   # in the rope as it is let go
	if flying:
		slack = HookLine.flight_slack(line.travel(clock))
	elif biting:
		slack = maxf(_rope - HookLine.reeled(clock - _bite_at) - _chest.distance_to(anchor), 0.0)
	if out:
		flying = false
		biting = false
		attached = false
		target = null
		carrier = null
		cooldown_left = tuning.grapple_cooldown
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
	# until a new press (fire), or every jump off would hook the next thing.
	_snag = not held
	line.let_go(clock, _back_time, slack + HookLine.LIMP * dist)


## The kick the hook gives the moment the rope pulls tight: speed toward the hook,
## never past the pull's top speed.
func yank(body: Node3D, vel: Vector3) -> Vector3:
	speed_cap = maxf(vel.length(), tuning.grapple_pull_speed)
	return _add_toward(body, vel, tuning.grapple_yank)


## Reels you in: speeds you up toward the hook, up to grapple_pull_speed. Speed you
## already have toward it beyond that (falling, swinging) is kept, never taken away.
## Fades out near the hook so you arrive on your own momentum instead of being
## pinned to the wall.
func pull(body: Node3D, vel: Vector3, delta: float) -> Vector3:
	if target:
		return _reel_to_player(body, vel, delta)
	return _add_toward(body, vel, tuning.grapple_pull_accel * delta)


## Extra upward kick when the hook catches somewhere above you (not a player).
func yank_lift(body: Node3D, vel: Vector3) -> Vector3:
	if target or anchor.y <= rope_origin(body).y:
		return vel
	if vel.y < tuning.grapple_lift_max:
		vel.y = minf(vel.y + tuning.grapple_yank_lift, tuning.grapple_lift_max)
	return vel


## While hooked somewhere above you, an extra upward pull on top of the reel-in,
## so grappling carries you higher. It fades out near the hook like the pull does,
## and stops adding once you are rising grapple_lift_max fast.
func lift(body: Node3D, vel: Vector3, delta: float) -> Vector3:
	if target:
		return vel
	var to := anchor - rope_origin(body)
	if to.y <= 0.0 or vel.y >= tuning.grapple_lift_max:
		return vel
	var dist := to.length()
	var fade := clampf((dist - tuning.grapple_min_length) / maxf(tuning.grapple_pull_stop - tuning.grapple_min_length, 0.01), 0.0, 1.0)
	vel.y = minf(vel.y + tuning.grapple_pull_lift * fade * delta, tuning.grapple_lift_max)
	return vel


## Hooked to a player: straight toward them, hard, up to tether_pull_speed. Speed
## you have sideways is kept, so you can curve in.
func _reel_to_player(body: Node3D, vel: Vector3, delta: float) -> Vector3:
	var to := anchor - rope_origin(body)
	var dist := to.length()
	if dist < 0.01:
		return vel
	var dir := to / dist
	var room := tuning.tether_pull_speed - vel.dot(dir)
	if room > 0.0:
		vel += dir * minf(tuning.tether_pull_accel * delta, room)
	# Gravity is mostly cancelled while you are reeled in, so you fly at them, not under them.
	vel.y += tuning.gravity * gravity_scale * 0.6 * delta
	return vel


func _add_toward(body: Node3D, vel: Vector3, amount: float) -> Vector3:
	var to := anchor - rope_origin(body)
	var dist := to.length()
	if dist < 0.01 or amount <= 0.0:
		return vel
	var dir := to / dist
	var fade := clampf((dist - tuning.grapple_min_length) / maxf(tuning.grapple_pull_stop - tuning.grapple_min_length, 0.01), 0.0, 1.0)
	var room := tuning.grapple_pull_speed * fade - vel.dot(dir)
	if room <= 0.0:
		return vel
	var out := vel + dir * minf(amount, room)
	var top := maxf(speed_cap, vel.length())
	if out.length() > top:
		out = out.normalized() * top   # turn toward the hook rather than speed up
	return out


## Removes any velocity that would stretch the rope. Velocity along the swing is
## untouched, which is what lets you swing around the hook.
func constrain_velocity(body: Node3D, vel: Vector3, delta: float) -> Vector3:
	if target:
		return vel   # a player is no fixed point to swing on: just the pull
	# The rope takes up its own slack: if you move closer to the anchor it gets
	# shorter and stays tight, so you never free-fall on a loose rope and then get
	# jerked to a stop.
	var current := rope_origin(body).distance_to(anchor)
	length = clamp(min(length - tuning.grapple_reel_speed * delta, current), tuning.grapple_min_length, length)
	var predicted := rope_origin(body) + vel * delta
	var offset := predicted - anchor
	if offset.length() <= length:
		return vel  # rope is slack
	var outward := offset.normalized()
	var stretch := vel.dot(outward)
	if stretch > 0.0:
		vel -= outward * stretch
	return vel


## After moving, nudge the player back onto the rope's sphere if they drifted past
## it (small numerical drift). Uses a collision-aware move, so it never pushes
## the player into walls.
func correct_position(body: CharacterBody3D) -> void:
	if target:
		return
	var offset := rope_origin(body) - anchor
	var excess := offset.length() - length
	if excess > 0.01:
		body.move_and_collide(-offset.normalized() * min(excess, 0.3))


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
