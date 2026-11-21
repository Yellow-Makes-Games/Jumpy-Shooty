extends Node
## The body of tests/mobility_test.gd (a separate file: it uses the game's autoloads).

var _ok := true


func run() -> void:
	var game = Game
	var net = Net
	var match_state = Match
	Settings.mobility = Mobility.BLINK   # (not saved: the test never calls save_settings)
	game.start_practice("testing_grounds")
	await _frames(30)
	var arena = net.arena
	_check(arena != null and arena.portals != null, "practice starts, with a place for portals")
	var me: Player = arena.local_player
	_check(me.mobility == Mobility.BLINK and me.blink != null, "you have the blink you picked")
	_check(net.player_mobility(net.my_id()) == Mobility.BLINK, "the lobby has it on record")

	# --- Blink in the open: three charges in a quick burst, each one shorter.
	var open := _open_spot(me, 28.0)
	_check(not open.is_empty(), "found an open stretch of floor to blink along")
	me.teleport(open[0], open[1])
	await _physics(20)
	var went := await _blink(me, open[2])
	_check(went > Blink.RANGE - 1.5, "a blink goes about its range (%.1f m)" % went)
	_check(Blink.CHARGES == 3 and me.blink.charges == 2, "it uses one of its three charges (%d left)" % me.blink.charges)
	_check(Net.arena.get_node_or_null("BlinkTrail") != null, "a trail of sparks follows you to where you land")
	_check(me.velocity.dot(open[2]) >= Blink.BLINK_PUSH - 0.5, "you keep moving the way you blinked (%.1f m/s)" % me.velocity.dot(open[2]))
	_check(me.blink.strength() < 1.0, "the next blink straight after is shorter (%.0f%%)" % (me.blink.strength() * 100.0))
	me.input.mobility_dir = open[2]
	me.input.grapple_pressed = true
	await _physics(2)
	_check(me.blink.charges == 2, "no second blink on the very next frame (a short gap)")
	await _physics(_ticks(Blink.GAP) + 2)
	var went2 := await _blink(me, open[2])
	_check(me.blink.charges == 1, "a second blink a moment later goes (%d left)" % me.blink.charges)
	_check(went2 < went - 1.5 and went2 > Blink.RANGE * Blink.MIN_REACH - 1.0, "...but shorter (%.1f m after %.1f m)" % [went2, went])
	await _physics(_ticks(Blink.GAP) + 2)
	var went3 := await _blink(me, open[2])
	_check(me.blink.charges == 0, "a third straight after goes too (%d left)" % me.blink.charges)
	_check(went3 < went2 - 1.0 and went3 > Blink.RANGE * Blink.MIN_REACH - 1.0, "...shorter again (%.1f m)" % went3)
	await _physics(_ticks(Blink.GAP) + 2)
	var went4 := await _blink(me, open[2])
	_check(me.blink.charges == 0 and went4 < 1.0, "no fourth: the charges are spent")
	await get_tree().create_timer(Blink.RECHARGE + 0.2).timeout
	_check(me.blink.charges == 1, "a charge comes back after %.1f s" % Blink.RECHARGE)
	await get_tree().create_timer(Blink.RECHARGE * (Blink.CHARGES - 1) + 0.3).timeout
	_check(me.blink.charges == Blink.CHARGES and is_equal_approx(me.blink.strength(), 1.0), "then all three, one at a time, and the next blink is full length again")

	# --- Spaced out, blinks keep their range.
	me.teleport(open[0], open[1])
	await _physics(20)
	var spaced_1 := await _blink(me, open[2])
	me.teleport(open[0], open[1])   # (back to the start, for room)
	await get_tree().create_timer(Blink.STRAIN_PER_BLINK / Blink.STRAIN_RECOVER + 0.05).timeout
	var spaced_2 := await _blink(me, open[2])
	_check(spaced_1 > Blink.RANGE - 1.5 and spaced_2 > Blink.RANGE - 1.5, "two blinks a second apart both go the full range (%.1f m, %.1f m)" % [spaced_1, spaced_2])
	me.blink.reset()

	# --- Through walls: a wall put up on the open floor, 4 m ahead.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	wall_shape.shape = box
	wall.add_child(wall_shape)
	Net.arena.add_child(wall)
	var side: Vector3 = (open[2] as Vector3).cross(Vector3.UP).normalized()
	var to_wall := 4.0
	# A thin one: you come out the far side, the full range away.
	box.size = Vector3(6.0, 5.0, 0.5)
	wall.global_transform = Transform3D(Basis(side, Vector3.UP, -open[2]), open[0] + open[2] * (to_wall + 0.25) + Vector3(0, 2.5, 0))
	me.teleport(open[0], open[1])
	me.blink.reset()
	await _physics(20)
	var through := await _blink(me, open[2])
	_check(through > Blink.RANGE - 1.5, "a blink at a thin wall %.0f m away goes through it, its full range (%.1f m)" % [to_wall, through])
	_check(me.global_position.y > open[0].y - 0.5, "...and lands on the floor on the far side, not under it")
	# One thicker than a blink's reach: no open ground past it, so you stop short.
	box.size = Vector3(6.0, 5.0, 30.0)
	wall.global_transform = Transform3D(Basis(side, Vector3.UP, -open[2]), open[0] + open[2] * (to_wall + 15.0) + Vector3(0, 2.5, 0))
	me.teleport(open[0], open[1])
	me.blink.reset()
	await _physics(20)
	var gone := await _blink(me, open[2])
	_check(gone < to_wall and gone > to_wall - 1.6, "a wall thicker than the reach: it stops short of it (%.1f m from %.0f m)" % [gone, to_wall])
	var space := me.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(open[0] + Vector3(0, 1, 0), me.global_position + Vector3(0, 1, 0), 1, [me.get_rid()])
	_check(space.intersect_ray(q).is_empty(), "...and on this side of it")
	wall.queue_free()
	# Floors are not walls: aimed steeply down at the floor, you stay on it.
	await _physics(4)
	me.teleport(open[0], open[1])
	me.blink.reset()
	await _physics(20)
	var y0 := me.global_position.y
	await _blink(me, (open[2] + Vector3(0, -1.5, 0)).normalized())
	await _physics(10)
	_check(me.global_position.y > y0 - 0.5, "a blink aimed down into the floor never goes through it (%.1f m)" % (me.global_position.y - y0))
	# Never out of the map: over nothing, or outside its fence.
	_check(Blink.in_map(me, open[0] + Vector3(0, 0.5, 0)), "open floor is somewhere a blink can land")
	_check(not Blink.in_map(me, open[0] + Vector3(2000.0, 0.5, 0)), "...the void off the map's edge is not")
	me.blink.reset()

	# --- Picking: refused while alive, taken while dead.
	net.set_my_mobility(Mobility.PORTAL)
	await _frames(3)
	_check(net.player_loadout_mobility(net.my_id()) == Mobility.BLINK, "a pick while alive waits")
	match_state._host_damage(9001, net.my_id(), 500.0)
	await _frames(5)
	_check(not match_state.is_alive(net.my_id()), "you died")
	await _frames(5)
	_check(net.player_loadout_mobility(net.my_id()) == Mobility.PORTAL, "dead: the pick made while alive is taken (%s)" % net.player_loadout_mobility(net.my_id()))
	_check(me.mobility == Mobility.PORTAL and me.portal_gun != null and me.blink == null, "you now have the portal gun")
	await get_tree().create_timer(Match.RESPAWN_DELAY + 0.5).timeout
	me = arena.local_player
	_check(match_state.is_alive(net.my_id()) and me.mobility == Mobility.PORTAL, "and come back with it")

	# --- Portal gun: two floor portals, fall into one, out of the other.
	var a := _open_spot(me, 16.0)
	me.teleport(a[0], a[1])
	await _physics(20)
	me.input.pitch = deg_to_rad(-80.0)
	me.input.grapple_pressed = true
	await _physics(2)
	var blue: Portal = arena.portals.get_portal(me.peer_id, 0)
	_check(blue != null and blue.normal.y > 0.9, "aiming at the floor puts a blue portal there")
	_check(me.portal_gun.next_slot == 1, "the next one is orange")
	var far_spot: Vector3 = a[0] + a[2] * 14.0
	await get_tree().create_timer(PortalGun.COOLDOWN + 0.05).timeout
	var eye := me.eye_position()
	me.input.mobility_dir = (far_spot - eye).normalized()
	me.input.grapple_pressed = true
	await _physics(2)
	var orange: Portal = arena.portals.get_portal(me.peer_id, 1)
	_check(orange != null and orange.global_position.distance_to(far_spot) < 1.5, "the next press puts an orange one where you aim")
	if blue and orange:
		# Stand on blue: out of orange, popping up.
		me.teleport(blue.global_position + Vector3(0, 0.05, 0), me.input.yaw)
		var trips := me.respawn_count()
		await _physics(3)
		_check(me.global_position.distance_to(orange.global_position) < 2.0, "stepping onto a portal brings you out of the other (%.1f m from it)" % me.global_position.distance_to(orange.global_position))
		_check(me.velocity.y > 2.0, "coming out of a floor, you pop up (%.1f m/s)" % me.velocity.y)
		_check(me.respawn_count() == trips + 1, "others are told it was a jump, not a run across the map")
		await _physics(90)
		_check(me.global_position.distance_to(orange.global_position) < 2.5, "landing back on it does not send you straight back")
		# A wall portal: in through the floor, out of the wall, moving out of it.
		var w := _wall_spot(me)
		if not w.is_empty():
			me.teleport(w[0], 0.0)
			await _physics(10)
			await get_tree().create_timer(PortalGun.COOLDOWN + 0.05).timeout
			me.input.mobility_dir = w[1]
			me.input.grapple_pressed = true
			await _physics(2)
			var on_wall: Portal = arena.portals.get_portal(me.peer_id, 0)
			_check(on_wall != null and absf(on_wall.normal.y) < 0.3, "a portal on a wall stands upright")
			_check(on_wall != null and on_wall.global_position.y - Portal.HALF_HEIGHT >= w[0].y - 0.1,
				"...and clear of the floor")
			if on_wall:
				me.teleport(orange.global_position + Vector3(0, 0.05, 0), 0.0)
				await _physics(3)
				var out := me.velocity.dot(on_wall.normal)
				_check(me.global_position.distance_to(on_wall.global_position) < 2.5 and out > 2.0,
					"in through the floor, out of the wall, moving away from it (%.1f m/s)" % out)
	# Too far apart: the new one closes the other.
	var span_from: Vector3 = a[0]
	arena.portals.place(me.peer_id, 0, span_from, Vector3.UP, Vector3.FORWARD)
	arena.portals.place(me.peer_id, 1, span_from + Vector3(Portals.MAX_SPAN - 5.0, 0, 0), Vector3.UP, Vector3.FORWARD)
	_check(arena.portals.get_portal(me.peer_id, 0) != null and arena.portals.get_portal(me.peer_id, 1) != null,
		"two portals within %d m of each other both stay" % int(Portals.MAX_SPAN))
	arena.portals.place(me.peer_id, 0, span_from + Vector3(Portals.MAX_SPAN - 5.0, 0, Portals.MAX_SPAN - 10.0), Vector3.UP, Vector3.FORWARD)
	await _frames(2)
	_check(arena.portals.get_portal(me.peer_id, 0) != null and arena.portals.get_portal(me.peer_id, 1) != null,
		"moving one still in range keeps the pair")
	arena.portals.place(me.peer_id, 1, span_from - Vector3(Portals.MAX_SPAN, 0, 0), Vector3.UP, Vector3.FORWARD)
	await _frames(2)
	_check(arena.portals.get_portal(me.peer_id, 1) != null and arena.portals.get_portal(me.peer_id, 0) == null,
		"a portal put up too far from the other closes it")
	# Your portals go when you die.
	match_state._host_damage(9001, net.my_id(), 500.0)
	await _frames(5)
	_check(arena.portals.get_portal(me.peer_id, 0) == null and arena.portals.get_portal(me.peer_id, 1) == null,
		"your portals go when you die")

	# --- Carrying speed through: a wall facing +Z to a floor.
	var pa := Portal.new()
	pa.place(Vector3.ZERO, Vector3(0, 0, 1), Vector3.UP)
	var pb := Portal.new()
	pb.place(Vector3(10, 0, 0), Vector3.UP, Vector3(0, 0, -1))
	var v := pa.carry(pb, Vector3(0, 0, -8))
	_check(v.is_equal_approx(Vector3(0, 8, 0)), "running into a wall portal at 8 m/s, you come out of a floor going up at 8 (%s)" % v)
	pa.free()
	pb.free()

	# --- Jetpack: holding the button lifts you off the ground and burns fuel; it refills.
	await get_tree().create_timer(Match.RESPAWN_DELAY + 0.5).timeout
	me = arena.local_player
	me.set_mobility(Mobility.JETPACK)
	var j := _open_spot(me, 6.0)
	me.teleport(j[0], j[1])
	await _physics(20)
	var ground_y := me.global_position.y
	DevArgs.drives_keys = true   # read the keys even though the mouse is not captured
	Input.action_press("grapple")
	await _physics(60)   # half a second at 120 Hz
	Input.action_release("grapple")
	await _physics(2)
	DevArgs.drives_keys = false
	_check(me.global_position.y > ground_y + 1.0, "holding the jetpack lifts you (%.1f m up)" % (me.global_position.y - ground_y))
	_check(me.jetpack.fuel < 0.9, "and burns fuel (%.2f left)" % me.jetpack.fuel)
	_check(RobotAnimInput.jetpack_of(me._my_anim_flags()) == false, "others are told when it stops")
	var low := me.jetpack.fuel
	await get_tree().create_timer(1.5).timeout
	_check(me.jetpack.fuel > low, "the fuel refills when you let go (%.2f)" % me.jetpack.fuel)

	# --- Bots take a tool, and a race always has the grapple.
	var id: int = net.add_bot(BotDifficulty.EXPERT, "", Mobility.PORTAL)
	await _frames(10)
	var bot: Player = arena.get_player(id)
	_check(bot != null and bot.mobility == Mobility.PORTAL and bot.portal_gun != null, "a bot can carry the portal gun")
	var id2: int = net.add_bot(BotDifficulty.EXPERT, "", Mobility.BLINK)
	await _frames(10)
	var bot2: Player = arena.get_player(id2)
	_check(bot2 != null and bot2.mobility == Mobility.BLINK and bot2.blink != null, "a bot can carry blink")
	var id3: int = net.add_bot(BotDifficulty.EXPERT, "", Mobility.JETPACK)
	await _frames(10)
	var bot3: Player = arena.get_player(id3)
	_check(bot3 != null and bot3.jetpack != null, "a bot can carry the jetpack")
	net.remove_bot(id)
	net.remove_bot(id2)
	net.remove_bot(id3)
	await _frames(5)
	game.start_practice("rooftop_run", "race")
	await _frames(40)
	arena = net.arena
	_check(arena != null and arena.local_player != null and arena.local_player.mobility == Mobility.GRAPPLE,
		"a race always has the grapple (picked: %s)" % net.player_loadout_mobility(net.my_id()))

	print("PASS" if _ok else "FAIL")
	get_tree().quit(0 if _ok else 1)


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


## A wall 5 to 9 m in front of a floor spot: [feet, direction, distance].
func _wall_spot(me: Player) -> Array:
	var space := me.get_world_3d().direct_space_state
	for s in Net.arena.layout.spawns:
		var base: Vector3 = s[0]
		var down := PhysicsRayQueryParameters3D.create(base + Vector3(0, 1, 0), base + Vector3(0, -5, 0), 1)
		var floor_hit := space.intersect_ray(down)
		if floor_hit.is_empty():
			continue
		var feet: Vector3 = floor_hit.position
		for k in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 16.0)
			var hits := []
			for h in [0.3, 1.0, 1.7, 2.6]:
				var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, h, 0), feet + Vector3(0, h, 0) + dir * 9.0, 1)
				hits.append(space.intersect_ray(q))
			var first: Dictionary = hits[1]
			if first.is_empty() or absf((first.normal as Vector3).y) > 0.1 or (first.normal as Vector3).dot(dir) > -0.9:
				continue
			var dist := Vector2(first.position.x - feet.x, first.position.z - feet.z).length()
			if dist < 5.0:
				continue
			var flat := true
			for hh in hits:
				if hh.is_empty() or absf(Vector2(hh.position.x - feet.x, hh.position.z - feet.z).length() - dist) > 0.3:
					flat = false
			if flat:
				return [feet, dir, dist]
	return []


## Blink along `dir`; how far (flat) you went.
func _blink(me: Player, dir: Vector3) -> float:
	var from := me.global_position
	me.input.mobility_dir = dir
	me.input.grapple_pressed = true
	await _physics(2)
	me.input.mobility_dir = Vector3.ZERO
	return Vector2(me.global_position.x - from.x, me.global_position.z - from.z).length()


## Physics ticks in `seconds`.
func _ticks(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


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
