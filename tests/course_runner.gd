extends SceneTree
## Shared by the map tests: runs a scripted player through a list of courses on a
## map, one after another, using the real movement code. A test script extends this
## one and says which map and which courses (see tests/course_test.gd).
##
## A course is a Dictionary: "name", "start" (Vector3), optional "yaw", "max_time",
## "drive" (called every physics step to press the buttons), "done" (stop early when
## it returns true) and "check" (called at the end; calls _expect).

const NORTH := 0.0
const SOUTH := PI
const EAST := -PI / 2.0   ## yaw that faces +x
const WEST := PI / 2.0

var body: CharacterBody3D
var motor: MovementController
var input: PlayerInput
var failures := 0
var level: Node3D

var _runs: Array = []
var _index := -1
var _time := 0.0
var _run: Dictionary
var _mem := {}   # scratch state for the current run


## The map to run on.
func _layout() -> MapLayout:
	return null


## The courses, in order.
func _courses() -> Array:
	return []


func _title() -> String:
	return "Course checks"


## Extra checks before the courses (after the map has been in the world for a moment).
func _before_courses() -> void:
	pass


func _initialize() -> void:
	level = Node3D.new()
	root.add_child(level)
	_layout().instantiate(level)

	body = CharacterBody3D.new()
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_stop_on_slope = true
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
	_runs = _courses()
	var only := OS.get_environment("COURSE_ONLY")   # run just the courses whose name contains this
	if only != "":
		_runs = _runs.filter(func(r): return only in r.name)
	print(_title())
	_start.call_deferred()


func _start() -> void:
	for i in 3:
		await physics_frame
	if OS.get_environment("COURSE_ONLY") in ["", "checks"]:   # "checks" = only the checks before the courses
		await _before_courses()
	physics_frame.connect(_tick)


func _tick() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _index == -1 or _time >= _run.max_time or _run.done.call():
		if _index >= 0:
			_run.check.call()
		_index += 1
		if _index >= _runs.size():
			print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
			quit(1 if failures else 0)
			return
		_run = _runs[_index]
		_time = 0.0
		_mem = {"states": {}}
		motor.reset()
		_clear_input()
		_teleport(_run.start, _run.get("yaw", EAST))
		print("  %s" % _run.name)
	_run.drive.call(dt)
	motor.step(body, input, dt)
	input.clear_edges()
	_mem.states[motor.state] = true
	if OS.get_environment("COURSE_DEBUG") == _run.name.get_slice(":", 0) and int(_time * 120) % 6 == 0:
		var p := body.global_position
		print("      t=%.2f pos=(%.1f, %.1f, %.1f) v=(%.1f, %.1f, %.1f) %s rope=%s" % [_time, p.x, p.y, p.z, body.velocity.x, body.velocity.y, body.velocity.z, MovementController.State.keys()[motor.state], motor.grapple.attached])
	_mem["max_speed"] = max(_mem.get("max_speed", 0.0), motor.horizontal_speed(body))
	_time += dt


# ---------------------------------------------------------------------------

func _look_at(target: Vector3) -> void:
	var to := target - (body.global_position + Vector3(0, motor.eye_height, 0))
	input.yaw = atan2(-to.x, -to.z)
	input.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _clear_input() -> void:
	input.move = Vector2.ZERO
	input.sprint = false
	input.crouch = false
	input.grapple = false
	input.yaw = 0.0
	input.pitch = 0.0
	input.clear_edges()


func _teleport(pos: Vector3, yaw: float) -> void:
	body.global_position = pos
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	body.global_position = pos
	body.velocity = Vector3.ZERO
	input.yaw = yaw


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _did(state: MovementController.State) -> bool:
	return _mem.states.has(state)


## Yaw that faces along `dir` (flat).
func _yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
