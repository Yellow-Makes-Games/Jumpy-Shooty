extends SceneTree
## Headless checks on what a shot does to whoever fires it (GunRecoil): looks only.
## Run: godot --headless --path . --script tests/gun_recoil_test.gd
##
## Every gun kicks, harder the heavier it is, and a melee weapon not at all; the kick is
## gone and the camera is back exactly where it was a moment after the last shot, however
## long the burst; the camera's kick is small and never past its limit; holding the
## trigger builds heat and letting go loses it; each akimbo gun kicks on its own shots;
## and every gun's working parts move bones the robots have, and are home again after.

const DT := 1.0 / 60.0

var _ok := true


func _init() -> void:
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	for id in WeaponData.IDS:
		var data := WeaponData.by_id(id)
		var r := GunRecoil.new(data)
		if data.is_melee():
			r.fire()
			_step(r, 0.05)
			_check(not r.busy() and r.camera() == Vector3.ZERO and r.arm_lift() == 0.0, "%s: a melee weapon has no recoil" % id)
			continue
		_check(GunRecoil.strength(data.kick) > 0.0, "%s: it kicks" % id)
		# One shot: there at once, the camera up within a few frames, everything back after.
		r.fire()
		_check(r.snap > 0.0 and r.busy(), "%s: a shot is felt at once" % id)
		var peak := 0.0
		var lift := 0.0
		for i in 12:
			_step(r, DT)
			peak = maxf(peak, r.camera().x)
			lift = maxf(lift, r.arm_lift())
		_check(peak > 0.0005 and peak <= GunRecoil.CAM_MAX, "%s: the camera kicks up, a little (%.4f)" % [id, peak])
		_check(lift > 0.0, "%s: the arms take it" % id)
		_step(r, 1.5)
		_check(not r.busy() and r.camera().length() < 0.0003 and absf(r.arm_lift()) < 0.0005 and absf(r.chest_rock()) < 0.0005,
			"%s: a second and a half later nothing is left of it (camera %.5f)" % [id, r.camera().length()])
		# The trigger held for three seconds: the camera stays inside its limit, the heat builds, and it all goes.
		var worst := 0.0
		var hot := 0.0
		var t := 0.0
		var next := 0.0
		while t < 3.0:
			if t >= next:
				r.fire(false)
				next += maxf(data.shot_gap(), 0.03)
			_step(r, DT)
			t += DT
			worst = maxf(worst, r.camera().length())
			hot = maxf(hot, r.heat)
		_check(worst <= GunRecoil.CAM_MAX + 0.00001, "%s: however fast it fires the camera stays inside its limit (%.4f)" % [id, worst])
		if data.shot_gap() <= 0.12:
			_check(hot > 0.8, "%s: holding the trigger heats it (%.2f)" % [id, hot])
		elif data.shot_gap() >= GunRecoil.HEAT_GAP:
			_check(hot == 0.0, "%s: a slow gun never heats (%.2f)" % [id, hot])
		# Its working parts: bones the robots have, moved by the shots, home again afterwards.
		var pose := rig.new_pose()
		var rest := rig.new_pose()
		r.fire()
		_step(r, 2.0 * DT)
		r.pose_parts(pose, rig.bones)
		var moved := false
		for b in pose.rot.size():
			moved = moved or not pose.pos[b].is_equal_approx(rest.pos[b]) or not pose.rot[b].is_equal_approx(rest.rot[b])
		_step(r, 2.0)
		_check(not r.busy() and r.heat == 0.0 and r.camera().length() < 0.0003, "%s: and two seconds after the burst it is all gone" % id)
		for part in GunRecoil.PARTS.get(WeaponData.look_of(id), []):
			_check(rig.bones.has("pistol_" + str(part[0])), "%s: its %s is a bone the robots have" % [id, part[0]])
		_check(moved == GunRecoil.PARTS.has(WeaponData.look_of(id)), "%s: its working parts move with the shot (where it has any)" % id)
		_step(r, 1.0)
		pose.copy(rest)
		r.pose_parts(pose, rig.bones)
		var home := true
		for b in pose.rot.size():
			if rig.bone_names[b].begins_with("pistol") and WeaponData.look_of(id) != "minigun":   # (its barrels stop wherever they stop)
				home = home and pose.pos[b].is_equal_approx(rest.pos[b]) and pose.rot[b].is_equal_approx(rest.rot[b])
		_check(home, "%s: and are home again afterwards" % id)
	# Heavier guns kick harder, but not without end.
	_check(GunRecoil.strength(4.0) > GunRecoil.strength(2.0) and GunRecoil.strength(2.0) > GunRecoil.strength(0.5)
		and GunRecoil.strength(4.0) < 2.0 * GunRecoil.strength(2.0), "a heavier gun kicks harder, the heaviest not twice as hard again")
	# Akimbo: each gun kicks on its own shots.
	var two := GunRecoil.new(WeaponData.by_id("akimbo"))
	two.fire(true)
	_check(two.snap_l > 0.0 and two.snap == 0.0 and two.arm_lift(true) > 0.0 and two.arm_lift(false) == 0.0, "akimbo: a left-hand shot kicks the left gun only")
	two.stop()
	two.fire(false)
	_check(two.snap > 0.0 and two.snap_l == 0.0 and two.hand_snap(false) > 0.0 and two.hand_snap(true) == 0.0, "akimbo: a right-hand shot kicks the right gun only")
	# The same shots give the same kick (a killcam shows what the shooter saw).
	var a := GunRecoil.new(WeaponData.by_id("rifle"))
	var b2 := GunRecoil.new(WeaponData.by_id("rifle"))
	for i in 40:
		if i % 6 == 0:
			a.fire()
			b2.fire()
		_step(a, DT)
		_step(b2, DT)
	_check(a.camera().is_equal_approx(b2.camera()) and is_equal_approx(a.rock, b2.rock) and a.view() == b2.view(), "the same shots give the same kick, every time")
	print("GUN RECOIL TEST PASSED" if _ok else "GUN RECOIL TEST FAILED")
	quit(0 if _ok else 1)


func _step(r: GunRecoil, seconds: float) -> void:
	var left := seconds
	while left > 0.00001:
		r.update(minf(left, DT))
		left -= DT


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		print("FAIL: " + what)
