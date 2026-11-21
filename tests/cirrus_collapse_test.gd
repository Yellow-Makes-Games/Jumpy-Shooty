extends SceneTree
## Buildings that come down on islands that fly (Cirrus): a MapFrame inside a MapIsland,
## held up by its walls.
## Run: godot --headless --fixed-fps 60 --path . --script tests/cirrus_collapse_test.gd
##
##  - each of the five buildings has a collapse of its own, riding its island, with
##    stretches of wall for columns;
##  - breaking some of a stretch brings nothing down; breaking enough of a corner's
##    brings down the bay over it, from that storey up, where the island is now;
##  - the pieces fall, come to rest on the island and become a pile that is the
##    island's: it goes where the island goes;
##  - an island that goes down comes back with its building whole;
##  - nothing of a building is kept from breaking: what stands on a floor that is shot
##    away goes with it, nobody spawns there, the domes break as whole blocks, and the
##    ground floor comes down when its walls go, so a building can be levelled;
##  - the plinth round a building stops at its doorways.

const ISLANDS := ["Observatory", "Labs", "LectureHall", "Cafeteria", "Library"]

var failures := 0
var map: MapRoot
var event: LayoutEvent


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
	map = Maps.make("cirrus")
	map.destructible = true
	root.add_child(map)
	map.build()
	event = map.get_node_or_null("Layout") as LayoutEvent
	for i in 4:
		await physics_frame
	var d := map.destruction
	_check(map.collapses.size() == 5, "each of the five buildings can come down (%d)" % map.collapses.size())
	var library := map.get_node("Library") as MapIsland
	var body := library._body
	var c: MapCollapse = null
	for other in map.collapses:
		_check(other.on != null and other.get_parent() == other.on and other.index == map.collapses.find(other),
			"collapse %d rides its island" % other.index)
		if other.on == body:
			c = other
	if c == null:
		_check(false, "the Library has one")
		quit(1)
		return
	var walls := c.segments.filter(func(seg): return seg.has("cells"))
	_check(walls.size() >= 20 and walls.size() == c.segments.size(), "it stands on its walls: %d stretches, no columns" % walls.size())
	_check(c.bays.size() == 6 and c.levels() == 4, "six bays; the ground floor, two upper floors and the roof")
	# Nothing of the five buildings is kept from breaking, and their domes break too.
	var guarded := 0
	var domes := 0
	for panel: Dictionary in d.panels:
		if panel.get("frame") == null:
			continue
		if panel.whole and panel.kind in ["dome_copper", "roof_terracotta"] and is_equal_approx(d.cells[panel.first].max_hp, 1500.0):
			domes += 1
		var n: Vector3i = panel.n
		for cell in range(int(panel.first), int(panel.first) + n.x * n.y * n.z):
			if d.cells[cell].protected:
				guarded += 1
	_check(guarded == 0, "no wall, floor or roof of a building is kept from breaking (%d pieces are)" % guarded)
	_check(domes == 2, "the Observatory's dome and the Lecture Hall's roof break as whole blocks (%d)" % domes)
	# A cornice runs the length of the building: each bay has its own stretch of it.
	var crossing := 0
	var stretches := 0
	for b: Dictionary in c.bays:
		for level: Array in b.loose:
			for piece: Dictionary in level:
				if not (piece.shape in ["box", "bevel"]) or piece.has("with"):
					continue
				stretches += 1
				var box: AABB = (piece.xf as Transform3D) * AABB(-(piece.size as Vector3) * 0.5, piece.size)
				for x in [c.frame.lines_x[1], c.frame.lines_x[2]]:
					if box.position.x < x - 0.1 and box.end.x > x + 0.1:
						crossing += 1
				if box.position.z < c.frame.lines_z[1] - 0.1 and box.end.z > c.frame.lines_z[1] + 0.1:
					crossing += 1
	_check(crossing == 0 and stretches > 20, "no cornice, band or parapet runs from one bay into the next (%d cross a line)" % crossing)

	# Out where the island is.
	_rest(LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.FAR, 1, 1))
	for i in 8:
		await physics_frame
	var corner := Vector2i(0, 0)
	# The plinth round the building stops at its doorways: there is wall behind all of it.
	var bare := 0
	var plinths := 0
	for node: Node in library.get_node("Building/Shell").get_children():
		var block := node as MapBlock
		if block == null or not String(block.name).begins_with("Plinth"):
			continue
		plinths += 1
		var along := Vector3.RIGHT if block.size.x > block.size.z else Vector3.BACK
		var length := maxf(block.size.x, block.size.z)
		var inward := (body.transform.origin + body.transform.basis * Vector3(0, 0, 6.1) - block.global_position) * Vector3(1, 0, 1)
		inward = (inward - inward.project(block.global_transform.basis * along)).normalized()
		var steps := int(length / 0.4)
		for n in range(1, steps):
			var at := block.global_transform * (along * (-length * 0.5 + n * length / steps))
			if _ray(at - inward * 0.5, at + inward * 0.8).is_empty():
				bare += 1
	_check(bare == 0 and plinths > 4, "the plinth stops at the doorways: wall behind all of it (%d pieces, %d places without)" % [plinths, bare])

	# A floor shot away from under a thing: the thing goes, and nobody spawns there.
	var thing: Dictionary = {}
	for b: Dictionary in c.bays:
		if int(b.i) > 0:   # (not the corner this test brings down)
			for level: Array in b.loose:
				for piece: Dictionary in level:
					var rests: PackedInt32Array = piece.rests
					if thing.is_empty() and piece.solid and rests.size() >= 4 and int(d.panels[d.cells[rests[0]].panel].thin) == 1:
						thing = piece
	_check(not thing.is_empty(), "a solid thing stands on a floor that can break")
	if not thing.is_empty():
		var under: PackedInt32Array = thing.rests
		var need_gone := ceili(under.size() * c.frame.rests_share)
		for n in need_gone - 1:
			d.damage(under[n], 10000.0)
		_apply(d)
		await physics_frame
		_check(not thing.get("lost", false), "with %d of the %d pieces under it gone it stands" % [need_gone - 1, under.size()])
		d.damage(under[need_gone - 1], 10000.0)
		_apply(d)
		await physics_frame
		_check(thing.get("lost", false), "one more and it goes with them")
		var where: Vector3 = body.transform * ((thing.xf as Transform3D).origin)
		var hit := _ray(where + Vector3(0, 0.05, 0), where - Vector3(0, 0.05, 0))
		_check(hit.is_empty(), "and it is no longer there to stand on")
	var spawn := body.transform * Vector3(-10.0, 5.7, 3.0)   # (one of the Library's, on its first floor)
	_check(not map.under_rubble(spawn), "a spawn point on an upper floor is open while the floor is there")
	d.damage_area(spawn - Vector3(0, 0.3, 0), 1.2, 100000.0)
	_apply(d)
	_check(map.under_rubble(spawn), "and closed once the floor under it is shot away")

	_check(c.has_column(corner, 2), "the front corner has a stretch of wall on the first floor")
	var seg: Dictionary = c.segments[c._columns[corner][2]]
	var cells: PackedInt32Array = seg.cells
	var need := ceili(cells.size() * c.frame.wall_share)
	# Not enough of it: nothing comes down.
	for n in need - 1:
		d.damage(cells[n], 10000.0)
	_apply(d)
	_check(c.flush().is_empty() and c.events.is_empty(), "with %d of its %d pieces gone the wall still holds" % [need - 1, cells.size()])
	var whole_before := d.broken_count()
	# One more.
	d.damage(cells[need - 1], 10000.0)
	_apply(d)
	var out := c.flush()
	_check(not out.is_empty() and (out.events as Array).size() == 1, "one more and the bay over it is coming down")
	if out.is_empty() or (out.events as Array).is_empty():
		quit(1)
		return
	var ev: Dictionary = out.events[0]
	var units: PackedInt32Array = ev.units
	var bay := units[0] / 16
	_check(int(ev.id) / MapCollapse.EVENTS_EACH == c.index and map.collapse_of(int(ev.id)) == c, "the collapse's number says whose it is")
	_check(int(c.bays[bay].i) == 0 and int(c.bays[bay].j) == 0 and units.size() == 3 and units[0] % 16 == 1,
		"the corner bay, from the first floor's walls up: the floor they stood on stays (%s)" % [units])
	c.apply_columns(out.columns[0], out.columns[1])
	c.start(ev)
	c.host(int(ev.id))
	var rested := PackedByteArray()
	c.rest_out.connect(func(_id: int, data: PackedByteArray): rested = data)
	var down := [false]
	c.settled.connect(func(_id: int, _key: String): down[0] = true)
	var e: Dictionary = c.events[0]
	for n in 400:
		await physics_frame
		if int(e.state) == MapCollapse.FALLING:
			break
	_check(int(e.state) == MapCollapse.FALLING and (e.pieces as Array).size() > 10, "after the warning it lets go (%d pieces)" % (e.pieces as Array).size())
	var made := (e.pieces as Array).filter(func(p): return p.body != null).size()
	var fallen := 0
	for unit in units:
		for cell: int in c._unit_cells.get(unit, PackedInt32Array()):
			if int(d.cells[cell].stage) == MapDestruction.FALLEN:
				fallen += 1
	_check(fallen > 100, "its walls, floor and roof are no longer part of the building (%d pieces of them)" % fallen)
	# A piece is where the island is.
	var where := Vector3.ZERO
	for p: Dictionary in e.pieces:
		if p.body:
			where = (p.body as Node3D).global_transform * (p.c as Vector3)
	_check(map.island_at(where) == library, "the pieces are out where the island is")
	_check(c.blocked(body.transform * Vector3(-12.0, 0.2, 1.0)) and not c.blocked(body.transform * Vector3(12.0, 0.2, 10.0)),
		"nobody is put under the bay that fell")
	for n in 3600:
		await physics_frame
		if down[0]:
			break
	_check(down[0] and int(e.state) == MapCollapse.DOWN, "the pieces come to rest")
	var heap := e.get("heap") as Node3D
	_check(heap != null and heap.get_parent() == c, "the pile is the island's")
	if heap == null:
		quit(1)
		return
	var pile := heap.get_node("Collision") as PhysicsBody3D
	_check(pile is AnimatableBody3D and pile.get_child_count() > 10, "and solid (%d shapes)" % pile.get_child_count())
	var on_island := 0
	var shapes := 0
	for shape: Node3D in pile.get_children():
		shapes += 1
		var at: Vector3 = shape.global_transform * _middle((shape as CollisionShape3D).shape)
		if map.island_at(at) == library and at.y > body.transform.origin.y - 1.0:
			on_island += 1
		elif OS.has_environment("SHOW"):
			print("      off: ", (body.transform.affine_inverse() * at).snapped(Vector3.ONE * 0.1), " island ", map.island_at(at))
	_check(on_island == shapes and shapes > 20, "all of it lies on the island: what fell off the edge is gone (%d of %d shapes, from %d pieces)" % [on_island, shapes, made])
	# The walls of the top floor toppled: they are not a stack of loose blocks where they stood.
	var stacked := 0
	for shape: Node3D in pile.get_children():
		var at: Vector3 = body.transform.affine_inverse() * (shape.global_transform * _middle((shape as CollisionShape3D).shape))
		if at.y > 13.0 and (absf(at.x + 14.0) < 0.4 or absf(at.z + 1.4) < 0.4):
			stacked += 1
	_check(stacked * 10 < shapes, "the walls above toppled, they did not stay standing as loose blocks (%d of %d still up there)" % [stacked, shapes])

	# The island glides: the pile goes with it.
	var first := (pile.get_child(0) as Node3D).global_transform * _middle((pile.get_child(0) as CollisionShape3D).shape)
	var before := body.transform
	_rest(LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.CLOSE, 0, 0))
	for i in 8:
		await physics_frame
	var now := (pile.get_child(0) as Node3D).global_transform * _middle((pile.get_child(0) as CollisionShape3D).shape)
	_check(body.transform.origin.distance_to(before.origin) > 3.0 and now.distance_to(body.transform * (before.affine_inverse() * first)) < 0.01,
		"the island moves and the pile goes with it")

	# Down and back: the building is whole.
	_rest(LayoutEvent.pack(_pair("Observatory", "Labs"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 8:
		await physics_frame
	_check(library.is_parked() and pile.collision_layer == 0, "parked below, nothing of the pile is there to hit")
	_rest(LayoutEvent.pack(_pair("Observatory", "Library"), LayoutEvent.Kind.SWAP, 0, 0))
	for i in 8:
		await physics_frame
	await process_frame
	var left := 0
	for i in d._damaged:
		if d.panels[d.cells[i].panel].get("frame") == body:
			left += 1
	_check(c.events.is_empty() and not is_instance_valid(heap) or heap.is_queued_for_deletion(), "back up, the pile is gone")
	_check(left == 0 and int(c.bays[bay].from) == c.levels() and int(seg.stage) == 0, "and the building is whole (%d pieces broken before)" % whole_before)
	_check(not thing.get("lost", false) and not map.under_rubble(body.transform * Vector3(-10.0, 5.7, 3.0)), "what went with its floor is back, and the spawn point is open")
	var roof := _ray(body.transform * Vector3(-12.0, 30.0, 1.0), body.transform * Vector3(-12.0, 12.0, 1.0))
	_check(not roof.is_empty() and (roof.position as Vector3).y > body.transform.origin.y + 18.0, "its roof is back over the corner")
	# And it can come down again.
	for n in need:
		d.damage(cells[n], 10000.0)
	_apply(d)
	_check(not c.flush().is_empty(), "it can be brought down again")
	# The test's way in (--blow-column): the far corner, at the ground.
	_check(c.dev_blow(Vector2i(3, 2), 1) and not c.dev_blow(Vector2i(9, 9), 1), "a corner's ground-floor wall blown out for a test")
	_apply(d)
	var far := c.flush()
	var far_units: PackedInt32Array = far.events[0].units if not far.is_empty() and not (far.events as Array).is_empty() else PackedInt32Array()
	_check(far_units.size() == 4 and far_units[0] % 16 == 0 and int(c.bays[far_units[0] / 16].i) == 2 and int(c.bays[far_units[0] / 16].j) == 1,
		"takes that corner down from the ground to the roof (%s)" % [far_units])

	print("FAIL: %d checks failed" % failures if failures else "PASS")
	quit(1 if failures else 0)


## The middle of a piece's shape, in the shape's own frame (a piece of wall is a lump
## of corners where it stood, not round its node's origin).
func _middle(shape: Shape3D) -> Vector3:
	var hull := shape as ConvexPolygonShape3D
	if hull == null or hull.points.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for point in hull.points:
		sum += point
	return sum / hull.points.size()


func _apply(d: MapDestruction) -> int:
	var change := d.flush()
	if change.is_empty():
		return 0
	return d.apply(change[0], change[1]).size()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _pair(a: String, b: String) -> int:
	var want := [ISLANDS.find(a), ISLANDS.find(b)]
	want.sort()
	return event.sets().find(want) + 1


func _rest(config: int) -> void:
	event.running = false
	event.elapsed = 0.0
	event.state = config | (config << LayoutEvent.BITS)
	event._place()
