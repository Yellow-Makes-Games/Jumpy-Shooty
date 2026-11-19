extends SceneTree
## How the body hangs on the grappling hook's rope (RopeSwing, laid over the body by
## RobotAnimator).
## Run: godot --headless --fixed-fps 60 --path . --script tests/rope_swing_test.gd
##
## Nothing changes while the hook flies and the slack comes in; once the rope is tight the body leans
## along it with the legs trailing and the gun down at its side, takes a jolt (bigger
## for more slack), the legs follow a change of direction after the hips do, a shot
## brings the gun up at once and it drops again after, the hips face along the swing
## while the chest stays on the aim, steering works the legs, letting go on the way up
## rolls the body once (a shot hurries it), your own body in first person leans less, a
## cape streams, a blade hangs point down, and the killcam's bodies are told about the rope.

const S := MovementController.State
const STEP := 1.0 / 60.0

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _weapon := "pistol"
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("ROPE SWING TEST PASSED" if failures == 0 else "ROPE SWING TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	var ahead := Vector3(0, 9.2, -8.0)   # a hook ahead and above: the rope 45 degrees up

	print("Before the rope is tight")
	_fresh()
	var flying := _input(S.AIR, Vector3(0, 0, -8), 0.3)
	flying.grapple_on = true
	flying.grapple_anchor = ahead
	flying.hook_slack = 2.0
	_run(flying, 0.4)
	_expect("the hook flying, slack in the rope: the body is falling as it would be", animator.rope.w == 0.0 and animator.source == "air")

	print("Tight: the body hangs along the rope")
	_fresh()
	_run(flying, 0.2)
	var on := _on_rope(ahead)
	_run(on, 1.0)
	_expect("it hangs on the rope", animator.rope.w == 1.0 and animator.source == "grapple")
	var hips := _at("hips")
	var chest := _at("chest")
	var feet := (_at("foot_l") + _at("foot_r")) * 0.5
	_expect("the hips are behind the chest (the body leans toward the hook)", hips.z > chest.z + 0.04, "%.2f against %.2f" % [hips.z, chest.z])
	_expect("the legs trail further still", feet.z > hips.z + 0.3, "%.2f against %.2f" % [feet.z, hips.z])
	_expect("the shoulders stay where the rope holds them", absf(chest.z) < 0.2 and absf(chest.y - 1.22) < 0.15, str(chest))
	var knee_r := _bend("thigh_r", "shin_r", "foot_r")
	var knee_l := _bend("thigh_l", "shin_l", "foot_l")
	_expect("one knee is up and the other leg long (%.0f and %.0f degrees)" % [rad_to_deg(knee_r), rad_to_deg(knee_l)], knee_r > knee_l + 0.3 and knee_l > 0.1)
	var gun := robot.marker("muzzle")
	_expect("the gun hangs at its side", gun.y < 1.0, str(gun))
	var left := robot.marker("grapple")
	_expect("the left arm is up the rope", (left - chest).normalized().dot(ahead - Vector3(0, 1.2, 0)) / (ahead - Vector3(0, 1.2, 0)).length() > 0.8)

	print("A shot")
	animator.fire()
	_run(on, STEP)
	gun = robot.marker("muzzle")
	_expect("the gun is up on the next frame", gun.y > 1.2 and gun.z < -0.3, str(gun))
	_run(on, RobotAnimator.ROPE_AIM_HOLD * 0.8)
	_expect("...and still up most of %.1f s later" % RobotAnimator.ROPE_AIM_HOLD, robot.marker("muzzle").y > 1.2)
	_run(on, 0.8)
	_expect("...then down again", robot.marker("muzzle").y < 1.0, str(robot.marker("muzzle")))

	print("The jolt")
	var small := _jolt(ahead, 0.8)
	var big := _jolt(ahead, 4.0)
	_expect("a rope with more slack jolts harder (%.2f against %.2f)" % [big[0], small[0]], big[0] > small[0] + 0.3 and small[0] > 0.0)
	_expect("...throws the legs further back (%.0f degrees against %.0f)" % [rad_to_deg(big[1]), rad_to_deg(small[1])], big[1] > small[1] + 0.1)
	_expect("...and jerks the chest further toward the hook (%.0f cm against %.0f cm)" % [big[2] * 100.0, small[2] * 100.0], big[2] > small[2] + 0.02 and big[2] <= RopeSwing.LUNGE_MAX + 0.001)
	_expect("the legs whip through past where they settle, then settle", big[1] > big[3] + 0.15 and absf(big[4] - big[3]) < 0.02,
		"furthest %.2f, settled %.2f, a moment before %.2f" % [big[1], big[3], big[4]])

	print("A change of direction: the hips first, the legs after")
	_fresh()
	on = _on_rope(ahead)
	_run(on, 1.2)
	var behind := _on_rope(Vector3(0, 9.2, 8.0))
	behind.hook_taut = 1.2
	var hips_from := _lean("hips", "chest")
	var legs_from := _lean("foot_l", "hips")
	_run(behind, 2.0)
	var hips_to := _lean("hips", "chest")
	var legs_to := _lean("foot_l", "hips")
	_fresh()
	_run(on, 1.2)
	var hips_half := -1.0
	var legs_half := -1.0
	var t := 0.0
	while t < 1.0 and (hips_half < 0.0 or legs_half < 0.0):
		_run(behind, STEP)
		t += STEP
		if hips_half < 0.0 and absf(_lean("hips", "chest") - hips_from) > absf(hips_to - hips_from) * 0.5:
			hips_half = t
		if legs_half < 0.0 and absf(_lean("foot_l", "hips") - legs_from) > absf(legs_to - legs_from) * 0.5:
			legs_half = t
	_expect("the hips are half way round after %.2f s, the legs after %.2f s" % [hips_half, legs_half], hips_half > 0.0 and legs_half > hips_half)
	_run(behind, 0.35 - t if t < 0.35 else 0.0)
	_expect("the legs have all but settled 0.35 s after", absf(_lean("foot_l", "hips") - legs_to) < absf(legs_to - legs_from) * 0.2)

	print("Facing: the hips along the swing, the chest on the aim")
	_fresh()
	var side := _on_rope(ahead)
	side.yaw = deg_to_rad(-70.0)   # aiming off to the right of the rope
	robot.rotation.y = side.yaw
	_run(side, 1.0)
	var hips_face := (robot.skeleton.get_bone_global_pose(robot.rig.bones["hips"]).basis * Vector3.FORWARD)
	var chest_face := (robot.skeleton.get_bone_global_pose(robot.rig.bones["chest"]).basis * Vector3.FORWARD)
	_expect("the chest faces the aim", Vector2(chest_face.x, chest_face.z).normalized().dot(Vector2(0, -1)) > 0.9, str(chest_face))
	_expect("the hips are turned toward the rope (%.0f degrees)" % rad_to_deg(atan2(-hips_face.x, -hips_face.z)), atan2(-hips_face.x, -hips_face.z) > deg_to_rad(40.0))
	robot.rotation.y = 0.0

	print("Steering works the legs")
	var kicks := []
	for pumping in [false, true]:
		for way in [-1.0, 1.0]:
			_fresh()
			var swing := _on_rope(Vector3(0, 6.0, -0.5))
			swing.velocity = Vector3(0, 0, -6.0 * way)
			swing.flags = RobotAnimInput.make_flags(false, false, false, 0, 0, 0, 0, false, 0, false, false, 0, pumping)
			_run(swing, 1.0)
			kicks.append([(_at("foot_l").z + _at("foot_r").z) * 0.5 - _at("hips").z, _bend("thigh_l", "shin_l", "foot_l")])
	_expect("going forward the feet are out in front, legs long; going back they are tucked under",
		kicks[3][0] < kicks[2][0] - 0.25 and kicks[2][1] > kicks[3][1] + 0.5, str(kicks))
	_expect("without steering the legs do much less of it", absf(kicks[1][0] - kicks[0][0]) < absf(kicks[3][0] - kicks[2][0]) * 0.5)
	var all := RobotAnimInput.make_flags(true, true, true, 3, 3, 3, 3, true, 3, true, true, 7, true)
	var packed := PackedFloat32Array([float(all)])
	var back := RobotAnimInput.new()
	back.flags = int(packed[0])
	_expect("the steering flag fits a snapshot float with every other flag set", int(packed[0]) == all and back.pumping() and back.reloading()
		and RobotAnimInput.step_of(back.flags) == 7 and not _input(S.AIR, Vector3.ZERO, 0.0).pumping())

	print("Letting go")
	_expect("on the way up, fast: one roll forward, over in %.1f s" % RopeSwing.FLIP_TIME, _roll(Vector3(0, 9.0, -11.0), false, 0) == [true, true])
	_expect("...also when the news of the fall comes two frames before the news of the rope", _roll(Vector3(0, 9.0, -11.0), false, 2) == [true, true])
	_expect("...and two frames after", _roll(Vector3(0, 9.0, -11.0), false, -2) == [true, true])
	_expect("slowly, or on the way down: no roll", _roll(Vector3(0, 5.0, -6.0), false, 0)[0] == false and _roll(Vector3(0, -3.0, -14.0), false, 0)[0] == false)
	var hurried := _roll(Vector3(0, 9.0, -11.0), true, 0)
	_expect("a shot cuts it short: over within 0.2 s, the gun up", hurried == [true, true, true], str(hurried))

	print("Your own body in first person")
	_fresh()
	on = _on_rope(ahead)
	_run(on, 1.0)
	var seen := robot.skeleton.get_bone_pose_rotation(robot.rig.bones["root"]).get_angle()
	_fresh()
	animator.first_person = true
	_run(on, 1.0)
	var own := robot.skeleton.get_bone_pose_rotation(robot.rig.bones["root"]).get_angle()
	_expect("it leans less than everyone else sees (%.0f degrees against %.0f)" % [rad_to_deg(own), rad_to_deg(seen)], own < seen * 0.8 and own > seen * 0.3)
	animator.first_person = false

	print("What else hangs")
	_drop()
	_weapon = "sword"
	_fresh()
	on = _on_rope(ahead)
	_run(on, 1.2)
	var blade := _blade()
	_expect("a sword hangs from the hand, point down", blade.y < -0.6, str(blade))
	for i in 20:
		animator.wind(0.5)
		_run(on, STEP)
	blade = _blade()
	_expect("...and comes up to be swung", blade.y > -0.2, str(blade))
	_drop()
	_weapon = "pistol"
	var caped := CustomCharacter.new()
	caped.accessories = {"back": "cape"}
	robot = RobotModel.new().build(caped.to_id(), Color.RED)
	root.add_child(robot)
	animator = RobotAnimator.new(robot)
	var still := _input(S.AIR, Vector3.ZERO, 0.0)
	_run(still, 0.3)
	var cape := robot.skeleton.find_bone("cape")
	var hung := robot.skeleton.get_bone_global_pose(cape).basis.get_rotation_quaternion()
	fast_rope(ahead)
	var streamed := robot.skeleton.get_bone_global_pose(cape).basis.get_rotation_quaternion()
	_expect("a cape streams out behind (%.0f degrees from how it hangs)" % rad_to_deg(hung.angle_to(streamed)), hung.angle_to(streamed) > RobotModel.CAPE_LEAN)

	print("The killcam")
	var told := RobotAnimInput.new()
	told.set_hook_replayed([ahead, 0.0, 1.5, 0.4])
	_expect("a body in a killcam is told its rope is tight", is_equal_approx(told.hook_taut, 0.4) and told.hook_slack == 0.0)
	told.set_hook_replayed([ahead, 2.5, 0.2, -1.0])
	_expect("...or has slack in it", told.hook_taut < 0.0 and is_equal_approx(told.hook_slack, 2.5))
	told.set_hook_replayed(null)
	_expect("...or is not there", told.hook_taut < 0.0 and told.hook_slack == 0.0)
	var look := RobotAnimInput.new()
	look.set_hook([HookLine.TAUT, ahead, 0.0, 1.0, 0.25])
	_expect("a body in the match is told the same from the rope as drawn", is_equal_approx(look.hook_taut, 0.25))
	look.set_hook([])
	_expect("...and that there is none", look.hook_taut < 0.0 and look.hook_slack == 0.0)


## On the rope with speed (a cape streams behind it).
func fast_rope(anchor: Vector3) -> void:
	var on := _on_rope(anchor)
	on.velocity = Vector3(0, 6.0, -14.0)
	_run(on, 1.0)


## Hangs a fresh body on a rope that had `slack` metres of slack. Returns [the jolt's
## strength, how far back the long leg was thrown at most (radians from hanging straight
## down), how far the chest was jerked at most, where the leg settles, where it was a
## moment before that].
func _jolt(anchor: Vector3, slack: float) -> Array:
	_fresh()
	var flying := _input(S.AIR, Vector3(0, 0, -8), 0.3)
	flying.grapple_on = true
	flying.grapple_anchor = anchor
	flying.hook_slack = slack
	_run(flying, 0.2)
	var on := _on_rope(anchor)
	var thrown := -INF
	var jerked := 0.0
	var t := 0.0
	var before := 0.0
	while t < 1.5:
		_run(on, STEP)
		t += STEP
		thrown = maxf(thrown, _lean("shin_l", "thigh_l"))
		jerked = maxf(jerked, animator.rope.lunge(0.0).length())
		if t < 1.4:
			before = _lean("shin_l", "thigh_l")
	return [animator.rope.jolted, thrown, jerked, _lean("shin_l", "thigh_l"), before]


## Hangs a fresh body on a rope and lets go with `velocity`. shoot: a shot a moment into
## any roll. late: the news of the fall comes this many frames after the news that the
## rope was let go (negative: before it). Returns [rolled, over in time (, the gun up)].
func _roll(velocity: Vector3, shoot: bool, late: int) -> Array:
	_fresh()
	var on := _on_rope(Vector3(0, 9.2, -8.0))
	on.velocity = velocity
	_run(on, 0.8)
	var falling := _input(S.AIR, velocity, 0.0)
	falling.grapple_on = true   # (the hook is on its way back)
	falling.grapple_anchor = on.grapple_anchor
	for i in absi(late):
		var between := _input(S.AIR if late < 0 else S.GRAPPLE, velocity, 0.0)
		between.grapple_on = true
		between.grapple_anchor = on.grapple_anchor
		between.hook_taut = 1.0 if late < 0 else -1.0
		_run(between, STEP)
	_run(falling, STEP)
	var rolled := animator.rope.flip() >= 0.0
	if not rolled:
		return [false, false]
	if shoot:
		_run(falling, 0.1)
		animator.fire()
		_run(falling, 0.2)
		var gun := robot.marker("muzzle")
		return [true, animator.rope.flip() < 0.0, gun.y > 1.2 and gun.z < -0.3]
	_run(falling, RopeSwing.FLIP_TIME * 0.5)
	var upside_down: bool = (robot.skeleton.get_bone_global_pose(robot.rig.bones["hips"]).basis * Vector3.UP).y < 0.0
	_run(falling, RopeSwing.FLIP_TIME * 0.5 + 0.05)
	return [upside_down, animator.rope.flip() < 0.0]


## A body in the GRAPPLE state on the grappling hook's rope, pulled tight a moment ago.
func _on_rope(anchor: Vector3) -> RobotAnimInput:
	var inp := _input(S.GRAPPLE, Vector3(0, 2, -10), 0.2)
	inp.grapple_on = true
	inp.grapple_anchor = anchor
	inp.hook_taut = 0.01
	return inp


## The way the blade in the right hand points, in the model.
func _blade() -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones["pistol"]).basis.orthonormalized() * (MeleeModel.HOLD * Vector3.UP)


## A bone's place in the model.
func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin


## How far from straight down the line from bone `top` to bone `low` leans, fore and aft (+ = trailing back).
func _lean(low: String, top: String) -> float:
	var d := _at(low) - _at(top)
	return atan2(d.z, -d.y)


## How far a knee is bent (0: the leg is straight).
func _bend(thigh: String, shin: String, foot: String) -> float:
	return (_at(shin) - _at(thigh)).angle_to(_at(foot) - _at(shin))


func _fresh() -> void:
	if robot == null:
		robot = RobotModel.new().setup(Characters.body(Characters.default_id()), Color(1, 0.3, 0.2), false, _weapon)
		root.add_child(robot)
	robot.position = Vector3.ZERO
	robot.rotation = Vector3.ZERO
	animator = RobotAnimator.new(robot)


func _drop() -> void:
	if robot == null:
		return
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles otherwise
		robot.mesh.set_surface_override_material(i, null)
	robot.queue_free()
	robot = null


func _input(state: int, velocity: Vector3, pitch: float) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = state
	inp.velocity = velocity
	inp.pitch = pitch
	return inp


func _run(inp: RobotAnimInput, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		animator.update(STEP, inp, robot.global_transform)
		t += STEP


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
