extends SceneTree
## Headless checks on the robot model and its animator.
## Run: godot --headless --path . --script tests/robot_test.gd
##
## Checks that the model files hold every bone and clip the game asks for, that each
## movement state plays the right animation, and that the poses make sense for the
## hitbox: standing height, crouch height, feet on the floor, gun following the aim.

const S := MovementController.State
const CROUCH_HEIGHT := 1.1   ## CROUCH_HEIGHT (the player script needs the full game to load)

const BODY_CLIPS := ["aim", "idle", "run", "sprint", "crouch_idle", "crouch_walk", "slide",
	"air", "air_tuck", "land", "wall_run_l", "wall_run_r", "wall_jump_l", "wall_jump_r",
	"vault", "climb", "grapple", "dive", "roll", "flip_front", "flip_back", "flip_left",
	"flip_right", "reload", "death", "respawn"]
const ARM_CLIPS := ["fp_idle", "fp_one_hand", "fp_sprint", "fp_slide", "fp_wall_l", "fp_wall_r",
	"fp_dive", "fp_tuck", "fp_mantle", "fp_raise", "fp_reload"]
const BODY_BONES := ["root", "hips", "spine", "chest", "head", "upper_arm_l", "forearm_l", "hand_l",
	"upper_arm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r",
	"foot_r", "pistol", "pistol_slide", "pistol_mag", "muzzle", "grapple"]
const ARM_BONES := ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"pistol", "pistol_slide", "pistol_mag", "muzzle", "grapple"]

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("ROBOT TEST PASSED" if failures == 0 else "ROBOT TEST FAILED: %d" % failures)
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles at exit otherwise
		robot.mesh.set_surface_override_material(i, null)
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	print("Robot model files")
	_check_file(RobotModel.BODY, BODY_BONES, BODY_CLIPS)
	_check_file(RobotModel.ARMS, ARM_BONES, ARM_CLIPS)

	print("Animation flags survive packing")
	var inp := RobotAnimInput.new()
	inp.flags = RobotAnimInput.make_flags(true, false, true, RobotAnimInput.FLIP_LEFT, 6)
	_expect("wall on the right", inp.wall_right())
	_expect("not vaulting", not inp.vaulting())
	_expect("reloading", inp.reloading())
	_expect("flip direction", inp.flip() == RobotAnimInput.FLIP_LEFT)
	_expect("wall-jump counter wraps", inp.wall_jumps() == 2)
	_expect("fits a snapshot float exactly", int(float(inp.flags)) == inp.flags and inp.flags < 128)

	print("Each movement state plays its animation")
	var right := RobotAnimInput.make_flags(true, false, false, 0, 0)
	var vault := RobotAnimInput.make_flags(false, true, false, 0, 0)
	var flip_r := RobotAnimInput.make_flags(false, false, false, RobotAnimInput.FLIP_RIGHT, 0)
	var cases := [
		[S.GROUND, false, 0, true, "loco"], [S.CROUCH, true, 0, true, "crouch"],
		[S.SLIDE, true, 0, true, "slide"], [S.AIR, false, 0, true, "air"],
		[S.AIR, true, 0, true, "tuck"], [S.GRAPPLE, false, 0, true, "grapple"],
		[S.WALL_RUN, false, 0, true, "wall_l"], [S.WALL_RUN, false, right, true, "wall_r"],
		[S.MANTLE, false, vault, true, "vault"], [S.MANTLE, false, 0, true, "climb"],
		[S.DIVE, true, 0, true, "dive"], [S.ROLL, true, 0, true, "roll"],
		[S.FLIP, false, 0, true, "flip_front"], [S.FLIP, false, flip_r, true, "flip_right"],
		[S.GROUND, false, 0, false, "death"],
	]
	for c in cases:
		_fresh()
		var i := _input(c[0], Vector3.ZERO, 0.0)
		i.crouched = c[1]
		i.flags = c[2]
		i.alive = c[3]
		_run(i, 0.2)
		_expect("%s%s shows \"%s\"" % [S.keys()[c[0]], "" if c[3] else " (dead)", c[4]], animator.source == c[4],
			"got \"%s\"" % animator.source)

	print("Poses fit the hitbox")
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 1.0)
	_near("standing: top of the head", _top(), 1.76, 0.08)
	_near("standing: lowest foot", _lowest_foot(), 0.10, 0.04)
	var level := robot.marker("muzzle")
	_expect("standing: gun held out in front", level.z < -0.35 and level.y > 1.2, str(level))
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, deg_to_rad(40.0)), 1.0)
	var up := robot.marker("muzzle")
	_expect("aiming up 40 degrees raises the gun", up.y > level.y + 0.2, "%.2f vs %.2f" % [up.y, level.y])
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, deg_to_rad(-40.0)), 1.0)
	var down := robot.marker("muzzle")
	_expect("aiming down 40 degrees lowers the gun", down.y < level.y - 0.2, "%.2f vs %.2f" % [down.y, level.y])

	_fresh()
	_run(_input(S.GROUND, Vector3(0, 0, -8), 0.0), 1.0)
	_near("running: top of the head", _top(), 1.72, 0.12)
	_expect("running: feet stay on or above the floor", _lowest_foot() > 0.02, "%.2f" % _lowest_foot())

	_fresh()
	var crouch := _input(S.CROUCH, Vector3.ZERO, 0.0)
	crouch.crouched = true
	_run(crouch, 1.0)
	_expect("crouched: head under the crouch height (%.1f m)" % CROUCH_HEIGHT,
		_top() < CROUCH_HEIGHT + 0.12, "%.2f" % _top())

	_fresh()
	var slide := _input(S.SLIDE, Vector3(0, 0, -12), 0.0)
	slide.crouched = true
	_run(slide, 1.0)
	_expect("sliding: head under the crouch height", _top() < CROUCH_HEIGHT + 0.12, "%.2f" % _top())

	_fresh()
	var before := robot.marker("muzzle")
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.5)
	before = robot.marker("muzzle")
	animator.fire()
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.03)
	var kicked := robot.marker("muzzle")
	_expect("firing kicks the gun", kicked.distance_to(before) > 0.01, "%.3f m" % kicked.distance_to(before))
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.6)
	_expect("and it settles back on target", robot.marker("muzzle").distance_to(before) < 0.01)

	_fresh()
	var dead := _input(S.GROUND, Vector3.ZERO, 0.0)
	_run(dead, 0.3)
	dead.alive = false
	_run(dead, 2.0)
	_expect("dead: the body is down on the floor", _top() < 0.75, "%.2f" % _top())
	_expect("dead: nothing sinks through the floor", _lowest_bone() > -0.12, "%.2f" % _lowest_bone())



func _check_file(path: String, bones: Array, clips: Array) -> void:
	var rig := RobotRig.open(path)
	var missing_bones := bones.filter(func(b): return not rig.bones.has(b))
	var missing_clips := clips.filter(func(c): return not rig.has_clip(c))
	_expect("%s: all %d bones" % [path.get_file(), bones.size()], missing_bones.is_empty(), str(missing_bones))
	_expect("%s: all %d clips" % [path.get_file(), clips.size()], missing_clips.is_empty(), str(missing_clips))
	var empty := clips.filter(func(c): return rig.has_clip(c) and rig.length(c) <= 0.0)
	_expect("%s: no empty clips" % path.get_file(), empty.is_empty(), str(empty))


## A robot back in its starting state (one model, a new animator each time).
func _fresh() -> void:
	if robot == null:
		robot = RobotModel.new().setup(RobotModel.BODY, Color(1, 0.3, 0.2))
		root.add_child(robot)
	animator = RobotAnimator.new(robot)


func _input(state: int, velocity: Vector3, pitch: float) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = state
	inp.velocity = velocity
	inp.pitch = pitch
	return inp


func _run(inp: RobotAnimInput, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		animator.update(1.0 / 60.0, inp, robot.global_transform)
		t += 1.0 / 60.0


func _bone_y(bone: String) -> float:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin.y


## The head bone sits at the neck; the top of the head is about 0.26 m above it.
func _top() -> float:
	var pose := robot.skeleton.get_bone_global_pose(robot.rig.bones["head"])
	return (pose * Vector3(0, 0.26, 0)).y


func _lowest_foot() -> float:
	return minf(_bone_y("foot_l"), _bone_y("foot_r"))


func _lowest_bone() -> float:
	var low := INF
	for b in BODY_BONES:
		if b not in ["root", "muzzle", "grapple"]:
			low = minf(low, _bone_y(b))
	return low


func _near(what: String, value: float, expected: float, tolerance: float) -> void:
	_expect("%s = %.2f (expected %.2f ± %.2f)" % [what, value, expected, tolerance], absf(value - expected) <= tolerance)


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
