extends SceneTree
## The map tools (addons/map_tools/map_ops.gd) and the parametric pieces (MapStairs,
## MapRamp, MapRow, MapRing), without the editor:
##  - the grid steps and snaps;
##  - Hollow keeps a box's outside and makes six walls that do not overlap;
##  - Clip's two halves add up to the block, and only shapes that can be cut are;
##  - a mirror twice over is where it started, never scales by -1, and carries a group;
##  - arrays in a line and round a circle;
##  - face snapping picks the nearest face of a neighbour square to the block;
##  - each piece makes the blocks its numbers say, and makes them again when they change;
##  - a prefab saved and placed is plain blocks with no tie to its file, and builds.
## Run: godot --headless --path . --script tests/map_tools_test.gd

const MapOps := preload("res://addons/map_tools/map_ops.gd")

var failures := 0


func _initialize() -> void:
	print("Map tools checks")
	_check_grid()
	_check_hollow()
	_check_clip()
	_check_mirror()
	_check_array()
	_check_snapping()
	_check_pieces()
	_check_prefab()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _block(parent: Node, at: Vector3, size: Vector3, kind := "concrete") -> MapBlock:
	var b := MapBlock.new()
	b.kind = kind
	b.size = size
	b.position = at
	parent.add_child(b)
	return b


func _volume(blocks: Array) -> float:
	var v := 0.0
	for b: MapBlock in blocks:
		v += b.size.x * b.size.y * b.size.z
	return v


func _check_grid() -> void:
	print("  grid")
	_expect(is_equal_approx(MapOps.snap(1.26, 0.25), 1.25) and is_equal_approx(MapOps.snap(-0.44, 0.1), -0.4), "a length snaps to the nearest grid line")
	_expect(is_equal_approx(MapOps.grid_step(0.5, 1), 1.0) and is_equal_approx(MapOps.grid_step(0.5, -1), 0.25), "] and [ step the grid up and down")
	_expect(is_equal_approx(MapOps.grid_step(4.0, 1), 4.0) and is_equal_approx(MapOps.grid_step(0.1, -1), 0.1), "the grid stops at its largest and smallest size")
	var box := MapOps.box_between(Vector3(2, 0, 3), Vector3(-1, 0, 5), 0.5)
	_expect((box[1] as Vector3).is_equal_approx(Vector3(3, 0.5, 2)) and (box[0] as Vector3).is_equal_approx(Vector3(0.5, 0.25, 4)), "a box drawn between two corners is never flat")


func _check_hollow() -> void:
	print("  hollow")
	var map := MapRoot.new()
	root.add_child(map)
	var b := _block(map, Vector3(3, 2, -4), Vector3(8, 4, 6), "drywall")
	b.rotation.y = 0.5
	b.tint = Color(0.9, 0.9, 0.9)
	var room := MapOps.hollow(b, 0.5)
	_expect(room != null and room.get_child_count() == 6, "a box becomes six walls")
	if room:
		map.add_child(room)
		var walls := MapOps.blocks_in(room)
		_expect(room.transform.is_equal_approx(b.transform) and room.get_meta("_edit_group_", false), "the room is a selection group where the block was")
		var inside := 7.0 * 3.0 * 5.0
		_expect(is_equal_approx(_volume(walls), 8.0 * 4.0 * 6.0 - inside), "the walls fill the box less the room inside (no overlaps)")
		var bounds := MapOps.bounds_of([room])
		var before := MapOps.bounds_of([b])
		_expect(bounds.position.is_equal_approx(before.position) and bounds.size.is_equal_approx(before.size), "the outside is the same size")
		_expect(walls.all(func(w: MapBlock) -> bool: return w.kind == "drywall" and w.tint == b.tint), "every wall keeps the block's kind and tint")
		var open := MapOps.hollow(b, 0.5, true, true)
		_expect(open.get_child_count() == 4 and MapOps.blocks_in(open).all(func(w: MapBlock) -> bool: return is_equal_approx(w.size.y, 4.0)),
			"with no floor and an open top, four walls the full height")
		open.free()
	_expect(MapOps.hollow(b, 2.0) == null, "walls too thick for the box are refused")
	b.shape = MapBlock.Shape.CYLINDER
	_expect(MapOps.hollow(b, 0.5) == null, "only boxes are hollowed")
	map.free()


func _check_clip() -> void:
	print("  clip")
	var map := MapRoot.new()
	root.add_child(map)
	var b := _block(map, Vector3(10, 1, 0), Vector3(6, 2, 4), "steel")
	b.rotation.y = PI / 2.0
	b.solid = false
	var parts := MapOps.clip(b, 0, 1.0)
	_expect(parts.size() == 2, "a box is cut in two")
	if parts.size() == 2:
		_expect(is_equal_approx(parts[0].size.x, 4.0) and is_equal_approx(parts[1].size.x, 2.0), "the halves' lengths add up (4 m + 2 m of 6 m)")
		for p in parts:
			map.add_child(p)
		var far_before: Vector3 = b.transform * Vector3(-3, 0, 0)
		var far_after: Vector3 = parts[0].transform * Vector3(-2, 0, 0)
		var cut_a: Vector3 = parts[0].transform * Vector3(2, 0, 0)
		var cut_b: Vector3 = parts[1].transform * Vector3(-1, 0, 0)
		_expect(far_before.is_equal_approx(far_after) and cut_a.is_equal_approx(cut_b) and cut_a.is_equal_approx(b.transform * Vector3(1, 0, 0)),
			"the outer faces stay put and the halves meet at the cut")
		_expect(parts.all(func(p: MapBlock) -> bool: return p.kind == "steel" and not p.solid), "both halves keep the block's settings")
	_expect(MapOps.clip(b, 0, 3.0).is_empty() and MapOps.clip(b, 0, -5.0).is_empty(), "a cut that misses the block does nothing")
	b.shape = MapBlock.Shape.CYLINDER
	var discs := MapOps.clip(b, 1, 0.0)
	_expect(MapOps.clip(b, 0, 0.0).is_empty() and discs.size() == 2, "a cylinder is only cut across its height")
	for p in discs:
		p.free()
	b.shape = MapBlock.Shape.CONE
	_expect(MapOps.clip(b, 1, 0.0).is_empty(), "a cone is not cut")
	map.free()


func _check_mirror() -> void:
	print("  mirror")
	var map := MapRoot.new()
	root.add_child(map)
	var group := Node3D.new()
	group.position = Vector3(8, 0, 3)
	group.rotation.y = 0.4
	map.add_child(group)
	var wedge := _block(group, Vector3(1, 1, 2), Vector3(2, 2, 4))
	wedge.shape = MapBlock.Shape.WEDGE
	wedge.rotation.y = 0.3
	var copy := MapOps.mirrored_copy(group, 0, Vector3.ZERO)
	map.add_child(copy)
	var cw := MapOps.blocks_in(copy)[0]
	var want: Vector3 = MapOps.global_of(wedge).origin * Vector3(-1, 1, 1)
	_expect(MapOps.global_of(cw).origin.is_equal_approx(want), "a block in a mirrored group lands at the mirror of where it was")
	# The wedge's tall side is its -z: mirrored across x, that direction's x flips.
	var back: Vector3 = MapOps.global_of(wedge).basis * Vector3(0, 0, -1)
	var back_copy: Vector3 = MapOps.global_of(cw).basis * Vector3(0, 0, -1)
	_expect(back_copy.is_equal_approx(back * Vector3(-1, 1, 1)), "and faces the mirrored way")
	_expect(MapOps.global_of(cw).basis.determinant() > 0.0 and copy.transform.basis.determinant() > 0.0, "nothing is scaled by -1")
	var twice := MapOps.mirrored_copy(copy, 0, Vector3.ZERO)
	map.add_child(twice)
	_expect(MapOps.global_of(MapOps.blocks_in(twice)[0]).is_equal_approx(MapOps.global_of(wedge)), "mirrored twice it is back where it started")
	var plan := MapOps.mirror_plan(group, 2, Vector3(0, 0, 10))
	for step in plan:
		(step[0] as Node3D).transform = step[1]
	_expect(is_equal_approx(MapOps.global_of(group).origin.z, 17.0) and plan.size() == 2, "mirroring in place across z = 10 moves the group and what is in it")
	map.free()


func _check_array() -> void:
	print("  array")
	var map := MapRoot.new()
	root.add_child(map)
	var holder := Node3D.new()
	holder.position = Vector3(0, 5, 0)
	map.add_child(holder)
	var b := _block(holder, Vector3(10, 0, 0), Vector3(1, 3, 1))
	var line := MapOps.array_line(b, 3, Vector3(0, 0, 2))
	_expect(line.size() == 3 and line[2].position.is_equal_approx(Vector3(10, 0, 6)), "three copies in a line, 2 m apart")
	for n in line:
		n.free()
	var ring := MapOps.array_ring(b, 4, Vector3(0, 0, 0))
	_expect(ring.size() == 3, "four round a circle is three copies")
	if ring.size() == 3:
		holder.add_child(ring[1])
		_expect(MapOps.global_of(ring[1]).origin.is_equal_approx(Vector3(-10, 5, 0)), "the one opposite is across the pivot, at the same height")
		var facing: Vector3 = MapOps.global_of(ring[1]).basis.x
		_expect(facing.is_equal_approx(Vector3(-1, 0, 0)), "and is turned half way round")
		ring[0].free()
		ring[2].free()
	map.free()


func _check_snapping() -> void:
	print("  face snapping")
	var map := MapRoot.new()
	root.add_child(map)
	var wall := _block(map, Vector3(5, 1.5, 0), Vector3(1, 3, 8))        # its near face is at x = 4.5
	var turned := _block(map, Vector3(3.3, 1, 0), Vector3(1, 2, 1))
	turned.rotation.y = 0.5                                              # not square: never snapped to
	var far := _block(map, Vector3(4.4, 1, 30), Vector3(1, 2, 1))        # square, but nowhere near
	var mover := _block(map, Vector3(3.37, 1, 1), Vector3(2, 2, 2))      # its far face is at x = 4.37
	var frame: Transform3D = MapOps.box_of(mover)[0]
	var others := MapOps.boxes_in_frame(frame, [wall, turned, far])
	_expect(others.size() == 2, "a block turned another way is left out")
	var box: AABB = MapOps.boxes_in_frame(frame, [mover])[0]
	var result := MapOps.snap_move(box, others, 0.25)
	var move: Vector3 = result[0]
	_expect(is_equal_approx(move.x, 0.13) and result[1].x == 1, "a block 0.13 m short of a wall snaps against it (moved %.2f)" % move.x)
	_expect(is_zero_approx(move.z) and result[1].z == 0, "and is not pulled toward a block that is not beside it")
	_expect(MapOps.snap_move(box, others, 0.1)[1] == Vector3i.ZERO, "nothing within reach: no snap")
	var quarter := _block(map, Vector3(-6, 1, 0), Vector3(2, 2, 6))
	quarter.rotation.y = PI / 2.0                                        # a quarter turn is still square: 6 m along x
	var seen := MapOps.boxes_in_frame(frame, [quarter])
	_expect(seen.size() == 1 and seen[0].size.is_equal_approx(Vector3(6, 2, 2)), "a block a quarter turn round still counts, measured the way it lies")
	var d := MapOps.snap_face(box, 0, 1.0, others, 0.25)
	_expect(is_equal_approx(d, 0.13), "a dragged face snaps to the wall's face")
	_expect(MapOps.snap_face(box, 0, -1.0, others, 0.25) == INF, "the face on the other side has nothing to snap to")
	map.free()


func _check_pieces() -> void:
	print("  pieces")
	var map := MapRoot.new()
	root.add_child(map)
	var stairs := MapStairs.new()
	stairs.rise = 3.0
	stairs.run = 6.0
	stairs.step_height = 0.25
	map.add_child(stairs)
	stairs.rebuild()
	var made := stairs.generated()
	_expect(stairs.steps() == 12 and made.size() == 13, "3 m of stairs with 0.25 m steps: 12 steps and the ramp you walk on")
	var walk := made.back() as MapBlock
	_expect(walk.shape == MapBlock.Shape.WEDGE and not walk.drawn and walk.solid and made.slice(0, 12).all(func(s: MapBlock) -> bool: return not s.solid),
		"smooth: the steps are drawn only, an invisible wedge is solid")
	var top := made[11] as MapBlock
	_expect(is_equal_approx(top.position.y + top.size.y * 0.5, 3.0) and is_equal_approx(top.position.z - top.size.z * 0.5, -6.0), "the top step ends 3 m up, 6 m along")
	# The wedge's surface passes through each step's front top edge.
	var first := made[0] as MapBlock
	var nose := Vector3(0, first.size.y, 0.0)
	var along := (walk.position.z + walk.size.z * 0.5 - nose.z) / walk.size.z   # 0 at its low end, 1 at its high end
	_expect(is_equal_approx(along * walk.size.y, nose.y), "the ramp lies on the steps' front edges")
	stairs.smooth = false
	stairs.rebuild()
	_expect(stairs.generated().size() == 12 and stairs.generated().all(func(s: MapBlock) -> bool: return s.solid), "not smooth: solid steps and no ramp")
	stairs.step_height = 0.5
	stairs.rebuild()
	_expect(stairs.generated().size() == 6, "taller steps: fewer of them, the old ones gone")

	var ramp := MapRamp.new()
	ramp.rise = 3.0
	ramp.run = 4.0
	ramp.thickness = 0.2
	map.add_child(ramp)
	ramp.rebuild()
	var slab := ramp.generated()[0] as MapBlock
	_expect(is_equal_approx(slab.size.z, 5.0) and is_equal_approx(ramp.slope, rad_to_deg(atan2(3.0, 4.0))), "a 3 m by 4 m ramp is a slab 5 m long at 36.9 degrees")
	var top_low: Vector3 = slab.transform * Vector3(0, 0.1, 2.5)
	var top_high: Vector3 = slab.transform * Vector3(0, 0.1, -2.5)
	_expect(top_low.is_equal_approx(Vector3.ZERO) and top_high.is_equal_approx(Vector3(0, 3, -4)), "its top runs from the origin to 3 m up, 4 m along")
	ramp.filled = true
	ramp.rebuild()
	_expect((ramp.generated()[0] as MapBlock).shape == MapBlock.Shape.WEDGE, "filled: one wedge")

	var row := MapRow.new()
	row.count = 5
	row.spacing = Vector3(1.5, 0, 0)
	map.add_child(row)
	var post := _block(row, Vector3(0, 1, 0), Vector3(0.2, 2, 0.2), "steel")
	row.rebuild()
	_expect(row.generated().size() == 4 and (row.generated()[3] as Node3D).position.is_equal_approx(Vector3(6, 1, 0)), "a row of 5: four copies, the last 6 m along")
	post.size = Vector3(0.4, 2, 0.4)
	row.refresh_if_changed()
	_expect((row.generated()[0] as MapBlock).size.is_equal_approx(Vector3(0.4, 2, 0.4)), "the copies follow a change to the first")

	var ring := MapRing.new()
	ring.count = 4
	map.add_child(ring)
	var pillar := _block(ring, Vector3(0, 1, -5), Vector3(1, 2, 1))
	ring.rebuild()
	var across := ring.generated()[1] as Node3D
	_expect(ring.generated().size() == 3 and across.position.is_equal_approx(Vector3(0, 1, 5)), "a ring of 4: three copies, one straight across")
	ring.arc = 90.0
	ring.rebuild()
	var last := ring.generated()[2] as Node3D
	_expect(last.position.is_equal_approx(Basis(Vector3.UP, PI / 2.0) * pillar.position), "over a 90 degree arc the last one is a quarter turn round")
	var empty := MapRow.new()
	map.add_child(empty)
	empty.rebuild()
	_expect(empty.generated().is_empty() and empty._get_configuration_warnings().size() == 1, "a row with nothing to repeat makes nothing and says why")

	var pieces := map.collect_pieces()
	_expect(pieces.size() == 6 + 1 + 5 + 4, "the game sees a piece's blocks like any others (%d pieces)" % pieces.size())
	map.free()


func _check_prefab() -> void:
	print("  prefabs")
	var map := MapRoot.new()
	var palette := MapPalette.new()
	palette.colors = {"concrete": Color.GRAY, "plank": Color.BROWN}
	map.palette = palette
	root.add_child(map)
	var group := Node3D.new()
	group.name = "Crates"
	group.position = Vector3(20, 2, 10)
	map.add_child(group)
	var low := _block(group, Vector3(0, 0.5, 0), Vector3(2, 1, 2), "plank")
	var high := _block(group, Vector3(0, 1.5, 0), Vector3(1, 1, 1), "rust")
	var prefab := MapOps.make_prefab([group, low], "CrateStack")
	_expect(prefab.get_child_count() == 1 and MapOps.blocks_in(prefab).size() == 2, "a block picked along with its group is saved once")
	var foot := MapOps.bounds_of([prefab])
	_expect(is_zero_approx(foot.position.y) and is_zero_approx(foot.get_center().x) and is_zero_approx(foot.get_center().z), "the prefab stands on its own origin, centred")
	var scene := PackedScene.new()
	_expect(scene.pack(prefab) == OK, "it packs as a scene")
	prefab.free()
	var placed := MapOps.place_prefab(scene)
	placed.position = Vector3(-5, 0, 0)
	map.add_child(placed)
	MapPiece.adopt(placed, map)
	var blocks := MapOps.blocks_in(placed)
	_expect(blocks.size() == 2 and placed.scene_file_path == "" and blocks.all(func(b: MapBlock) -> bool: return b.owner == map and b.scene_file_path == ""),
		"placed, it is plain blocks owned by the map with no tie to the file")
	_expect(placed.get_meta("_edit_group_", false), "and one selection group")
	_expect(MapOps.missing_kinds(placed, palette) == PackedStringArray(["rust"]), "a kind the map's palette lacks is named")
	high.kind = "plank"
	_expect(MapOps.blocks_in(placed).any(func(b: MapBlock) -> bool: return b.kind == "rust"), "changing the original does not change the copy")
	map.build(false)
	_expect(map.get_node("Collision").get_child_count() == 4, "the map builds collision for the original and the copy")
	map.free()
