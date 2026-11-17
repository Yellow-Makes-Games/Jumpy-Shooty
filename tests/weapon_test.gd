extends SceneTree
## Headless checks on the guns' numbers and ammo handling.
## Run: godot --headless --path . --script tests/weapon_test.gd
##
## Every gun in the pickers exists and is sane; the shotgun kills in one shot up close
## and not far away; the sniper kills with one headshot and two body shots; the rifle
## and pistol need several hits; magazines reload, and the shotgun's shell-by-shell
## reload can be cut short by firing. Melee weapons: never run dry, have reach and
## an arc; every swing is charged (a tap is weak and cannot slam anyone into a wall, a
## full wind-up hits harder and shoves far harder, but never kills outright: the
## hammer and the bat kill by the wall they send you into); all but the dagger and
## the knuckles are two-handed, and the left hand stays on the handle through the
## whole wind-up and swing; the swing always comes back to the ready pose.

## Match's wall-slam rules (it is an autoload, not loaded in this test).
const SLAM_SPEED := 17.5
const SLAM_DAMAGE := 4.0
const SLAM_MAX := 80.0

var _ok := true


func _init() -> void:
	for id in WeaponData.IDS:
		var w := WeaponData.by_id(id)
		_check(w.id == id, "%s: by_id gives the right gun" % id)
		if w.is_melee():
			_check(w.fire_interval > 0.0 and w.max_range > 1.5 and w.max_range < 4.5 and w.arc_degrees > 0.0,
				"%s: swing interval, reach and arc are sane" % id)
			_check(w.windup < w.charge_time and w.windup < w.fire_interval, "%s: a tap is quicker than a full wind-up" % id)
			_check(w.charge_damage >= w.damage * 2.0, "%s: a full wind-up does much more damage than a tap" % id)
			_check(w.charge_knockback >= w.knockback * 3.0, "%s: a full wind-up shoves much harder than a tap" % id)
			_check(w.melee_damage(0.0) == w.damage and w.melee_damage(1.0) == w.charge_damage and w.melee_damage(0.5) > w.damage \
				and w.melee_damage(7.0) == w.charge_damage, "%s: damage grows with the wind-up, up to full" % id)
			_check(w.melee_knockback(0.0)[0] == w.knockback and w.melee_knockback(1.0)[0] == w.charge_knockback \
				and w.melee_knockback(0.5)[0] < (w.knockback + w.charge_knockback) * 0.5, "%s: the shove grows with the wind-up, most at the end" % id)
			_check(w.damage <= 20.0 and w.knockback < SLAM_SPEED * 0.5, "%s: a tap is weak and slams nobody into a wall" % id)
			_check(w.charge_damage * w.backstab_multiplier < 100.0, "%s: no blow kills a healthy player outright" % id)
			_check(w.charge_of(0.0) == 0.0 and w.charge_of(w.charge_time) == 1.0 and w.charge_of(99.0) == 1.0, "%s: wound up after charge_time" % id)
			_check(w.two_handed == (id not in ["dagger", "brass_knuckles"]), "%s: two-handed unless it cannot be" % id)
		else:
			_check(w.magazine > 0 and w.fire_interval > 0.0 and w.reload_time > 0.0 and w.pellets > 0,
				"%s: magazine, fire interval, reload and pellets are positive" % id)
		_check(w.knockback > 0.0, "%s: hits shove" % id)
		_check(w.blurb != "" and w.short_name != "", "%s: has a name and a line for the picker" % id)
		_check(w.damage_at(0.0) == w.damage, "%s: full damage point blank" % id)
		_check(w.damage_at(1000.0) <= w.damage, "%s: no more damage far away" % id)
	_check(WeaponData.valid("bazooka") == "pistol", "unknown guns fall back to the pistol")

	var shotgun := WeaponData.by_id("shotgun")
	_check(shotgun.damage_at(5.0) * shotgun.pellets >= 100.0, "shotgun: every pellet at 5 m kills")
	_check(shotgun.damage_at(30.0) * shotgun.pellets < 50.0, "shotgun: weak at 30 m")
	_check(shotgun.damage_at(15.0) < shotgun.damage_at(9.0) and shotgun.damage_at(15.0) > shotgun.damage_at(22.0),
		"shotgun: damage falls off between 9 and 22 m")

	var sniper := WeaponData.by_id("sniper")
	_check(sniper.damage * sniper.headshot_multiplier >= 100.0, "sniper: a headshot kills")
	_check(sniper.damage < 100.0 and sniper.damage * 2.0 >= 100.0, "sniper: two body shots kill, one does not")
	_check(sniper.spread_degrees == 0.0, "sniper: no wobble")

	var rifle := WeaponData.by_id("rifle")
	_check(rifle.automatic and rifle.magazine == 30, "rifle: automatic, 30 rounds")
	_check(rifle.damage * rifle.headshot_multiplier < 100.0, "rifle: no one-shot kills")

	# Whole-magazine reload: empty the rifle, then wait out the reload.
	var s := WeaponState.new(rifle)
	var shots := 0
	for i in 100:
		if s.fire():
			shots += 1
		s.update(rifle.fire_interval)
		if s.is_reloading():
			break
	_check(shots == 30 and s.is_reloading(), "rifle: 30 shots, then reloads by itself")
	_check(not s.can_fire(), "rifle: cannot fire while reloading")
	_step(s, rifle.reload_time + 0.05)
	_check(s.ammo == 30 and not s.is_reloading(), "rifle: full after one reload")

	# Shell-by-shell: two shots, reload one shell, fire again mid-reload.
	s = WeaponState.new(shotgun)
	s.fire()
	_step(s, shotgun.fire_interval)
	s.fire()
	_step(s, shotgun.fire_interval)
	_check(s.ammo == 4, "shotgun: two shells used")
	s.start_reload()
	_step(s, shotgun.reload_time + 0.05)
	_check(s.ammo == 5 and s.is_reloading(), "shotgun: one shell in, still loading")
	_check(s.reload_progress() > 5.0 / 6.0 - 0.01 and s.reload_progress() < 1.0, "shotgun: progress is how full it is")
	_check(s.can_fire(), "shotgun: can fire between shells")
	_check(s.fire() and not s.is_reloading() and s.ammo == 4, "shotgun: firing stops the reload")
	s.start_reload()
	_step(s, shotgun.reload_time * 2.0 + 0.1)
	_check(s.ammo == 6 and not s.is_reloading(), "shotgun: stops loading when full")

	_check(WeaponData.IDS.size() == WeaponData.GUNS.size() + WeaponData.MELEE.size(), "every weapon is a gun or melee")
	var sword := WeaponData.by_id("sword")
	var hammer := WeaponData.by_id("hammer")
	_check(sword.display_name == "Longsword" and sword.two_handed and absf(sword.max_range - hammer.max_range) <= 0.3,
		"sword: a two-handed longsword with the hammer's kind of reach")
	_check(sword.charge_damage * 2.0 >= 100.0, "sword: two full swings kill")
	for id in ["hammer", "bat"]:
		var w := WeaponData.by_id(id)
		_check(w.charge_damage + minf((w.charge_knockback - SLAM_SPEED) * SLAM_DAMAGE, SLAM_MAX) >= 100.0,
			"%s: a full swing into a wall kills" % id)
	for id in WeaponData.MELEE:
		if WeaponData.by_id(id).two_handed:
			_check(WeaponData.by_id(id).charge_knockback > SLAM_SPEED, "%s: a full swing can slam someone into a wall" % id)
	var dagger := WeaponData.by_id("dagger")
	_check(dagger.backstab_multiplier > 1.0, "dagger: a stab in the back does more")
	s = WeaponState.new(sword)
	var swings := 0
	for i in 200:
		if s.fire():
			swings += 1
		s.update(1.0 / 60.0)
	_check(swings >= 5 and swings <= 7, "sword: swings at its pace and never needs a reload (%d swings in 3.3 s)" % swings)
	s.start_reload()
	_check(not s.is_reloading(), "sword: nothing to reload")
	_melee_animation()

	print("WEAPON TEST PASSED" if _ok else "WEAPON TEST FAILED")
	quit(0 if _ok else 1)


## The wind-up and swing of every melee weapon, on a real robot skeleton: the body
## coils as the swing is held, the blow starts from there and ends back at ready, a
## tap from each side and the heavy blow of a full wind-up, and a two-handed weapon
## has the left hand on its handle the whole way.
func _melee_animation() -> void:
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var dt := 1.0 / 60.0
	for id in WeaponData.MELEE:
		var w := WeaponData.by_id(id)
		var moves := MeleeSwing.moves(id)
		_check((moves.taps as Array).size() == 2 and moves.has("heavy") and MeleeSwing.PACE.has(id), "%s: has its own taps and heavy blow" % id)
		_check(MeleeSwing.impact_time(id) < 0.2, "%s: the blow lands straight after letting go" % id)
		for first_person in [false, true]:
			for blow in [[0.0, 0], [0.0, 1], [1.0, 0], [1.0, 1]]:
				var power: float = blow[0]
				var side: int = blow[1]
				var what := "%s%s %s" % [id, " (first person)" if first_person else "", "full swing" if power == 1.0 else ["tap from the right", "tap from the left"][side]]
				var anim := MeleeSwing.new(id, first_person)
				var worst := 0.0
				var held := 0.0
				# Hold: a tap's worth, or all the way.
				while held < (w.windup if power == 0.0 else w.charge_time + 0.4):
					held += dt
					anim.wind(w.charge_of(held), side)
					worst = maxf(worst, _left_hand_gap(rig, anim.sample(dt), anim.two_handed))
				var coiled := anim.coil()
				_check(anim.winding(), "%s: holding winds the swing up" % what)
				if power == 1.0:
					_check(coiled < -0.95, "%s: fully wound, the weapon is drawn right back (%.2f)" % [what, coiled])
					_check(anim.glow() > 2.0, "%s: and its glow has built up (%.2f)" % [what, anim.glow()])
				else:
					_check(coiled < -0.05 and coiled > -0.7, "%s: a tap only draws back a little (%.2f)" % [what, coiled])
				anim.swing(power, side)
				_check(anim.heavy() == (power >= MeleeSwing.HEAVY_AT), "%s: %s the heavy blow" % [what, "is" if power == 1.0 else "is not"])
				var cut := false
				var flared := 0.0
				var t := 0.0
				var last := []
				while t < anim.length() + 0.6:
					t += dt
					cut = cut or anim.cutting()
					flared = maxf(flared, anim.glow())
					last = anim.sample(dt)
					worst = maxf(worst, _left_hand_gap(rig, last, anim.two_handed))
				var ready: Array = MeleeSwing.new(id, first_person).sample(0.0)
				_check(cut and not anim.active() and (last[MeleeSwing.GRIP] as Vector3).distance_to(ready[MeleeSwing.GRIP]) < 0.005 \
					and (last[MeleeSwing.BLADE] as Vector3).angle_to(ready[MeleeSwing.BLADE]) < 0.02,
					"%s: cuts and ends back at ready" % what)
				_check(flared > 2.0 and is_equal_approx(anim.glow(), 1.0), "%s: the glow flares with the blow and settles (%.2f)" % [what, flared])
				if w.two_handed:
					_check(worst < 0.01, "%s: the left hand stays on the handle (%.3f m off at worst)" % [what, worst])
	_check(is_equal_approx(MeleeSwing.hit_stop_time(0.0), 0.05) and is_equal_approx(MeleeSwing.hit_stop_time(1.0), 0.12),
		"a blow that lands freezes for 0.05 s (a tap) to 0.12 s (a full wind-up)")
	# The longsword's taps take turns: one sweeps left, the next right; its heavy blow comes down.
	var sword := MeleeSwing.new("sword")
	sword.swing(0.0, 0)
	var from_right := sword.travel()
	sword.swing(0.0, 1)
	var from_left := sword.travel()
	sword.swing(1.0, 0)
	_check(from_right.x < -0.5 and from_left.x > 0.5, "sword: taps take turns, from the right then from the left")
	_check(sword.travel().y < -0.4 and sword.travel().x < -0.4, "sword: the heavy blow cuts down and across")


## Poses a skeleton to hold the weapon as key `k` says, and measures how far the left
## palm is from where it should be on the handle (0 for a one-handed weapon).
func _left_hand_gap(rig: RobotRig, k: Array, two_handed: bool) -> float:
	if not two_handed:
		return 0.0
	var pose := rig.new_pose()
	MeleeSwing.turn_body(pose, rig.bones, k)
	MeleeSwing.hold(pose, rig, k, true)
	var grip := _bone(rig, pose, "pistol")
	var hand := _bone(rig, pose, "hand_l")
	var blade := (grip.basis * MeleeModel.HOLD * Vector3.UP).normalized()
	var palm := hand * rig.rest_pos[rig.bones["pistol"]]
	return palm.distance_to(grip.origin + blade * float(k[MeleeSwing.LEFT]))


## Where a bone is in the model's space, in `pose`.
func _bone(rig: RobotRig, pose: RobotPose, bone: String) -> Transform3D:
	var chains := {"pistol": ["root", "hips", "spine", "chest", "upper_arm_r", "forearm_r", "hand_r", "pistol"],
		"hand_l": ["root", "hips", "spine", "chest", "upper_arm_l", "forearm_l", "hand_l"]}
	var t := Transform3D.IDENTITY
	for b in chains[bone]:
		var i: int = rig.bones[b]
		t = t * Transform3D(Basis(pose.rot[i]), pose.pos[i])
	return t


func _step(s: WeaponState, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.update(1.0 / 60.0)
		t += 1.0 / 60.0


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		print("FAIL: " + what)
