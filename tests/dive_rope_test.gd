extends SceneTree
## Diving into the grappling hook's rope (MovementController.dove_in), driven with scripted
## input on a flat floor in front of a tall wall to hook.
## Run: godot --headless --path . --fixed-fps 60 --script tests/dive_rope_test.gd
##
## In a dive when the rope pulls tight (dived after firing, or fired in the dive), the
## dive gives way to the rope: the GRAPPLE state, with the rope's steering and its jump
## off, remembered as dived into until you arrive (where the pull fades, or no longer
## closing on the hook). Let go before that and the dive carries on and lands as a dive
## does (a roll, or on your belly with the key held); come down on the floor still on
## the rope with the key held and you are dragged on your belly. A hook too near to zip
## to is just a swing, and so is a rope caught without a dive. The fact travels to other
## players in the animation flags.

const S := MovementController.State
const WALL_Z := -42.0   ## the wall's face
const FROM_Z := -24.0   ## where each run at it starts

var _fails := 0
var input := PlayerInput.new()


func _initialize() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(400, 1, 400))               # the floor
	_box(Vector3(0, 30, WALL_Z - 0.5), Vector3(400, 60, 1))       # a tall wall to hook
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


func _run() -> void:
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
	var m := MovementController.new(MovementTuning.for_variant("b"))
	var t := m.tuning
	print("Diving into the rope")

	# --- Dived after firing: the rope pulls tight in the dive.
	await _dive_in(body, m, 16.0, false)
	_check(m.state == S.GRAPPLE and m.dove_in, "in a dive as the rope pulls tight: it is the rope's move, remembered as dived into (%s)" % S.keys()[m.state])
	var far := m.grapple.rope_origin(body).distance_to(m.grapple.anchor)
	# The rope's own steering (six times the dive's).
	input.move = Vector2(1, 0)
	await _steps(body, m, 18)
	var sideways := absf(body.velocity.x)
	_check(m.state == S.GRAPPLE and sideways > 1.5, "...with the rope's steering (%.1f m/s sideways in 0.3 s; a dive's would give %.1f)" % [
		sideways, sideways * t.dive_air_accel / t.grapple_air_accel])
	input.move = Vector2(0, 1)
	# Arriving.
	var there := -1.0
	var zipped := 0
	for i in 400:
		await _steps(body, m, 1)
		if m.dove_in:
			zipped += 1
		elif there < 0.0:
			there = m.grapple.rope_origin(body).distance_to(m.grapple.anchor)
			break
	_check(there >= 0.0 and m.grapple.attached and m.state == S.GRAPPLE,
		"...until you arrive, still on the rope (from %.0f m, %.1f m from the hook after %.2f s)" % [far, there, zipped / 60.0])
	_check(there <= t.grapple_pull_stop + 0.5 or zipped > 20, "...where the pull fades, or no longer closing on it")
	input.grapple = false
	await _steps(body, m, 2)
	_check(m.state in [S.AIR, S.WALL_RUN, S.WALL_SIT], "let go after arriving: not the dive again (%s)" % S.keys()[m.state])

	# --- Fired in the dive.
	await _dive_in(body, m, 16.0, true)
	_check(m.state == S.GRAPPLE and m.dove_in, "the hook fired in the dive counts the same")

	# --- Let go part of the way along: the dive carries on, and lands as a dive does.
	await _steps(body, m, 15)
	input.grapple = false
	await _steps(body, m, 1)
	_check(m.state == S.DIVE and not m.dove_in, "let go before arriving: the dive carries on (%s)" % S.keys()[m.state])
	input.move = Vector2.ZERO
	var rolled := false
	for i in 300:
		await _steps(body, m, 1)
		rolled = rolled or m.state == S.ROLL
		if m.state in [S.GROUND, S.CROUCH]:
			break
	_check(rolled, "...and lands in its roll")
	await _dive_in(body, m, 16.0, false)
	await _steps(body, m, 15)
	input.grapple = false
	input.crouch = true   # (Ctrl held all the way down)
	var belly := false
	for i in 300:
		await _steps(body, m, 1)
		belly = belly or m.state == S.BELLY_SLIDE
		if belly:
			break
	_check(belly, "...or on your belly with the key held")
	input.crouch = false

	# --- The rope's jump off, in the zip.
	await _dive_in(body, m, 16.0, false)
	await _steps(body, m, 12)
	var rising := body.velocity.y
	input.jump_pressed = true
	await _steps(body, m, 1)
	_check(m.state == S.AIR and not m.dove_in and not m.grapple.attached and body.velocity.y > rising + t.grapple_jump_boost * 0.5,
		"a jump off the rope in the zip is a jump, not the dive again (%s, rising %.1f from %.1f)" % [S.keys()[m.state], body.velocity.y, rising])

	# --- Down on the floor still on the rope, the key held: dragged on your belly.
	await _dive_in(body, m, 0.6, false, true)
	var dragged := 0
	var on_rope := 0
	for i in 200:
		await _steps(body, m, 1)
		if m.grapple.attached:
			on_rope += 1
			if m.state == S.BELLY_SLIDE:
				dragged += 1
	_check(dragged > 20, "a low hook, the key held: dragged along the floor on your belly (%.2f s of %.2f s on the rope)" % [dragged / 60.0, on_rope / 60.0])
	input.crouch = false

	# --- A hook too near to zip to, and a rope caught without a dive: just a swing.
	await _settle(body, m, Vector3(0, 0, WALL_Z + 6.0))
	input.move = Vector2(0, 1)
	_press_jump()
	await _steps(body, m, 8)
	input.pitch = deg_to_rad(40.0)
	input.grapple = true
	input.grapple_pressed = true
	input.crouch = true
	input.crouch_pressed = true
	await _steps(body, m, 1)
	input.grapple_pressed = false
	input.crouch = false
	var near := await _until_tight(body, m)
	_check(near and m.state == S.GRAPPLE and not m.dove_in, "a dive into a hook %.0f m off is just a swing" % m.grapple.rope_origin(body).distance_to(m.grapple.anchor))
	await _settle(body, m, Vector3(0, 0, FROM_Z))
	input.move = Vector2(0, 1)
	_press_jump()
	await _steps(body, m, 8)
	input.pitch = deg_to_rad(40.0)
	input.grapple = true
	input.grapple_pressed = true
	await _steps(body, m, 1)
	input.grapple_pressed = false
	var plain := await _until_tight(body, m)
	_check(plain and m.state == S.GRAPPLE and not m.dove_in, "the rope caught in a plain fall is a swing too")
	input.grapple = false
	await _steps(body, m, 2)
	_check(m.state == S.AIR, "...and letting go of it is a plain fall")

	# --- What travels to other players.
	var none := RobotAnimInput.new()
	none.flags = RobotAnimInput.make_flags(false, false, false, 0, 0, 0, 0, false, 0, false, false, 0, true, RobotAnimInput.zip_of(false, 1))
	var left := RobotAnimInput.new()
	left.flags = RobotAnimInput.make_flags(true, true, true, 3, 3, 3, 3, true, 3, true, true, 7, true, RobotAnimInput.zip_of(true, -1))
	var right := RobotAnimInput.new()
	right.flags = int(PackedFloat32Array([float(RobotAnimInput.make_flags(true, true, true, 3, 3, 3, 3, true, 3, true, true, 7, true, RobotAnimInput.zip_of(true, 1)))])[0])
	var straight := RobotAnimInput.new()
	straight.flags = RobotAnimInput.make_flags(false, false, false, 0, 0, 0, 0, false, 0, false, false, 0, false, RobotAnimInput.zip_of(true, 0))
	_check(not none.zipping() and none.pumping() and left.zipping() and left.zip_side() == -1 and left.pumping() and RobotAnimInput.step_of(left.flags) == 7
		and right.zipping() and right.zip_side() == 1 and right.reloading() and straight.zipping() and straight.zip_side() == 0 and not straight.pumping(),
		"the dive into the rope and the way it was steered fit a snapshot's flags, beside every other flag")

	print("DIVE ROPE TEST PASSED" if _fails == 0 else "DIVE ROPE TEST FAILED: %d" % _fails)
	quit(1 if _fails else 0)


## Runs, jumps, fires the hook at the wall `up` metres above the floor... and dives
## (after firing, or first: `dive_first`), then steps until the rope has pulled tight.
## hold: the dive key stays held.
func _dive_in(body: CharacterBody3D, m: MovementController, up: float, dive_first: bool, hold: bool = false) -> void:
	await _settle(body, m, Vector3(0, 0, FROM_Z + 5.0))
	input.move = Vector2(0, 1)
	await _steps(body, m, 40)
	_press_jump()
	await _steps(body, m, 10)
	var eye := body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	input.pitch = atan2(up - eye.y, eye.z - WALL_Z)
	if dive_first:
		input.crouch = true
		input.crouch_pressed = true
		await _steps(body, m, 1)
		input.crouch = hold
		await _steps(body, m, 2)
	input.grapple = true
	input.grapple_pressed = true
	await _steps(body, m, 1)
	input.grapple_pressed = false
	if not dive_first:
		for i in 60:   # (the dive once the hook has bitten: the slack is on its way in)
			if m.grapple.biting or m.grapple.attached:
				break
			await _steps(body, m, 1)
		input.crouch = true
		input.crouch_pressed = true
		await _steps(body, m, 1)
		input.crouch = hold
	if not await _until_tight(body, m):
		_check(false, "the hook caught the wall")


func _until_tight(body: CharacterBody3D, m: MovementController) -> bool:
	for i in 120:
		if m.grapple.attached:
			return true
		await _steps(body, m, 1)
	return m.grapple.attached


func _settle(body: CharacterBody3D, m: MovementController, at: Vector3) -> void:
	input = PlayerInput.new()
	m.reset()
	body.global_position = at
	body.velocity = Vector3.ZERO
	await _steps(body, m, 20)


func _press_jump() -> void:
	input.jump_pressed = true
	input.jump_held = true


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
		input.grapple_pressed = false


func _check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
