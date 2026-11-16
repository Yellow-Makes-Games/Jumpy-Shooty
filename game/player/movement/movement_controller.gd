class_name MovementController
extends RefCounted
## The player's movement rules. One controller with a small set of states that all
## share one velocity, so speed carries from one move into the next by design.
##
##   GROUND    running and sprinting
##   AIR       jumping and falling (bunny-hops and air-strafing live here)
##   GRAPPLE   swinging on the rope (see grapple.gd)
##   CROUCH    crouched on the ground: lower and slower
##   SLIDE     crouch while moving fast: keeps momentum, speeds up downhill
##   WALL_RUN  run along a wall with little gravity; jump to kick off it
##   MANTLE    vaulting a low obstacle or climbing up a ledge
##   DIVE      a forward lunge toward where you look (from the ground or once per jump)
##   ROLL      landing from a dive: a short roll that keeps your speed
##   FLIP      press jump again in mid-air: a flip toward your WASD direction with a
##             small burst, once per jump (a dodge)
##
## Crouching in the air tucks your legs up (head stays put), which helps you clear
## edges. Wall jumps work from a wall run or any wall you are touching in the air.

const TUCK_SETTLE_SPEED := 3.0   ## metres per second

enum State { GROUND, AIR, GRAPPLE, CROUCH, SLIDE, WALL_RUN, MANTLE, DIVE, ROLL, FLIP }

var tuning: MovementTuning
var state: State = State.AIR
var grapple: Grapple
var crouched := false
var eye_height := MovementTuning.EYE_HEIGHT  ## eyes above the feet right now (eases when crouching)
var wall_normal := Vector3.ZERO              ## the wall being run on
## How far the feet are lifted by tucking the legs up in the air (0 or up to
## stand_height - crouch_height). The head stays put when you tuck. Others are sent
## your feet minus this, which never jumps; on the ground it settles back to 0
## smoothly. See Player._sent_position().
var tuck := 0.0
## Direction of the current flip, relative to where you face (x = right, y = forward).
var flip_dir := Vector2.ZERO

var _since_ground := 0.0   # seconds since we last stood on the floor
var _jump_buffer := 0.0    # seconds left on a buffered jump press
var _since_slide_boost := 99.0
var _wall_time := 0.0      # seconds into the current wall run
var _used_wall := Vector3.ZERO   # last wall run or jumped off; can't reuse it until you land or touch another
var _recent_wall := Vector3.ZERO # last wall touched in the air (for late wall jumps)
var _since_wall := 99.0
var _mantle := {}          # the vault or climb in progress
var _shape: CollisionShape3D
var _since_dive := 99.0
var _air_dive_used := false   # one dive per jump
var _flip_used := false       # one flip per jump
var _roll_left := 0.0
var _flip_left := 0.0


func _init(t: MovementTuning = null) -> void:
	tuning = t if t else MovementTuning.new()
	grapple = Grapple.new(tuning)


## Advance the body by one physics step.
func step(body: CharacterBody3D, input: PlayerInput, delta: float) -> void:
	var t := tuning
	_bind_shape(body)
	var vel := body.velocity
	var grounded := body.is_on_floor()

	if grounded:
		_since_ground = 0.0
		_used_wall = Vector3.ZERO
		_air_dive_used = false
		_flip_used = false
		_flip_left = 0.0
	else:
		_since_ground += delta
	if input.jump_pressed:
		_jump_buffer = t.jump_buffer
	else:
		_jump_buffer = max(_jump_buffer - delta, 0.0)
	_since_slide_boost += delta
	_since_wall += delta
	_since_dive += delta
	_flip_left = max(_flip_left - delta, 0.0)
	grapple.update(delta)

	if state == State.MANTLE:
		_step_mantle(body, delta)
		_ease_eye(delta)
		return

	var wish := _wish_dir(input)
	var wish_speed: float = (t.sprint_speed if input.sprint else t.run_speed) * min(input.move.length(), 1.0)
	var forward := input.move.y > 0.3

	# --- Grapple: hold to stay on the rope, let go to fly off with your momentum,
	# or jump to let go with an upward kick.
	if input.grapple_pressed and not grapple.attached:
		grapple.try_attach(body, input)
	if grapple.attached and not input.grapple:
		grapple.release()
	var rope_jump := false
	if grapple.attached and _jump_buffer > 0.0 and not grounded:
		grapple.release()
		_jump_buffer = 0.0
		rope_jump = true

	if grapple.attached or state == State.WALL_RUN:
		_flip_used = false   # swinging or wall-running gives your flip back

	# --- Dive (and the roll when you land from one)
	var diving_now := false
	if input.dive_pressed and _can_dive(grounded):
		vel = _start_dive(vel, input, grounded)
		diving_now = true
	if state == State.DIVE and grounded and not diving_now:
		state = State.ROLL
		_roll_left = tuning.roll_time
	if state == State.ROLL:
		_roll_left -= delta
		if not grounded:
			state = State.AIR   # rolled off an edge
		elif _roll_left <= 0.0:
			state = State.GROUND
			if input.crouch and Vector2(vel.x, vel.z).length() >= t.slide_start_speed:
				vel = _start_slide(vel)   # roll straight into a slide
	var low_move := state in [State.DIVE, State.ROLL]

	# --- Crouch (or tuck your legs in the air). Diving and rolling are low too.
	_update_crouch(body, input.crouch or low_move, grounded, delta)

	# --- Vault over low obstacles; grab and climb higher ledges while in the air
	if forward and not low_move and not grapple.attached and not rope_jump and vel.y < t.jump_velocity:
		var ledge := SurfaceProbe.find_ledge(body, _facing(input), t, t.crouch_height)
		if not ledge.is_empty() and _start_mantle(ledge, grounded, vel):
			_step_mantle(body, delta)
			_ease_eye(delta)
			return

	# --- Walls
	var wall := Vector3.ZERO
	if not grounded and not grapple.attached:
		wall = SurfaceProbe.find_wall(body, vel, wall_normal, eye_height - 0.6, t.wall_reach)
		if wall != Vector3.ZERO:
			_recent_wall = wall
			_since_wall = 0.0
	if state == State.WALL_RUN and not _keep_wall_running(wall, vel, forward, grounded):
		_end_wall_run()

	var jumping := _jump_buffer > 0.0 and _since_ground <= t.coyote_time
	var wall_jump := false
	if not jumping and _jump_buffer > 0.0 and not grounded and not grapple.attached:
		var kick := wall if wall != Vector3.ZERO else (_recent_wall if _since_wall <= t.wall_jump_grace else Vector3.ZERO)
		if kick != Vector3.ZERO and (state == State.WALL_RUN or _wall_is_fresh(kick)):
			wall_jump = true
			_jump_buffer = 0.0
			vel = _wall_jump(vel, kick)

	if not wall_jump and state != State.WALL_RUN and _can_start_wall_run(body, wall, vel, forward, grounded):
		_start_wall_run(wall)
		vel.y = clamp(vel.y, -1.0, t.wall_run_max_rise)

	# A mid-air jump that isn't a wall jump is a flip: a small burst toward your
	# WASD direction, once per jump. Pressed close above the floor, it is kept
	# as a buffered jump for when you land instead (so bunny-hops still work).
	var flipping := false
	if input.jump_pressed and not jumping and not wall_jump and not rope_jump and not grounded \
			and not grapple.attached and not _flip_used and state != State.MANTLE \
			and not SurfaceProbe.floor_within(body, max(1.0, -vel.y * t.jump_buffer + 0.3)):
		flipping = true
		_flip_used = true
		_jump_buffer = 0.0

	var hspeed := Vector2(vel.x, vel.z).length()
	if wall_jump:
		state = State.AIR
		vel.y = max(vel.y - t.gravity * delta, -t.max_fall_speed)
	elif state == State.WALL_RUN:
		vel = _wall_run(vel, delta)
	elif state == State.DIVE:
		if not diving_now:
			vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.dive_air_accel, delta)
			vel.y = max(vel.y - t.gravity * delta, -t.max_fall_speed)
	elif state == State.ROLL:
		vel = _roll(vel, wish, delta)
	elif grapple.attached and not grounded:
		# Swinging: gravity plus stronger air steering (to pump the swing), then
		# the rope removes any motion that would stretch it.
		state = State.GRAPPLE
		vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.grapple_air_accel, delta)
		vel.y = max(vel.y - t.gravity * delta, -t.max_fall_speed)
	elif grounded and not jumping:
		var just_landed := state not in [State.GROUND, State.CROUCH, State.SLIDE]
		if state == State.SLIDE and (not crouched or hspeed < t.slide_end_speed):
			state = State.GROUND
		elif state != State.SLIDE and crouched and hspeed >= t.slide_start_speed and (input.crouch_pressed or just_landed):
			vel = _start_slide(vel)
		if state == State.SLIDE:
			vel = _slide(body, vel, wish, delta)
		else:
			state = State.CROUCH if crouched else State.GROUND
			var top: float = t.crouch_speed * min(input.move.length(), 1.0) if crouched else wish_speed
			vel = _apply_friction(vel, top, delta)
			vel = _accelerate(vel, wish, top, t.ground_accel, delta)
			vel.y = min(vel.y, 0.0)
	else:
		# In the air, and also on the exact frame a well-timed jump leaves the ground:
		# no friction that frame, so a jump pressed just before landing keeps all
		# your speed (bunny-hopping). Air steering can add speed when you strafe
		# and turn together (air-strafing), but never takes speed away.
		state = State.FLIP if _flip_left > 0.0 else State.AIR
		vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.air_accel, delta)
		if not grounded:
			vel.y = max(vel.y - t.gravity * delta, -t.max_fall_speed)

	if jumping:
		vel.y = t.jump_velocity
		_jump_buffer = 0.0
		_since_ground = t.coyote_time + 1.0  # spend the coyote window
		state = State.AIR
	if rope_jump:
		vel.y = max(vel.y, 0.0) + t.grapple_jump_boost
		state = State.AIR
	if flipping:
		vel = _flip(vel, wish, input)

	if grapple.attached:
		vel = grapple.constrain_velocity(body, vel, delta)
		if grounded:
			state = State.GRAPPLE if vel.y > 0.1 else State.GROUND

	body.velocity = vel
	body.move_and_slide()
	if grapple.attached:
		grapple.correct_position(body)
	_ease_eye(delta)


func horizontal_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


## Crouching, sliding, or legs tucked in the air: the short body shape.
func is_low() -> bool:
	return crouched


## Forget everything in progress (respawn, teleport).
func reset() -> void:
	grapple.reset()
	state = State.AIR
	wall_normal = Vector3.ZERO
	_used_wall = Vector3.ZERO
	_mantle = {}
	_jump_buffer = 0.0
	_since_dive = 99.0
	_air_dive_used = false
	_flip_used = false
	_roll_left = 0.0
	_flip_left = 0.0
	if crouched and _shape:
		_set_height(tuning.stand_height)
	crouched = false
	tuck = 0.0
	eye_height = MovementTuning.EYE_HEIGHT


# ---------------------------------------------------------------------------
# Crouch

func _bind_shape(body: CharacterBody3D) -> void:
	if _shape:
		return
	for c in body.get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			_shape = c
			return


func _set_height(h: float) -> void:
	(_shape.shape as CapsuleShape3D).height = h
	_shape.position.y = h * 0.5


func _update_crouch(body: CharacterBody3D, want: bool, grounded: bool, delta: float) -> void:
	var t := tuning
	var diff := t.stand_height - t.crouch_height
	if grounded:
		tuck = move_toward(tuck, 0.0, TUCK_SETTLE_SPEED * delta)
	if want and not crouched:
		_set_height(t.crouch_height)
		crouched = true
		if not grounded:
			# Tuck the legs up: the head stays where it was.
			body.global_position.y += diff
			eye_height -= diff
			tuck = diff
	elif not want and crouched:
		if grounded:
			if not body.test_move(body.global_transform, Vector3(0, diff, 0)):
				_set_height(t.stand_height)
				crouched = false
		elif tuck < diff * 0.5 and not body.test_move(body.global_transform, Vector3(0, diff, 0)):
			# Crouched since the ground (not a tuck): stand up, feet stay where they are.
			_set_height(t.stand_height)
			crouched = false
		elif not body.test_move(body.global_transform, Vector3(0, -diff, 0)):
			# Legs back down; the head stays where it was.
			body.global_position.y -= diff
			eye_height += diff
			_set_height(t.stand_height)
			crouched = false
			tuck = 0.0
		elif not body.test_move(body.global_transform, Vector3(0, diff, 0)):
			_set_height(t.stand_height)
			crouched = false


func _ease_eye(delta: float) -> void:
	var target := tuning.crouch_eye_height if crouched else MovementTuning.EYE_HEIGHT
	eye_height = move_toward(eye_height, target, tuning.eye_move_speed * delta)


# ---------------------------------------------------------------------------
# Slide

func _start_slide(vel: Vector3) -> Vector3:
	var t := tuning
	state = State.SLIDE
	var h := Vector3(vel.x, 0, vel.z)
	var speed := h.length()
	if _since_slide_boost >= t.slide_boost_cooldown and speed < t.slide_boost_max_speed:
		_since_slide_boost = 0.0
		var boosted: float = min(speed + t.slide_boost, t.slide_boost_max_speed)
		h = h / speed * boosted
	return Vector3(h.x, vel.y, h.z)


## Little friction, a little steering, and gravity pulls you along slopes.
func _slide(body: CharacterBody3D, vel: Vector3, wish: Vector3, delta: float) -> Vector3:
	var t := tuning
	var n := body.get_floor_normal()
	# Gravity along the floor: zero on flat ground, speeds you up downhill.
	var downhill := Vector3(0, -t.gravity, 0)
	downhill -= n * downhill.dot(n)
	vel += downhill * delta
	var h := Vector3(vel.x, 0, vel.z)
	var speed := h.length()
	if speed > 0.01:
		var dir := h / speed
		if wish != Vector3.ZERO:
			var angle := dir.signed_angle_to(wish, Vector3.UP)
			dir = dir.rotated(Vector3.UP, clamp(angle, -t.slide_turn_rate * delta, t.slide_turn_rate * delta))
		speed = max(speed - t.slide_decel * delta, 0.0)
		h = dir * speed
	return Vector3(h.x, min(vel.y, 0.0), h.z)


# ---------------------------------------------------------------------------
# Walls

func _wall_is_fresh(n: Vector3) -> bool:
	return _used_wall == Vector3.ZERO or n.dot(_used_wall) < 0.9


func _can_start_wall_run(body: CharacterBody3D, wall: Vector3, vel: Vector3, forward: bool, grounded: bool) -> bool:
	var t := tuning
	if grounded or wall == Vector3.ZERO or not forward or grapple.attached or crouched:
		return false
	if not _wall_is_fresh(wall):
		return false
	var h := Vector3(vel.x, 0, vel.z)
	var along := h - wall * h.dot(wall)
	if along.length() < t.wall_run_min_speed:
		return false
	return not SurfaceProbe.floor_within(body, t.wall_run_min_height)


func _start_wall_run(wall: Vector3) -> void:
	state = State.WALL_RUN
	wall_normal = wall
	_wall_time = 0.0


func _keep_wall_running(wall: Vector3, vel: Vector3, forward: bool, grounded: bool) -> bool:
	if grounded or not forward or grapple.attached or crouched:
		return false
	if wall == Vector3.ZERO or wall.dot(wall_normal) < 0.7:
		return false
	if _wall_time > tuning.wall_run_max_time:
		return false
	var h := Vector3(vel.x, 0, vel.z)
	return (h - wall * h.dot(wall)).length() >= tuning.wall_run_min_speed * 0.8


func _end_wall_run() -> void:
	_used_wall = wall_normal
	wall_normal = Vector3.ZERO
	state = State.AIR


func _wall_run(vel: Vector3, delta: float) -> Vector3:
	var t := tuning
	_wall_time += delta
	var n := wall_normal
	var h := Vector3(vel.x, 0, vel.z)
	var along := h - n * h.dot(n)
	var speed := along.length()
	var dir := along / speed if speed > 0.01 else Vector3.ZERO
	if speed < t.wall_run_speed:
		speed = min(speed + t.wall_run_accel * delta, t.wall_run_speed)
	h = dir * speed - n * t.wall_stick
	var y: float = max(vel.y - t.wall_run_gravity * delta, -t.max_fall_speed)
	return Vector3(h.x, y, h.z)


func _wall_jump(vel: Vector3, n: Vector3) -> Vector3:
	var t := tuning
	if state == State.WALL_RUN:
		_end_wall_run()
	_used_wall = n
	var h := Vector3(vel.x, 0, vel.z)
	var into := h.dot(n)
	if into < 0.0:
		h -= n * into
	h += n * t.wall_jump_push
	return Vector3(h.x, max(vel.y, t.wall_jump_up), h.z)


# ---------------------------------------------------------------------------
# Dive, roll and flip

func _can_dive(grounded: bool) -> bool:
	if _since_dive < tuning.dive_cooldown or grapple.attached:
		return false
	if state in [State.MANTLE, State.DIVE, State.ROLL]:
		return false
	return grounded or not _air_dive_used


func _start_dive(vel: Vector3, input: PlayerInput, grounded: bool) -> Vector3:
	var t := tuning
	if state == State.WALL_RUN:
		_end_wall_run()
	var dir := _facing(input)
	var h := Vector3(vel.x, 0, vel.z)
	var along := h.dot(dir)
	if along < t.dive_max_speed:
		h += dir * min(t.dive_boost, t.dive_max_speed - max(along, 0.0))
	if h.dot(dir) < t.run_speed:
		h += dir * (t.run_speed - h.dot(dir))   # a dive always carries you forward
	state = State.DIVE
	_since_dive = 0.0
	if not grounded:
		_air_dive_used = true
	var y: float = t.dive_hop if grounded else max(vel.y, t.dive_air_up)
	return Vector3(h.x, y, h.z)


## Rolling: keeps your speed, with a little steering.
func _roll(vel: Vector3, wish: Vector3, delta: float) -> Vector3:
	var h := Vector3(vel.x, 0, vel.z)
	var speed := h.length()
	if speed > 0.01 and wish != Vector3.ZERO:
		var dir := h / speed
		var angle := dir.signed_angle_to(wish, Vector3.UP)
		var turn := tuning.roll_turn_rate * delta
		h = dir.rotated(Vector3.UP, clamp(angle, -turn, turn)) * speed
	return Vector3(h.x, min(vel.y, 0.0), h.z)


func _flip(vel: Vector3, wish: Vector3, input: PlayerInput) -> Vector3:
	var t := tuning
	state = State.FLIP
	_flip_left = t.flip_time
	flip_dir = input.move.limit_length(1.0).normalized() if wish != Vector3.ZERO else Vector2(0, -1)  # no direction: backflip
	var h := Vector3(vel.x, 0, vel.z) + wish * t.flip_burst
	return Vector3(h.x, max(vel.y, t.flip_up), h.z)


# ---------------------------------------------------------------------------
# Vault and ledge climb

func _facing(input: PlayerInput) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, input.yaw)


func _start_mantle(ledge: Dictionary, grounded: bool, vel: Vector3) -> bool:
	var t := tuning
	var lip: float = ledge.lip
	if lip < t.vault_min_height:
		return false
	var vault: bool = lip <= t.vault_max_height
	if not vault and (grounded or lip > t.ledge_max_height):
		return false  # higher ledges are grabbed only when you jump at them
	var hspeed := Vector2(vel.x, vel.z).length()
	_mantle = {
		"top": ledge.top + 0.05,
		"dir": -(ledge.normal as Vector3),
		"up": t.vault_up_speed if vault else t.ledge_up_speed,
		# A vault keeps your speed; climbing a ledge slows you down.
		"exit": max(hspeed, t.run_speed) if vault else t.ledge_exit_speed,
		"time": 0.0,
		"vault": vault,
	}
	if state == State.WALL_RUN:
		_end_wall_run()
	state = State.MANTLE
	return true


func _step_mantle(body: CharacterBody3D, delta: float) -> void:
	_mantle.time += delta
	var dir: Vector3 = _mantle.dir
	if body.global_position.y >= _mantle.top or _mantle.time > 0.9:
		# Over the lip: carry on forward.
		state = State.AIR
		body.velocity = dir * _mantle.exit
		_mantle = {}
	else:
		body.velocity = Vector3(0, _mantle.up, 0) + dir * 0.5
	body.move_and_slide()


## True for the frame-by-frame life of a vault (not a ledge climb). For animation.
func is_vaulting() -> bool:
	return state == State.MANTLE and _mantle.get("vault", false)


# ---------------------------------------------------------------------------
# Shared helpers

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
