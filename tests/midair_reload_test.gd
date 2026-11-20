extends SceneTree
## Reloading off the ground: with one hand when the other is busy (OneHandReload, on the
## rope and on a wall run), with the body joining in in the air, and on through a flip.
## Looks only. Run: godot --headless --fixed-fps 60 --path . --script tests/midair_reload_test.gd
##
## Every gun has a one-handed reload that starts and ends at the hold, is down at the
## belt as the new cell goes home, and keeps to the gun's own moments (the cell out from
## the flick to the slam, when ReloadFx throws it and brings the gun back to life); your
## own arms only ever go down for it; it moves the gun arm and nothing else. On a body:
## standing, a reload is the two-handed clip it always was; on the rope and on a wall run
## the gun hand goes down to the belt alone and the other arm stays where it was; in the
## air both hands work and the knees come up; a flip no longer hides it; an akimbo left
## gun that sat one out on the rope catches up once its hand is free.

const S := MovementController.State
const STEP := 1.0 / 60.0
const RELOADING := 4      # RobotAnimInput.make_flags: bit 2
const WALL_RIGHT := 1

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _weapon := "pistol"
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("MIDAIR RELOAD TEST PASSED" if failures == 0 else "MIDAIR RELOAD TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	print("Every gun's one-handed reload")
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var bad := []
	var mag_fed := 0
	for id in WeaponData.IDS:
		var data := WeaponData.by_id(id)
		if data.is_melee():
			continue
		var look := WeaponData.look_of(id)
		var clip: String = "reload_" + look if rig.has_clip("reload_" + look) else "reload"
		var length := rig.length(clip)
		var per := data.reload_per_round
		var b := OneHandReload.beats(look, length, per)
		var row := OneHandReload.keys(look, length, per)
		var why := ""
		for i in range(1, row.size()):
			if float(row[i][0]) < float(row[i - 1][0]):
				why = "its poses are out of order"
		if float(b[1]) <= 0.0 or float(b[1]) > length:
			why = "the new cell is home outside the reload (%.2f of %.2f)" % [b[1], length]
		if not per and (float(OneHandReload.at(look, 0.0, length, per).w) > 0.001 or float(OneHandReload.at(look, length, length, per).w) > 0.05):
			why = "it does not start and end at the hold"
		if not bool(b[2]) and OneHandReload.low(look, float(b[1]), length, per) < 0.99:
			why = "it is not down at the belt as the cell goes home"
		if float(b[0]) >= 0.0:
			mag_fed += 1
			if float(b[0]) >= float(b[1]) or OneHandReload.cell_out(look, float(b[0]) - 0.01, length, per) \
					or not OneHandReload.cell_out(look, (float(b[0]) + float(b[1])) * 0.5, length, per) or OneHandReload.cell_out(look, float(b[1]) + 0.01, length, per):
				why = "its cell is not out from the flick to the slam, and only then"
		elif OneHandReload.cell_out(look, float(b[1]) * 0.5, length, per):
			why = "its cell goes missing though nothing leaves it"
		var t := 0.0
		while t <= length:
			var v: Array = OneHandReload.view(look, t, length, per)
			if (v[0] as Vector3).y > 0.0001 or (v[0] as Vector3).y < -(OneHandReload.VIEW_DOWN + OneHandReload.VIEW_SLAM) - 0.001:
				why = "your own arms go up, or too far down, at %.2f (%.3f)" % [t, (v[0] as Vector3).y]
			t += 0.02
		if why != "":
			bad.append("%s: %s" % [id, why])
	_expect("every gun has one: in order, hold to hold, at the belt for the new cell, the cell out between flick and slam, your own arms only ever down", bad.is_empty(), str(bad))
	_expect("most guns throw something out (%d)" % mag_fed, mag_fed >= 12)
	var pose := rig.new_pose()
	rig.sample(pose, "idle", 0.0)
	var was := rig.new_pose()
	was.copy(pose)
	OneHandReload.lay(pose, rig.bones, "rifle", 1.1, 1.9, false, 1.0)
	var moved := []
	for bone in rig.bones:
		if not pose.rot[rig.bones[bone]].is_equal_approx(was.rot[rig.bones[bone]]) or not pose.pos[rig.bones[bone]].is_equal_approx(was.pos[rig.bones[bone]]):
			moved.append(bone)
	moved.sort()
	_expect("it moves the gun arm and nothing else", moved == ["forearm_r", "hand_r", "upper_arm_r"], str(moved))
	pose.copy(was)
	OneHandReload.lay_catch_up(pose, rig.bones, "akimbo", 0.24, 1.0)
	_expect("an akimbo left gun's catch-up moves the left arm", not pose.rot[rig.bones["upper_arm_l"]].is_equal_approx(was.rot[rig.bones["upper_arm_l"]])
		and pose.rot[rig.bones["upper_arm_r"]].is_equal_approx(was.rot[rig.bones["upper_arm_r"]]))

	print("On a body")
	_weapon = "rifle"
	_fresh()
	var seat := float(OneHandReload.beats("rifle", robot.rig.length("reload_rifle"), false)[1])
	var stand := _input(S.GROUND, Vector3.ZERO, 0.0)
	_run(stand, 0.5)
	var hold := _at("hand_r")
	var off_hand := _at("hand_l")
	stand.flags = RELOADING
	_run(stand, seat)
	_expect("standing: the two-handed reload, as ever", animator._one_w == 0.0 and animator._reload_w == 1.0 and _at("hand_l").distance_to(off_hand) > 0.05,
		"one-handed %.2f, the off hand moved %.2f" % [animator._one_w, _at("hand_l").distance_to(off_hand)])

	_fresh()
	var rope := _input(S.GRAPPLE, Vector3.ZERO, 0.0)
	rope.grapple_on = true
	rope.grapple_anchor = Vector3(0.2, 8.0, -0.5)
	rope.hook_taut = 1.0
	_run(rope, 0.8)
	hold = _at("hand_r")
	rope.flags = RELOADING
	_run(rope, 0.12)
	var cocked := _at("hand_r")
	_run(rope, seat - 0.12 - 0.1)
	_expect("on the rope: the gun hand goes down to the belt alone", animator._one_w == 1.0 and _at("hand_r").y < 1.05 and _at("hand_r").y < cocked.y - 0.1,
		"one-handed %.2f, the hand at %.2f (it was cocked at %.2f)" % [animator._one_w, _at("hand_r").y, cocked.y])
	_expect("...the rope arm stays up the rope", _at("hand_l").y > 1.5, str(_at("hand_l")))
	_expect("...and the gun is without its cell until it is slammed home", robot.skeleton.get_bone_pose_scale(robot.rig.bones["pistol_mag"]).x < 0.01)
	_run(rope, 0.2)
	_expect("...then has it", robot.skeleton.get_bone_pose_scale(robot.rig.bones["pistol_mag"]).x > 0.9)
	_run(rope, robot.rig.length("reload_rifle") - seat - 0.1)
	rope.flags = 0
	_run(rope, 0.4)
	_expect("...and is back at the hold after", animator._one_w == 0.0 and _at("hand_r").distance_to(hold) < 0.06, "%.3f" % _at("hand_r").distance_to(hold))

	_fresh()
	var wall := _input(S.WALL_RUN, Vector3(0, 0, -9), 0.0)
	wall.flags = WALL_RIGHT
	_run(wall, 0.5)
	hold = _at("hand_r")
	wall.flags = WALL_RIGHT | RELOADING
	_run(wall, seat)
	_expect("on a wall run: one hand too", animator._one_w == 1.0 and _at("hand_r").y < hold.y - 0.15, "%.2f, the hand at %.2f from %.2f" % [animator._one_w, _at("hand_r").y, hold.y])

	_fresh()
	var air := _input(S.AIR, Vector3(0, -2, -4), 0.0)
	_run(air, 0.5)
	var knee := _at("shin_l").y
	air.flags = RELOADING
	_run(air, 0.6)
	_expect("in the air: both hands, and the knees come up", animator._one_w == 0.0 and animator._reload_w == 1.0 and _at("shin_l").y > knee + 0.03,
		"the knee %.3f from %.3f" % [_at("shin_l").y, knee])
	air.flags = 0
	_run(air, 0.8)
	_expect("...and go back down after", absf(_at("shin_l").y - knee) < 0.01, "%.3f from %.3f" % [_at("shin_l").y, knee])

	_fresh()
	air.flags = RELOADING
	_run(air, 0.2)
	var flip := _input(S.FLIP, Vector3(0, 3, -6), 0.0)
	flip.flags = RELOADING
	_run(flip, 0.2)
	_expect("through a flip: the reload goes on in the hands", animator.source.begins_with("flip") and animator._reload_w == 1.0, "%s %.2f" % [animator.source, animator._reload_w])
	var roll := _input(S.ROLL, Vector3(0, 0, -6), 0.0)
	roll.flags = RELOADING
	_run(roll, 0.15)
	_expect("...a landing roll still keeps the hands busy", animator._reload_w == 0.0, "%s %.2f" % [animator.source, animator._reload_w])

	print("Akimbo")
	_drop()
	_weapon = "akimbo"
	_fresh()
	var length := robot.rig.length("reload_akimbo")
	_run(rope, 0.8)
	off_hand = _at("hand_l")
	rope.flags = RELOADING
	_run(rope, length * 0.5)
	_expect("on the rope the free gun reloads and the other waits", animator._one_w == 1.0 and _at("hand_l").distance_to(off_hand) < 0.05)
	_run(rope, length * 0.5)
	rope.flags = 0
	_run(rope, 0.3)
	_expect("...and is owed its turn", animator._owed and animator._catch_t < 0.0)
	var free := _input(S.AIR, Vector3(0, -3, -4), 0.0)
	_run(free, 0.3)
	_expect("let go of the rope, it catches up", animator._catch_t >= 0.0 and not animator._owed, "%.2f" % animator._catch_t)
	_run(free, 0.6)
	_expect("...and that is that", animator._catch_t < 0.0 and not animator._owed)


## Where a bone is, in the model.
func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin


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
