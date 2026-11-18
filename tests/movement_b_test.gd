extends SceneTree
## Variant B's movement (see MovementTuning._apply_b), driven with scripted input on a
## flat floor beside a tall wall, next to a classic body for comparison.
## Run: godot --headless --path . --fixed-fps 60 --script tests/movement_b_test.gd
##
## Checks: about 15% slower running, the same jump height; legs tucked in the air with
## no key; no flips or glides; Space in mid-air fires the rocket boots, and with the
## jetpack a tap boosts while a hold asks for the jetpack; Ctrl forward dives onto your
## belly and crawls, Ctrl back slides on your back and ends in a crouch, Ctrl standing
## still crouches; pushing into a wall in mid-air sits on it for a second, then slides
## down, and a jump kicks off it. Classic still flips.

const S := MovementController.State
const WALL_Z := -3.0   ## the wall's face (it stands beyond, toward -z)

var _fails := 0
var input := PlayerInput.new()


func _initialize() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(400, 1, 400))           # the floor
	_box(Vector3(100, 6, WALL_Z - 0.5), Vector3(20, 12, 1))  # a tall wall, no ledge to climb
	_box(Vector3(130, 6, 50), Vector3(1, 12, 20))          # another, facing -x (face at x = 129.5)
	_run.call_deferred()


func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = pos
	root.add_child(b)


func _body(x: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	root.add_child(body)
	body.global_position = Vector3(x, 0.0, 0.0)
	return body


func _run() -> void:
	var b_body := _body(0.0)
	var b := MovementController.new(MovementTuning.for_variant("b"))
	var c_body := _body(-50.0)
	var c := MovementController.new(MovementTuning.for_variant("classic"))
	print("Variant B movement checks")

	# --- Slower running, same jump.
	var b_speed := await _run_speed(b_body, b)
	var c_speed := await _run_speed(c_body, c)
	_check(absf(b_speed / c_speed - 0.85) < 0.02, "runs about 15%% slower (%.2f vs %.2f m/s)" % [b_speed, c_speed])
	var b_head := await _jump_peak(b_body, b)
	var c_head := await _jump_peak(c_body, c)
	_check(absf(b_head - c_head) < 0.05, "jumps as high (%.2f vs %.2f m)" % [b_head, c_head])

	# --- Tucked in the air with no key, standing again on landing.
	await _settle(b_body, b, Vector3(0, 0, 0))
	_press_jump()
	await _steps(b_body, b, 18)
	_check(b.crouched and b.state == S.AIR, "legs tucked in the air with no key")
	await _steps(b_body, b, 60)
	_check(not b.crouched and b.state == S.GROUND, "standing again after landing")

	# --- Space in mid-air: rocket boots, not a flip. Shift: no glide.
	await _settle(b_body, b, Vector3(0, 0, 0))
	_press_jump()
	await _steps(b_body, b, 18)
	var boosts := b.boosts
	input.glide = true
	input.glide_pressed = true
	_press_jump()
	await _steps(b_body, b, 1)
	_check(b.boosts == boosts + 1 and b.state != S.FLIP, "Space in mid-air fires the rocket boots, no flip")
	await _steps(b_body, b, 20)
	_check(b.state != S.GLIDE, "Shift in mid-air does not glide")
	input.glide = false

	# --- With the jetpack: a tap boosts, a hold asks for the jetpack.
	b.has_jetpack = true
	await _settle(b_body, b, Vector3(0, 0, 0))
	_press_jump()
	await _steps(b_body, b, 16)
	input.jump_held = false
	await _steps(b_body, b, 2)
	boosts = b.boosts
	_press_jump()
	await _steps(b_body, b, 4)
	input.jump_held = false
	await _steps(b_body, b, 1)
	_check(b.boosts == boosts + 1 and not b.space_jet, "with the jetpack, a Space tap fires the boots")
	b.clear_cooldowns()
	_press_jump()
	var jet := false
	for i in 24:
		await _steps(b_body, b, 1)
		jet = jet or b.space_jet
	_check(jet and b.boosts == boosts + 1, "...and holding Space flies the jetpack instead")
	input.jump_held = false
	b.has_jetpack = false

	# --- Ctrl forward: dive, belly slide, crawl.
	await _settle(b_body, b, Vector3(0, 0, 0))
	input.move = Vector2(0, 1)
	await _steps(b_body, b, 60)
	input.crouch = true
	input.crouch_pressed = true
	await _steps(b_body, b, 1)
	input.crouch_pressed = false
	_check(b.state == S.DIVE, "Ctrl running forward dives")
	var belly := false
	for i in 90:
		await _steps(b_body, b, 1)
		belly = belly or b.state == S.BELLY_SLIDE
	_check(belly, "...lands on your belly while Ctrl is held")
	input.move = Vector2.ZERO
	await _steps(b_body, b, 240)
	_check(b.state == S.BELLY_SLIDE and b.prone and b.horizontal_speed(b_body) <= b.tuning.belly_crawl_speed + 0.1,
			"...and you lie there once the slide runs out (%.2f m/s)" % b.horizontal_speed(b_body))
	input.move = Vector2(0, 1)
	await _steps(b_body, b, 180)
	_check(b.state == S.BELLY_SLIDE and absf(b.horizontal_speed(b_body) - b.tuning.belly_crawl_speed) < 0.25,
			"...crawling on your stomach while Ctrl is held (%.2f m/s)" % b.horizontal_speed(b_body))
	input.move = Vector2.ZERO
	input.crouch = false
	await _steps(b_body, b, 30)
	_check(not b.prone and b.state != S.BELLY_SLIDE, "letting go gets you up")

	# --- Ctrl backward: a slide on your back, then a crouch.
	await _settle(b_body, b, Vector3(0, 0, 0))
	input.move = Vector2(0, -1)
	await _steps(b_body, b, 60)
	input.crouch = true
	input.crouch_pressed = true
	await _steps(b_body, b, 1)
	input.crouch_pressed = false
	_check(b.state == S.SLIDE, "Ctrl running backward slides on your back (%s)" % S.keys()[b.state])
	input.move = Vector2.ZERO
	await _steps(b_body, b, 180)
	_check(b.state == S.CROUCH, "...and ends in a crouch (%s)" % S.keys()[b.state])
	input.crouch = false
	await _steps(b_body, b, 10)

	# --- Ctrl standing still: a crouch, no dive or slide.
	await _settle(b_body, b, Vector3(0, 0, 0))
	input.crouch = true
	input.crouch_pressed = true
	await _steps(b_body, b, 1)
	input.crouch_pressed = false
	await _steps(b_body, b, 10)
	_check(b.state == S.CROUCH, "Ctrl standing still crouches (%s)" % S.keys()[b.state])
	input.crouch = false
	await _steps(b_body, b, 10)

	# --- Wall sit: stick a second, slide down, kick off with a jump.
	await _settle(b_body, b, Vector3(100, 0, WALL_Z + 1.2))
	input.move = Vector2(0, 1)   # into the wall
	_press_jump()
	var sat_at := -1
	for i in 60:
		await _steps(b_body, b, 1)
		if b.state == S.WALL_SIT:
			sat_at = i
			break
	_check(sat_at >= 0, "pushing into a wall in mid-air sits on it")
	var y0 := b_body.global_position.y - b.tuck   # (the legs come down onto the wall: the body stays put)
	await _steps(b_body, b, 45)
	var moved := b_body.global_position.y - b.tuck - y0
	_check(b.state == S.WALL_SIT and absf(moved) < 0.05, "...and stays put for a while (moved %.2f m)" % moved)
	await _steps(b_body, b, 30)
	_check(b.state == S.WALL_SIT and b_body.velocity.y < -1.0, "...then slides down it (%.1f m/s)" % b_body.velocity.y)
	var kicks := b.wall_jumps
	_press_jump()
	await _steps(b_body, b, 1)
	_check(b.wall_jumps == kicks + 1 and b_body.velocity.z > 1.0, "a jump kicks off the wall")
	input.move = Vector2.ZERO

	# Stopped dead against a wall (no speed to look along), facing +x: still sits.
	await _settle(b_body, b, Vector3(120, 0, 50))
	b_body.global_position = Vector3(129.5 - 0.42, 3.0, 50.0)
	b_body.velocity = Vector3.ZERO
	input.yaw = -PI / 2.0
	input.move = Vector2(0, 1)
	var sat := false
	for i in 20:
		await _steps(b_body, b, 1)
		sat = sat or b.state == S.WALL_SIT
	await _steps(b_body, b, 20)
	_check(sat and b.state == S.WALL_SIT, "hanging still against a wall, pushing into it sits on it (%s)" % S.keys()[b.state])
	input.move = Vector2.ZERO
	input.yaw = 0.0

	# --- Classic is untouched: a mid-air jump still flips.
	await _settle(c_body, c, Vector3(-50, 0, 0))
	_press_jump()
	await _steps(c_body, c, 18)
	_press_jump()
	await _steps(c_body, c, 1)
	_check(c.state == S.FLIP and not c.crouched, "classic: a mid-air jump flips, legs not tucked")

	print("PASS: all Variant B checks" if _fails == 0 else "FAIL: %d Variant B checks" % _fails)
	quit(1 if _fails > 0 else 0)


## Top running speed after 3 s.
func _run_speed(body: CharacterBody3D, m: MovementController) -> float:
	await _settle(body, m, Vector3(body.global_position.x, 0, 0))
	input.move = Vector2(0, 1)
	await _steps(body, m, 180)
	input.move = Vector2.ZERO
	return m.horizontal_speed(body)


## The highest a standing jump lifts the body (less the tuck, which lifts only the feet).
func _jump_peak(body: CharacterBody3D, m: MovementController) -> float:
	await _settle(body, m, Vector3(body.global_position.x, 0, 0))
	var top := 0.0
	_press_jump()
	for i in 70:
		await _steps(body, m, 1)
		top = maxf(top, body.global_position.y - m.tuck)
	return top


func _settle(body: CharacterBody3D, m: MovementController, at: Vector3) -> void:
	input = PlayerInput.new()
	m.reset()
	body.global_position = at
	body.velocity = Vector3.ZERO
	await _steps(body, m, 20)


func _press_jump() -> void:
	input.jump_pressed = true
	input.jump_held = true


## Steps the body `n` sixtieths of a second (the physics runs faster: every tick of it).
## Presses last one step.
func _steps(body: CharacterBody3D, m: MovementController, n: int) -> void:
	var ticks := Engine.physics_ticks_per_second
	for i in n * ticks / 60:
		await physics_frame
		m.step(body, input, 1.0 / ticks)
		input.jump_pressed = false
		input.crouch_pressed = false
		input.dive_pressed = false
		input.glide_pressed = false
		input.boost_pressed = false


func _check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
