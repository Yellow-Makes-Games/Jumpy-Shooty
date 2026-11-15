class_name MovementController
extends RefCounted
## The player's movement rules. One controller with a small set of states that all
## share one velocity, so speed carries from one move into the next by design.
##
## Phase 0 has GROUND and AIR. Phase 2 adds SLIDE, WALL_RUN, GRAPPLE, DIVE, ROLL and
## VAULT as further states in this same controller, each in its own file.

enum State { GROUND, AIR }

var tuning: MovementTuning
var state: State = State.AIR

var _since_ground := 0.0   # seconds since we last stood on the floor
var _jump_buffer := 0.0    # seconds left on a buffered jump press


func _init(t: MovementTuning = null) -> void:
	tuning = t if t else MovementTuning.new()


## Advance the body by one physics step.
func step(body: CharacterBody3D, input: PlayerInput, delta: float) -> void:
	var t := tuning
	var vel := body.velocity
	var grounded := body.is_on_floor()

	if grounded:
		_since_ground = 0.0
	else:
		_since_ground += delta
	if input.jump_pressed:
		_jump_buffer = t.jump_buffer
	else:
		_jump_buffer = max(_jump_buffer - delta, 0.0)

	var wish := _wish_dir(input)
	var wish_speed: float = (t.sprint_speed if input.sprint else t.run_speed) * min(input.move.length(), 1.0)

	var jumping := _jump_buffer > 0.0 and _since_ground <= t.coyote_time

	if grounded and not jumping:
		state = State.GROUND
		vel = _apply_friction(vel, wish_speed, delta)
		vel = _accelerate(vel, wish, wish_speed, t.ground_accel, delta)
		vel.y = min(vel.y, 0.0)
	else:
		# In the air, and also on the exact frame a well-timed jump leaves the ground:
		# no friction that frame, so a jump pressed just before landing keeps all
		# your speed (bunny-hopping). Air steering can add speed when you strafe
		# and turn together (air-strafing), but never takes speed away.
		state = State.AIR
		vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.air_accel, delta)
		if not grounded:
			vel.y = max(vel.y - t.gravity * delta, -t.max_fall_speed)

	if jumping:
		vel.y = t.jump_velocity
		_jump_buffer = 0.0
		_since_ground = t.coyote_time + 1.0  # spend the coyote window
		state = State.AIR

	body.velocity = vel
	body.move_and_slide()


func horizontal_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func _wish_dir(input: PlayerInput) -> Vector3:
	var m := input.move.limit_length(1.0)
	var local := Vector3(m.x, 0.0, -m.y)
	return local.rotated(Vector3.UP, input.yaw).normalized() if local.length_squared() > 0.0001 else Vector3.ZERO


## Speed up toward wish_speed along wish, never cutting speed you already have.
## This is what lets momentum from jumps, swings and slides carry through.
func _accelerate(vel: Vector3, wish: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	if wish == Vector3.ZERO:
		return vel
	var current := vel.dot(wish)
	var add := wish_speed - current
	if add <= 0.0:
		return vel
	var gain: float = min(accel * wish_speed * delta, add)
	return vel + wish * gain


func _apply_friction(vel: Vector3, wish_speed: float, delta: float) -> Vector3:
	var t := tuning
	var h := Vector3(vel.x, 0.0, vel.z)
	var speed := h.length()
	if speed < 0.01:
		return Vector3(0.0, vel.y, 0.0)
	var top: float = max(wish_speed, t.run_speed)
	var f: float = t.overspeed_friction if speed > top + 0.5 else t.friction
	var drop: float = max(speed, t.stop_speed) * f * delta
	var new_speed: float = max(speed - drop, 0.0)
	h *= new_speed / speed
	return Vector3(h.x, vel.y, h.z)
