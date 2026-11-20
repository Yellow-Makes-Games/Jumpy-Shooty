extends SceneTree
## The hand without the gun (FreeHand): reaching for a pickup, snatching it, pressing a
## terminal, riding a lever, working at a bomb. Looks only.
## Run: godot --headless --fixed-fps 60 --path . --script tests/free_hand_test.gd
##
## Left alone it does nothing; a reach brings the arm out and lets it go again when the
## pickup is no longer ahead; a snatch shuts the fist and pulls in to the chest, with the
## pickup's colour flashing and fading; a press is on for as long as it is asked and
## follows a thing that moves; a hold stays on, bends the body to something low and
## strikes sparks about once a second; a shot cuts everything short and keeps the hand
## off for a moment. On a pose it moves the left arm alone and puts the wrist on what it
## is after (or the arm straight at it, if it is out of reach). On a body: the hand goes
## out, the body bends at the waist to plant while the gun stays on the aim, and none of
## it shows with that arm up the rope or in a flip.

const S := MovementController.State
const STEP := 1.0 / 60.0

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _done := false
var _moving := Vector3.ZERO


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("FREE HAND TEST PASSED" if failures == 0 else "FREE HAND TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	var body := Transform3D.IDENTITY
	print("The hand")
	var h := FreeHand.new()
	_step(h, body, 0.5)
	_expect("left alone it does nothing", h.w == 0.0 and h.fist == 0.0 and h.bow == 0.0 and h.pulse == 0.0)
	var pad := Vector3(-0.3, 1.3, -1.5)
	for i in 30:
		h.reach(pad)
		h.update(STEP, body)
	_expect("a pickup ahead: the arm comes out to it", h.w == 1.0 and h.target().distance_to(pad) < 0.01 and h.fist == 0.0, "%.2f" % h.w)
	_step(h, body, 0.5)
	_expect("...and goes back when it is no longer ahead", h.w == 0.0)

	h = FreeHand.new()
	for i in 20:
		h.reach(pad)
		h.update(STEP, body)
	h.grab(pad, Color(0.35, 1.0, 0.45))
	_step(h, body, FreeHand.GRAB_SHUT + 0.03)
	_expect("a snatch: the fist shuts on it", h.fist > 0.8 and h.w == 1.0, "%.2f" % h.fist)
	_expect("...its colour flashes through the body", h.pulse > 0.6 and h.pulse_color.g > 0.9)
	_step(h, body, FreeHand.GRAB_TIME - FreeHand.GRAB_SHUT - 0.05)
	_expect("...and it is pulled in to the chest", h.target().distance_to(FreeHand.PULL_TO) < 0.25, "%.2f m off, of %.2f" % [h.target().distance_to(FreeHand.PULL_TO), pad.distance_to(FreeHand.PULL_TO)])
	_step(h, body, 0.6)
	_expect("...then the arm is its own again, the fist open, the colour gone", h.w == 0.0 and h.fist == 0.0 and h.pulse == 0.0)
	h.grab(pad)
	_expect("a weapon has no colour to flash", h.pulse == 0.0)

	h = FreeHand.new()
	_moving = Vector3(0, 1.2, -0.6)
	h.touch(_moving, 0.4, func() -> Vector3: return _moving)
	_step(h, body, 0.2)
	_moving = Vector3(0, 1.1, -0.9)
	_step(h, body, 0.15)
	_expect("a press: the hand is on it, and follows it as it moves (a lever)", h.w == 1.0 and h.target().distance_to(_moving) < 0.05, "%.3f" % h.target().distance_to(_moving))
	_step(h, body, 0.6)
	_expect("...for as long as it was asked", h.w == 0.0)

	h = FreeHand.new()
	var sparks := 0
	for i in 180:
		h.hold(Vector3(0, 0.3, -0.5), true, true, true)
		h.update(STEP, body)
		if h.take_spark():
			sparks += 1
	_expect("a hold on something low: the hand stays on it and the body bends to it", h.w == 1.0 and h.bow == 1.0 and h.target().distance_to(Vector3(0, 0.3, -0.5)) < FreeHand.WORK * 2.5)
	_expect("...striking a spark about once a second (%d in 3 s)" % sparks, sparks >= 2 and sparks <= 4)
	for i in 30:
		h.hold(Vector3(0, 1.0, -0.6))
		h.update(STEP, body)
	_expect("a hold on something at hand: no bending", h.bow < 0.2 and h.w == 1.0, "%.2f" % h.bow)
	h.cut()
	_step(h, body, 0.1)
	_expect("a shot: it is dropped at once", h.w < 0.2, "%.2f" % h.w)
	h.reach(pad)
	h.hold(pad)
	h.touch(pad, 1.0)
	h.grab(pad)
	_step(h, body, 0.15)
	_expect("...and the hand stays off for a moment", h.w == 0.0)
	_step(h, body, FreeHand.BLOCK)
	for i in 20:
		h.reach(pad)
		h.update(STEP, body)
	_expect("...then is free again", h.w == 1.0)
	h.stop()
	_expect("stop() clears it", h.w == 0.0 and h.bow == 0.0 and not h.take_spark())

	print("On a pose")
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var pose := rig.new_pose()
	rig.sample(pose, "idle", 0.0)
	var was := rig.new_pose()
	was.copy(pose)
	for near in [true, false]:
		pose.copy(was)
		var at := Vector3(-0.25, 1.15, -0.4) if near else Vector3(-0.3, 1.4, -2.5)
		h = FreeHand.new()
		for i in 30:
			h.reach(at)
			h.update(STEP, body)
		h.lay(pose, rig.bones, body)
		var moved := []
		for bone in rig.bones:
			if not pose.rot[rig.bones[bone]].is_equal_approx(was.rot[rig.bones[bone]]) or not pose.pos[rig.bones[bone]].is_equal_approx(was.pos[rig.bones[bone]]):
				moved.append(bone)
		moved.sort()
		_expect("it moves the left arm and nothing else", moved == ["forearm_l", "hand_l", "upper_arm_l"], str(moved))
		var wrist := _joint(pose, rig.bones, ["root", "hips", "spine", "chest", "upper_arm_l", "forearm_l", "hand_l"])
		var shoulder := _joint(pose, rig.bones, ["root", "hips", "spine", "chest", "upper_arm_l"])
		if near:
			_expect("within reach: the wrist is on it", wrist.distance_to(at) < 0.03, "%.3f m off" % wrist.distance_to(at))
		else:
			_expect("out of reach: the arm is straight out at it", (wrist - shoulder).normalized().dot((at - shoulder).normalized()) > 0.995)
	pose.copy(was)
	h.lay(pose, rig.bones, body, 0.0)
	_expect("none of it with the animator's say at nothing", pose.rot[rig.bones["upper_arm_l"]].is_equal_approx(was.rot[rig.bones["upper_arm_l"]]))

	print("On a body")
	_fresh()
	var free := FreeHand.new()
	animator.free = free
	var stand := _input(S.GROUND)
	_run(stand, free, 0.5)
	var rest := _at("hand_l")
	var gun := _aim()
	var chest_up := _up("chest")
	var ahead := Vector3(-0.3, 1.4, -1.6)
	_run(stand, free, 0.5, ahead)
	_expect("a pickup ahead: the left hand goes out toward it", _at("hand_l").distance_to(ahead) < rest.distance_to(ahead) - 0.2 and _at("hand_l").z < rest.z - 0.1,
		"%.2f m from it, was %.2f" % [_at("hand_l").distance_to(ahead), rest.distance_to(ahead)])
	_expect("...and the gun stays on the aim", _aim().dot(gun) > 0.995, "%.4f" % _aim().dot(gun))
	_run(stand, free, 0.6)
	_expect("...and comes back", _at("hand_l").distance_to(rest) < 0.03, "%.3f" % _at("hand_l").distance_to(rest))
	for i in 60:
		free.hold(Vector3(0, 0.3, -0.5), true, true)
		free.update(STEP, robot.global_transform)
		animator.update(STEP, stand, robot.global_transform)
	_expect("planting: bent at the waist, the hand down by the knees", _up("chest").z < chest_up.z - 0.5 and _at("hand_l").y < 0.75,
		"the chest tipped %.2f, the hand at %.2f" % [_up("chest").z, _at("hand_l").y])
	_expect("...the hips where they were, the gun still on the aim", absf(_at("hips").y - 0.95) < 0.1 and _aim().dot(gun) > 0.97, "%.3f" % _aim().dot(gun))
	_fresh()
	free = FreeHand.new()
	animator.free = free
	var rope := _input(S.GRAPPLE)
	rope.grapple_on = true
	rope.grapple_anchor = Vector3(0.2, 8.0, -0.5)
	rope.hook_taut = 1.0
	_run(rope, free, 0.6, ahead)
	_expect("with that arm up the rope: nothing", animator._free_w == 0.0 and _at("hand_l").y > 1.5)
	_fresh()
	free = FreeHand.new()
	animator.free = free
	_run(_input(S.FLIP), free, 0.3, ahead)
	_expect("in a flip: nothing", animator._free_w == 0.0)
	animator.free = null
	_run(stand, free, 0.2)
	_expect("a body with no hand of its own (a stand-in) is posed as ever", animator.source == "loco")


func _step(h: FreeHand, body: Transform3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		h.update(STEP, body)
		t += STEP


## Where a chain of bones ends, in the body's space.
func _joint(pose: RobotPose, bones: Dictionary, chain: Array) -> Vector3:
	var at := Transform3D.IDENTITY
	for bone in chain:
		at = at * Transform3D(Basis(pose.rot[bones[bone]]), pose.pos[bones[bone]])
	return at.origin


func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin


func _up(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).basis.orthonormalized() * Vector3.UP


## The way the gun points, in the model.
func _aim() -> Vector3:
	return (robot.skeleton.get_bone_global_pose(robot.rig.bones["pistol"]).basis.orthonormalized() * (GunRecoil.REST * Vector3.FORWARD)).normalized()


func _fresh() -> void:
	if robot == null:
		robot = RobotModel.new().setup(Characters.body(Characters.default_id()), Color(1, 0.3, 0.2), false, "rifle")
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


func _input(state: int) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = state
	return inp


## The body run for `seconds`, its hand reaching for `at` all the while (INF: left alone).
func _run(inp: RobotAnimInput, free: FreeHand, seconds: float, at: Vector3 = Vector3.INF) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		if at != Vector3.INF:
			free.reach(at)
		free.update(STEP, robot.global_transform)
		animator.update(STEP, inp, robot.global_transform)
		t += STEP


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
