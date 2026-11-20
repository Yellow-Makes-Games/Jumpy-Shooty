extends SceneTree
## Headless checks on a body on the rope bracing against a wall (WallBrace): looks only.
## Run: godot --headless --path . --script tests/wall_brace_test.gd
##
## Nothing happens away from a wall, off the rope, or without one (a ceiling gives none);
## coming in, the legs come up before the body arrives and the landing is told once,
## harder the faster it came; hanging there, both feet are on the wall, apart, under the
## hips, and the pose really puts the ankles there; the hips face the wall and the waist
## stays within its turn; aimed away, the body goes side-on with one leg on the wall;
## worked along the wall, the feet step and stay on it; going fast along it they come
## off; a jump off the rope shoves off and a plain let-go does not; and it all clears.

const S := MovementController.State
const DT := 1.0 / 60.0
const WALL_X := 10.0
const OUT := Vector3(-1, 0, 0)          # the wall's normal: it faces west, the body is on its west side
const EAST := -PI / 2.0                 # facing the wall

var _ok := true


func _init() -> void:
	# Away from the wall, and without one.
	var b := WallBrace.new()
	var inp := _hanging(EAST)
	_run(b, inp, Vector3(WALL_X - 3.0, 5, 0), 0.5)
	_check(b.w == 0.0, "3 m from a wall, hanging still: no brace")
	inp.wall_normal = Vector3.ZERO
	_run(b, inp, Vector3(WALL_X - 0.45, 5, 0), 0.5)
	_check(b.w == 0.0, "no wall found (a ceiling, the underside of something): no brace")
	inp = _hanging(EAST)
	inp.state = S.AIR
	_run(b, inp, Vector3(WALL_X - 0.45, 5, 0), 0.5)
	_check(b.w == 0.0, "not on the rope: no brace")
	inp = _hanging(EAST)
	inp.hook_taut = -1.0
	_run(b, inp, Vector3(WALL_X - 0.45, 5, 0), 0.5)
	_check(b.w == 0.0, "the rope still slack: no brace")

	# Coming in at 6 m/s: the legs come up first, the landing is told once.
	for speed in [3.0, 9.0]:
		b = WallBrace.new()
		inp = _hanging(EAST)
		inp.velocity = Vector3(speed, 0, 0)
		var x := WALL_X - 3.2
		var up_at := -1.0
		var hard := 0.0
		var told := 0
		while x < WALL_X - 0.45:
			x += speed * DT
			b.update(DT, inp, Vector3(x, 5, 0))
			if b.w > 0.3 and up_at < 0.0:
				up_at = WALL_X - x
			var h := b.take_landed()
			if h > 0.0:
				told += 1
				hard = h
		_check(up_at > WallBrace.LEG, "coming in at %.0f m/s the legs are up %.2f m out, before the feet can reach" % [speed, up_at])
		_check(told == 1, "...and the landing is told once (%d)" % told)
		_check(hard > 0.0 and absf(hard - clampf(speed / 9.0, 0.12, 1.0)) < 0.05, "...as hard as it came in (%.2f)" % hard)

	# Hanging there.
	b = WallBrace.new()
	inp = _hanging(EAST)
	var feet := Vector3(WALL_X - 0.45, 5, 0)
	_run(b, inp, feet, 1.0)
	_check(b.w == 1.0 and b.standing(), "hanging 0.45 m from the wall: braced")
	_check(absf(b.foot(0).x - WALL_X) < 0.001 and absf(b.foot(1).x - WALL_X) < 0.001, "both feet are on the wall")
	_check(b.foot(0).z < -0.1 and b.foot(1).z > 0.1, "the left to the left, the right to the right (%.2f, %.2f)" % [b.foot(0).z, b.foot(1).z])
	_check(b.foot(0).y < feet.y + WallBrace.HIPS - 0.2, "below the hips")
	_check(absf(b.twist(EAST)) < 0.01 and b.flank() == 0, "the hips face the wall")
	# The pose puts the ankles there.
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var pose := rig.new_pose()
	rig.sample(pose, "idle", 0.0)
	var was := rig.new_pose()
	was.copy(pose)
	var model := Transform3D(Basis(Vector3.UP, EAST), feet)
	b.lay(pose, rig.bones, rig, model)
	for i in 2:
		var side: String = ["l", "r"][i]
		var ankle := model * _ankle(pose, rig.bones, side)
		var want := b.foot(i) + OUT * WallBrace.ANKLE
		_check(ankle.distance_to(want) < 0.03, "the %s ankle is at its foothold (%.3f m off)" % [side, ankle.distance_to(want)])
		_check(not pose.rot[rig.bones["thigh_" + side]].is_equal_approx(was.rot[rig.bones["thigh_" + side]]), "...the leg bent to reach it")
	for kept in ["spine", "chest", "head", "upper_arm_l", "upper_arm_r"]:
		_check(pose.rot[rig.bones[kept]].is_equal_approx(was.rot[rig.bones[kept]]), "the %s is left alone" % kept, true)
	_check(pose.pos[rig.bones["root"]].distance_to(was.pos[rig.bones["root"]]) <= WallBrace.OUT + 0.001, "the hips ease out no more than %.2f m" % WallBrace.OUT)

	# Aimed along the wall, then away from it.
	inp.yaw = EAST + 1.2
	_run(b, inp, feet, 0.6)
	_check(b.flank() == 0 and absf(absf(b.twist(inp.yaw)) - 1.2) < 0.05, "aimed 70 degrees round: the hips still face the wall, the waist turned (%.2f)" % b.twist(inp.yaw))
	inp.yaw = EAST + 2.6
	_run(b, inp, feet, 1.0)
	_check(b.flank() != 0, "aimed away from the wall: side-on")
	_check(absf(b.twist(inp.yaw)) <= PI * 0.5 + 0.05, "...the waist turned less than a quarter turn (%.2f)" % b.twist(inp.yaw))
	pose.copy(was)
	b.lay(pose, rig.bones, rig, Transform3D(Basis(Vector3.UP, inp.yaw), feet))
	var bent := 0
	for side in ["l", "r"]:
		if not pose.rot[rig.bones["thigh_" + side]].is_equal_approx(was.rot[rig.bones["thigh_" + side]]):
			bent += 1
	_check(bent == 1, "...one leg on the wall, the other left hanging (%d)" % bent)
	inp.yaw = EAST
	_run(b, inp, feet, 1.0)
	_check(b.flank() == 0, "aimed back at it: facing the wall again")

	# Worked along the wall, slowly: the feet step and stay on it.
	inp.velocity = Vector3(0, 0, 2.0)
	var steps := 0
	var worst := 0.0
	for i in 120:
		feet += inp.velocity * DT
		b.update(DT, inp, feet)
		if b.take_stepped():
			steps += 1
		for f in 2:
			worst = maxf(worst, absf(b.foot(f).z - feet.z))
			_check(b.foot(f).x >= WALL_X - WallBrace.STEP_LIFT - 0.001 and b.foot(f).x <= WALL_X + 0.001, "a foot leaves the wall only to step", true)
	_check(steps >= 4, "4 m along the wall at 2 m/s: the feet step along it (%d steps)" % steps)
	_check(worst < 0.8 and b.w == 1.0, "...and keep up (never more than %.2f m behind)" % worst)
	# ...and fast: they come off.
	inp.velocity = Vector3(0, 0, 9.0)
	for i in 40:
		feet += inp.velocity * DT
		b.update(DT, inp, feet)
	_check(b.w == 0.0, "9 m/s along the wall: the feet come off it")

	# A jump off the rope shoves off; a plain let-go does not.
	for jump in [true, false]:
		b = WallBrace.new()
		inp = _hanging(EAST)
		feet = Vector3(WALL_X - 0.45, 5, 0)
		_run(b, inp, feet, 1.0)
		var planted := b.foot(0)
		inp.state = S.AIR
		inp.hook_taut = -1.0
		inp.grapple_on = false
		inp.velocity = Vector3(-3.0, 6.0 if jump else 0.0, 0)
		b.update(DT, inp, feet)
		if jump:
			_check(b.pushing() and b.w == 1.0, "a jump off the rope: the legs shove off")
			feet += inp.velocity * DT * 3.0
			b.update(DT * 3.0, inp, feet)
			_check(b.foot(0).is_equal_approx(planted), "...the feet still where they were, the body going")
			_run(b, inp, feet + Vector3(-2, 2, 0), 0.5)
			_check(b.w == 0.0 and not b.pushing(), "...and it is over once the wall is out of reach")
		else:
			_check(not b.pushing() and b.w < 1.0, "a plain let-go: no shove, the legs just come away")
	b.stop()
	_check(b.w == 0.0 and b.take_landed() == 0.0 and not b.take_stepped(), "stop() clears it")
	print("wall_brace_test: %s" % ("OK" if _ok else "FAILED"))
	quit(0 if _ok else 1)


# On a tight rope, still, at the wall, hooked high up on it.
func _hanging(yaw: float) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = S.GRAPPLE
	inp.alive = true
	inp.yaw = yaw
	inp.grapple_on = true
	inp.grapple_anchor = Vector3(WALL_X, 12, 0)
	inp.hook_taut = 1.0
	inp.wall_at = Vector3(WALL_X, 6, 0)
	inp.wall_normal = OUT
	return inp


func _run(b: WallBrace, inp: RobotAnimInput, feet: Vector3, seconds: float) -> void:
	for i in int(seconds / DT):
		b.update(DT, inp, feet)


# Where a pose puts an ankle, in the body's space.
func _ankle(pose: RobotPose, bones: Dictionary, side: String) -> Vector3:
	var at := Transform3D.IDENTITY
	for bone in ["root", "hips", "thigh_" + side, "shin_" + side, "foot_" + side]:
		at = at * Transform3D(Basis(pose.rot[bones[bone]]), pose.pos[bones[bone]])
	return at.origin


func _check(ok: bool, what: String, quiet: bool = false) -> void:
	if not ok:
		_ok = false
		print("FAIL  ", what)
	elif not quiet:
		print("ok    ", what)
