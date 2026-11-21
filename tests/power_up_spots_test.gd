extends SceneTree
## Deathmatch power-up spots (MapItemSpawn) on every map that hosts a Deathmatch:
##  - 6 to 12 of them, every kind (ItemPickup.KINDS) among them, at most 2 double
##    damage and at most 2 uber;
##  - each over a floor (within half a metre) with room to stand, inside the bounds and
##    well above the kill height;
##  - none within 1.5 m of a weapon pickup or another power-up (one step takes both);
##  - not all bunched up: the two that lie furthest apart are at least a third as far
##    apart as the spawn points spread (the width of where people play).
## It also prints a note for a spot within 2 m of a spawn point (one who spawns there
## takes it without meaning to: best avoided, but the first maps do it), and, for each spot that is not on a moving part, whether a bot could walk
## to it from the first spawn point (looks only: a spot up a climb, a jump or a grapple
## is fine, but most of the health should be walkable).
## Run: godot --headless --path . --script tests/power_up_spots_test.gd
## One map: POWERUPS_ONLY=office godot --headless --path . --script tests/power_up_spots_test.gd
## Skip the walking report (faster): POWERUPS_NO_NAV=1

const MIN_COUNT := 6
const MAX_COUNT := 12
const MIN_GAP := 1.5      ## to a weapon pickup or another power-up
const SPAWN_GAP := 2.0    ## to a spawn point (a note only)

var failures := 0


func _initialize() -> void:
	print("Power-up spot checks")
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_environment("POWERUPS_ONLY")
	for id in Maps.ids_for("dm"):
		if only != "" and id != only:
			continue
		await _check_map(id)
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _check_map(id: String) -> void:
	print("  %s" % Maps.name_of(id))
	var map := Maps.make(id)
	root.add_child(map)
	map.build(false)
	for i in 3:
		await physics_frame
	var space := root.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var items: Array = map.item_spawns
	var count := {}
	var bad := []
	var outside := []
	var low := []
	var crowded := []
	for i in items.size():
		var pos: Vector3 = items[i][0]
		var kind: String = items[i][1]
		count[kind] = count.get(kind, 0) + 1
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -0.5, 0), 1))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), pos + Vector3(0, 1.0, 0))
		if not down or not space.intersect_shape(q, 1).is_empty():
			bad.append("%s %s" % [kind, pos])
		if map.bounds.has_area() and not map.bounds.has_point(Vector2(pos.x, pos.z)):
			outside.append("%s %s" % [kind, pos])
		if pos.y < map.kill_height + 4.0:
			low.append("%s %s" % [kind, pos])
		var near := []
		for w in map.weapon_spawns:
			if (w[0] as Vector3).distance_to(pos) < MIN_GAP:
				near.append("weapon %s" % w[1])
		for j in items.size():
			if j != i and (items[j][0] as Vector3).distance_to(pos) < MIN_GAP:
				near.append("power-up %s" % items[j][1])
		for s in map.spawns:
			if (s[0] as Vector3).distance_to(pos) < SPAWN_GAP:
				print("    note %s %s is on a spawn point" % [kind, pos])
				break
		if not near.is_empty():
			crowded.append("%s %s (%s)" % [kind, pos, ", ".join(near)])
	var spread := 0.0
	for i in items.size():
		for j in range(i + 1, items.size()):
			spread = maxf(spread, (items[i][0] as Vector3).distance_to(items[j][0]))
	# (The width of where people play: the spread of the spawn points, as some maps' Bounds
	# are a far safety net.)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in map.spawns:
		var p := Vector2((s[0] as Vector3).x, (s[0] as Vector3).z)
		lo = lo.min(p)
		hi = hi.max(p)
	var width := maxf(hi.x - lo.x, hi.y - lo.y) if map.spawns.size() >= 2 else 0.0
	_expect(items.size() >= MIN_COUNT and items.size() <= MAX_COUNT, "%d power-ups (%d to %d)" % [items.size(), MIN_COUNT, MAX_COUNT])
	var kinds: Array = load("res://game/arena/item_pickup.gd").KINDS   # (loaded, not named: it needs the Match autoload)
	var missing := kinds.filter(func(k): return not count.has(k))
	_expect(missing.is_empty(), "every kind is there %s (missing %s)" % [count, missing])
	_expect(count.get("damage", 0) <= 2 and count.get("uber", 0) <= 2, "at most 2 double damage and 2 uber")
	_expect(bad.is_empty(), "every one is over a floor with room to stand %s" % [bad])
	_expect(outside.is_empty(), "every one is inside the bounds %s" % [outside])
	_expect(low.is_empty(), "every one is well above the kill height (%.0f m) %s" % [map.kill_height, low])
	_expect(crowded.is_empty(), "none within %.1f m of a weapon pickup or another power-up %s" % [MIN_GAP, crowded])
	_expect(items.size() < 2 or width <= 0.0 or spread >= width / 3.0, "spread over the map (furthest apart %.0f m, spawn points spread over %.0f m)" % [spread, width])
	if OS.get_environment("POWERUPS_NO_NAV") == "" and not items.is_empty() and not map.spawns.is_empty():
		await _walk_report(map, items)
	map.queue_free()
	await process_frame


## Prints which spots a bot could walk to from the first spawn point (and back).
func _walk_report(map: MapRoot, items: Array) -> void:
	var region := MapScenery.bake_navigation(map)
	root.add_child(region)
	var nav_map := root.get_world_3d().navigation_map
	var from: Vector3 = map.spawns[0][0]
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and NavigationServer3D.map_get_closest_point(nav_map, from).distance_to(from) < 1.0:
			break
	for it in items:
		var pos: Vector3 = it[0]
		if map.mover_under(pos) >= 0:
			print("    info %s %s: on a moving part (not walked)" % [it[1], pos])
			continue
		var there := NavigationServer3D.map_get_path(nav_map, from, pos, true)
		var back := NavigationServer3D.map_get_path(nav_map, pos, from, true)
		var miss := 99.0 if there.is_empty() else there[there.size() - 1].distance_to(pos)
		var miss_back := 99.0 if back.is_empty() else back[back.size() - 1].distance_to(from)
		var short := maxf(miss, miss_back)
		print("    info %s %s: %s" % [it[1], pos, "walkable" if short <= 1.0 else "not walkable (%.1f m short)" % short])
	region.queue_free()


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
