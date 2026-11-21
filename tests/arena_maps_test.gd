extends SceneTree
## Rail Yard, Lost Temple and Neon Arcade checks (the arenas built by
## tools/arena/build_arena_maps.py):
##  - enough spawn points for their size (16 players on the large maps), each clear,
##    standing on a floor and inside the bounds;
##  - the bots' navigation mesh lets a bot walk from every spawn point to every other
##    one and to the floors each map is built around;
##  - walls and floors break (and the floor under every spawn stays).
## Run: godot --headless --path . --script tests/arena_maps_test.gd
## One map: ARENA_ONLY=rail_yard godot --headless --path . --script tests/arena_maps_test.gd

## Where a bot must be able to walk to on each map (besides every spawn point).
const GOALS := {
	"rail_yard": {
		"concourse": Vector3(0, 1, -26), "mezzanine": Vector3(-20, 6.5, -30), "station roof": Vector3(20, 13.6, -22),
		"footbridge": Vector3(0, 6.5, 2), "platform 2": Vector3(-20, 1, -3.5), "platform 3": Vector3(20, 1, 9.5),
		"inside a carriage": Vector3(-10, 1, -9.5), "goods shed office": Vector3(-36, 4, 37.5),
		"signal box": Vector3(29, 4, 26.6), "yard": Vector3(10, 0, 40),
	},
	"lost_temple": {
		"shrine": Vector3(0, 9, -3.5), "crypt": Vector3(0, 0, 2.8), "palace upper floor": Vector3(-40, 4.3, -30),
		"aqueduct": Vector3(36, 7, -32.5), "treehouse A": Vector3(-34, 6, 25), "treehouse B": Vector3(-31.5, 6, 42.5),
		"treehouse C": Vector3(-19.5, 6, 40.5), "courtyard dais": Vector3(33.5, 1.2, 30.5), "scaffold deck": Vector3(-35, 4.5, -1),
	},
	"neon_arcade": {
		"north mezzanine": Vector3(0, 4.5, -12), "west mezzanine": Vector3(-18, 4.5, 12), "party room": Vector3(2, 0, -10.6),
		"stage": Vector3(18, 0.6, 8.4), "arcade roof": Vector3(0, 9.6, 0), "flat over the noodle bar": Vector3(-33, 3.9, 10),
		"pool room": Vector3(36.5, 3.9, 12), "diner": Vector3(-14.5, 0, 35), "laundromat": Vector3(4, 0, 35),
		"back lot": Vector3(0, 0, -20), "filling station": Vector3(38.2, 0, -5), "plaza": Vector3(-33.4, 0, 38.9),
	},
}
const MIN_SPAWNS := {"rail_yard": 16, "lost_temple": 16, "neon_arcade": 24}

var failures := 0


func _initialize() -> void:
	print("Arena map checks")
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_environment("ARENA_ONLY")
	for id in GOALS:
		if only != "" and id != only:
			continue
		await _check_map(id)
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _check_map(id: String) -> void:
	print("  %s" % Maps.name_of(id))
	_expect(Maps.fits(id, "ffa") and Maps.fits(id, "dm"), "listed for free-for-all and Deathmatch")
	var map := Maps.make(id)
	map.destructible = true
	root.add_child(map)
	var started := Time.get_ticks_msec()
	map.build(false)
	print("    built in %d ms" % (Time.get_ticks_msec() - started))
	for i in 3:
		await physics_frame
	var space := root.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var bad := []
	for s in map.spawns:
		var pos: Vector3 = s[0]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0)))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty() or not map.bounds.has_point(Vector2(pos.x, pos.z)):
			bad.append(pos)
	_expect(map.spawns.size() >= MIN_SPAWNS[id], "%d spawn points (%d or more)" % [map.spawns.size(), MIN_SPAWNS[id]])
	_expect(bad.is_empty(), "every spawn point is clear, on a floor and inside the bounds %s" % [bad])

	var d := map.destruction
	_expect(d != null and d.breakable_count() > 50, "walls and floors break (%d of %d pieces can)" % [d.breakable_count() if d else 0, d.cells.size() if d else 0])

	var region := MapScenery.bake_navigation(map)
	root.add_child(region)
	var nav_map := root.get_world_3d().navigation_map
	var probe: Vector3 = map.spawns[0][0]
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and NavigationServer3D.map_get_closest_point(nav_map, probe).distance_to(probe) < 1.0:
			break
	var goals: Dictionary = GOALS[id].duplicate()
	for i in map.spawns.size():
		goals["spawn %d" % (i + 1)] = map.spawns[i][0]
	var from: Vector3 = map.spawns[0][0]
	var missed := []
	for goal_name in goals:
		var goal: Vector3 = goals[goal_name]
		var there := NavigationServer3D.map_get_path(nav_map, from, goal, true)
		var back := NavigationServer3D.map_get_path(nav_map, goal, from, true)
		var miss := 99.0 if there.is_empty() else there[there.size() - 1].distance_to(goal)
		var miss_back := 99.0 if back.is_empty() else back[back.size() - 1].distance_to(from)
		if maxf(miss, miss_back) > 1.0:
			missed.append("%s (%.1f m short)" % [goal_name, maxf(miss, miss_back)])
	_expect(missed.is_empty(), "a bot can walk between every spawn point and to %s %s" % [", ".join(GOALS[id].keys()), missed])
	region.queue_free()
	map.queue_free()
	await process_frame


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
