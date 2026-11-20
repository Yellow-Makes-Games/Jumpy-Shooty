extends SceneTree
## Emotes (Emote), the wheel's picking (EmoteWheel) and a chosen victory pose (Podium).
## Looks only.
## Run: godot --headless --fixed-fps 60 --path . --script tests/emote_test.gd
##
## The wheel saved in the settings is always six different emotes; an emote may start
## only alive, on the ground and still; a one-shot eases in, ends by itself and eases
## out, the dance goes on until it is stopped; each emote puts the free hand where it
## says with a gun, a blade, a gun in each hand, fists and nothing, the weapon staying
## low in the other hand; the dance moves the hips over feet that stay put; the body is
## back as it was afterwards; the wheel's pointer picks the slot it is nearest; and the
## results page's winner strikes the pose they chose.

const STEP := 1.0 / 60.0

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var inp: RobotAnimInput
var emote: Emote
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_rules()
	_gestures()
	_wheel()
	_victory()
	print("EMOTE TEST PASSED" if failures == 0 else "EMOTE TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _rules() -> void:
	print("The rules")
	_expect("eight emotes, each with a name and a length", Emote.LIST.size() == 8 and Emote.LIST.all(func(e): return Emote.name_of(e) != "" and float(Emote.LENGTH[e]) > 1.0))
	_expect("the wheel starts with six of them", Emote.wheel(null) == Emote.DEFAULT_WHEEL and Emote.DEFAULT_WHEEL.size() == Emote.SLOTS)
	var mended := Emote.wheel(["dance", "nonsense", "dance", "shrug"])
	_expect("a saved wheel is made six different emotes, keeping what it can", mended.size() == 6 and mended[0] == "dance" and mended[1] == "shrug"
		and mended.all(func(e): return Emote.valid(e)) and mended.all(func(e): return mended.count(e) == 1), str(mended))
	_expect("...and never more than six", Emote.wheel(Emote.LIST).size() == 6)
	_expect("one may start standing still on the ground", Emote.may_start(true, true, 0.3))
	_expect("...not moving, not in the air, not knocked out", not Emote.may_start(true, true, 3.0) and not Emote.may_start(true, false, 0.0) and not Emote.may_start(false, true, 0.0))
	var e := Emote.new()
	e.play("nonsense")
	_expect("nothing plays that is not an emote", not e.active())
	e.play("wave")
	e.update(STEP)
	_expect("one starts easing in", e.active() and e.w > 0.0 and e.w < 0.5)
	for i in 30:
		e.update(STEP)
	_expect("...and is all there in a moment", is_equal_approx(e.w, 1.0))
	var steps := 31
	while e.active() and steps < 600:
		e.update(STEP)
		steps += 1
	_expect("a wave ends by itself (%.2f s)" % (steps * STEP), absf(steps * STEP - float(Emote.LENGTH["wave"])) < 0.05)
	for i in 30:
		e.update(STEP)
	_expect("...and eases out", e.w == 0.0)
	e.play("dance")
	for i in 600:
		e.update(STEP)
	_expect("the dance goes on until it is stopped", e.active() and is_equal_approx(e.w, 1.0))
	e.stop()
	e.update(STEP)
	_expect("...then eases out from where it was", not e.active() and e.w > 0.5)
	for i in 30:
		e.update(STEP)
	_expect("...to nothing", e.w == 0.0)
	_expect("how each weapon is held, for these", BodyPose.grip_of("sword").melee and BodyPose.grip_of("claws").fists and BodyPose.grip_of("none").empty
		and BodyPose.grip_of("akimbo").akimbo and not BodyPose.grip_of("rifle").melee and BodyPose.grip_of("rocket_launcher").shoulder)


func _gestures() -> void:
	print("The gestures")
	var aim := Vector3(0.5, 0.15, -1.0).normalized()
	for gun in ["rifle", "sword", "akimbo", "claws", "none"]:
		_fresh(gun)
		for i in 40:
			_step()
		var rest_left := _at("hand_l")
		var rest_hips := _at("hips")
		var rest_foot := _at("foot_l")
		var shoulder := _at("upper_arm_l")
		var head := _at("head").y
		for id in Emote.LIST:
			emote.play(id, aim)
			var most := 0.0   # how far the free hand gets from where it was
			var low := true   # the weapon hand stays below the shoulder
			var sank := 0.0
			var slid := 0.0
			var ok := false
			var why := ""
			for i in int(minf(float(Emote.LENGTH[id]), 1.9) / STEP) - 6:
				_step()
				var left := _at("hand_l")
				most = maxf(most, left.distance_to(rest_left))
				low = low and (id == "dance" or emote.w < 1.0 or _at("hand_r").y < shoulder.y + 0.02)   # (once it is in)
				sank = maxf(sank, rest_hips.y - _at("hips").y)
				slid = maxf(slid, Vector2(_at("foot_l").x - rest_foot.x, _at("foot_l").z - rest_foot.z).length())
				match id:
					"wave": ok = ok or left.y > head + 0.05
					"salute": ok = ok or (left.y > shoulder.y + 0.15 and absf(left.x) < 0.3)
					"thumbs_up", "beckon": ok = ok or (left.z < -0.3 and absf(left.y - shoulder.y) < 0.2)
					"point": ok = ok or (left - shoulder).normalized().dot(aim) > 0.93
					"shrug": ok = ok or (left.x < -0.38 and left.y > shoulder.y - 0.3)
					"laugh": ok = ok or (absf(left.x) < 0.16 and left.y < shoulder.y - 0.2 and left.z < -0.08)
					"dance": ok = ok or left.y > shoulder.y + 0.1
				why = "left %.2f %.2f %.2f, shoulder %.2f %.2f %.2f" % [left.x, left.y, left.z, shoulder.x, shoulder.y, shoulder.z]
			if gun == "rifle" or not ok or not low:
				_expect("%s with a %s: the free hand does it, the weapon stays low" % [id, gun], ok and low and most > 0.2, "%s; done %s, low %s, moved %.2f m" % [why, ok, low, most])
			if id == "dance":
				_expect("...the hips bounce (%.0f cm) over feet that stay put (%.1f cm)" % [sank * 100.0, slid * 100.0], sank > 0.05 and slid < 0.03)
			emote.stop()
			for i in 40:
				_step()
			if _at("hand_l").distance_to(rest_left) > 0.03:
				_expect("%s with a %s: the body is back as it was" % [id, gun], false, "%.3f m off" % _at("hand_l").distance_to(rest_left))
	_expect("(every emote with every kind of weapon, and back)", true)
	_fresh("rifle")
	for i in 40:
		_step()
	var before := _at("hand_l")
	animator.first_person = true
	for i in 10:
		_step()
	var view := _at("hand_l")
	emote.play("wave")
	for i in 50:
		_step()
	_expect("your own first-person body does not do it (the camera has pulled back to the other one)", _at("hand_l").distance_to(view) < 0.02,
		"%.2f" % _at("hand_l").distance_to(view))
	animator.first_person = false
	emote.stop()
	inp.alive = false
	for i in 60:
		_step()
	var down := _at("hand_l")
	emote.play("wave")
	for i in 50:
		_step()
	_expect("nor a body that is down", _at("hand_l").distance_to(down) < 0.05 and before.distance_to(view) < 1.0, "%.2f" % _at("hand_l").distance_to(down))


func _wheel() -> void:
	print("The wheel")
	var wheel: Script = load("res://game/ui/emote_wheel.gd")
	_expect("the middle picks nothing", wheel.slot_for(Vector2.ZERO) == -1 and wheel.slot_for(Vector2(10, -10)) == -1)
	_expect("up is the first slot, and they go round clockwise", wheel.slot_for(Vector2(0, -90)) == 0 and wheel.slot_for(Vector2(80, -45)) == 1
		and wheel.slot_for(Vector2(80, 45)) == 2 and wheel.slot_for(Vector2(0, 90)) == 3 and wheel.slot_for(Vector2(-80, 45)) == 4 and wheel.slot_for(Vector2(-80, -45)) == 5)
	var round_trip := true
	for i in Emote.SLOTS:
		round_trip = round_trip and wheel.slot_for(wheel.way_of(i) * 80.0) == i
	_expect("each slot's own direction picks it", round_trip)
	_expect("a pointer between two picks the nearer", wheel.slot_for(Vector2(20, -90)) == 0 and wheel.slot_for(Vector2(60, -70)) == 1)


func _victory() -> void:
	print("A chosen victory pose")
	var rows := [{"id": 4, "name": "A", "kills": 9, "deaths": 1, "pose": "hip"}, {"id": 2, "name": "B", "kills": 7, "deaths": 3, "pose": "raise"}]
	var who := Podium.lineup(rows)
	_expect("the winner strikes the one they chose", who[0].pose == Podium.HIP)
	_expect("...second place still nods, whatever they chose", who[1].pose == Podium.SPORT)
	rows[0].pose = Podium.RANDOM
	_expect("random: the one the results pick", Podium.lineup(rows)[0].pose == Podium.victory(rows))
	rows[0].pose = "sport"
	_expect("...and so is anything that is not a victory pose", Podium.lineup(rows)[0].pose == Podium.victory(rows) and Podium.valid_choice("sport") == Podium.RANDOM
		and Podium.valid_choice("pump") == "pump" and Podium.valid_choice("") == Podium.RANDOM)
	var red := {"team": 0, "teams": "snd", "scores": [4, 2]}
	var team := [{"id": 1, "name": "A", "kills": 6, "pose": "present"}.merged(red), {"id": 2, "name": "B", "kills": 4, "pose": "present"}.merged(red),
		{"id": 3, "name": "C", "kills": 2}.merged(red)]
	who = Podium.lineup(team)
	_expect("a winning team: each their own choice, or one picked for them", who[0].pose == Podium.PRESENT and who[1].pose == Podium.PRESENT
		and who[2].pose == (Podium.victory(team) + 2) % Podium.VICTORIES)
	var race := [{"id": 3, "name": "A", "race": true, "finished": true, "time": 61.2, "pose": "pump"}]
	_expect("a race's winner too", Podium.lineup(race)[0].pose == Podium.PUMP)
	_expect("the four poses have names for the menu", Podium.TITLES.size() == Podium.VICTORIES)


# --- Helpers

func _fresh(gun: String) -> void:
	_drop()
	robot = RobotModel.new().build("needle", Color(1.0, 0.4, 0.2), false, gun)
	root.add_child(robot)
	animator = RobotAnimator.new(robot)
	inp = RobotAnimInput.new()
	inp.state = MovementController.State.GROUND
	inp.alive = true
	emote = Emote.new()
	animator.emote = emote


func _step() -> void:
	emote.update(STEP)
	animator.update(STEP, inp, Transform3D.IDENTITY)


## Where a bone is, in the robot's own space.
func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.skeleton.find_bone(bone)).origin


func _drop() -> void:
	if robot == null:
		return
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles otherwise
		robot.mesh.set_surface_override_material(i, null)
	robot.queue_free()
	robot = null


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
