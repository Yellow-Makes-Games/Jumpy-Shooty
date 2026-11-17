class_name Grapple
extends RefCounted
## Momentum-based grappling hook.
##
## When it catches a surface it yanks you toward it, then keeps reeling you in,
## speeding you up toward the hook (up to grapple_pull_speed). The pull only adds
## speed along the rope: whatever sideways speed you had is kept, so hooking a point
## off to one side while running pulls you into a fast, tightening swing. Close to
## the hook the pull stops and you coast in on your own momentum. It is also a rope:
## it never lets you move further away than its length, and takes up slack as you
## get closer. Gravity and your speed do the rest:
##  - swinging down converts height into speed;
##  - steering in the air (WASD) at the right moment pumps the swing higher;
##  - letting go keeps all your velocity, so releasing at the bottom or on the
##    upswing launches you;
##  - jumping while attached lets go with an extra upward kick.
## It catches any surface in range and has a short cooldown after you let go.
##
## It also catches other players. Then the anchor rides on them, there is no rope
## length to swing on, and the pull reels you in harder until you meet (they are
## dragged toward you too: see Player.tug). While you have someone hooked you can
## flying-kick them (see Kick).

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
## Can the hook catch players? (Not in a race.)
var hook_players := true
var _tether_time := 0.0


func _init(t: MovementTuning) -> void:
	tuning = t


func update(delta: float) -> void:
	cooldown_left = max(cooldown_left - delta, 0.0)


## Hooked to a player: the anchor follows their chest. Lets go if they died or
## left, once you meet, or after tether_time.
func follow_target(body: Node3D, delta: float) -> void:
	if not attached or target == null:
		return
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.get("alive") or not target.visible_in_world():
		print("DBG release invalid ", is_instance_valid(target) and target.is_inside_tree(), " ", target.get("alive"), " ", target.visual.visible, " ", target.collision_layer)
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
	return not attached and cooldown_left <= 0.0


## Where the rope meets the player's body (around the chest).
func rope_origin(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0, tuning.grapple_attach_height, 0)


## Finds the point the player is aiming at, if it is in range. Any surface counts.
func find_target(body: CollisionObject3D, input: PlayerInput) -> Dictionary:
	var eye := body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	var space := body.get_world_3d().direct_space_state
	var exclude := [body.get_rid()]
	var mask := 1 | (1 << 1) if hook_players else 1   # the level, and other players
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
	cooldown_left = 0.0


func try_attach(body: CollisionObject3D, input: PlayerInput) -> bool:
	if not ready_to_fire():
		return false
	var hit := find_target(body, input)
	if hit.is_empty():
		return false
	target = hit_player(hit)
	_tether_time = 0.0
	anchor = target_point(target) if target else hit.position
	length = clamp(rope_origin(body).distance_to(anchor), tuning.grapple_min_length, tuning.grapple_range)
	attached = true
	return true


func release() -> void:
	if attached:
		attached = false
		target = null
		cooldown_left = tuning.grapple_cooldown


## The kick the hook gives the moment it catches: speed toward the hook, never
## past the pull's top speed.
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
	vel.y += tuning.gravity * WorldGravity.scale * 0.6 * delta
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
