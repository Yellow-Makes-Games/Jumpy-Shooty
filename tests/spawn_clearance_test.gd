extends SceneTree
## Every spawn point of every map leaves a player standing clear of the level: the
## robot's capsule, put where the arena puts it (MapRoot.spawns), overlaps nothing
## solid, and there is floor under it within reach.
## Moving parts are checked where they start (the arena's first spawns are there).
## Run: godot --headless --path . --script tests/spawn_clearance_test.gd [-- map_id ...]
## Prints one line per spawn point that is in the ground (or has no floor) with how
## far its floor is above or below the marker.

const MASK := 0xFFFFFFFF & ~(1 << 1)   # everything but players
const RADIUS := 0.4                    # Player.CAPSULE_RADIUS (Player needs the autoloads)
const HEIGHT := 1.8                    # Player.CAPSULE_HEIGHT
const SHRINK := 0.02                   # a capsule just touching the floor is not "in" it
const MAX_DROP := 1.0                  # floor more than this far under the feet: a fall

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	print("Spawn clearance checks")
	for id in Maps.ids():
		if only.is_empty() or id in only:
			await _check_map(id)
	print("FAIL: %d spawn points in the ground" % failures if failures else "PASS: every spawn point is clear")
	quit(1 if failures else 0)


func _check_map(id: String) -> void:
	var map := Maps.make(id)
	if map == null:
		print("  %s: does not load" % id)
		failures += 1
		return
	root.add_child(map)
	map.build()
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var bad := 0
	var least := INF
	for i in map.spawns.size():
		var feet: Vector3 = map.spawns[i][0]
		var r := _probe(space, feet)
		least = minf(least, feet.y - r.floor)
		if not r.ok:
			bad += 1
			print("  %s spawn %d at %s: %s" % [id, i, _v(feet - Vector3(0, 0.2, 0)), r.why])
	print("  %s: %d/%d clear (least gap feet-to-floor %.2f)" % [Maps.name_of(id), map.spawns.size() - bad, map.spawns.size(), least])
	failures += bad
	# A spawn point sunk into its floor (a moving part come up through it): the arena
	# lifts the player out (MapRoot.clear_feet), onto the floor and no higher than it needs.
	if not map.spawns.is_empty():
		var feet: Vector3 = map.spawns[0][0]
		var floor_y: float = _probe(space, feet).floor
		var sunk := Vector3(feet.x, floor_y - 0.6, feet.z)
		var out := map.clear_feet(sunk)
		var r := _probe(space, out)
		if not (r.ok and out.y >= floor_y and out.y - floor_y < 0.4) or not map.clear_feet(feet).is_equal_approx(feet):
			failures += 1
			print("  %s: a spawn point 0.6 m into the floor is put at %+.2f from the floor (%s); one with room moved to %s" % [id, out.y - floor_y, r.why, map.clear_feet(feet)])
	map.queue_free()
	await process_frame


## {ok, why, floor}: is a player standing at `feet` clear of the level?
static func _probe(space: PhysicsDirectSpaceState3D, feet: Vector3) -> Dictionary:
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS - SHRINK
	cap.height = HEIGHT - SHRINK * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = MASK
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, HEIGHT * 0.5, 0))
	var hits := space.intersect_shape(q, 4)
	# The floor: straight down from head height (a ray started inside a block misses it).
	var down := PhysicsRayQueryParameters3D.create(feet + Vector3(0, HEIGHT - 0.05, 0), feet - Vector3(0, 6, 0), MASK)
	var hit := space.intersect_ray(down)
	var floor_y: float = hit.position.y if not hit.is_empty() else -INF
	var marker := feet.y - 0.2
	if not hits.is_empty():
		var names := []
		for h in hits:
			names.append(str((h.collider as Node).name) if h.collider else "?")
		return {"ok": false, "floor": floor_y, "why": "capsule overlaps %s; floor %+.2f from marker" % [", ".join(names), floor_y - marker]}
	if hit.is_empty() or feet.y - floor_y > MAX_DROP:
		return {"ok": false, "floor": floor_y, "why": "no floor within %.1f under the feet" % MAX_DROP}
	return {"ok": true, "floor": floor_y, "why": ""}


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
