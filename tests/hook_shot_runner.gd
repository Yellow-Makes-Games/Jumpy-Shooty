extends Node
## The body of tests/hook_shot_test.gd (a separate file: it uses the game's autoloads).

const STEP := 1.0 / 120.0   # the game's physics step

var _ok := true
var _me: Player
var _log: Array = []   # one shot, every physics step: [clock, look, packed, chest, hand]
var _shot: HookLine    # that shot's record, once it is over


func run() -> void:
	Settings.mobility = Mobility.GRAPPLE2   # (not saved: the test never calls save_settings)
	Game.start_practice("testing_grounds")
	await _frames(30)
	var arena = Net.arena
	_me = arena.local_player
	var me := _me
	_check(Mobility.has(Mobility.GRAPPLE2) and Mobility.name_of(Mobility.GRAPPLE2) == "Grappling Hook 2", "Grappling Hook 2 is a mobility tool")
	_check(Mobility.IDS.has(Mobility.GRAPPLE) and Mobility.default_id() == Mobility.GRAPPLE, "the first grappling hook is still there, and still the default")
	_check(me.mobility == Mobility.GRAPPLE2 and me.motor.grapple is HookShot, "you have the Grappling Hook 2 you picked")
	_check(Net.player_mobility(Net.my_id()) == Mobility.GRAPPLE2, "the lobby has it on record")
	var g := me.motor.grapple as HookShot
	var range_m: float = me.motor.tuning.grapple_range

	# --- A shot at a wall: flight, bite, the slack coming in, then the pull.
	var spot := _wall_spot(me, 14.0, 34.0)
	_check(not spot.is_empty(), "found a wall 14 to 34 m away to shoot at")
	if spot.is_empty():
		_finish()
		return
	var dist: float = spot[2]
	me.teleport(spot[0], 0.0)
	await _physics(30)
	_aim(me, spot[1])
	var start := me.global_position
	_hold(true)
	for i in 4:   # (the press is read on the next step)
		await _physics(1)
		_record(me, g)
		if g.flying:
			break
	var t0 := g.line.t_launch
	_check(g.flying and not g.attached and g.busy(), "firing sends the hook out: nothing is hooked at once")
	_check(me.velocity.length() < 0.5 and me.motor.state != MovementController.State.GRAPPLE, "nothing pulls while it flies (%.2f m/s)" % me.velocity.length())
	_check(me._hook_look.size() == 5 and int(me._hook_look[0]) == HookLine.FLYING or me._hook_look.is_empty(), "the hook is drawn in flight")
	var eye := me.eye_position()
	var bite_at := -1.0
	var taut_at := -1.0
	var slack_seen := 0.0
	var longest_spare := 0.0
	var pts := PackedVector3Array()
	pts.resize(HookRope.SEGMENTS + 1)
	var mid_flight := Vector3.INF
	for i in 200:
		await _physics(1)
		_record(me, g)
		var look := g.line.look(g.clock, me.rope_origin(), g.rope_origin(me))
		if g.flying:
			if i == 12:
				mid_flight = g.rope_end()
			_check(me.velocity.length() < 0.5, "still nothing pulls in flight") if i == 5 else null
		if look.size() == 5 and float(look[2]) > 0.0:
			HookRope.curve(me.rope_origin(), look[1], look[2], look[3], look[4], pts)
			longest_spare = maxf(longest_spare, HookRope.length_of(pts) - me.rope_origin().distance_to(look[1]))
		if g.biting and bite_at < 0.0:
			bite_at = g.line.t_stop - t0
			slack_seen = float(look[2])
			_check(not g.attached and int(look[0]) == HookLine.BITING, "the hook bites, and the rope is still slack")
			_check(me.velocity.length() < 0.5, "...so nothing pulls yet (%.2f m/s)" % me.velocity.length())
		if g.attached:
			if bite_at < 0.0:
				bite_at = g.line.t_stop - t0
			taut_at = g.clock - t0
			break
	_check(mid_flight != Vector3.INF and absf((mid_flight - eye).normalized().dot(spot[1]) - 1.0) < 0.001,
		"the hook flies straight along the aim")
	_check(bite_at > 0.0, "the hook reaches the wall")
	var flight := (dist - 0.2) / HookLine.SPEED
	_check(absf(bite_at - flight) < 0.03, "a wall %.1f m away takes the hook %.2f s to reach (%.3f s)" % [dist, flight, bite_at])
	_check(slack_seen > 0.5, "there is slack in the rope when it bites (%.2f m)" % slack_seen)
	_check(longest_spare > 0.5, "the rope drawn is longer than the straight line while it is slack (%.2f m more)" % longest_spare)
	_check(taut_at > bite_at + 0.03 and taut_at < bite_at + 0.3, "the winch takes the slack in, then the rope pulls tight (%.3f s after the bite)" % (taut_at - bite_at))
	var toward := (g.anchor - g.rope_origin(me)).normalized()
	await _physics(1)
	_record(me, g)
	_check(me.velocity.dot(toward) > me.motor.tuning.grapple_yank, "pulling tight yanks you toward the hook, harder than the first hook's (%.1f m/s)" % me.velocity.dot(toward))
	_check(g.anchor.distance_to(eye + spot[1] * dist) < 1.0, "it is hooked where you aimed (%.2f m off)" % g.anchor.distance_to(eye + spot[1] * dist))
	var tight := g.line.look(g.clock, me.rope_origin(), g.rope_origin(me))
	_check(int(tight[0]) == HookLine.TAUT and float(tight[2]) == 0.0 and float(tight[4]) >= 0.0, "the rope is drawn tight, and twanging")
	for i in 40:
		await _physics(1)
		_record(me, g)
	HookRope.curve(me.rope_origin(), g.anchor, 0.0, 1.0, 0.6, pts)
	_check(HookRope.length_of(pts) - me.rope_origin().distance_to(g.anchor) < 0.01, "once the twang dies away the rope is a straight line")
	_check(me.motor.state == MovementController.State.GRAPPLE and me.global_position.distance_to(start) > 1.5,
		"then it pulls you in like the first grappling hook (%.1f m so far)" % me.global_position.distance_to(start))
	var frame := me.shown_state()
	_check(frame.size() > 12 and frame[12] != null and (frame[12] as Array).size() == 4 and bool(frame[6]),
		"the killcam's frame holds the rope as it was drawn")
	_hold(false)
	await _physics(2)
	_record(me, g)
	_check(not g.attached and g.cooldown_left > 0.0, "letting go lets go, and the cooldown starts")
	var back := g.line.look(g.clock, me.rope_origin(), g.rope_origin(me))
	_check(back.size() == 5 and int(back[0]) == HookLine.RETRACT, "the hook whips back")
	for i in int(HookLine.RETRACT_TIME / STEP) + 3:
		await _physics(1)
		_record(me, g)
	_check(g.line.look(g.clock, me.rope_origin(), g.rope_origin(me)).is_empty(), "...and is gone in %.1f s" % HookLine.RETRACT_TIME)
	await _frames(3)
	_check(me.shown_state()[12] == null and not bool(me.shown_state()[6]), "the killcam's frame has no rope once it is gone")

	_shot = g.line
	_check_network()
	_check_replay()

	# --- A miss: at the sky.
	await get_tree().create_timer(me.motor.tuning.grapple_cooldown + 0.1).timeout
	me.teleport(spot[0], 0.0)
	await _physics(20)
	_aim(me, Vector3(0.05, 1.0, 0.05).normalized())
	var clear := me.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(me.eye_position(), me.eye_position() + Vector3(0.05, 1.0, 0.05).normalized() * (range_m + 2.0), 1)).is_empty()
	_hold(true)
	await _physics(1)
	var fired := g.clock
	var ever := false
	var out_for := 0.0
	for i in 200:
		await _physics(1)
		ever = ever or g.attached or g.biting
		if not g.flying:
			out_for = g.clock - fired
			break
	_hold(false)
	if clear:
		_check(not ever and absf(out_for - range_m / HookLine.SPEED) < 0.03, "shot at the sky it flies its %d m of rope, catches nothing (%.2f s)" % [int(range_m), out_for])
		_check(g.cooldown_left > 0.0 and not g.ready_to_fire(), "...and the cooldown starts")
	await _physics(2)

	# --- Called back in flight.
	await get_tree().create_timer(me.motor.tuning.grapple_cooldown + 0.1).timeout
	me.teleport(spot[0], 0.0)
	await _physics(20)
	_aim(me, spot[1])
	_hold(true)
	await _physics(4)
	_check(g.flying, "fired again")
	_hold(false)
	await _physics(2)
	_check(not g.flying and not g.biting and not g.attached, "letting go while it flies calls the hook back")
	await _physics(int(dist / HookLine.SPEED / STEP) + 30)
	_check(not g.attached and me.global_position.distance_to(spot[0]) < 0.5, "...and it never catches")

	# --- Hooking a player: the hook flies to them, bites, pulls tight, and they are reeled in.
	await get_tree().create_timer(me.motor.tuning.grapple_cooldown + 0.1).timeout
	var open := _open_spot(me, 16.0)
	_check(not open.is_empty(), "found an open stretch of floor")
	if not open.is_empty():
		Cheats.freeze_bots = true
		var id: int = Net.add_bot(BotDifficulty.EXPERT, "", Mobility.GRAPPLE2)
		await _frames(10)
		var bot: Player = arena.get_player(id)
		_check(bot != null and bot.motor.grapple is HookShot, "a bot can carry Grappling Hook 2")
		var feet: Vector3 = open[0]
		var along: Vector3 = open[2]
		me.teleport(feet, open[1])
		bot.teleport(feet + along * 14.0, 0.0)
		await _physics(30)
		_aim(me, (Grapple.target_point(bot) - me.eye_position()).normalized())
		_hold(true)
		var caught := false
		var was_biting := false
		for i in 120:
			await _physics(1)
			was_biting = was_biting or (g.biting and g.target == bot)
			if g.hooked_player():
				caught = true
				break
		_check(was_biting, "the hook bites a player in its way")
		_check(caught and g.target == bot, "then the rope pulls tight on them")
		_check(g.line.target_id == id, "the shot's record says who it is hooked on (so every copy ends the rope on them)")
		await _physics(20)
		_check(bot.velocity.dot(-along) > 1.0 or bot.global_position.distance_to(feet + along * 14.0) > 0.3, "and they are reeled in toward you")
		_hold(false)
		await _physics(3)
		Net.remove_bot(id)
		Cheats.freeze_bots = false
		await _frames(5)

	# --- A race always has the first grappling hook.
	Game.start_practice("rooftop_run", "race")
	await _frames(40)
	arena = Net.arena
	_check(arena != null and arena.local_player != null and arena.local_player.mobility == Mobility.GRAPPLE
		and not (arena.local_player.motor.grapple is HookShot), "a race always has the first grappling hook")
	_finish()


## The shot recorded above, rebuilt the way another copy of the game does it: from the
## snapshots' records, a little late, with packets lost. At every moment of the shot
## it must put the hook and the rope where the player's own game had them.
func _check_network() -> void:
	var shift := 1234.5   # the two clocks are not the same clock
	for plan in [["every snapshot (40 a second), 70 ms late", 3, 0.07, 0.0], ["a third of the packets lost, 110 ms late", 3, 0.11, 0.34],
			["two thirds lost, 200 ms late", 3, 0.2, 0.67]]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var theirs := HookLine.new()
		var next := 0
		var worst := 0.0
		var worst_slack := 0.0
		var stages_off := 0
		var compared := 0
		var pts_a := PackedVector3Array()
		var pts_b := PackedVector3Array()
		pts_a.resize(HookRope.SEGMENTS + 1)
		pts_b.resize(HookRope.SEGMENTS + 1)
		var worst_rope := 0.0
		for k in _log.size():
			# A moment between two steps (the other copy draws at its own frames, not on our steps).
			var now: float = float(_log[k][0]) + STEP * 0.37
			# Everything sent up to (now + how late we draw) has arrived.
			while next < _log.size() and float(_log[next][0]) <= now + float(plan[2]):
				if next % int(plan[1]) == 0 and rng.randf() >= float(plan[3]):
					var packed: PackedFloat32Array = _log[next][2]
					if not packed.is_empty():
						theirs.absorb(float(_log[next][0]) + shift, packed, 0)
				next += 1
			var mine: Array = _shot.look(now, _log[k][4], _log[k][3])   # (the player's own record of the shot)
			var seen := theirs.look(now + shift, _log[k][4], _log[k][3])
			if mine.is_empty() and seen.is_empty():
				continue
			compared += 1
			if mine.is_empty() != seen.is_empty() or int(mine[0]) != int(seen[0]):
				stages_off += 1
				continue
			worst = maxf(worst, (mine[1] as Vector3).distance_to(seen[1]))
			worst_slack = maxf(worst_slack, absf(float(mine[2]) - float(seen[2])))
			HookRope.curve(_log[k][4], mine[1], mine[2], mine[3], mine[4], pts_a)
			HookRope.curve(_log[k][4], seen[1], seen[2], seen[3], seen[4], pts_b)
			for i in pts_a.size():
				worst_rope = maxf(worst_rope, pts_a[i].distance_to(pts_b[i]))
		_check(compared > 60 and stages_off == 0 and worst < 0.02 and worst_slack < 0.02 and worst_rope < 0.03,
			"another copy, %s: the hook is never more than %.1f cm off, the slack %.1f cm, any point of the rope %.1f cm (%d moments, %d in another stage)"
			% [plan[0], worst * 100.0, worst_slack * 100.0, worst_rope * 100.0, compared, stages_off])


## The killcam: frames of the rope as drawn, 30 a second, blended back to any moment
## between them, give the rope that was drawn at that moment.
func _check_replay() -> void:
	var track := KillClip.Track.new()
	var every := 4   # 120 steps a second: every 4th is 30 frames a second
	for k in range(0, _log.size(), every):
		track.push(float(_log[k][0]), _frame_of(_log[k]))
	var worst := 0.0
	var worst_back := 0.0
	var worst_slack := 0.0
	var worst_twang := 0.0
	var compared := 0
	for k in _log.size():
		var mine: Array = _log[k][1]
		var f := track.sample(float(_log[k][0]))
		if mine.is_empty() or f[12] == null:
			continue
		var k0 := k - k % every
		if k0 + every >= _log.size() or (_log[k0][1] as Array).is_empty() or (_log[k0 + every][1] as Array).is_empty() \
				or int(_log[k0][1][0]) != int(_log[k0 + every][1][0]):
			continue   # (the frames either side are in different stages: the blend crosses a bite or a release)
		compared += 1
		var r: Array = f[12]
		if int(mine[0]) == HookLine.RETRACT:   # (the whip back speeds up: its path curves between two frames)
			worst_back = maxf(worst_back, (mine[1] as Vector3).distance_to(r[0]))
			continue
		worst = maxf(worst, (mine[1] as Vector3).distance_to(r[0]))
		worst_slack = maxf(worst_slack, absf(float(mine[2]) - float(r[1])))
		if float(mine[4]) >= 0.0:
			worst_twang = maxf(worst_twang, absf(float(mine[4]) - float(r[3])))
	_check(compared > 40 and worst < 0.05 and worst_slack < 0.05 and worst_twang < 0.002,
		"a replay puts the hook within %.1f cm, the slack within %.1f cm and the twang within %.1f ms of what was drawn (%d moments)"
		% [worst * 100.0, worst_slack * 100.0, worst_twang * 1000.0, compared])
	_check(worst_back < 0.3, "...and within %.0f cm as it whips back at 100 m/s" % (worst_back * 100.0))


## A killcam frame with only what the blend looks at filled in.
func _frame_of(entry: Array) -> Array:
	var look: Array = entry[1]
	return [entry[3], Vector3.ZERO, 0.0, 0.0, 0, 0, not look.is_empty(), look[1] if not look.is_empty() else Vector3.ZERO,
		true, true, 1.6, "none", look.slice(1) if not look.is_empty() else null]


func _record(me: Player, g: HookShot) -> void:
	var packed := g.line.pack(g.clock) if g.line.sending(g.clock) else PackedFloat32Array()
	_log.append([g.clock, g.line.look(g.clock, me.rope_origin(), g.rope_origin(me)), packed, g.rope_origin(me), me.rope_origin()])


func _aim(me: Player, dir: Vector3) -> void:
	me.input.yaw = atan2(-dir.x, -dir.z)
	me.input.pitch = asin(clampf(dir.y, -1.0, 1.0))


## Presses (or lets go of) the mobility button, read even though the mouse is not captured.
func _hold(down: bool) -> void:
	DevArgs.drives_keys = down
	if down:
		Input.action_press("grapple")
	else:
		Input.action_release("grapple")
		_me.input.grapple = false


## A wall `from` to `to` metres in front of a floor spot, square to the shot at eye
## height and above: [feet, direction, distance from the eyes].
func _wall_spot(me: Player, from: float, to: float) -> Array:
	var space := me.get_world_3d().direct_space_state
	for s in Net.arena.layout.spawns:
		var base: Vector3 = s[0]
		var down := PhysicsRayQueryParameters3D.create(base + Vector3(0, 1, 0), base + Vector3(0, -5, 0), 1)
		var floor_hit := space.intersect_ray(down)
		if floor_hit.is_empty():
			continue
		var feet: Vector3 = floor_hit.position
		var eye := feet + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
		for k in 32:
			var flat := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 32.0)
			var dir := (flat + Vector3(0, 0.25, 0)).normalized()
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * to, 1))
			if hit.is_empty() or eye.distance_to(hit.position) < from or (hit.normal as Vector3).dot(flat) > -0.9:
				continue
			if hit.collider is AnimatableBody3D:
				continue
			return [feet, dir, eye.distance_to(hit.position)]
	return []


## A spot on the floor with `length` metres of clear, flat floor ahead: [feet, yaw, direction].
func _open_spot(me: Player, length: float) -> Array:
	var space := me.get_world_3d().direct_space_state
	for s in Net.arena.layout.spawns:
		var base: Vector3 = s[0]
		var down := PhysicsRayQueryParameters3D.create(base + Vector3(0, 1, 0), base + Vector3(0, -5, 0), 1)
		var floor_hit := space.intersect_ray(down)
		if floor_hit.is_empty():
			continue
		var feet: Vector3 = floor_hit.position
		for k in 16:
			var yaw := k * TAU / 16.0
			var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
			var ok := true
			for h in [0.3, 1.0, 1.7]:
				var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, h, 0), feet + Vector3(0, h, 0) + dir * (length + 1.0), 1)
				if not space.intersect_ray(q).is_empty():
					ok = false
			for step in [4.0, 8.0, length]:
				var p: Vector3 = feet + dir * step
				var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -0.5, 0), 1)
				var hit := space.intersect_ray(q)
				if hit.is_empty() or (hit.normal as Vector3).y < 0.95:
					ok = false
			if ok:
				return [feet, yaw, dir]
	return []


func _finish() -> void:
	print("PASS" if _ok else "FAIL")
	get_tree().quit(0 if _ok else 1)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_ok = false
