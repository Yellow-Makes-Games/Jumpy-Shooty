extends SceneTree
## Headless movement checks. Run: godot --headless --path . --script tests/movement_test.gd
## Builds a flat floor and a test body, drives MovementController with scripted
## input, and checks speeds, stopping, jump height and momentum carry.

var body: CharacterBody3D
var motor: MovementController
var input: PlayerInput
var failures := 0
var _steps: Array = []
var _frame := 0
var _scenario := -1
var _data := {}

const ANCHOR := Vector3(150, 60, 0)   ## underside of the block we swing from
const ROPE := 15.0


func _initialize() -> void:
	physics_frame.connect(_tick)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)

	body = CharacterBody3D.new()
	body.floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	root.add_child(body)

	# A block hanging high in the air to swing from. Its underside is at y = 60.
	var hang := StaticBody3D.new()
	var hang_shape := CollisionShape3D.new()
	var hang_box := BoxShape3D.new()
	hang_box.size = Vector3(4, 2, 4)
	hang_shape.shape = hang_box
	hang.add_child(hang_shape)
	hang.position = ANCHOR + Vector3(0, 1, 0)
	root.add_child(hang)

	motor = MovementController.new()
	input = PlayerInput.new()

	var t := motor.tuning
	_steps = [
		["settle", 0.3, func(): pass, func(): pass],
		["run reaches run speed", 1.5,
			func(): input.move = Vector2(0, 1),
			func(): _expect_near("run speed", motor.horizontal_speed(body), t.run_speed, 0.3)],
		["sprint reaches sprint speed", 1.5,
			func(): input.sprint = true,
			func(): _expect_near("sprint speed", motor.horizontal_speed(body), t.sprint_speed, 0.3)],
		["stops quickly when released", 0.6,
			func():
				input.move = Vector2.ZERO
				input.sprint = false,
			func(): _expect_below("speed after 0.6 s", motor.horizontal_speed(body), 0.5)],
		["jump height", 1.2,
			func():
				_data["y0"] = body.global_position.y
				_data["peak"] = body.global_position.y
				input.jump_pressed = true,
			func():
				var expected: float = t.jump_velocity * t.jump_velocity / (2.0 * t.gravity)
				_expect_near("jump height", _data["peak"] - _data["y0"], expected, 0.12)
				_expect_true("landed again", body.is_on_floor())],
		["air momentum is kept", 0.5,
			func():
				body.global_position = Vector3(0, 30, 0)
				body.velocity = Vector3.ZERO
				body.move_and_slide()  # refresh "on floor" after the teleport
				body.velocity = Vector3(0, 0, -20)
				input.move = Vector2(0, 1),
			func(): _expect_near("air speed after 0.5 s", motor.horizontal_speed(body), 20.0, 0.05)],
		["air steering turns without slowing much", 0.5,
			func(): input.move = Vector2(1, 0),
			func(): _expect_true("still fast (>18 m/s)", motor.horizontal_speed(body) > 18.0)],
		["land and stop", 3.0,
			func(): input.move = Vector2.ZERO,
			func(): _expect_true("on the floor", body.is_on_floor())],
		["bunny hop keeps speed", 3.0,
			func():
				body.velocity = Vector3(0, 0, -14)
				input.move = Vector2(0, 1)
				input.jump_pressed = true
				_data["bhop"] = true,
			func():
				_data.erase("bhop")
				_expect_true("still above 13.5 m/s after 3 s of timed jumps (%.2f)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > 13.5)],
		["no bunny hop without jumping", 1.0,
			func(): pass,
			func(): _expect_below("speed after 1 s on the ground without jumping", motor.horizontal_speed(body), 9.0)],
		["air strafing gains speed", 2.5,
			func():
				body.global_position = Vector3(0, 80, 0)
				body.velocity = Vector3.ZERO
				body.move_and_slide()
				body.velocity = Vector3(0, 0, -9)
				input.yaw = 0.0
				input.move = Vector2(1, 0)
				_data["strafe"] = true,
			func():
				_data.erase("strafe")
				_expect_true("faster than the 9 m/s it started with (%.2f)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > 10.5)],
		["grapple catches the block and swings like a pendulum", 2.6,
			func():
				_start_swing()
				_data["swing"] = {"max_speed": 0.0, "max_stretch": 0.0, "lowest": 999.0},
			func():
				var d: Dictionary = _data["swing"]
				_data.erase("swing")
				var g := motor.grapple
				_expect_true("hooked on (anchor %s)" % g.anchor, g.attached)
				_expect_near("rope length", g.length, ROPE, 0.3)
				# Falling from 60 degrees: drop = L(1 - cos 60) = L/2, so v = sqrt(2 g L/2).
				var expected := sqrt(t.gravity * g.length)
				_expect_near("speed at the bottom of the swing", d["max_speed"], expected, expected * 0.06)
				_expect_below("rope stretch", d["max_stretch"], 0.15)
				_expect_near("lowest point is a rope's length below the anchor", g.anchor.y - d["lowest"], g.length, 0.2)],
		["letting go keeps your momentum", 0.4,
			func():
				_start_swing()
				_data["release_at_bottom"] = true,
			func():
				_expect_true("let go", not motor.grapple.attached)
				var v0: float = _data.get("release_speed", 0.0)
				_expect_true("released fast (%.2f m/s)" % v0, v0 > 0.9 * sqrt(t.gravity * ROPE))
				_expect_near("horizontal speed 0.4 s after letting go", motor.horizontal_speed(body), v0, 0.2)
				_data.erase("release_speed")],
		["cooldown blocks an instant re-grapple", 0.05,
			func():
				_teleport(ANCHOR + Vector3(0, -12, 3))
				_aim_at(ANCHOR)
				input.grapple = true
				input.grapple_pressed = true
				_data["regrab"] = 0,
			func():
				_data.erase("regrab")
				_expect_true("still off the rope during the cooldown", not motor.grapple.attached)],
		["grapple works again after the cooldown", t.grapple_cooldown + 0.05,
			func(): input.grapple = false,
			func():
				_aim_at(ANCHOR)
				input.grapple = true
				input.grapple_pressed = true
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
				input.clear_edges()
				_expect_true("hooked on again", motor.grapple.attached)
				input.grapple = false
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)],
		["grapple misses when the target is out of range", 0.1,
			func():
				motor.grapple.reset()
				_teleport(ANCHOR + Vector3(t.grapple_range + 5.0, -2.0, 0))
				_aim_at(ANCHOR)
				input.grapple = true
				input.grapple_pressed = true,
			func():
				_expect_true("not hooked", not motor.grapple.attached)
				input.grapple = false
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)],
		["jumping off the rope gives an upward kick", 0.05,
			func():
				motor.grapple.reset()
				_start_swing()
				_data["jump_off_after"] = 0.6,
			func():
				_data.erase("jump_off_after")
				_expect_true("let go", not motor.grapple.attached)
				_expect_true("moving upward after the jump (%.2f m/s)" % body.velocity.y, body.velocity.y > t.grapple_jump_boost * 0.8)],
	]
	print("Movement checks")


func _tick() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _scenario == -1 or _frame * dt >= _steps[_scenario][1]:
		if _scenario >= 0:
			_steps[_scenario][3].call()
		_scenario += 1
		_frame = 0
		if _scenario >= _steps.size():
			print("FAIL: %d movement checks failed" % failures if failures else "PASS: all movement checks")
			quit(1 if failures else 0)
			return
		_steps[_scenario][2].call()
	if _data.has("bhop") and body.is_on_floor() == false and body.velocity.y < 0.0 and body.global_position.y < 0.15:
		input.jump_pressed = true  # press jump just before touching down
	if _data.has("strafe"):
		input.yaw -= 1.6 * dt  # turn smoothly toward the strafe direction
	if _data.has("release_at_bottom"):
		_steps[_scenario][1] = 99.0  # keep swinging until we pass under the anchor
		if motor.grapple.attached and body.global_position.x <= ANCHOR.x:
			_data.erase("release_at_bottom")
			input.grapple = false  # let go
			_data["release_speed"] = motor.horizontal_speed(body)
			_frame = 0
			_steps[_scenario][1] = 0.4
	if _data.has("regrab"):
		_data["regrab"] += 1
		if _data["regrab"] == 2:
			input.grapple = false  # let go
		elif _data["regrab"] == 4:
			input.grapple = true   # and immediately try again
			input.grapple_pressed = true
	if _data.has("jump_off_after"):
		_data["jump_off_after"] -= dt
		_steps[_scenario][1] = 99.0
		if _data["jump_off_after"] <= 0.0:
			input.jump_pressed = true
			_steps[_scenario][1] = 0.0  # check straight after this step
	motor.step(body, input, dt)
	input.clear_edges()
	if _data.has("swing"):
		var d: Dictionary = _data["swing"]
		d["max_speed"] = max(d["max_speed"], body.velocity.length())
		var g := motor.grapple
		if g.attached:
			d["max_stretch"] = max(d["max_stretch"], g.rope_origin(body).distance_to(g.anchor) - g.length)
			d["lowest"] = min(d["lowest"], g.rope_origin(body).y)
	if _data.has("peak"):
		_data["peak"] = max(_data["peak"], body.global_position.y)
	_frame += 1


## Hang at 60 degrees from vertical, ROPE metres from the anchor, at rest, and fire the hook.
func _start_swing() -> void:
	var t := motor.tuning
	motor.grapple.reset()
	var origin := ANCHOR + Vector3(sin(PI / 3.0), -cos(PI / 3.0), 0) * ROPE
	_teleport(origin - Vector3(0, t.grapple_attach_height, 0))
	_aim_at(ANCHOR)
	input.move = Vector2.ZERO
	input.sprint = false
	input.grapple = true
	input.grapple_pressed = true


func _teleport(pos: Vector3) -> void:
	body.global_position = pos
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	body.global_position = pos
	body.velocity = Vector3.ZERO


func _aim_at(target: Vector3) -> void:
	var to := target - (body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0))
	input.yaw = atan2(-to.x, -to.z)
	input.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _expect_near(what: String, value: float, expected: float, tolerance: float) -> void:
	var ok: bool = abs(value - expected) <= tolerance
	_report(ok, "%s = %.2f (expected %.2f ± %.2f)" % [what, value, expected, tolerance])


func _expect_below(what: String, value: float, limit: float) -> void:
	_report(value < limit, "%s = %.2f (expected below %.2f)" % [what, value, limit])


func _expect_true(what: String, ok: bool) -> void:
	_report(ok, what)


func _report(ok: bool, text: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", text])
	if not ok:
		failures += 1
