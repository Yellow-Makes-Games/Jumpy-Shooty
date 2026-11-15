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
	motor.step(body, input, dt)
	input.clear_edges()
	if _data.has("peak"):
		_data["peak"] = max(_data["peak"], body.global_position.y)
	_frame += 1


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
