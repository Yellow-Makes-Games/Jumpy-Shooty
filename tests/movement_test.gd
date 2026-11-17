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
const LOW_HOOK := Vector3(150, 11, 80)  ## underside of a low block, hookable from the floor


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
	_box(LOW_HOOK + Vector3(0, 1, 0), Vector3(4, 2, 4))

	# Obstacles for crouch, slide, wall-run, vault and ledge checks.
	_box(Vector3(-100, 1.9, -10), Vector3(4, 1, 10))      # low ceiling: 1.4 m gap underneath, z -15..-5
	_box(Vector3(-100, 1.45, 40), Vector3(4, 1, 10))      # lower still: 0.95 m gap (only lying down fits), z 35..45
	_box(Vector3(-150, 4, 0), Vector3(1, 8, 60))          # long wall, face at x = -149.5
	_box(Vector3(100, 0.5, -20), Vector3(2, 1.0, 1.2))    # 1 m crate (vault)
	_box(Vector3(100, 1.0, -60), Vector3(3, 2.0, 3))      # 2 m block (ledge climb)
	var ramp := _box(Vector3(-60, 7, -20), Vector3(10, 1, 40))  # 20 degree slope, downhill toward +z
	ramp.rotation.x = deg_to_rad(20.0)

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
		["with the pull off, the rope swings like a pendulum", 2.6,
			func():
				_data["pull_was"] = [t.grapple_pull_accel, t.grapple_yank]
				t.grapple_pull_accel = 0.0   # check the rope on its own
				t.grapple_yank = 0.0
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
				_expect_near("lowest point is a rope's length below the anchor", g.anchor.y - d["lowest"], g.length, 0.2)
				t.grapple_pull_accel = _data["pull_was"][0]
				t.grapple_yank = _data["pull_was"][1]
				_data.erase("pull_was")],
		["grapple yanks you toward the hook the moment it catches", 1.0 / Engine.physics_ticks_per_second,
			func(): _start_swing(),
			func():
				var g := motor.grapple
				_expect_true("hooked on", g.attached)
				var toward := body.velocity.dot((g.anchor - g.rope_origin(body)).normalized())
				_expect_true("moving toward the hook (%.1f m/s)" % toward, toward > t.grapple_yank * 0.8)],
		["the rope reels you in and builds speed", 0.6,
			func():
				_data["pull"] = {"fastest_in": 0.0, "d0": motor.grapple.rope_origin(body).distance_to(motor.grapple.anchor)},
			func():
				var d: Dictionary = _data["pull"]
				_data.erase("pull")
				var g := motor.grapple
				var now := g.rope_origin(body).distance_to(g.anchor)
				_expect_true("pulled in (%.1f m -> %.1f m)" % [d["d0"], now], now < d["d0"] - 5.0)
				_expect_true("built up speed toward the hook (%.1f m/s)" % d["fastest_in"], d["fastest_in"] > t.grapple_pull_speed * 0.8)
				_expect_below("the pull alone never goes past its top speed", d["fastest_in"], t.grapple_pull_speed + 1.0)
				input.grapple = false],
		["letting go mid-pull flings you on with that speed", 0.3,
			func():
				_start_swing()
				_data["let_go_after"] = 0.45,
			func():
				var v0: float = _data["fling_speed"]
				_data.erase("fling_speed")
				_expect_true("let go", not motor.grapple.attached)
				_expect_true("fast when let go (%.1f m/s)" % v0, v0 > 12.0)
				_expect_near("speed 0.3 s later (minus gravity's share)", Vector2(body.velocity.x, body.velocity.z).length(), _data.get("fling_flat", 0.0), 0.3)
				_data.erase("fling_flat")],
		["hooking from the floor pops you up and reels you in", 0.5,
			func():
				motor.reset()
				_teleport(LOW_HOOK + Vector3(14, -11.0 + 0.05, 0))
				_clear_input()
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)   # settle on the floor
				_data["y0"] = body.global_position.y
				_aim_at(LOW_HOOK)
				input.grapple = true
				input.grapple_pressed = true,
			func():
				_expect_true("off the floor", not body.is_on_floor())
				_expect_true("risen (%.1f m)" % (body.global_position.y - _data["y0"]), body.global_position.y - _data["y0"] > 1.5)
				_expect_true("moved toward the hook (x = %.1f)" % body.global_position.x, body.global_position.x < LOW_HOOK.x + 9.0)
				_data.erase("y0")
				input.grapple = false],
		["hooking a near point at speed turns you toward it, never faster", 0.5,
			func():
				motor.reset()
				_teleport(LOW_HOOK + Vector3(5, -2.5, 0))
				_clear_input()
				_aim_at(LOW_HOOK)
				body.velocity = Vector3(0, 0, -20)
				input.grapple = true
				input.grapple_pressed = true
				_data["fastest"] = 0.0,
			func():
				_expect_below("top speed on the rope", _data["fastest"], 20.5)
				_data.erase("fastest")
				input.grapple = false
				motor.grapple.reset()],
		["running past a hook keeps your sideways speed", 1.0 / Engine.physics_ticks_per_second,
			func():
				motor.reset()
				_teleport(LOW_HOOK + Vector3(10, -2.0, 0))
				_clear_input()
				_aim_at(LOW_HOOK)
				body.velocity = Vector3(0, 0, -11)
				input.grapple = true
				input.grapple_pressed = true,
			func():
				_expect_true("hooked on", motor.grapple.attached)
				_expect_near("sideways speed", body.velocity.z, -11.0, 0.5)
				input.grapple = false
				motor.grapple.reset()],
		["letting go keeps your momentum", 0.4,
			func():
				_start_swing()
				_data["release_at_bottom"] = true,
			func():
				_expect_true("let go", not motor.grapple.attached)
				var v0: float = _data.get("release_speed", 0.0)
				_expect_true("released fast (%.2f m/s)" % v0, v0 > 0.9 * t.grapple_pull_speed)
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
		["crouch is slow", 1.5,
			func():
				motor.grapple.reset()
				_teleport(Vector3(-100, 0.05, 0))
				_clear_input()
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.crouch = true,
			func():
				_expect_near("crouched speed", motor.horizontal_speed(body), t.crouch_speed, 0.3)
				_expect_true("state is Crouch", motor.state == MovementController.State.CROUCH)],
		["crouching fits under a 1.4 m gap", 1.5,
			func(): pass,
			func(): _expect_true("got under it (z = %.1f)" % body.global_position.z, body.global_position.z < -8.0)],
		["can't stand up under the low ceiling", 0.3,
			func(): input.crouch = false,
			func(): _expect_true("still crouched", motor.crouched)],
		["standing up you can't get under it", 1.5,
			func():
				motor.reset()
				_teleport(Vector3(-100, 0.05, 0))
				input.crouch = false,
			func(): _expect_true("blocked at the edge (z = %.1f)" % body.global_position.z, body.global_position.z > -5.0)],
		["slide from a sprint boosts and keeps speed", 1.0,
			func():
				motor.reset()
				_teleport(Vector3(-30, 0.05, 50))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.sprint_speed)
				input.move = Vector2(0, 1)
				input.sprint = true
				input.crouch = true
				input.crouch_pressed = true
				_data["states"] = {},
			func():
				var expected: float = t.sprint_speed + t.slide_boost - t.slide_decel * 1.0
				_expect_near("speed after 1 s of sliding", motor.horizontal_speed(body), expected, 0.4)
				_expect_true("state is Slide", motor.state == MovementController.State.SLIDE)],
		["slide ends when slow, back to crouching", 3.0,
			func(): pass,
			func(): _expect_true("state is Crouch", motor.state == MovementController.State.CROUCH)],
		["sliding downhill speeds you up", 1.0,
			func():
				motor.reset()
				_teleport(Vector3(-60, 13.2, -33.5))
				_clear_input()
				body.velocity = Vector3(0, 0, 8)
				input.yaw = PI
				input.move = Vector2(0, 1)
				input.crouch = true
				_data["slope_speed"] = 0.0,
			func():
				_expect_true("faster than you started (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > 11.5)
				_expect_true("still sliding", motor.state == MovementController.State.SLIDE)],
		["wall run along a wall", 1.0,
			func():
				motor.reset()
				_teleport(Vector3(-148.9, 2.0, 25))
				_clear_input()
				body.velocity = Vector3(0, 3, -11)
				input.yaw = 0.0
				input.move = Vector2(0, 1),
			func():
				_expect_true("state is Wall Run", motor.state == MovementController.State.WALL_RUN)
				_expect_true("barely dropped (height %.2f)" % body.global_position.y, body.global_position.y > 2.5)
				_expect_true("kept speed (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) >= 10.9)],
		["wall jump kicks you off the wall", 0.05,
			func(): input.jump_pressed = true,
			func():
				_expect_true("state is Air", motor.state == MovementController.State.AIR)
				_expect_true("pushed away from the wall (%.1f m/s)" % body.velocity.x, body.velocity.x > t.wall_jump_push * 0.8)
				_expect_true("going up (%.1f m/s)" % body.velocity.y, body.velocity.y > t.wall_jump_up - t.gravity * 0.05 - 0.2)],
		["wall run times out", t.wall_run_max_time + 0.3,
			func():
				motor.reset()
				_teleport(Vector3(-148.9, 6.0, 25))
				_clear_input()
				body.velocity = Vector3(0, 3, -11)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				_data["states"] = {},
			func():
				_expect_true("wall ran", _data["states"].has(MovementController.State.WALL_RUN))
				_expect_true("then dropped off", motor.state != MovementController.State.WALL_RUN)],
		["no wall run of the same wall twice without landing", 0.5,
			func(): pass,
			func(): _expect_true("did not start again", motor.state != MovementController.State.WALL_RUN)],
		["running into a 1 m crate vaults over it, keeping speed", 1.6,
			func():
				motor.reset()
				_teleport(Vector3(100, 0.05, -12))
				_clear_input()
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.sprint = true
				_data["states"] = {},
			func():
				_expect_true("vaulted", _data["states"].has(MovementController.State.MANTLE))
				_expect_true("ended up past the crate (z = %.1f)" % body.global_position.z, body.global_position.z < -21.5)
				_expect_true("still fast (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > t.run_speed)],
		["running into a 2 m block stops you", 1.0,
			func():
				motor.reset()
				_teleport(Vector3(100, 0.05, -55))
				input.sprint = false,
			func():
				_expect_true("stopped at the block (z = %.1f)" % body.global_position.z, body.global_position.z > -58.7)
				_expect_true("still on the ground", body.global_position.y < 0.1)],
		["jumping at it grabs the ledge and climbs up", 1.2,
			func():
				input.jump_pressed = true
				_data["climb"] = true,
			func():
				_data.erase("climb")
				_expect_near("standing on top", body.global_position.y, 2.0, 0.08)
				_expect_true("on the floor", body.is_on_floor())],
		["dive from a run lunges forward", 0.15,
			func():
				motor.reset()
				_teleport(Vector3(-30, 0.05, 120))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.run_speed)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.dive_pressed = true
				_data["states"] = {},
			func():
				_expect_true("state is Dive", motor.state == MovementController.State.DIVE)
				_expect_true("faster (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > t.run_speed + t.dive_boost - 0.6)
				_expect_true("low hitbox while diving", motor.crouched)
				_expect_true("off the ground", not body.is_on_floor())],
		["landing from a dive rolls, keeping speed", 0.7,
			func(): pass,
			func():
				_expect_true("rolled", _data["states"].has(MovementController.State.ROLL))
				_expect_true("still fast after the roll (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > t.run_speed + t.dive_boost - 1.5)],
		["holding dive through the landing slides on your belly", 0.9,
			func():
				motor.reset()
				_teleport(Vector3(-30, 0.05, 200))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.run_speed)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.dive = true
				input.dive_pressed = true
				_data["states"] = {},
			func():
				_expect_true("belly-sliding", motor.state == MovementController.State.BELLY_SLIDE)
				_expect_true("no roll", not _data["states"].has(MovementController.State.ROLL))
				_expect_true("lying down: lower than a crouch", motor.prone and motor.eye_height < t.crouch_eye_height - 0.2)
				_expect_true("still faster than running (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > t.run_speed + 1.0)],
		["letting go of dive gets you up, keeping speed", 0.4,
			func(): input.dive = false,
			func():
				_expect_true("standing", motor.state == MovementController.State.GROUND and not motor.crouched and not motor.prone)
				_expect_true("kept moving (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) > t.run_speed - 0.5)],
		["letting go while holding crouch goes straight into a slide", 0.9,
			func():
				motor.reset()
				_teleport(Vector3(30, 0.05, 170))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.run_speed)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.dive = true
				input.dive_pressed = true
				_data["belly_then_crouch"] = true,
			func():
				_data.erase("belly_then_crouch")
				_expect_true("sliding (%s)" % MovementController.State.keys()[motor.state], motor.state == MovementController.State.SLIDE)],
		["a belly slide runs out into a crawl, and you stay down while dive is held", 4.0,
			func():
				motor.reset()
				_teleport(Vector3(30, 0.05, 130))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.run_speed)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.dive = true
				input.dive_pressed = true,
			func():
				_expect_true("still on the belly", motor.state == MovementController.State.BELLY_SLIDE and motor.prone)
				_expect_near("crawling", motor.horizontal_speed(body), t.belly_crawl_speed, 0.15)],
		["belly-slide under a 0.95 m gap; let go inside and you stay down until you crawl out", 6.0,
			func():
				motor.reset()
				_teleport(Vector3(-100, 0.05, 52))
				_clear_input()
				body.velocity = Vector3(0, 0, -t.run_speed)
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.dive = true
				input.dive_pressed = true
				_data["tunnel"] = true,
			func():
				_data.erase("tunnel")
				_expect_true("let go under the gap", _data.has("released"))
				_expect_true("never got up under it", not _data.has("stood_inside"))
				_expect_true("crawled out the far side (z = %.1f)" % body.global_position.z, body.global_position.z < 34.5)
				_expect_true("and stood up", not motor.prone and not motor.crouched)],
		["only one dive per jump, and a cooldown", 0.8,
			func():
				motor.reset()
				_teleport(Vector3(-30, 40, 120))
				_clear_input()
				body.velocity = Vector3(0, 0, -8)
				input.dive_pressed = true
				_data["dive_again"] = 0,
			func():
				_data.erase("dive_again")
				_expect_true("second dive did nothing (%.1f m/s)" % motor.horizontal_speed(body), motor.horizontal_speed(body) < 8.0 + t.dive_boost + 0.5)],
		["jump in mid-air flips toward your direction", 0.05,
			func():
				motor.reset()
				_teleport(Vector3(-30, 40, 140))
				_clear_input()
				body.velocity = Vector3(0, -2, -8)
				input.yaw = 0.0
				input.move = Vector2(1, 0)
				input.jump_pressed = true,
			func():
				_expect_true("state is Flip", motor.state == MovementController.State.FLIP)
				_expect_true("pushed right (%.1f m/s)" % body.velocity.x, body.velocity.x > t.flip_burst * 0.9)
				_expect_true("pushed up (%.1f m/s)" % body.velocity.y, body.velocity.y > t.flip_up - 1.5)],
		["only one flip per jump", 0.2,
			func():
				_data["vy"] = body.velocity.y
				input.move = Vector2.ZERO
				input.jump_pressed = true,
			func(): _expect_true("second flip did nothing (still falling: %.1f m/s)" % body.velocity.y, body.velocity.y < _data["vy"] - 3.0)],
		["a jump pressed just above the floor is kept for landing, not a flip", 1.6,
			func():
				motor.reset()
				_teleport(Vector3(-30, 3.0, 160))
				_clear_input()
				_data["flip_watch"] = true
				_data["states"] = {},
			func():
				_data.erase("flip_watch")
				_expect_true("no flip", not _data["states"].has(MovementController.State.FLIP))
				_expect_true("jumped on landing", _data.get("rebounded", false))],
		["Shift in mid-air floats: level, the way you face, at the speed you had", 1.0,
			func():
				motor.reset()
				_teleport(Vector3(-30, 40, 180))
				_clear_input()
				body.velocity = Vector3(6, -9, -15)   # falling fast, drifting right
				input.yaw = 0.0
				input.pitch = deg_to_rad(-30.0)   # looking down changes nothing: a float is level
				input.float_pressed = true
				_data["float_from"] = body.global_position,
			func():
				var from: Vector3 = _data["float_from"]
				_data.erase("float_from")
				var p := body.global_position
				_expect_true("state is Float", motor.state == MovementController.State.FLOAT)
				_expect_near("height kept", p.y, from.y, 0.02)
				_expect_near("speed kept", motor.horizontal_speed(body), Vector2(6, 15).length(), 0.05)
				_expect_near("going the way you face (sideways speed)", body.velocity.x, 0.0, 0.05)
				_expect_near("distance covered in 1 s", from.z - p.z, Vector2(6, 15).length(), 0.3)
				_expect_near("HUD: part of the float left", motor.float_readiness(), 1.0 - 1.0 / t.float_time, 0.02)],
		["steering does nothing while floating", 0.5,
			func(): input.move = Vector2(1, -1),
			func():
				_expect_near("still straight (sideways speed)", body.velocity.x, 0.0, 0.05)
				_expect_near("speed kept", motor.horizontal_speed(body), Vector2(6, 15).length(), 0.05)
				input.move = Vector2.ZERO],
		["the float runs out and you fall on, keeping your speed", 0.2,
			func(): _steps[_scenario][1] = t.float_time - 1.5 + 0.2,
			func():
				_expect_true("falling again (%s, %.1f m/s)" % [MovementController.State.keys()[motor.state], body.velocity.y],
					motor.state == MovementController.State.AIR and body.velocity.y < -2.0)
				_expect_near("speed kept", motor.horizontal_speed(body), Vector2(6, 15).length(), 0.05)
				_expect_near("HUD: float spent", motor.float_readiness(), 0.0, 0.001)],
		["only one float per jump", 0.2,
			func():
				_data["vy"] = body.velocity.y
				input.float_pressed = true,
			func(): _expect_true("second float did nothing (still falling: %.1f m/s)" % body.velocity.y,
					motor.state == MovementController.State.AIR and body.velocity.y < _data["vy"] - 3.0)],
		["floating from a standstill drifts you forward; Shift again drops you out", 0.4,
			func():
				motor.reset()
				_teleport(Vector3(-30, 40, 180))
				_clear_input()
				body.velocity = Vector3(0, 6, 0)   # going straight up
				input.yaw = PI * 0.5               # facing -x
				input.float_pressed = true
				_data["float_again"] = 36,
			func():
				_data.erase("float_again")
				_expect_true("stopped rising, drifting the way you face (%s)" % _data["float_vel"],
					absf(_data["float_vel"].y) < 0.01 and absf(_data["float_vel"].x + t.float_min_speed) < 0.05)
				_expect_true("dropped out (%s, %.1f m/s)" % [MovementController.State.keys()[motor.state], body.velocity.y],
					motor.state == MovementController.State.AIR and body.velocity.y < -1.0)
				_data.erase("float_vel")],
		["a flip takes over from a float", 0.05,
			func():
				_start_float(Vector3(0, -6, -12))
				input.move = Vector2(0, 1)
				input.jump_pressed = true,
			func():
				_expect_true("state is Flip", motor.state == MovementController.State.FLIP)
				_expect_true("going up (%.1f m/s)" % body.velocity.y, body.velocity.y > t.flip_up - 1.5)
				_expect_true("faster forward (%.1f m/s)" % -body.velocity.z, -body.velocity.z > 12.0 + t.flip_burst * 0.9)],
		["a dive takes over from a float", 0.05,
			func():
				_start_float(Vector3(0, -6, -12))
				input.dive_pressed = true,
			func():
				_expect_true("state is Dive", motor.state == MovementController.State.DIVE)
				_expect_true("faster forward (%.1f m/s)" % -body.velocity.z, -body.velocity.z > 12.0 + t.dive_boost * 0.9)],
		["rocket boots take over from a float", 0.05,
			func():
				_start_float(Vector3(0, -6, -12))
				input.jump_held = true   # tips the burst upward
				input.boost_pressed = true,
			func():
				input.jump_held = false
				_expect_true("no longer floating", motor.state == MovementController.State.AIR)
				_expect_true("boosted forward and up (%s)" % body.velocity, -body.velocity.z > 20.0 and body.velocity.y > 3.0)],
		["the grapple takes over from a float, and gives it back", 0.3,
			func():
				_start_swing()
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
				input.grapple = false   # let go: in the air, off the rope
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
				input.float_pressed = true
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
				input.clear_edges()
				_data["was_floating"] = motor.state == MovementController.State.FLOAT
				motor.grapple.cooldown_left = 0.0
				_aim_at(ANCHOR)
				input.grapple = true
				input.grapple_pressed = true,
			func():
				_expect_true("floated off the rope", _data["was_floating"])
				_data.erase("was_floating")
				_expect_true("hooked on, swinging (%s)" % MovementController.State.keys()[motor.state],
					motor.grapple.attached and motor.state == MovementController.State.GRAPPLE)
				_expect_near("HUD: float ready again", motor.float_readiness(), 1.0, 0.001)
				input.grapple = false],
		["a small nudge keeps you floating level; a real shove knocks you out of it", 0.1,
			func():
				_start_float(Vector3(0, -6, -12))
				motor.knock(Vector3(0, 0.3, -2.0))
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
				_data["nudged"] = [motor.state, body.velocity]
				motor.knock(Vector3(0, 2.0, -9.0)),
			func():
				var n: Array = _data["nudged"]
				_data.erase("nudged")
				_expect_true("nudged: still floating level, a little faster (%s)" % n[1],
					n[0] == MovementController.State.FLOAT and absf(n[1].y) < 0.01 and absf(n[1].z + 14.0) < 0.05)
				_expect_true("shoved: falling (%s)" % MovementController.State.keys()[motor.state], motor.state == MovementController.State.AIR)],
		["no float on the floor: Shift there is still sprint", 1.5,
			func():
				motor.reset()
				_teleport(Vector3(0, 0.05, 0))
				_clear_input()
				motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)   # settle on the floor
				input.yaw = 0.0
				input.move = Vector2(0, 1)
				input.sprint = true
				input.float_pressed = true
				_data["states"] = {},
			func():
				_expect_true("never floated", not _data["states"].has(MovementController.State.FLOAT))
				_expect_near("sprint speed", motor.horizontal_speed(body), t.sprint_speed, 0.3)
				input.sprint = false
				input.move = Vector2.ZERO],
		["no float just above the floor either (Shift as you land is a sprint)", 0.5,
			func():
				motor.reset()
				_teleport(Vector3(0, 0.35, 0))
				_clear_input()
				body.velocity = Vector3(0, -1, -8)
				input.float_pressed = true
				_data["states"] = {},
			func():
				_expect_true("never floated", not _data["states"].has(MovementController.State.FLOAT))
				_expect_true("landed", body.is_on_floor())
				_data.erase("states")],
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
	if _data.has("pull") and motor.grapple.attached:
		var g := motor.grapple
		var into := body.velocity.dot((g.anchor - g.rope_origin(body)).normalized())
		_data["pull"]["fastest_in"] = max(_data["pull"]["fastest_in"], into)
	if _data.has("fastest"):
		_data["fastest"] = max(_data["fastest"], body.velocity.length())
	if _data.has("let_go_after"):
		_data["let_go_after"] -= dt
		_steps[_scenario][1] = 99.0
		if _data["let_go_after"] <= 0.0:
			_data.erase("let_go_after")
			input.grapple = false
			_data["fling_speed"] = body.velocity.length()
			_data["fling_flat"] = Vector2(body.velocity.x, body.velocity.z).length()
			_frame = 0
			_steps[_scenario][1] = 0.3
	if _data.has("jump_off_after"):
		_data["jump_off_after"] -= dt
		_steps[_scenario][1] = 99.0
		if _data["jump_off_after"] <= 0.0:
			input.jump_pressed = true
			_steps[_scenario][1] = 0.0  # check straight after this step
	if _data.has("belly_then_crouch") and motor.state == MovementController.State.BELLY_SLIDE:
		input.dive = false
		input.crouch = true
		input.crouch_pressed = true
	if _data.has("tunnel"):
		var z := body.global_position.z
		if z < 43.0 and input.dive:
			input.dive = false
			_data["released"] = true
		if z > 35.4 and z < 44.6 and _data.has("released") and not motor.prone:
			_data["stood_inside"] = true
	if _data.has("dive_again"):
		_data["dive_again"] += 1
		if _data["dive_again"] == 30:
			input.dive_pressed = true   # try again in the same jump
	if _data.has("float_again"):
		_data["float_again"] -= 1
		if _data["float_again"] == 0:
			_data["float_vel"] = body.velocity
			input.float_pressed = true   # Shift again
	if _data.has("flip_watch") and not body.is_on_floor() and body.velocity.y < 0.0 and body.global_position.y < 0.6 and not _data.has("pressed"):
		input.jump_pressed = true   # just above the floor
		_data["pressed"] = true
	if _data.has("flip_watch") and _data.has("pressed") and body.velocity.y > 5.0:
		_data["rebounded"] = true
	motor.step(body, input, dt)
	input.clear_edges()
	if _data.has("states"):
		_data["states"][motor.state] = true
	if _data.has("climb") and motor.state == MovementController.State.MANTLE:
		input.move = Vector2.ZERO  # stop once up, so we stay on top
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


## High in the air with this velocity, facing -z, and Shift pressed: one step later, floating.
func _start_float(vel: Vector3) -> void:
	motor.reset()
	_teleport(Vector3(-30, 40, 180))
	_clear_input()
	body.velocity = vel
	input.yaw = 0.0
	input.pitch = 0.0
	input.float_pressed = true
	motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
	input.clear_edges()
	if motor.state != MovementController.State.FLOAT:
		_report(false, "set-up: floating (%s)" % MovementController.State.keys()[motor.state])


func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	root.add_child(b)
	return b


func _clear_input() -> void:
	input.move = Vector2.ZERO
	input.sprint = false
	input.crouch = false
	input.grapple = false
	input.dive = false
	input.clear_edges()


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
