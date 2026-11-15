class_name Grapple
extends RefCounted
## Momentum-based grappling hook.
##
## The hook does NOT pull you in. It works like a rope: when it catches a surface,
## the rope's length is fixed at your current distance, and the rope only stops you
## from moving further away than that. Gravity and your speed do the rest, so you
## swing like a pendulum around the anchor:
##  - swinging down converts height into speed;
##  - steering in the air (WASD) at the right moment pumps the swing higher;
##  - letting go keeps all your velocity, so releasing at the bottom or on the
##    upswing launches you;
##  - jumping while attached lets go with an extra upward kick.
## It catches any surface in range and has a short cooldown after you let go.

var tuning: MovementTuning
var attached := false
var anchor := Vector3.ZERO
var length := 0.0
var cooldown_left := 0.0


func _init(t: MovementTuning) -> void:
	tuning = t


func update(delta: float) -> void:
	cooldown_left = max(cooldown_left - delta, 0.0)


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
	if input.aim_dir != Vector3.ZERO:
		# Third person: what is under the crosshair, as long as the eyes can see it too.
		var from := input.aim_origin
		var q := PhysicsRayQueryParameters3D.create(from, from + input.aim_dir * (tuning.grapple_range + 6.0), 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or eye.distance_to(hit.position) > tuning.grapple_range:
			return {}
		var check := PhysicsRayQueryParameters3D.create(eye, hit.position, 1, exclude)
		var block := space.intersect_ray(check)
		if not block.is_empty() and block.position.distance_to(hit.position) > 0.3:
			return block  # something between you and the crosshair point: hook that instead
		return hit
	var aim := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD
	var query := PhysicsRayQueryParameters3D.create(eye, eye + aim * tuning.grapple_range, 1, exclude)
	return space.intersect_ray(query)


## Lets go without starting the cooldown (death, respawn).
func reset() -> void:
	attached = false
	cooldown_left = 0.0


func try_attach(body: CollisionObject3D, input: PlayerInput) -> bool:
	if not ready_to_fire():
		return false
	var hit := find_target(body, input)
	if hit.is_empty():
		return false
	anchor = hit.position
	length = clamp(rope_origin(body).distance_to(anchor), tuning.grapple_min_length, tuning.grapple_range)
	attached = true
	return true


func release() -> void:
	if attached:
		attached = false
		cooldown_left = tuning.grapple_cooldown


## Removes any velocity that would stretch the rope. Velocity along the swing is
## untouched, which is what makes this a pendulum rather than a pull.
func constrain_velocity(body: Node3D, vel: Vector3, delta: float) -> Vector3:
	length = max(length - tuning.grapple_reel_speed * delta, tuning.grapple_min_length)
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
	var offset := rope_origin(body) - anchor
	var excess := offset.length() - length
	if excess > 0.01:
		body.move_and_collide(-offset.normalized() * min(excess, 0.3))
