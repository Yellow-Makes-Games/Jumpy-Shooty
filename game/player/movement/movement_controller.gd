class_name MovementController
extends RefCounted
## The player's movement rules. One controller with a small set of states that all
## share one velocity, so speed carries from one move into the next by design.
##
##   GROUND    running and sprinting
##   AIR       jumping and falling (bunny-hops and air-strafing live here)
##   GRAPPLE   reeled in and swinging on the rope (see grapple.gd)
##   CROUCH    crouched on the ground: lower and slower
##   SLIDE     crouch while moving fast: keeps momentum, speeds up downhill
##   WALL_RUN  run along a wall with little gravity; jump to kick off it
##   MANTLE    vaulting a low obstacle or climbing up a ledge
##   DIVE      a forward lunge toward where you look (from the ground or once per jump)
##   ROLL      landing from a dive: a short roll that keeps your speed
##   BELLY_SLIDE  keep holding dive as you land: slide along on your front instead
##             of rolling. Lower than a crouch. Let go (or jump) to get up; once
##             the slide runs out you can crawl until you let go.
##   FLIP      press jump again in mid-air: a flip toward your WASD direction with a
##             small burst, once per jump (a dodge)
##   GLIDE     hold Shift in mid-air (pressed there: jumping with sprint held does
##             not start one): your up-and-down speed is cancelled and you carry on
##             the way you were going, free to look and aim anywhere. Your speed
##             bleeds off to a drift and you sink, slowly at first and faster the
##             longer you glide. One budget of glide_time seconds per time in the
##             air, spent in as many pieces as you like; landing, a wall run or the
##             grapple refills it. Let go to stop. Any other move takes over from it
##             (flip, dive, grapple, a wall), so it works as a way to stop rising or
##             falling before the next move. Rocket boots do not end it: they send
##             the glide off the way you press instead (see _glide_boost).
##   SLAM      a ground slam (melee): you drive straight down and nothing stops it
##             but the floor (see start_slam; Player decides when, GroundSlam what it does)
## Winding a melee swing up in a plain fall hangs you in the air for a moment (see
## _hang): hang_time seconds per time in the air, refilled like the glide.
##
## Rocket boots (E): a burst of speed toward your WASD direction as seen from
## where you look (straight where you look if you hold no direction), so you can
## boost up, down, sideways or back, on the ground, in the air or mid-swing. It
## adds to the speed you have, so a burst along a grapple swing whips you round
## much faster. It recharges over boost_cooldown seconds.
##
## Crouching in the air tucks your legs up (head stays put), which helps you clear
## edges. Wall jumps work from a wall run or any wall you are touching in the air.

const TUCK_SETTLE_SPEED := 3.0   ## metres per second
const BELLY_SLOPE := 0.985       ## floor normal's y below this (about 10 degrees): a belly slide never slows to a crawl

## New states go on the end: the numbers travel in snapshots (Player.make_pose).
enum State { GROUND, AIR, GRAPPLE, CROUCH, SLIDE, WALL_RUN, MANTLE, DIVE, ROLL, FLIP, BELLY_SLIDE, GLIDE, SLAM }

var tuning: MovementTuning
var state: State = State.AIR
var grapple: Grapple
var crouched := false
var prone := false   ## lying on your front (belly slide): shorter still than crouched; crouched stays true
var eye_height := MovementTuning.EYE_HEIGHT  ## eyes above the feet right now (eases when crouching)
var wall_normal := Vector3.ZERO              ## the wall being run on
## How far the feet are lifted by tucking the legs up in the air (0 or up to
## stand_height - crouch_height). The head stays put when you tuck. Others are sent
## your feet minus this, which never jumps; on the ground it settles back to 0
## smoothly. See Player._sent_position().
var tuck := 0.0
## Direction of the current flip, relative to where you face (x = right, y = forward).
var flip_dir := Vector2.ZERO
## Wall jumps so far, and the wall last kicked off. For animation.
var wall_jumps := 0
var kick_wall := Vector3.ZERO
## The hardest hit against a wall, ceiling or prop in the last step: speed straight
## into it (m/s) and where. Landing on the floor does not count. See Player._check_slam().
var impact_speed := 0.0
var impact_point := Vector3.ZERO
## Rocket-boot bursts so far (for the flame and sound others see), and seconds since the last.
var boosts := 0
var since_boost := 99.0

var _knock := Vector3.ZERO   # knockback waiting to be added on the next step

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
var _glide_left := 0.0        # seconds of glide left for this time in the air
var _glide_wanted := false    # Shift was pressed in the air and is still held
var _glide_on := false        # a glide is under way (to notice another move taking over from it)
var hang := false             ## set every step by the player: winding a melee swing up (the fall slows in mid-air, see _hang)
var hanging := false          ## the fall is being slowed right now
var _hang_left := 0.0         # seconds of that left for this time in the air
var _slam_used := false       # a ground slam has been done this time in the air
var _slam_time := 0.0         # seconds this slam has lasted
var _slam_from := 0.0         # the height it started at
var _slam_landing := -1.0     # a slam just landed, from this many metres up (taken by take_slam_landing), or -1


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
		_glide_left = t.glide_time
		_hang_left = t.hang_time
		_slam_used = false
	else:
		_since_ground += delta
	hanging = false
	if input.jump_pressed:
		_jump_buffer = t.jump_buffer
	else:
		_jump_buffer = max(_jump_buffer - delta, 0.0)
	_since_slide_boost += delta
	_since_wall += delta
	_since_dive += delta
	_flip_left = max(_flip_left - delta, 0.0)
	since_boost += delta
	grapple.update(delta)
	grapple.follow_target(body, delta)

	if state == State.MANTLE:
		_step_mantle(body, delta)
		_ease_eye(delta)
		return
	if state == State.SLAM:
		_step_slam(body, delta)
		_ease_eye(delta)
		return

	var wish := _wish_dir(input)
	var wish_speed: float = (t.sprint_speed if input.sprint else t.run_speed) * min(input.move.length(), 1.0)
	var forward := input.move.y > 0.3

	# --- Grapple: hold to stay on the rope, let go to fly off with your momentum,
	# or jump to let go with an upward kick.
	var hooked_now := false
	if input.grapple_pressed and not grapple.attached:
		hooked_now = grapple.try_attach(body, input)
	if grapple.attached and not input.grapple:
		grapple.release()
	var rope_jump := false
	if grapple.attached and _jump_buffer > 0.0 and not grounded:
		grapple.release()
		_jump_buffer = 0.0
		rope_jump = true

	if grapple.attached or state == State.WALL_RUN:
		_flip_used = false   # swinging or wall-running gives your flip back
		_glide_left = t.glide_time  # ...and refills your glide
		_hang_left = t.hang_time    # ...and your hang

	# --- Glide: Shift held in the air, having been pressed there. Letting go,
	# landing or catching the rope ends it. Every other move below simply takes
	# over from it, and then it needs a fresh press to start again.
	if _glide_on and state != State.GLIDE:
		_glide_on = false
		_glide_wanted = false
	if not input.glide or grounded or state == State.WALL_RUN:
		_glide_wanted = false
	elif input.glide_pressed:
		_glide_wanted = true
	if state == State.GLIDE:
		if grounded or grapple.attached or not _glide_wanted:
			state = State.AIR
			_glide_on = false
	elif _glide_wanted and _can_glide(body, grounded):
		vel = _start_glide(vel)

	# --- Dive (and the roll when you land from one)
	var diving_now := false
	if input.dive_pressed and _can_dive(grounded):
		vel = _start_dive(vel, input, grounded)
		diving_now = true
	if state == State.DIVE and grounded and not diving_now:
		if input.dive:
			vel = _start_belly_slide(vel)   # still holding dive: land on your belly
		else:
			state = State.ROLL
			_roll_left = tuning.roll_time
	if state == State.BELLY_SLIDE and not grounded:
		state = State.AIR   # slid off an edge
	if state == State.ROLL:
		_roll_left -= delta
		if not grounded:
			state = State.AIR   # rolled off an edge
		elif _roll_left <= 0.0:
			state = State.GROUND
			if input.crouch and Vector2(vel.x, vel.z).length() >= t.slide_start_speed:
				vel = _start_slide(vel)   # roll straight into a slide
	var low_move := state in [State.DIVE, State.ROLL, State.BELLY_SLIDE]

	# --- Crouch (or tuck your legs in the air). Diving and rolling are low too, and
	# a belly slide is lower still. Let go of dive (or jump) to get up from your belly.
	var want_prone := state == State.BELLY_SLIDE and input.dive and _jump_buffer <= 0.0
	_update_crouch(body, input.crouch or low_move, want_prone, grounded, delta)
	if state == State.BELLY_SLIDE and not prone:
		state = State.GROUND   # up on your feet (or crouched, if there is no room to stand)
		low_move = false
		if input.crouch and Vector2(vel.x, vel.z).length() >= t.slide_start_speed:
			vel = _start_slide(vel)   # up from your belly straight into a slide

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

	var jumping := _jump_buffer > 0.0 and _since_ground <= t.coyote_time and not prone
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
		vel.y = max(vel.y - t.gravity * WorldGravity.scale * delta, -t.max_fall_speed)
	elif state == State.WALL_RUN:
		vel = _wall_run(vel, delta)
	elif state == State.GLIDE:
		vel = _glide(vel, delta)
	elif state == State.DIVE:
		if not diving_now:
			vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.dive_air_accel, delta)
			vel.y = max(vel.y - t.gravity * WorldGravity.scale * delta, -t.max_fall_speed)
	elif state == State.ROLL:
		vel = _roll(vel, wish, delta)
	elif state == State.BELLY_SLIDE:
		vel = _belly_slide(body, vel, wish, input, delta)
	elif grapple.attached and not grounded:
		# Swinging: gravity plus stronger air steering (to pump the swing), then
		# the rope removes any motion that would stretch it.
		state = State.GRAPPLE
		vel = _accelerate(vel, wish, min(wish_speed, t.air_speed), t.grapple_air_accel, delta)
		vel.y = max(vel.y - t.gravity * WorldGravity.scale * delta, -t.max_fall_speed)
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
			if hang and state == State.AIR and _hang_left > 0.0 and since_boost > 0.3 and not jumping:
				vel = _hang(vel, delta)
			else:
				vel.y = max(vel.y - t.gravity * WorldGravity.scale * delta, -t.max_fall_speed)

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
		# Reel in: a yank when the hook catches, then a steady pull toward it.
		if hooked_now:
			vel = grapple.yank(body, vel)
			vel = grapple.yank_lift(body, vel)
			if grounded and (grapple.target != null or grapple.anchor.y > grapple.rope_origin(body).y):
				vel.y = max(vel.y, t.grapple_hop)   # pop off the floor instead of dragging along it
		vel = grapple.pull(body, vel, delta)
		vel = grapple.lift(body, vel, delta)
		vel = grapple.constrain_velocity(body, vel, delta)
		if grounded and state != State.BELLY_SLIDE:
			state = State.GRAPPLE if vel.y > 0.1 else State.GROUND
			if vel.y > 0.1:
				_since_ground = t.coyote_time + 1.0   # pulled off the floor

	if input.boost_pressed and since_boost >= t.boost_cooldown:
		vel = _boost(vel, input, grounded)

	if _knock != Vector3.ZERO:
		if state == State.GLIDE:
			if _knock.y > 0.5:
				state = State.AIR   # a real shove knocks you out of a glide
			else:
				_knock.y = 0.0      # a nudge (a bullet, your own lunge) pushes you along, no lift
		vel += _knock
		if _knock.y > 0.5 and state in [State.GROUND, State.CROUCH, State.SLIDE, State.ROLL, State.BELLY_SLIDE]:
			state = State.AIR   # knocked off your feet
			_since_ground = t.coyote_time + 1.0
		_knock = Vector3.ZERO
	body.velocity = vel
	body.move_and_slide()
	_measure_impact(body, vel)
	if grapple.attached:
		grapple.correct_position(body)
	_ease_eye(delta)


## Rocket boots: a burst toward where you push (see the top of this file).
func _boost(vel: Vector3, input: PlayerInput, grounded: bool) -> Vector3:
	var t := tuning
	if state == State.GLIDE:
		return _glide_boost(vel, input)
	var dir := input.boost_dir
	if dir == Vector3.ZERO:
		var look := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0))
		dir = look * Vector3(input.move.x, 0.0, -input.move.y) if input.move.length() > 0.2 else look * Vector3.FORWARD
		if input.jump_held:
			dir += Vector3.UP * 0.6   # holding jump tips the burst upward
	if dir.length_squared() < 0.0001:
		return vel
	dir = dir.normalized()
	# Fighting your own momentum? The burst first cancels what you have the other way.
	var against := vel.dot(dir)
	if against < 0.0:
		vel -= dir * maxf(against, -t.boost_speed * 0.5)
	vel += dir * t.boost_speed
	since_boost = 0.0
	boosts += 1
	if state in [State.MANTLE, State.ROLL, State.BELLY_SLIDE, State.WALL_RUN]:
		if state == State.WALL_RUN:
			_end_wall_run()
		state = State.AIR
	if grounded:
		vel.y = maxf(vel.y, t.boost_ground_lift)   # off the floor, so friction doesn't eat it
		state = State.AIR
		_since_ground = t.coyote_time + 1.0
	return vel


func boost_readiness() -> float:
	return clampf(since_boost / tuning.boost_cooldown, 0.0, 1.0)


## A hit or a shove: added to your speed on the next step (and lifts you off the
## ground if it pushes upward at all), so it carries through every move.
func knock(push: Vector3) -> void:
	_knock += push


func _measure_impact(body: CharacterBody3D, vel: Vector3) -> void:
	impact_speed = 0.0
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var normal := c.get_normal()
		if normal.y > 0.7 or c.get_collider() is CharacterBody3D:
			continue   # a floor (landing), or another player
		if grapple.attached and c.get_position().distance_to(grapple.anchor) < 2.5:
			continue   # reeled into your own hook point: that's arriving, not a crash
		var into := -vel.dot(normal)
		if into > impact_speed:
			impact_speed = into
			impact_point = c.get_position()


func horizontal_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


## Crouching, sliding, or legs tucked in the air: the short body shape.
func is_low() -> bool:
	return crouched



## Forget everything in progress (respawn, teleport).
func reset() -> void:
	grapple.reset()
	_knock = Vector3.ZERO
	impact_speed = 0.0
	state = State.AIR
	wall_normal = Vector3.ZERO
	_used_wall = Vector3.ZERO
	_mantle = {}
	_jump_buffer = 0.0
	_since_dive = 99.0
	since_boost = 99.0
	_air_dive_used = false
	_flip_used = false
	_roll_left = 0.0
	_flip_left = 0.0
	_glide_left = tuning.glide_time
	_glide_wanted = false
	_glide_on = false
	hang = false
	hanging = false
	_hang_left = tuning.hang_time
	_slam_used = false
	_slam_landing = -1.0
	if crouched and _shape:
		_set_height(tuning.stand_height)
	crouched = false
	prone = false
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


func _update_crouch(body: CharacterBody3D, want: bool, want_prone: bool, grounded: bool, delta: float) -> void:
	var t := tuning
	var diff := t.stand_height - t.crouch_height
	if grounded:
		tuck = move_toward(tuck, 0.0, TUCK_SETTLE_SPEED * delta)
	if want_prone and not prone:
		# Down on your belly: the feet stay on the floor, the top of the body drops.
		_set_height(t.prone_height)
		prone = true
		crouched = true
		return
	if prone:
		if want_prone:
			return
		# Up to a crouch, if there is room above; otherwise stay down (and crawl).
		if body.test_move(body.global_transform, Vector3(0, t.crouch_height - t.prone_height, 0)):
			return
		_set_height(t.crouch_height)
		prone = false
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
	if prone:
		target = tuning.prone_eye_height
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
	var downhill := Vector3(0, -t.gravity * WorldGravity.scale, 0)
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

## In the air, touching (or just off) a wall that a jump would kick off now. For bots.
func can_wall_jump() -> bool:
	return _since_wall <= tuning.wall_jump_grace * 0.7 and _recent_wall != Vector3.ZERO and _wall_is_fresh(_recent_wall) \
		and state != State.GROUND


## The wall last touched in the air (its normal), for bots.
func last_wall() -> Vector3:
	return _recent_wall


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
	var y: float = max(vel.y - t.wall_run_gravity * WorldGravity.scale * delta, -t.max_fall_speed)
	return Vector3(h.x, y, h.z)


func _wall_jump(vel: Vector3, n: Vector3) -> Vector3:
	var t := tuning
	if state == State.WALL_RUN:
		_end_wall_run()
	_used_wall = n
	kick_wall = n
	wall_jumps += 1
	var h := Vector3(vel.x, 0, vel.z)
	var into := h.dot(n)
	if into < 0.0:
		h -= n * into
	# Carry on the way you were running, a little faster (chained kicks don't stack
	# past wall_jump_forward_max).
	var along := h - n * h.dot(n)
	var speed := along.length()
	if speed > 1.0:
		var faster := maxf(speed, minf(speed + t.wall_jump_forward, t.wall_jump_forward_max))
		h += along / speed * (faster - speed)
	h += n * t.wall_jump_push
	return Vector3(h.x, max(vel.y, t.wall_jump_up), h.z)


# ---------------------------------------------------------------------------
# Dive, roll and flip

## Debug menu ("No cooldowns"): the grapple, dive and slide boost are ready again.
func clear_cooldowns() -> void:
	grapple.cooldown_left = 0.0
	since_boost = 99.0
	_since_dive = 99.0
	_since_slide_boost = 99.0


## HUD readouts: how ready each move is, from 0 (just used) to 1 (ready).
func dive_readiness() -> float:
	if _air_dive_used:
		return 0.0   # already dived on this jump
	return clampf(_since_dive / tuning.dive_cooldown, 0.0, 1.0)


func flip_readiness() -> float:
	return 0.0 if _flip_used else 1.0


func slide_boost_readiness() -> float:
	return clampf(_since_slide_boost / tuning.slide_boost_cooldown, 0.0, 1.0)


## Winding a melee swing up in mid-air: the fall is braked to a slow sink, and a
## rise loses most of gravity, for hang_time seconds per time in the air. Sideways
## speed is kept. Any other move takes over from it (it only works in a plain fall).
func _hang(vel: Vector3, delta: float) -> Vector3:
	var t := tuning
	_hang_left = maxf(_hang_left - delta, 0.0)
	hanging = true
	if vel.y > -t.hang_fall_speed:
		vel.y = maxf(vel.y - t.gravity * t.hang_gravity * WorldGravity.scale * delta, -t.hang_fall_speed)
	else:
		vel.y = minf(vel.y + t.hang_brake * delta, -t.hang_fall_speed)
	return vel


## How much of this air time's hang is left, 1..0.
func hang_readiness() -> float:
	return clampf(_hang_left / tuning.hang_time, 0.0, 1.0)


## A ground slam can start: in the air, not yet done this time in the air, with
## room to fall, and not in a move that has you tied up.
func can_slam(body: CharacterBody3D) -> bool:
	if body.is_on_floor() or _slam_used or state in [State.SLAM, State.MANTLE, State.WALL_RUN, State.BELLY_SLIDE, State.ROLL]:
		return false
	return not SurfaceProbe.floor_within(body, tuning.slam_min_height)


## Drive straight down (see _step_slam). Nothing stops it but the floor.
func start_slam(body: CharacterBody3D) -> void:
	if grapple.attached:
		grapple.release()
	if state == State.WALL_RUN:
		_end_wall_run()
	state = State.SLAM
	_slam_used = true
	_slam_time = 0.0
	_slam_from = body.global_position.y
	_slam_landing = -1.0
	_glide_on = false
	_glide_wanted = false
	_flip_left = 0.0
	_knock = Vector3.ZERO
	body.velocity = Vector3(body.velocity.x * 0.25, minf(body.velocity.y, 0.0), body.velocity.z * 0.25)


## A ground slam: straight down at slam_speed, whatever gravity is doing, with the
## sideways speed bled away. No move, shove or key changes it; it ends on the floor
## (take_slam_landing then says from how high), or after slam_timeout with none found.
func _step_slam(body: CharacterBody3D, delta: float) -> void:
	var t := tuning
	_slam_time += delta
	_knock = Vector3.ZERO
	var vel := body.velocity
	var bleed := exp(-8.0 * delta)
	vel = Vector3(vel.x * bleed, maxf(vel.y - t.slam_accel * delta, -t.slam_speed), vel.z * bleed)
	body.velocity = vel
	body.move_and_slide()
	if body.is_on_floor():
		_slam_landing = maxf(_slam_from - body.global_position.y, 0.0)
		state = State.GROUND
		_since_ground = 0.0
		body.velocity = Vector3.ZERO
	elif _slam_time >= t.slam_timeout:
		state = State.AIR


## Has a ground slam just landed? Returns how far it fell (metres) once, then -1.
func take_slam_landing() -> float:
	var fell := _slam_landing
	_slam_landing = -1.0
	return fell


## How much of this air time's glide is left: 1 = all of it, 0 = spent until you land.
func glide_readiness() -> float:
	return clampf(_glide_left / tuning.glide_time, 0.0, 1.0)


func _can_dive(grounded: bool) -> bool:
	if _since_dive < tuning.dive_cooldown or grapple.attached:
		return false
	if state in [State.MANTLE, State.DIVE, State.ROLL, State.BELLY_SLIDE]:
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


## Landing from a dive with the dive button still held: onto your belly, with a
## small push forward.
func _start_belly_slide(vel: Vector3) -> Vector3:
	var t := tuning
	state = State.BELLY_SLIDE
	var h := Vector3(vel.x, 0, vel.z)
	var speed := h.length()
	if speed > 0.01 and speed < t.dive_max_speed:
		h = h / speed * min(speed + t.belly_boost, t.dive_max_speed)
	return Vector3(h.x, vel.y, h.z)


## Sliding on your front: like a slide (little friction, gravity pulls you down
## slopes) but harder to steer. Once it slows to a crawl, you crawl.
func _belly_slide(body: CharacterBody3D, vel: Vector3, wish: Vector3, input: PlayerInput, delta: float) -> Vector3:
	var t := tuning
	var h := Vector3(vel.x, 0, vel.z)
	var speed := h.length()
	var n := body.get_floor_normal()
	# Crawling, unless the floor is steep enough to slide you off again (a belly slide
	# down a chute that slowed to a crawl picks up speed, rather than crawling on down).
	if speed <= t.belly_crawl_speed + 0.05 and n.y > BELLY_SLOPE:
		var top: float = t.belly_crawl_speed * min(input.move.length(), 1.0)
		vel = _apply_friction(vel, top, delta)
		vel = _accelerate(vel, wish, top, t.ground_accel, delta)
		return Vector3(vel.x, min(vel.y, 0.0), vel.z)
	var downhill := Vector3(0, -t.gravity * WorldGravity.scale, 0)
	downhill -= n * downhill.dot(n)
	vel += downhill * delta
	h = Vector3(vel.x, 0, vel.z)
	speed = h.length()
	var dir := h / speed
	if wish != Vector3.ZERO:
		var angle := dir.signed_angle_to(wish, Vector3.UP)
		dir = dir.rotated(Vector3.UP, clamp(angle, -t.belly_turn_rate * delta, t.belly_turn_rate * delta))
	speed = max(speed - t.belly_decel * delta, t.belly_crawl_speed)
	h = dir * speed
	return Vector3(h.x, min(vel.y, 0.0), h.z)


func _flip(vel: Vector3, wish: Vector3, input: PlayerInput) -> Vector3:
	var t := tuning
	state = State.FLIP
	_flip_left = t.flip_time
	flip_dir = input.move.limit_length(1.0).normalized() if wish != Vector3.ZERO else Vector2(0, -1)  # no direction: backflip
	var h := Vector3(vel.x, 0, vel.z) + wish * t.flip_burst
	return Vector3(h.x, max(vel.y, t.flip_up), h.z)


# ---------------------------------------------------------------------------
# Glide

func _can_glide(body: CharacterBody3D, grounded: bool) -> bool:
	if grounded or _glide_left <= 0.0 or grapple.attached or state == State.WALL_RUN:
		return false
	# Shift pressed as you leave or reach the floor is a sprint, not a glide.
	return not SurfaceProbe.floor_within(body, tuning.glide_min_height)


## Up-and-down speed goes; you carry on the way you were going. (From there you
## slow and sink: see _glide.)
func _start_glide(vel: Vector3) -> Vector3:
	state = State.GLIDE
	_glide_on = true
	_flip_left = 0.0   # gliding out of a flip: the flip is over
	return Vector3(vel.x, 0.0, vel.z)


## Gliding: no steering, so you hold your line while your speed bleeds off toward
## a drift, and you sink: hardly at all at first, faster the more of the budget
## you have used (so stopping and starting again does not buy a fresh hover).
func _glide(vel: Vector3, delta: float) -> Vector3:
	var t := tuning
	_glide_left = maxf(_glide_left - delta, 0.0)
	if _glide_left <= 0.0:
		state = State.AIR
	var used := 1.0 - _glide_left / t.glide_time
	var h := Vector2(vel.x, vel.z)
	var speed := h.length()
	if speed > t.glide_drift_speed:
		h *= (t.glide_drift_speed + (speed - t.glide_drift_speed) * exp(-t.glide_drag * delta)) / speed
	return Vector3(h.x, -t.glide_fall_speed * used * WorldGravity.scale, h.y)


## Rocket boots while gliding: the burst turns the whole glide the way you press
## (WASD as seen from the way you face; forward if you hold nothing), carrying
## all the speed you had plus the burst's. You keep gliding.
func _glide_boost(vel: Vector3, input: PlayerInput) -> Vector3:
	var t := tuning
	var dir := Vector3(input.boost_dir.x, 0.0, input.boost_dir.z)   # a bot's aim, kept level
	if dir.length_squared() < 0.0001:
		dir = _wish_dir(input)
	if dir.length_squared() < 0.0001:
		dir = _facing(input)
	dir = dir.normalized()
	var speed := Vector2(vel.x, vel.z).length() + t.boost_speed
	since_boost = 0.0
	boosts += 1
	return Vector3(dir.x * speed, vel.y, dir.z * speed)


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
