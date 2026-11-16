extends SceneTree
## Runs a scripted player through every practice course in the Testing Grounds
## training yard, to prove each one can actually be completed with the current
## movement tuning (and that nothing in the layout blocks the way).
## Run: godot --headless --path . --script tests/course_test.gd

const EAST := -PI / 2.0   ## yaw that faces +x (down the lanes)

var body: CharacterBody3D
var motor: MovementController
var input: PlayerInput
var failures := 0

var _runs: Array = []
var _index := -1
var _time := 0.0
var _run: Dictionary
var _mem := {}   # scratch state for the current run


func _initialize() -> void:
	physics_frame.connect(_tick)
	var level := Node3D.new()
	root.add_child(level)
	TestingGrounds.new().build().instantiate(level)

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

	_runs = [
		_vault_run(), _ledge_run(1.6, true), _ledge_run(2.4, true), _ledge_run(3.2, true), _ledge_run(3.8, false),
		_slide_run(), _grapple_run(), _wall_run(), _chimney_run(),
	]
	print("Testing Grounds course checks")


func _tick() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _index == -1 or _time >= _run.max_time or _run.done.call():
		if _index >= 0:
			_run.check.call()
		_index += 1
		if _index >= _runs.size():
			print("FAIL: %d course checks failed" % failures if failures else "PASS: all courses can be completed")
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
# Courses

func _vault_run() -> Dictionary:
	return {
		"name": "vault row: sprint over the 0.5 to 1.25 m blocks",
		"start": Vector3(45, 0.05, 26), "max_time": 4.0,
		"drive": func(_dt):
			input.move = Vector2(0, 1)
			input.sprint = true,
		"done": func(): return false,
		"check": func():
			var x := body.global_position.x
			_expect(_mem.states.has(MovementController.State.MANTLE), "vaulted")
			_expect(x > 69.0, "got past all four (x = %.1f)" % x)
			_expect(_mem.max_speed > 10.0, "kept sprinting speed through the vaults (top %.1f m/s)" % _mem.max_speed),
	}


func _ledge_run(h: float, should_climb: bool) -> Dictionary:
	var index := TestingGrounds.LEDGE_HEIGHTS.find(h)
	var face := 74.0 + index * 6.0 - 1.0   # west face of that block
	return {
		"name": "ledge %.1f m: run, jump and climb" % h if should_climb else "ledge %.1f m: too high to climb" % h,
		"start": Vector3(face - 3.0, 0.05, 26), "max_time": 2.0,
		"drive": func(_dt):
			# Run at it; stop pushing once up (so we stay on this block).
			input.move = Vector2(0, 1) if body.global_position.y < h - 0.2 else Vector2.ZERO
			if face - body.global_position.x < 1.1 and body.is_on_floor() and not _mem.has("jumped"):
				input.jump_pressed = true
				_mem["jumped"] = true,
		"done": func(): return false,
		"check": func():
			var y := body.global_position.y
			if should_climb:
				_expect(abs(y - h) < 0.1 and body.is_on_floor(), "standing on top (feet at %.2f m)" % y)
			else:
				_expect(y < 0.1, "could not get up (feet at %.2f m)" % y),
	}


func _slide_run() -> Dictionary:
	return {
		"name": "slide: down the hill and under all three bars",
		"start": Vector3(50.5, TestingGrounds.SLIDE_HILL + 0.05, 10), "max_time": 5.0,
		"drive": func(_dt):
			input.move = Vector2(0, 1)
			input.sprint = true
			var on_slope := body.global_position.x > 53.0
			if on_slope and not input.crouch:
				input.crouch_pressed = true
			input.crouch = on_slope,
		"done": func(): return body.global_position.x > 96.0,
		"check": func():
			_expect(_mem.states.has(MovementController.State.SLIDE), "slid")
			_expect(body.global_position.x > 96.0, "made it under the bars to the kicker (x = %.1f)" % body.global_position.x)
			_expect(_mem.max_speed > 14.0, "the hill sped the slide up (top %.1f m/s)" % _mem.max_speed),
	}


func _grapple_run() -> Dictionary:
	var beams: Array = TestingGrounds.GRAPPLE_BEAMS
	var z := TestingGrounds.LANE_GRAPPLE
	return {
		"name": "grapple: swing beam to beam across the pit to the far platform",
		"start": Vector3(51, 6.05, z), "max_time": 10.0,
		"drive": func(_dt):
			var p := body.global_position
			var next: int = _mem.get("beam", 0)
			input.move = Vector2(0, 1)
			input.sprint = true
			if p.x > 54.2 and body.is_on_floor() and next == 0:
				input.jump_pressed = true   # off the edge of the start platform
			var g := motor.grapple
			if next < beams.size():
				var beam_x: float = beams[next]
				_look_at(Vector3(beam_x, TestingGrounds.GRAPPLE_BEAM_Y, z))
				input.move = Vector2(0, 1 if beam_x > p.x else -1)   # always push east (pumps the swing)
				if not g.attached and not body.is_on_floor() and g.ready_to_fire():
					input.grapple = true
					input.grapple_pressed = true
				elif g.attached:
					input.grapple = true
					# Let go past the beam, on the way up at about 45 degrees, or at the top.
					var v := body.velocity
					if p.x > beam_x + 1.0 and (v.y >= 0.8 * v.x or v.y < 0.0):
						input.grapple = false
						_mem["beam"] = next + 1
			else:
				input.grapple = false
				input.yaw = EAST
				input.pitch = 0.0
				input.move = Vector2(0, 1),
		"done": func():
			var p := body.global_position
			return p.x > 95.5 and p.y > 5.9 and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			_expect(p.x > 95.5 and p.y > 5.9 and body.is_on_floor(),
				"landed on the finish platform (at x %.1f, height %.1f, used %d beams)" % [p.x, p.y, _mem.get("beam", 0)])
			_expect(_mem.states.has(MovementController.State.GRAPPLE), "swung on the rope"),
	}


func _wall_run() -> Dictionary:
	var panels: Array = TestingGrounds.WALL_PANELS
	return {
		"name": "wall run: zigzag along the four panels to the far platform",
		"start": Vector3(51, 2.55, -11.45), "max_time": 8.0,
		"drive": func(_dt):
			var p := body.global_position
			var next: int = _mem.get("panel", 0)
			input.move = Vector2(0, 1)
			input.sprint = true
			input.pitch = 0.0
			if p.x > 54.0 and body.is_on_floor() and next == 0 and not _mem.has("left_start"):
				input.jump_pressed = true
				_mem["left_start"] = true
			if next < panels.size():
				var panel: Array = panels[next]
				var wall_z: float = panel[2]
				if motor.state == MovementController.State.WALL_RUN:
					_mem["ran"] = _mem.get("ran", 0) + 1
					input.yaw = EAST
					# Kick off toward the next panel near the end of this one.
					if p.x > panel[1] - 3.0:
						input.jump_pressed = true
						_mem["panel"] = next + 1
				elif not _mem.has("left_start"):
					input.yaw = EAST   # run straight along the first wall
				else:
					# Angle toward the wall we want to run on.
					var toward := signf(wall_z - p.z)
					input.yaw = EAST - toward * deg_to_rad(28.0)
			else:
				input.yaw = EAST
				input.move = Vector2(0, 1)
				# Head for the middle of the finish platform.
				var dz := TestingGrounds.LANE_WALL - p.z
				input.move.x = clamp(dz, -1.0, 1.0),
		"done": func():
			var p := body.global_position
			return p.x > 98.2 and p.y > 3.9 and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			_expect(p.x > 98.2 and p.y > 3.9 and body.is_on_floor(),
				"landed on the finish platform (at x %.1f, height %.1f, after %d panels)" % [p.x, p.y, _mem.get("panel", 0)])
			_expect(_mem.get("ran", 0) > 0, "wall ran"),
	}


func _chimney_run() -> Dictionary:
	var cz := 35.0
	return {
		"name": "chimney: wall-jump up between the walls and climb onto the platform",
		"start": Vector3(98, 0.05, cz - 1.5 + 0.45), "max_time": 8.0,
		"drive": func(_dt):
			var p := body.global_position
			input.move = Vector2.ZERO
			input.yaw = EAST
			input.pitch = 0.0
			if body.is_on_floor() and p.y < 0.5 and not _mem.has("started"):
				input.jump_pressed = true
				_mem["started"] = true
				_mem["last_jump"] = 0.0
			_mem["last_jump"] = _mem.get("last_jump", 0.0) + _dt
			# Near the top, push east to grab the platform's ledge.
			if p.y > TestingGrounds.CHIMNEY_TOP - 1.5 - 2.2:
				input.move = Vector2(0, 1)
			elif _mem.has("started") and _mem.last_jump > 0.12 and body.velocity.y < 3.0:
				input.jump_pressed = true   # wall jump off whichever wall we are touching
				_mem["last_jump"] = 0.0,
		"done": func(): return body.global_position.y > TestingGrounds.CHIMNEY_TOP - 1.6 and body.is_on_floor(),
		"check": func():
			var y := body.global_position.y
			_expect(y > TestingGrounds.CHIMNEY_TOP - 1.6 and body.is_on_floor(), "standing on the platform at the top (feet at %.1f m)" % y),
	}


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
