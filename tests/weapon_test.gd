extends SceneTree
## Headless checks on the guns' numbers and ammo handling.
## Run: godot --headless --path . --script tests/weapon_test.gd
##
## Every gun in the pickers exists and is sane; the shotgun kills in one shot up close
## and not far away; the sniper kills with one headshot and two body shots; the rifle
## and pistol need several hits; magazines reload, and the shotgun's shell-by-shell
## reload can be cut short by firing. Melee weapons: never run dry, have reach and
## an arc, and the hammer shoves hard enough to slam someone into a wall; the
## swing animation always comes back to rest.

var _ok := true


func _init() -> void:
	for id in WeaponData.IDS:
		var w := WeaponData.by_id(id)
		_check(w.id == id, "%s: by_id gives the right gun" % id)
		if w.is_melee():
			_check(w.fire_interval > 0.0 and w.max_range > 1.5 and w.max_range < 4.0 and w.arc_degrees > 0.0,
				"%s: swing interval, reach and arc are sane" % id)
			_check(w.windup < w.fire_interval, "%s: the blow lands before the next swing" % id)
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
	_check(sword.damage < 100.0 and sword.damage * 2.0 >= 100.0, "sword: two hits kill")
	_check(WeaponData.by_id("hammer").knockback > 17.5, "hammer: a hit can slam someone into a wall")
	var dagger := WeaponData.by_id("dagger")
	_check(dagger.damage * dagger.backstab_multiplier >= 100.0, "dagger: a stab in the back kills")
	s = WeaponState.new(sword)
	var swings := 0
	for i in 200:
		if s.fire():
			swings += 1
		s.update(1.0 / 60.0)
	_check(swings >= 5 and swings <= 7, "sword: swings at its pace and never needs a reload (%d swings in 3.3 s)" % swings)
	s.start_reload()
	_check(not s.is_reloading(), "sword: nothing to reload")
	var anim := MeleeSwing.new()
	for id in WeaponData.MELEE:
		for count in 2:
			anim.start(id, count)
			var last := []
			for i in 120:
				last = anim.sample(1.0 / 60.0)
			_check(not anim.active() and last == [0.0, 0.0, 0.0, 0.0], "%s: swing %d ends back at rest" % [id, count])

	print("WEAPON TEST PASSED" if _ok else "WEAPON TEST FAILED")
	quit(0 if _ok else 1)


func _step(s: WeaponState, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.update(1.0 / 60.0)
		t += 1.0 / 60.0


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		print("FAIL: " + what)
