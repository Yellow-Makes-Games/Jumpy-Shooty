extends SceneTree
## Headless checks on taking weapons out and putting them away (WeaponDraw,
## StowedWeapon): looks only.
## Run: godot --headless --path . --script tests/weapon_draw_test.gd
##
## Every weapon has a draw and a flourish of its own; a draw starts away from the hold,
## ends exactly on it and leaves nothing behind (the arms, the view, the weapon's bones,
## its glow, its size); a shot cuts it short at once; its beats use bones the robots have
## and sounds the game has. Every weapon has a place on the body, two carried weapons
## never share one, and a body wearing something on its back slings long ones at its side.

const DT := 1.0 / 60.0

var _ok := true


func _init() -> void:
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var looks := {}
	for id in WeaponData.IDS:
		var look := WeaponData.look_of(id)
		looks[look] = true
		_check(WeaponDraw.FLOURISH.has(look), "%s: it has a flourish of its own" % id)
		_check(WeaponDraw.KINDS.has(WeaponDraw.kind_of(id)), "%s: it has a draw" % id)
		var d := WeaponDraw.new()
		_check(not d.active() and d.come() == 0.0 and d.glow() == 1.0 and d.grown() == 1.0, "%s: nothing shows before it is taken out" % id)
		d.start(id)
		_check(d.active() and is_equal_approx(d.come(), 1.0), "%s: it starts away from the hold" % id)
		_check(d.glow() < 0.05, "%s: it comes out dark" % id)
		var view: Array = d.view()
		_check((view[0] as Vector3).length() > 0.1, "%s: your own arms bring it in from somewhere (%.2f m)" % [id, (view[0] as Vector3).length()])
		_check(absf(d.lift()) > 0.3, "%s: the body's arms swing it in (%.2f)" % [id, d.lift()])
		# Stepped to its end: the weapon's bones moved on the way (if it has beats that move them) and are home after.
		var rest := rig.new_pose()
		var pose := rig.new_pose()
		var moved := false
		var cues := []
		var seconds := 0.0
		while d.active() and seconds < 3.0:
			d.update(DT)
			seconds += DT
			cues.append_array(d.cues())
			pose.copy(rest)
			d.pose_weapon(pose, rig.bones)
			for b in pose.rot.size():
				if not pose.pos[b].is_equal_approx(rest.pos[b]) or not pose.rot[b].is_equal_approx(rest.rot[b]):
					moved = true
					_check(rig.bone_names[b].begins_with("pistol"), "%s: the flourish moves only the weapon's own bones (not %s)" % [id, rig.bone_names[b]])
		_check(seconds < 1.5, "%s: it is over in a moment (%.2f s)" % [id, seconds])
		var moves := false
		for beat in WeaponDraw.FLOURISH[look].beats:
			moves = moves or str(beat[0]) in ["spin", "unspin", "toss", "nod", "part", "shut", "whirl"]
			if str(beat[0]) == "cue":
				_check(SfxList.VOLUME.has(str(beat[2])), "%s: its sound %s is one the game has" % [id, beat[2]])
			if str(beat[0]) in ["part", "shut"]:
				var part: Array = beat[2] if str(beat[0]) == "part" else beat[3]
				_check(rig.bones.has("pistol_" + str(part[0])), "%s: its %s is a bone the robots have" % [id, part[0]])
			if str(beat[0]) == "whirl":
				_check(rig.bones.has("pistol_" + str(beat[3])), "%s: its %s is a bone the robots have" % [id, beat[3]])
		_check(moved == moves, "%s: the weapon does its flourish in the hand (where it has one)" % id)
		for cue in cues:
			_check(SfxList.VOLUME.has(str(cue)), "%s: the sound %s is one the game has" % [id, cue])
		_check(id == "karate" or "power_on" in cues, "%s: it hums as its lights come on" % id)
		pose.copy(rest)
		d.pose_weapon(pose, rig.bones)
		var home := true
		for b in pose.rot.size():
			home = home and pose.pos[b].is_equal_approx(rest.pos[b]) and pose.rot[b].is_equal_approx(rest.rot[b])
		view = d.view()
		_check(home and d.come() == 0.0 and d.lift() == 0.0 and d.turn() == 0.0 and d.jolt() == 0.0 and d.glow() == 1.0 and d.grown() == 1.0
			and (view[0] as Vector3).is_zero_approx() and (view[1] as Vector3).is_zero_approx(), "%s: and nothing of it is left afterwards" % id)
		# A shot a moment in: it is over at once.
		d.start(id)
		d.update(0.1)
		d.cut()
		_check(not d.active() and d.was_cut() and d.come() == 0.0 and d.glow() == 1.0, "%s: a shot cuts it short at once" % id)
		d.update(DT)
		_check(d.cues().is_empty() and not d.clip_due(), "%s: and nothing more of it plays" % id)
	for look in WeaponDraw.FLOURISH:
		_check(looks.has(look), "%s: every flourish is some weapon's" % look)

	# Where each is carried.
	_check(WeaponDraw.carried("pistol") == "thigh" and WeaponDraw.carried("rifle") == "back" and WeaponDraw.carried("rocket_launcher") == "back"
		and WeaponDraw.carried("sword") == "back" and WeaponDraw.carried("dagger") == "thigh" and WeaponDraw.carried("claws") == "belt"
		and WeaponDraw.carried("karate") == "none" and WeaponDraw.carried("none") == "none", "sidearms and small blades on the thigh, long ones on the back, fists on the belt")
	_check(WeaponDraw.kind_of("rocket_launcher") == "heavy" and WeaponDraw.kind_of("minigun") == "heavy" and WeaponDraw.kind_of("rifle") == "back", "the big ones are heaved off the back")

	# Put away on a body.
	var color := Color(0.9, 0.3, 0.2)
	var body := RobotModel.new().build(Characters.default_id(), color, false, "pistol")
	for id in WeaponData.IDS:
		var one := StowedWeapon.put_on(body, [id], color, Characters.default_id())
		_check(one.size() == (0 if id == "karate" else 1), "%s: it has a place on the body (or, bare hands, none)" % id)
		for key in one:
			var prop := one[key] as StowedWeapon
			_check(prop.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s: put away, it is there to see" % id)
			_check(prop.position.length() < 0.9 and prop.get_parent() is BoneAttachment3D, "%s: it rides on the body, by one of its bones (%s)" % [id, prop.position])
			prop.get_parent().free()
	for pair in [["rifle", "shotgun"], ["pistol", "revolver"], ["sword", "rifle"], ["brass_knuckles", "claws"], ["pistol", "rifle"]]:
		var two := StowedWeapon.put_on(body, pair, color, Characters.default_id())
		_check(two.size() == 2 and (two[pair[0]] as StowedWeapon).place != (two[pair[1]] as StowedWeapon).place,
			"%s and %s: carried together, each has its own place" % pair)
		for key in two:
			(two[key] as StowedWeapon).get_parent().free()
	body.free()
	# Something worn on the back: long weapons go to the side.
	var caped := CustomCharacter.new()
	caped.accessories["back"] = "cape"
	_check(StowedWeapon.wears_on_back(caped.to_id()) and not StowedWeapon.wears_on_back(Characters.default_id()), "a cape is something on the back; a plain robot has nothing there")
	_check(StowedWeapon.place_for("rifle", caped.to_id()) == "sling" and StowedWeapon.place_for("rifle", Characters.default_id()) == "back"
		and StowedWeapon.place_for("pistol", caped.to_id()) == "thigh", "with a cape on, a long gun is slung at the side and a sidearm stays on the thigh")

	# Put away mid-match, it flies from the hand; let go for good, it breaks up and is gone.
	var holder := Node3D.new()
	root.add_child(holder)
	var gone := StowedWeapon.break_up(holder, "rifle", color, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	_check(gone != null and gone.get_parent() == holder, "a weapon let go breaks up where it was")
	_check(StowedWeapon.break_up(holder, "karate", color, Transform3D.IDENTITY) == null and StowedWeapon.break_up(holder, "none", color, Transform3D.IDENTITY) == null,
		"bare hands leave nothing behind")
	for i in int(StowedWeapon.BREAK_UP / DT) + 3:
		gone._process(DT)
	_check(gone.is_queued_for_deletion(), "and is gone %.1f s later" % StowedWeapon.BREAK_UP)
	holder.free()
	print("WEAPON DRAW TEST PASSED" if _ok else "WEAPON DRAW TEST FAILED")
	quit(0 if _ok else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		print("FAIL: " + what)
