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
##  - an island that goes down comes back with its building whole.

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
	_check(c.bays.size() == 6 and c.levels() == 3, "six bays, two upper floors and the roof")
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
	_check(c.has_column(corner, 1), "the front corner has a stretch of wall on the first floor")
	var seg: Dictionary = c.segments[c._columns[corner][1]]
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
	_check(int(c.bays[bay].i) == 0 and int(c.bays[bay].j) == 0 and units.size() == 2 and units[0] % 16 == 1,
		"the corner bay, from the first floor up (%s)" % [units])
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
	var roof := _ray(body.transform * Vector3(-12.0, 30.0, 1.0), body.transform * Vector3(-12.0, 12.0, 1.0))
	_check(not roof.is_empty() and (roof.position as Vector3).y > body.transform.origin.y + 18.0, "its roof is back over the corner")
	# And it can come down again.
	for n in need:
		d.damage(cells[n], 10000.0)
	_apply(d)
	_check(not c.flush().is_empty(), "it can be brought down again")
	# The test's way in (--blow-column): the far corner, at the ground.
	_check(c.dev_blow(Vector2i(3, 2), 0) and not c.dev_blow(Vector2i(9, 9), 0), "a corner blown out for a test")
	_apply(d)
	var far := c.flush()
	var far_units: PackedInt32Array = far.events[0].units if not far.is_empty() and not (far.events as Array).is_empty() else PackedInt32Array()
	_check(far_units.size() == 3 and far_units[0] % 16 == 0 and int(c.bays[far_units[0] / 16].i) == 2 and int(c.bays[far_units[0] / 16].j) == 1,
		"takes that corner down from the first floor to the roof (%s)" % [far_units])

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
