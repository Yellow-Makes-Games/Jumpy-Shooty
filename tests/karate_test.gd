extends SceneTree
## Headless checks on Karate's full wind-ups (2026-11-21).
## Run: godot --headless --path . --script tests/karate_test.gd
##
## Four heavy blows on the ground and three in the air; every one in a pool lands at the
## same moment with the same hop (only the look differs); which one it is travels in the
## animation flags untouched by the rest of them; a picked blow is the one the swing plays;
## and a player never gets the same one twice running.

var _ok := true


func _init() -> void:
	var sizes := MeleeSwing.pool_sizes("karate")
	_check(sizes == Vector2i(4, 3), "Karate picks from 4 ground and 3 mid-air wind-ups (got %s)" % sizes)
	_check(MeleeSwing.pool_sizes("sword") == Vector2i(1, 1), "a blade has one of each")
	var land := MeleeSwing.impact_time("karate", 0, 1.0, false, 0)
	var length := MeleeSwing.blow_length("karate", 0, 1.0, false, 0)
	for g in sizes.x:
		var pick := MeleeSwing.pick_of(g, 0)
		_check(is_equal_approx(MeleeSwing.impact_time("karate", 0, 1.0, false, pick), land), "ground move %d lands with the tornado kick" % g)
		_check(is_equal_approx(MeleeSwing.blow_length("karate", 0, 1.0, false, pick), length), "ground move %d is as long" % g)
		_check(is_equal_approx(float(MeleeSwing.blow_of("karate", 0, 1.0, false, pick).get("hop", 0.0)), 4.5), "ground move %d hops the same" % g)
	var air_land := MeleeSwing.impact_time("karate", 0, 1.0, true, 0)
	for a in sizes.y:
		var pick := MeleeSwing.pick_of(0, a)
		_check(is_equal_approx(MeleeSwing.impact_time("karate", 0, 1.0, true, pick), air_land), "air move %d lands with the helicopter kick" % a)
	# The pick survives the flags whatever else is packed in them.
	for g in 4:
		for a in 3:
			var pick := MeleeSwing.pick_of(g, a)
			var f := RobotAnimInput.make_flags(true, true, true, 3, 3, 3, 3, true, 3, true, true, 5, true, 3, pick) | RobotAnimInput.ZOOMED_BIT
			_check(RobotAnimInput.pick_of(f) == pick and RobotAnimInput.step_of(f) == 5 and RobotAnimInput.zoomed_of(f), "pick %d,%d travels in the flags" % [g, a])
	# The swing plays the move it was given.
	var s := MeleeSwing.new("karate")
	s.wind(1.0, 0, false, MeleeSwing.pick_of(3, 0))
	s.sample(0.016)
	s.swing(1.0, 0, false, MeleeSwing.pick_of(3, 0))
	_check(s.open_hands() and s.burst(), "pick 3 on the ground is the palm blast")
	s.stop()
	s.swing(1.0, 0, false, MeleeSwing.pick_of(1, 0))
	_check(s.kicking() == "knee_r", "pick 1 on the ground is the flying knee")
	# Never the same move twice running.
	for last in 4:
		for i in 40:
			var p: int = MeleeSwing.pick_new(4, last)
			_check(p != last and p >= 0 and p < 4, "a new pick is never the last one (%d after %d)" % [p, last])
	if _ok:
		print("KARATE TEST PASSED")
	quit(0 if _ok else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_ok = false
		print("FAIL " + what)
