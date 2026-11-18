extends SceneTree
## Tractor-beam lift checks (MapLiftWell), with the real movement code:
##  - a body that walks into the beam is lifted at about 9 m/s (a 30 m tier in a
##    little over 3 s), and one that falls in from above is caught and lifted too;
##  - it slows to a hover at the top instead of being thrown out;
##  - it can be left sideways at any height (steering out, or an air flip), and then
##    you fall as usual;
##  - a body beside the beam is left alone, and so is one in a ground slam;
##  - the beam itself is never solid.
## Run: godot --headless --fixed-fps 60 --path . --script tests/lift_test.gd

var STEP := 1.0 / Engine.physics_ticks_per_second   # (move_and_slide moves by the engine's own step)

var failures := 0
var body: CharacterBody3D
var motor: MovementController
var input: PlayerInput
var lift: MapLiftWell


func _initialize() -> void:
	print("Tractor-beam lift checks")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	lift = MapLiftWell.new()
	lift.height = 60.0
	lift.position = Vector3(10, 0, 0)
	root.add_child(lift)
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
	_expect(is_equal_approx(lift.speed, 9.0) and is_equal_approx(lift.radius, 1.6), "9 m/s (30 ft/s), 1.6 m to its edge")
	_expect(lift.get_child_count() == 0 or not (lift.get_child(0) is CollisionObject3D), "the beam is not solid")
	await _rides()
	await _falls_in()
	await _leaves()
	await _left_alone()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _fresh(at: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	motor = MovementController.new()
	input = PlayerInput.new()
	body.global_position = at
	body.velocity = vel


## One physics step the way the game does it: the beam first, then the body's own.
func _tick() -> bool:
	await physics_frame
	var held := lift.lift(body, motor, STEP)
	motor.step(body, input, STEP)
	input.clear_edges()
	return held


func _rides() -> void:
	print("  walking in")
	_fresh(Vector3(6, 0.05, 0))
	input.yaw = -PI / 2   # facing +x, toward the beam
	input.move = Vector2(0, 1)
	var entered := -1
	var at_30 := -1
	var speeds := []
	for i in 1500:
		var held: bool = await _tick()
		if held and entered < 0:
			entered = i
		if entered >= 0:
			# In the beam: steer for its middle and stay there (what a rider does).
			var want := Vector3(10.0 - body.global_position.x, 0, -body.global_position.z) * 2.0 - Vector3(body.velocity.x, 0, body.velocity.z) * 0.5
			input.move = Vector2(want.z, want.x).limit_length(1.0)   # (facing +x: forward is +x, right is +z)
		if entered >= 0 and body.global_position.y > 5.0 and body.global_position.y < 50.0:
			speeds.append(body.velocity.y)
		if at_30 < 0 and body.global_position.y >= 30.0:
			at_30 = i
		if body.global_position.y > 59.0 and absf(body.velocity.y) < 0.6:
			break
	_expect(entered >= 0, "walking into the beam, it takes hold")
	var lo: float = speeds.min() if not speeds.is_empty() else 0.0
	var hi: float = speeds.max() if not speeds.is_empty() else 0.0
	_expect(not speeds.is_empty() and lo > 8.6 and hi < 9.4, "it lifts at about 9 m/s (%.2f to %.2f m/s)" % [lo, hi])
	var took := (at_30 - entered) * STEP
	_expect(at_30 > 0 and took > 3.0 and took < 3.9, "a 30 m tier takes a little over 3 s (%.2f s)" % took)
	_expect(body.global_position.y > 58.5 and body.global_position.y < 61.5 and absf(body.velocity.y) < 0.8,
		"at the top it hovers, it is not thrown out (%.1f m, %.2f m/s)" % [body.global_position.y, body.velocity.y])
	_expect(motor.state == MovementController.State.AIR, "riding is plain air time: free to look, aim and shoot")


func _falls_in() -> void:
	print("  falling in")
	_fresh(Vector3(10, 40, 0), Vector3(0, -25, 0))
	var lowest := 40.0
	for i in 240:
		await _tick()
		lowest = minf(lowest, body.global_position.y)
	_expect(lowest > 30.0, "a fall into the beam is caught within a few metres (lowest %.1f m)" % lowest)
	_expect(absf(body.velocity.y - 9.0) < 0.4, "and then lifted like anyone else (%.2f m/s)" % body.velocity.y)


func _leaves() -> void:
	print("  leaving sideways")
	for from in [8.0, 27.0, 44.0]:
		_fresh(Vector3(10, from, 0), Vector3(0, 9, 0))
		for i in 20:
			await _tick()
		input.yaw = -PI / 2
		input.move = Vector2(0, 1)   # steer out toward +x
		var out_at := -1.0
		for i in 480:
			var held: bool = await _tick()
			if not held:
				out_at = body.global_position.y
				break
		_expect(out_at > 0.0 and out_at < 59.0, "steering out from %d m up: out of the beam at %.1f m" % [int(from), out_at])
		for i in 160:
			await _tick()
		_expect(body.velocity.y < 0.0 and body.global_position.x > 11.6, "and falling, clear of it (%.1f m/s)" % body.velocity.y)
	# An air flip (jump pressed in mid-air) throws you out at once.
	_fresh(Vector3(10, 20, 0), Vector3(0, 9, 0))
	for i in 10:
		await _tick()
	input.yaw = -PI / 2
	input.move = Vector2(0, 1)
	input.jump_pressed = true
	var frames := 0
	for i in 120:
		var held: bool = await _tick()
		frames += 1
		if not held:
			break
	_expect(frames * STEP < 0.6, "a flip (jump in mid-air) gets you out as well (%.2f s)" % (frames * STEP))


func _left_alone() -> void:
	print("  what it leaves alone")
	_fresh(Vector3(13, 0.05, 0))
	for i in 60:
		await _tick()
	_expect(body.is_on_floor() and absf(body.velocity.y) < 0.01, "someone standing beside the beam stays on the floor")
	_fresh(Vector3(10, 30, 0), Vector3(0, -5, 0))
	motor.state = MovementController.State.SLAM
	_expect(not lift.lift(body, motor, STEP), "a ground slam goes straight down through it")
	_expect(MapLiftWell.at(self, Vector3(10, 12, 0.5)) == lift and MapLiftWell.at(self, Vector3(14, 12, 0)) == null, "bots can ask which beam holds a point")


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
