extends SceneTree
## Walls that break on islands that fly (Cirrus): fine destruction, bullet marks and
## rubble on a MapIsland, wherever it has gone.
## Run: godot --headless --fixed-fps 60 --path . --script tests/cirrus_destruction_test.gd
##
##  - the buildings' stone walls and floors break small; a shot at a wall lands on the
##    cell it is aimed at where the island is now, not where it sits in the scene;
##  - a wall that rides an island is drawn like the rest of the island (its pattern
##    measured from the island), also once it has holes in it;
##  - a bullet mark, the cracks of a damaged wall and the rubble of a broken one are the
##    island's: they go where it goes;
##  - an island that goes down comes back up mended: whole walls that stop a shot
##    again, no marks, no rubble. The quad never goes down, and what breaks there stays
##    broken.

const ID := "cirrus"
const ISLANDS := ["Observatory", "Labs", "LectureHall", "Cafeteria", "Library"]

var failures := 0
var map: MapRoot
var event: LayoutEvent
var space: PhysicsDirectSpaceState3D


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _run() -> void:
	await process_frame
	map = Maps.make(ID)
	map.destructible = true
	root.add_child(map)
	map.build()
	event = map.get_node_or_null("Layout") as LayoutEvent
	MapDebris.headless_too = true
	for i in 4:
		await physics_frame
	space = root.get_world_3d().direct_space_state
	var d := map.destruction
	var marks := map.marks
	var debris := map.debris
	_check(d != null and d.fine and marks != null and debris != null, "Cirrus breaks small, with marks and rubble")
	if d == null or marks == null or debris == null:
		quit(1)
		return
	var labs := map.get_node("Labs") as MapIsland
	var body := labs._body
	var styles := {}
	for panel in d.panels:
		if panel.fine:
			styles[panel.kind] = panel.style
	_check(styles.get("stone") == "masonry" and styles.get("stone_warm") == "masonry" and styles.get("floor_wood") == "wood",
		"stone goes block by block, the wooden floors board by board (%s)" % [styles])
	# A band of colour round a building lies on many stretches of wall: each has its part.
	var bands := 0
	var over := 0
	for panel in d.panels:
		for skin in panel.skins:
			if String(skin.kind).begins_with("accent_"):
				bands += 1
				var half: Vector3 = panel.size * 0.5
				for a in 3:
					if a != panel.thin and ((skin.box as AABB).position[a] < -half[a] - 0.06 or (skin.box as AABB).end[a] > half[a] + 0.06):
						over += 1
	_check(bands >= 60 and over == 0, "the bands of colour round the buildings break with the wall they lie on (%d lengths)" % bands)

	# The Labs and the Library up, the Labs far out and low: a wall of the Labs.
	_rest(LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.FAR, 1, 1))
	for i in 8:
		await physics_frame
	var home: Transform3D = map.movers[body.get_meta("mover")].base
	_check(body.transform.origin.distance_to(home.origin) > 5.0, "the Labs is not where it sits in the scene")
	var c := _wall_cell(d, body)
	_check(c >= 0, "the Labs has a stone wall that can break")
	if c < 0:
		quit(1)
		return
	var panel: Dictionary = d.panels[d.cells[c].panel]
	var at := d.cell_center(c)
	var normal: Vector3 = d._panel_xf(panel).basis[panel.thin].normalized()
	var hit := _ray(at + normal * 1.5, at - normal * 0.5)
	if hit.is_empty() or d.cell_at(hit.collider, hit.position, hit.normal) != c:
		normal = -normal
		hit = _ray(at + normal * 1.5, at - normal * 0.5)
	_check(not hit.is_empty() and d.cell_at(hit.collider, hit.position, hit.normal) == c, "a shot at a wall lands on the cell it is aimed at")
	_check(map.island_at(at) == labs, "which is out where the island is")

	# A bullet mark is the island's.
	var had: int = marks.counts()[0]
	marks.shot(at + normal * 1.5, hit.position, WeaponData.by_id("rifle"))
	_check(marks.counts()[0] == had + 1, "marks: a round that stops in an island's wall leaves one")
	var slot := (marks._next + BulletMarks.MAX_MARKS - 1) % BulletMarks.MAX_MARKS
	var on_body: bool = marks._mark_on[slot] == body.get_instance_id()
	_check(on_body and marks._mark_cell[slot] == c, "marks: it is the island's, on that cell")
	_check((body.transform * marks._mark_at[slot]).distance_to(hit.position) < 0.05, "marks: and it is where the round stopped")
	var deck := _ray(body.transform * Vector3(0, 3.0, -9.0), body.transform * Vector3(0, -1.0, -9.0))
	_check(not deck.is_empty() and BulletMarks.frame_of(deck.collider) == body, "the island's deck is the island's too")
	if not deck.is_empty():
		had = marks.counts()[0]
		marks.scorch((deck.position as Vector3) + Vector3.UP * 0.3, 3.0)
		_check(marks.counts()[0] > had, "marks: a blast scorches an island's deck")

	# Cracks.
	var cracks: int = marks.counts()[1]
	d.damage(c, d.cells[c].max_hp * 0.5 + panel.armour)
	_apply(d)
	_check(d.cells[c].stage > 0 and not d.is_broken(c) and marks.counts()[1] == cracks + 1, "marks: a damaged wall on an island shows its cracks")

	# A blast: the wall breaks, the rubble lands on the island.
	debris.push_blast(at + normal * 0.4, 4.5)
	d.damage_area(at, 1.6, 400.0)
	var broke := _apply(d)
	_check(d.is_broken(c) and broke > 3, "a blast breaks the wall (%d cells)" % broke)
	_check(marks.counts()[1] <= cracks + broke * 3 and not marks._by_cell.has(c), "marks: the marks on what broke go with it")
	var through := _ray(at + normal * 1.5, at - normal * 0.5)
	_check(through.is_empty() or d.cell_at(through.collider, through.position, through.normal) != c, "a shot goes through the hole")
	_check(debris.counts()[0] > 0, "debris: chunks fly (%d)" % debris.counts()[0])
	await process_frame   # (the wall is redrawn at the end of the frame)
	var drawn := true
	var count := 0
	for mesh in (panel.meshes as Node3D).get_children():
		count += 1   # (the wall itself, and the bands of colour that lie on it)
		var uv2: PackedVector2Array = (mesh as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		if uv2.is_empty() or uv2[0].x < 0.5:   # (the mark MapMesher.riding() puts on a mesh)
			drawn = false
	_check(drawn and count > 0, "a wall with holes in it is drawn with its pattern measured from the island (%d meshes)" % count)
	for n in 1200:
		await physics_frame
		if debris.counts()[0] == 0:
			break
	var lying := debris.lying_on(body)
	_check(debris.counts()[0] == 0 and lying > 0, "debris: rubble comes to rest on the island (%d of %d chunks)" % [lying, debris.counts()[1]])
	var lot: Dictionary = {}
	for key: String in debris._resting:
		if debris._resting[key].frame == body:
			lot = debris._resting[key]
	var chunk_local := Vector3.ZERO
	if not lot.is_empty():
		for xf in lot.xf:
			if xf != null:
				chunk_local = (xf as Transform3D).origin
		var chunk_at := body.transform * chunk_local
		_check(map.island_at(chunk_at) == labs, "debris: a chunk lies on the Labs")

	# The quad: what breaks there stays broken.
	var q := -1
	for i in d.cells.size():
		if q < 0 and not d.cells[i].protected and d.panels[d.cells[i].panel].get("frame") == null and d.panels[d.cells[i].panel].fine:
			q = i
	_check(q >= 0, "the quad has stone that can break")
	if q >= 0:
		d.damage(q, 10000.0)
		_apply(d)
		_check(d.is_broken(q), "and it breaks")

	# The clock tower: its walls break between corners that do not, and the stage that
	# carries the clock faces does not either.
	var wall := _ray(Vector3(-2.8, 12.0, -12.0), Vector3(-2.8, 12.0, -3.0))
	var wall_cell: int = d.cell_at(wall.collider, wall.position, wall.normal) if not wall.is_empty() and (wall.collider as Node).has_meta("panel") else -1
	_check(wall_cell >= 0 and absf((wall.position as Vector3).z + 5.2) < 0.05, "the clock tower's wall can break")
	d.damage_area(Vector3(-2.8, 12.0, -5.2), 1.5, 100000.0)
	_apply(d)
	var tower_hole := _ray(Vector3(-2.8, 12.0, -12.0), Vector3(-2.8, 12.0, -4.5))
	_check(wall_cell >= 0 and d.is_broken(wall_cell) and tower_hole.is_empty(), "a blast makes a hole in it")
	var small := _ray(Vector3(0.0, 5.6, -12.0), Vector3(0.0, 5.6, -3.0))
	_check(not small.is_empty() and (small.collider as Node).has_meta("panel") and absf((small.position as Vector3).z + 5.2) < 0.05,
		"the narrow wall between its window slits can break too")
	for spot: Array in [[Vector3(-4.6, 12.0, -12.0), Vector3(-4.6, 12.0, -3.0), "a corner of the tower"],
			[Vector3(-12.0, 12.0, -4.6), Vector3(-3.0, 12.0, -4.6), "the same corner from the other side"],
			[Vector3(2.9, 23.2, -12.0), Vector3(2.9, 23.2, -3.0), "the stage that carries the clock"]]:
		var middle: Vector3 = ((spot[0] as Vector3) + (spot[1] as Vector3)) * 0.5
		d.damage_area(Vector3(spot[0].x if absf(spot[0].x) < 6.0 else -5.2, spot[0].y, spot[0].z if absf(spot[0].z) < 6.0 else -5.2), 1.5, 100000.0)
		_apply(d)
		var solid := _ray(spot[0], spot[1])
		_check(not solid.is_empty() and not (solid.collider as Node).has_meta("panel") and (solid.position as Vector3).distance_to(middle) < 3.5,
			"%s does not break" % spot[2])

	# The island glides somewhere else: it all goes with it.
	var before := body.transform
	_rest(LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.CLOSE, 0, 0))
	for i in 8:
		await physics_frame
	_check(body.transform.origin.distance_to(before.origin) > 3.0, "the Labs has moved (%.1f m)" % body.transform.origin.distance_to(before.origin))
	_check(d.is_broken(c) and d.cell_center(c).distance_to(body.transform * (before.affine_inverse() * at)) < 0.01, "the hole went with it")
	var far_side := _ray(d.cell_center(c) + body.transform.basis * (before.basis.inverse() * normal) * 1.5,
		d.cell_center(c) - body.transform.basis * (before.basis.inverse() * normal) * 0.5)
	_check(far_side.is_empty() or d.cell_at(far_side.collider, far_side.position, far_side.normal) != c, "and a shot still goes through it")
	_check(debris.lying_on(body) == lying and map.island_at(body.transform * chunk_local) == labs, "debris: the rubble went with it")
	var riding_nodes := 0
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			riding_nodes += 1
	_check(riding_nodes >= 3, "the marks, cracks and rubble are drawn from the island (%d batches)" % riding_nodes)

	# It goes down, and comes back up mended.
	var broken_before := d.broken_count()
	_rest(LayoutEvent.pack(_pair("Observatory", "Library"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 8:
		await physics_frame
	_check(labs.is_parked() and d.is_broken(c), "down below, the Labs is parked (and still as it was)")
	var parked_solid := false
	for child in body.get_children():
		if child is CollisionObject3D and (child as CollisionObject3D).collision_layer != 0:
			parked_solid = true
	_check(not parked_solid and body.collision_layer == 0, "and nothing of it is there to hit")
	_rest(LayoutEvent.pack(_pair("Labs", "Observatory"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 8:
		await physics_frame
	await process_frame
	_check(not labs.is_parked() and not d.is_broken(c) and d.cells[c].stage == 0, "back up, the wall is whole")
	_check(is_equal_approx(d.cells[c].hp, d.cells[c].max_hp), "with all its strength")
	var left := 0
	for i in d._damaged:
		if d.panels[d.cells[i].panel].get("frame") == body:
			left += 1
	_check(left == 0 and d.broken_count() < broken_before, "nothing on the Labs is damaged (%d cells broken before, %d now)" % [broken_before, d.broken_count()])
	at = d.cell_center(c)
	normal = d._panel_xf(panel).basis[panel.thin].normalized()
	var again := _ray(at + normal * 1.5, at - normal * 0.5)
	if again.is_empty() or d.cell_at(again.collider, again.position, again.normal) != c:
		again = _ray(at - normal * 1.5, at + normal * 0.5)
	_check(not again.is_empty() and d.cell_at(again.collider, again.position, again.normal) == c, "and it stops a shot again")
	_check((panel.body as Node).get_child_count() == 1, "a mended wall collides as one box again")
	var on_labs := 0
	for s in BulletMarks.MAX_MARKS:
		if marks._shown[s] == 1 and marks._mark_on[s] == body.get_instance_id():
			on_labs += 1
	var cracked := 0
	for pair in BulletMarks.MAX_CRACKS:
		if marks._crack_of[pair] != -1 and marks._crack_on[pair] == body.get_instance_id():
			cracked += 1
	_check(on_labs == 0 and cracked == 0, "marks: no marks or cracks are left on it")
	_check(debris.lying_on(body) == 0, "debris: and no rubble")
	if q >= 0:
		_check(d.is_broken(q), "what broke on the quad is still broken")
	# An island that does not mend keeps its damage.
	labs.mends = false
	d.damage(c, 10000.0)
	_apply(d)
	_rest(LayoutEvent.pack(_pair("Observatory", "Library"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 4:
		await physics_frame
	_rest(LayoutEvent.pack(_pair("Labs", "Observatory"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 4:
		await physics_frame
	_check(d.is_broken(c), "an island set not to mend comes back as it went")

	print("FAIL: %d checks failed" % failures if failures else "PASS")
	quit(1 if failures else 0)


## The host's changes, done here as every copy does them. Returns how many cells broke.
func _apply(d: MapDestruction) -> int:
	var change := d.flush()
	if change.is_empty():
		return 0
	return d.apply(change[0], change[1]).size()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


## A cell of a stone wall that rides `body`, can break, and has whole wall all round it.
func _wall_cell(d: MapDestruction, body: Node3D) -> int:
	for panel: Dictionary in d.panels:
		if panel.get("frame") != body or not panel.fine or panel.kind != "stone" or panel.thin == 1:
			continue
		if panel.nu < 7 or panel.nv < 7:
			continue
		var n: Vector3i = panel.n
		var ijk := Vector3i(n.x / 2, n.y / 2, n.z / 2)
		var c: int = int(panel.first) + ijk.x + n.x * (ijk.y + n.y * ijk.z)
		if not d.cells[c].protected:
			return c
	return -1


## The number of the pair made of these two islands (1.. in event.sets()).
func _pair(a: String, b: String) -> int:
	var want := [ISLANDS.find(a), ISLANDS.find(b)]
	want.sort()
	return event.sets().find(want) + 1


## Puts the map in an arrangement, at rest, the clock stopped.
func _rest(config: int) -> void:
	event.running = false
	event.elapsed = 0.0
	event.state = config | (config << LayoutEvent.BITS)
	event._place()
