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

	# --- Blink in the open.
	var open := _open_spot(me, 16.0)
	_check(not open.is_empty(), "found an open stretch of floor to blink along")
	me.teleport(open[0], open[1])
	await _physics(20)
	var from := me.global_position
	me.input.mobility_dir = open[2]
	me.input.grapple_pressed = true
	await _physics(2)
	var went := Vector2(me.global_position.x - from.x, me.global_position.z - from.z).length()
	_check(went > Blink.RANGE - 1.5, "a blink goes about its range (%.1f m)" % went)
	_check(Blink.CHARGES == 1 and me.blink.charges == 0, "it uses its one charge (%d left)" % me.blink.charges)
	_check(Net.arena.get_node_or_null("BlinkTrail") != null, "a trail of sparks follows you to where you land")
	_check(me.velocity.dot(open[2]) >= Blink.BLINK_PUSH - 0.5, "you keep moving the way you blinked (%.1f m/s)" % me.velocity.dot(open[2]))
	me.input.mobility_dir = open[2]
	me.input.grapple_pressed = true
	await _physics(1)
	_check(me.blink.charges == Blink.CHARGES - 1, "no second blink straight away (a short gap)")
	await get_tree().create_timer(Blink.RECHARGE + 0.4).timeout
	_check(me.blink.charges == Blink.CHARGES, "the charge comes back")

	# --- Blink at a wall: stops short of it.
	var wall := _wall_spot(me)
	_check(not wall.is_empty(), "found a wall to blink at")
	if not wall.is_empty():
		me.teleport(wall[0], 0.0)
		await _physics(20)
		me.input.mobility_dir = wall[1]
		me.input.grapple_pressed = true
		await _physics(2)
		var to_wall: float = wall[2]
		var gone := Vector2(me.global_position.x - wall[0].x, me.global_position.z - wall[0].z).length()
		_check(gone < to_wall and gone > to_wall - 1.6, "a blink at a wall %.1f m away stops short of it (%.1f m)" % [to_wall, gone])
		var space := me.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(wall[0] + Vector3(0, 1, 0), me.global_position + Vector3(0, 1, 0), 1, [me.get_rid()])
		_check(space.intersect_ray(q).is_empty(), "...and on this side of it")

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

	# --- Bots take a tool, and a race always has the grapple.
	var id: int = net.add_bot(BotDifficulty.EXPERT, "", Mobility.PORTAL)
	await _frames(10)
	var bot: Player = arena.get_player(id)
	_check(bot != null and bot.mobility == Mobility.PORTAL and bot.portal_gun != null, "a bot can carry the portal gun")
	var id2: int = net.add_bot(BotDifficulty.EXPERT, "", Mobility.BLINK)
	await _frames(10)
	var bot2: Player = arena.get_player(id2)
	_check(bot2 != null and bot2.mobility == Mobility.BLINK and bot2.blink != null, "a bot can carry blink")
	net.remove_bot(id)
	net.remove_bot(id2)
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
