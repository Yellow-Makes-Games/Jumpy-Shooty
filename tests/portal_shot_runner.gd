extends Node
## The body of tests/portal_shot_test.gd (a separate file: it uses the game's autoloads).

var _ok := true
var _hits: Array = []
var _shots: Array = []
var _booms: Array = []


func run() -> void:
	var game = Game
	var net = Net
	var match_state = Match
	game.start_practice("testing_grounds")
	await _frames(30)
	var arena = net.arena
	var portals: Portals = arena.portals
	var me: Player = arena.local_player
	var my_id: int = net.my_id()
	match_state.dummy_hit.connect(func(s, d, dmg, h, k): _hits.append([s, d, dmg, h]))
	match_state.shot_fired.connect(func(s, m, ends, hits, vias): _shots.append([ends, hits, vias]))
	match_state.exploded.connect(func(id, at, w): _booms.append([id, at, w]))
	var dummy: TargetDummy = arena.dummies[1]   # 10 m out, nothing in front of it
	var d: Vector3 = dummy.global_position
	var pistol := WeaponData.by_id("pistol")

	# Stand 8 m short of the dummy, facing away from it (-x); blue 3 m behind you...
	# no: in front of you, the way you face; orange 4 m to the dummy's side, facing it.
	me.teleport(d - Vector3(8.0, 0, 0), PI / 2)
	await _frames(3)
	var eye := me.eye_position()
	portals.place(my_id, 0, eye + Vector3(-3.0, 0, 0), Vector3(1, 0, 0), Vector3.UP)
	portals.place(my_id, 1, d + Vector3(0, 1.0, -4.0), Vector3(0, 0, 1), Vector3.UP)
	var blue := portals.get_portal(my_id, 0)
	_check(blue.carrier == null, "a portal in open air rides nothing")
	match_state.request_shot(eye, PackedVector3Array([Vector3(-1, 0, 0)]), {}, "pistol", me.peer_id)
	await _frames(3)
	_check(_hits.size() == 1 and int(_hits[0][1]) == 1,
		"a shot into blue comes out of orange and hits the dummy you faced away from: %s" % str(_hits))
	var expect := pistol.damage_at(3.0 + 4.0)
	_check(_hits.size() == 1 and absf(float(_hits[0][2]) - expect) < 1.0,
		"its damage falls off over the whole way (%.1f, want %.1f)" % [float(_hits[0][2]) if _hits else -1.0, expect])
	var vias: Array = _shots[-1][2] if _shots else []
	_check(vias.size() == 1 and (vias[0] as PackedVector3Array).size() == 2,
		"the shot effect goes in one portal and out of the other: %s" % str(vias))
	if vias.size() == 1 and (vias[0] as PackedVector3Array).size() == 2:
		var via: PackedVector3Array = vias[0]
		_check(via[0].distance_to(blue.frame.origin) < 0.2 and via[1].distance_to(portals.get_portal(my_id, 1).frame.origin) < 0.2,
			"...through the middle of each")
		var end: Vector3 = _shots[-1][0][0]
		_check(absf(end.x - d.x) < 0.6 and end.z > d.z - 4.0 and end.z <= d.z + 0.01, "...and ends on the dummy (%s)" % str(end))

	# The same shot as you see it straight away (Player's own prediction): the same way.
	var legs := portals.shot_path(me.get_world_3d().direct_space_state, eye, Vector3(-1, 0, 0), pistol.max_range, 1 | (1 << 1), [me.get_rid()])
	_check(legs.size() == 2 and legs[1].hit and legs[1].hit.collider == dummy, "your own copy of the shot hits it too")

	# A lone portal lets bullets fly on.
	portals.clear(my_id)
	portals.place(my_id, 0, eye + Vector3(-3.0, 0, 0), Vector3(1, 0, 0), Vector3.UP)
	legs = portals.shot_path(me.get_world_3d().direct_space_state, eye, Vector3(-1, 0, 0), pistol.max_range, 1)
	_check(legs.size() == 1, "a lone portal does not take bullets")
	portals.place(my_id, 1, d + Vector3(0, 1.0, -4.0), Vector3(0, 0, 1), Vector3.UP)
	legs = portals.shot_path(me.get_world_3d().direct_space_state, eye + Vector3(-4.0, 0, 0), Vector3(1, 0, 0), pistol.max_range, 1)
	_check(legs.size() == 1, "nor does a portal shot at from behind")

	_check(Projectile.SHOT_EXIT == Portals.SHOT_EXIT, "rockets and bullets come out of a portal alike")
	# A rocket: into blue, out of orange, onto the dummy (the host's flight)...
	match_state._projectiles.clear()
	match_state._projectiles[777] = {"pos": eye, "vel": Vector3(-1, 0, 0) * 30.0, "shooter": me.peer_id, "weapon": "rocket_launcher", "t": 0.0}
	var before := _hits.size()
	for i in 60:
		await get_tree().physics_frame
		if not match_state._projectiles.has(777):
			break
	_check(not match_state._projectiles.has(777) and _booms.size() > 0 and (_booms[-1][1] as Vector3).distance_to(d + Vector3(0, 1.0, 0)) < 1.2,
		"a rocket flies through and blows up on the dummy (%s)" % (str(_booms[-1][1]) if _booms else "no boom"))
	_check(_hits.size() > before, "...and hurts it")
	# ...and the rocket everyone sees flies the same way.
	var rocket := Projectile.make(990, WeaponData.by_id("rocket_launcher"), eye, Vector3(-1, 0, 0), Vector3.INF, Color.WHITE)
	arena.add_child(rocket)
	rocket.set_physics_process(false)
	for i in 10:   # 0.17 s at 30 m/s: 5 m, through the portal 3 m on
		rocket._physics_process(1.0 / 60.0)
	_check(rocket._vel.normalized().distance_to(Vector3(0, 0, 1)) < 0.05 and absf(rocket._pos.x - d.x) < 0.3 and rocket._pos.z > d.z - 4.0,
		"the rocket you see comes out of orange heading for the dummy (%s, %s)" % [str(rocket._pos), str(rocket._vel)])
	rocket.queue_free()

	# Portals on a moving part ride it.
	var part := AnimatableBody3D.new()
	part.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.4)
	shape.shape = box
	part.add_child(shape)
	part.name = "TestPart"
	arena.add_child(part)
	part.global_position = d + Vector3(0, 3.0, 12.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var face := part.global_position + Vector3(0, 0, -0.2)
	portals.place(my_id, 0, face + Vector3(0, 0, -0.02), Vector3(0, 0, -1), Vector3.UP)
	var on := portals.get_portal(my_id, 0)
	_check(on.carrier == part, "a portal put up on a moving part rides it")
	part.global_position += Vector3(5.0, 1.0, 0.0)
	part.rotate_y(0.3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var want := (part.global_transform * on.carrier_frame).origin
	_check(on.frame.origin.distance_to(want) < 0.01 and on.frame.origin.distance_to(face) > 4.0,
		"it goes where the part goes (%s)" % str(on.frame.origin))
	_check(on.normal.distance_to(part.global_transform.basis * Vector3(0, 0, -1)) < 0.01, "and turns with it")
	_check(on.global_transform.origin.distance_to(on.frame.origin) < 0.01, "and is drawn there")
	# Told from elsewhere (a message from another copy): onto the same spot of the part.
	var sent := portals.carrier_of(on, arena)
	_check(sent[0] == str(arena.get_path_to(part)), "the message names the part (%s)" % sent[0])
	part.global_position += Vector3(0, 0, 2.0)
	portals.place_on(my_id, 0, Vector3(99, 99, 99), Vector3.UP, Vector3.FORWARD, arena, sent[0], sent[1])
	on = portals.get_portal(my_id, 0)
	_check(on.carrier == part and on.frame.origin.distance_to((part.global_transform * sent[1]).origin) < 0.01,
		"a portal put up elsewhere lands on the same spot of the part, where it is now")
	part.queue_free()
	await _frames(2)
	await get_tree().physics_frame
	await _frames(1)
	_check(portals.get_portal(my_id, 0) == null, "it closes when the part goes")

	print("portal shots: %s" % ("all passed" if _ok else "FAILED"))
	get_tree().quit(0 if _ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_ok = false
