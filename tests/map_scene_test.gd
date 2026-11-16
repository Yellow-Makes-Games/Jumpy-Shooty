extends SceneTree
## Checks the map scenes and the pieces they are made of:
##  - every map in the list loads, builds collision and meshes, has enough spawn
##    points inside its bounds, and every block's kind has a colour in the palette;
##  - a block's scale is folded into its size, and a hidden block is left out;
##  - the resize handles' face moves keep the opposite face in place.
## Run: godot --headless --path . --script tests/map_scene_test.gd

var failures := 0


func _initialize() -> void:
	print("Map scene checks")
	for id in Maps.ids():
		_check_map(id)
	_check_blocks()
	_check_face_moves()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _check_map(id: String) -> void:
	print("  %s" % Maps.name_of(id))
	var map := Maps.make(id)
	_expect(map != null, "loads as a MapRoot")
	if map == null:
		return
	root.add_child(map)
	var pieces := map.collect_pieces()
	var unknown := {}
	for p in pieces:
		if not map.palette.colors.has(p.kind):
			unknown[p.kind] = true
	_expect(unknown.is_empty(), "every block kind has a colour in the palette%s" % ("" if unknown.is_empty() else " (missing: %s)" % ", ".join(unknown.keys())))
	map.build()
	var shapes := map.get_node("Collision").get_child_count()
	var meshes := map.find_children("Mesh_*", "MeshInstance3D", false, false).size()
	_expect(shapes > 0 and meshes > 0, "builds %d collision shapes and %d merged meshes from %d blocks" % [shapes, meshes, pieces.size()])
	_expect(map.spawns.size() >= 8, "%d spawn points (the arena needs at least 8)" % map.spawns.size())
	var outside := 0
	for s in map.spawns:
		if map.bounds.has_area() and not map.bounds.has_point(Vector2(s[0].x, s[0].z)):
			outside += 1
	_expect(outside == 0, "every spawn point is inside the map's bounds")
	_expect(map.find_children("*", "WorldEnvironment", true, false).size() == 1, "has one WorldEnvironment (sky and ambient light)")
	map.free()


func _check_blocks() -> void:
	print("  blocks")
	var map := MapRoot.new()
	var group := Node3D.new()
	group.position = Vector3(10, 0, 0)
	group.rotation.y = PI / 2.0
	map.add_child(group)
	var block := MapBlock.new()
	block.size = Vector3(2, 1, 4)
	block.position = Vector3(0, 0.5, 3)
	block.scale = Vector3(2, 1, 1)
	group.add_child(block)
	var hidden := MapBlock.new()
	hidden.visible = false
	group.add_child(hidden)
	var spawn := MapSpawn.new()
	spawn.position = Vector3(5, 0, 5)
	spawn.rotation.y = 1.0
	map.add_child(spawn)
	var pieces := map.collect_pieces()
	_expect(pieces.size() == 1, "a hidden block is left out (%d pieces)" % pieces.size())
	if pieces.size() == 1:
		var p: Dictionary = pieces[0]
		_expect(p.size.is_equal_approx(Vector3(4, 1, 4)), "scale is folded into the size (%s)" % p.size)
		_expect(p.xf.origin.is_equal_approx(Vector3(13, 0.5, 0)), "placed through its group (at %s)" % p.xf.origin)
		_expect(p.xf.basis.get_scale().is_equal_approx(Vector3.ONE), "the piece's frame is unscaled")
	map.build(false)
	_expect(map.spawns.size() == 1 and absf(map.spawns[0][1] - 1.0) < 0.001 and is_equal_approx(map.spawns[0][0].y, 0.2),
		"a spawn point gives its position (lifted 0.2 m) and the way it faces")
	map.free()


func _check_face_moves() -> void:
	print("  resize handles")
	var b := MapBlock.new()
	b.size = Vector3(2, 2, 2)
	b.move_face(0, 3.0, 0.1)   # +x face out to 3 m from the centre
	_expect(b.size.is_equal_approx(Vector3(4, 2, 2)) and b.position.is_equal_approx(Vector3(1, 0, 0)),
		"dragging the +x face grows the box that way only (size %s, centre %s)" % [b.size, b.position])
	b.move_face(3, 0.5, 0.1)   # bottom face up to 0.5 m below the centre
	_expect(is_equal_approx(b.size.y, 1.5) and is_equal_approx(b.position.y, 0.25),
		"dragging the bottom face up keeps the top in place (height %.2f, centre %.2f)" % [b.size.y, b.position.y])
	b.move_face(1, 2.04, 0.1)
	_expect(is_equal_approx(b.size.x, 4.0), "sizes snap to the step (width %.2f)" % b.size.x)
	b.rotation.y = PI / 2.0
	b.position = Vector3.ZERO
	b.move_face(4, 2.0, 0.1)   # +z face of a turned box moves along world x
	_expect(is_equal_approx(b.size.z, 3.0) and b.position.is_equal_approx(Vector3(0.5, 0, 0)),
		"a turned box grows along its own axis (centre %s)" % b.position)
	var c := MapBlock.new()
	c.shape = MapBlock.Shape.CYLINDER
	c.move_face(0, 1.5, 0.1)
	_expect(c.size.is_equal_approx(Vector3(3, 1, 3)) and c.position == Vector3.ZERO, "a cylinder's side handle sets its diameter")
	b.free()
	c.free()


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
