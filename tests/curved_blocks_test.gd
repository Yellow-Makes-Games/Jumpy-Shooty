extends SceneTree
## Slices of cylinders and tubes (an Arc under 360) and spiral blocks (curved ramps and
## stairs), in a real map:
##  - a slice collides where it is drawn: on its arc, not in its open slice (facing +z),
##    not in a tube's hole; it is drawn with no face left inside it;
##  - a spiral ramp is walked on at the height its numbers say, all the way up, and
##    climbs anticlockwise seen from above unless Clockwise; a mirrored copy climbs the
##    other way, over the same ground;
##  - spiral stairs: steps drawn, a smooth ramp over their front edges walked on; Solid
##    steps go down to the foot, Slab steps sit on a sloping slab and Treads float,
##    and under the high end of those two there is room to walk;
##  - bots find a way up a spiral ramp from one floor to another;
##  - the settings are saved with the map and show in the inspector only for the
##    shapes that use them; a too-steep spiral warns.
## Run: godot --headless --path . --script tests/curved_blocks_test.gd

const MapOps := preload("res://addons/map_tools/map_ops.gd")

var failures := 0
var space: PhysicsDirectSpaceState3D


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _block(shape: MapBlock.Shape, size: Vector3, at: Vector3, settings := {}) -> MapBlock:
	var b := MapBlock.new()
	b.shape = shape
	b.size = size
	b.position = at
	for k in settings:
		b.set(k, settings[k])
	return b


## Straight down onto `b`, `reach` metres out from its axis at `angle` (its own frame,
## round from +x toward +z): the height hit in its own frame, or -INF.
func _down(b: MapBlock, angle: float, reach: float) -> float:
	var xf := b.global_transform
	var at := xf * Vector3(cos(angle) * reach, 0, sin(angle) * reach)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at - Vector3.UP * 20.0))
	if hit.is_empty() or not (hit.position.y > xf.origin.y - b.size.y * 0.5 - 0.01):
		return -INF
	return (xf.affine_inverse() * hit.position).y


## Across, level, at height `y` in `b`'s own frame and `reach` out at `angle`: is there
## anything solid?
func _across(b: MapBlock, angle: float, reach: float, y: float) -> bool:
	var xf := b.global_transform
	var at := xf * Vector3(cos(angle) * reach, y, sin(angle) * reach)
	var side := xf.basis * Vector3(-sin(angle), 0, cos(angle)) * 0.3
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(at - side, at + side)).is_empty()


## Straight down onto `b` at `local` (its own frame; y is ignored): the height hit in
## its own frame, or -INF.
func _down_at(b: MapBlock, local: Vector3) -> float:
	var xf := b.global_transform
	var at := xf * Vector3(local.x, 0, local.z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at - Vector3.UP * 20.0))
	return -INF if hit.is_empty() else (xf.affine_inverse() * hit.position).y


## Across `b` (along its own x, from one side to the other) at `local`: anything solid?
func _across_at(b: MapBlock, local: Vector3) -> bool:
	var xf := b.global_transform
	var side := xf.basis.x.normalized() * (b.size.x * 0.5 + 0.5)
	var at := xf * Vector3(0, local.y, local.z)
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(at - side, at + side)).is_empty()


## Does any drawn face of `piece` lie inside it (a face two of its lumps share, left in)?
static func _inner_faces(piece: Dictionary, lumps: Array) -> int:
	var count := 0
	var planes := []
	for lump in lumps:
		planes.append(MapMesher.hull_planes(lump))
	var arrays: Dictionary = MapMesher.build_arrays([piece])
	for kind in arrays:
		var verts: PackedVector3Array = arrays[kind][Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[kind][Mesh.ARRAY_NORMAL]
		for i in range(0, verts.size(), 3):
			var c := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0 + normals[i] * 0.002
			for p in planes:
				if MapMesher.hull_has(p, c, -0.0005):
					count += 1
					break
	return count


func _run() -> void:
	await process_frame
	print("Curved block checks")
	var map := MapRoot.new()
	var group := Node3D.new()      # (turned and moved: collision follows a block's frame)
	group.position = Vector3(10, 0, -4)
	group.rotation.y = 0.5
	map.add_child(group)
	var pie := _block(MapBlock.Shape.CYLINDER, Vector3(8, 1, 8), Vector3(0, 0.5, 0), {"arc": 90.0, "sides": 6})
	var ring := _block(MapBlock.Shape.TUBE, Vector3(8, 1, 8), Vector3(30, 0.5, 0), {"arc": 200.0, "sides": 10, "inner": 4.0})
	var big_pie := _block(MapBlock.Shape.CYLINDER, Vector3(8, 1, 8), Vector3(60, 0.5, 0), {"arc": 300.0, "sides": 20})
	var ramp := _block(MapBlock.Shape.SPIRAL, Vector3(12, 3, 12), Vector3(0, 1.5, 40), {"arc": 180.0, "sides": 16, "inner": 4.0})
	var turned := _block(MapBlock.Shape.SPIRAL, Vector3(12, 3, 12), Vector3(30, 1.5, 40), {"arc": 180.0, "sides": 16, "inner": 4.0, "clockwise": true})
	var stairs := {}
	var x := 0.0
	for style in [MapBlock.StepStyle.SOLID, MapBlock.StepStyle.SLAB, MapBlock.StepStyle.TREADS]:
		var s := _block(MapBlock.Shape.SPIRAL, Vector3(10, 3.2, 10), Vector3(x, 1.6, 80),
			{"arc": 240.0, "sides": 24, "inner": 3.0, "steps": 12, "step_style": style, "thickness": 0.4})
		stairs[style] = s
		x += 30.0
	# Straight stairs: 12 steps over 6.5 m (a step's depth of way on, then 12 of 0.5 m), 3 m up.
	var flights := {}
	x = 0.0
	for style in [MapBlock.StepStyle.SOLID, MapBlock.StepStyle.SLAB, MapBlock.StepStyle.TREADS]:
		flights[style] = _block(MapBlock.Shape.STAIRS, Vector3(3, 3.4, 6.5), Vector3(x, 1.7, 120),
			{"steps": 12, "step_style": style, "thickness": 0.4})
		x += 10.0
	var rough := _block(MapBlock.Shape.STAIRS, Vector3(3, 3, 6.5), Vector3(x, 1.5, 120), {"steps": 12, "smooth": false})
	for b in [pie, ring, big_pie, ramp, turned, rough] + stairs.values() + flights.values():
		group.add_child(b)
	root.add_child(map)
	map.build(false)
	await physics_frame
	await physics_frame
	space = map.get_world_3d().direct_space_state

	print("  slices")
	var middle := PI * 1.5   # the middle of a slice: facing -z, away from its open side
	_check(is_equal_approx(_down(pie, middle, 2.0), 0.5) and is_equal_approx(_down(pie, middle + 0.6, 3.5), 0.5),
		"a quarter of a cylinder: its top is there, across its arc")
	_check(_down(pie, PI * 0.5, 2.0) == -INF and _down(pie, middle + PI * 0.3, 2.0) == -INF and _down(pie, middle, 4.5) == -INF,
		"nothing in its open slice, past its edge or beyond its radius")
	_check(is_equal_approx(_down(ring, middle, 3.0), 0.5) and _down(ring, middle, 1.0) == -INF and _down(ring, PI * 0.5, 3.0) == -INF,
		"a slice of a tube: its ring is there; its hole and its open slice are not")
	_check(is_equal_approx(_down(big_pie, PI, 2.0), 0.5) and is_equal_approx(_down(big_pie, 0.0, 2.0), 0.5) and _down(big_pie, PI * 0.5, 1.5) == -INF,
		"300 degrees of a cylinder (several lumps, none past half a turn): all there but its slit")
	var lumps := big_pie.shape_lumps()
	_check(lumps.size() >= 2 and lumps.all(func(l): return MapMesher.hull_planes(l).size() >= 4 and l.size() <= MapMesher.MAX_HULL_CORNERS),
		"its lumps are solid and each within the corner limit (%d lumps)" % lumps.size())
	for b: MapBlock in [pie, ring, big_pie]:
		_check(_inner_faces(b.to_piece(Transform3D.IDENTITY), b.shape_lumps()) == 0, "%s is drawn with no face left inside it" % ["the quarter", "the tube slice", "the 300 degree slice"][[pie, ring, big_pie].find(b)])
	_check(MapOps.editable_lumps(ring).size() == 10, "Make Editable turns a tube slice into one hull a side")

	print("  spiral ramps")
	var mid := (12.0 + 4.0) * 0.25
	var worst := 0.0
	var climbing := true
	var last := -INF
	for i in 9:
		var f := 0.05 + 0.9 * i / 8.0 + 0.003   # (off the seams between its pieces: a ray straight down one can slip between them)
		var p := ramp.to_piece(Transform3D.IDENTITY)
		var a := MapMesher.spiral_angle(p, f)
		var want := MapMesher.climb_height(p, f)
		var got := _down(ramp, a, mid)
		worst = maxf(worst, absf(got - want))
		climbing = climbing and got > last
		last = got
	_check(worst < 0.05, "walked at the height its numbers say all the way up, to within its flat-faced pieces (worst %.3f m off)" % worst)
	_check(climbing, "and always climbing")
	# Anticlockwise seen from above: from the +x end round by -z to the -x end.
	var low := _down(ramp, TAU - 0.15, mid)
	var high := _down(ramp, PI + 0.15, mid)
	_check(low < -1.0 and high > 1.0, "anticlockwise seen from above: low at +x, high at -x (%.2f, %.2f)" % [low, high])
	_check(_down(turned, TAU - 0.15, mid) > 1.0 and _down(turned, PI + 0.15, mid) < -1.0, "Clockwise climbs the other way round")
	_check(is_equal_approx(_down(ramp, PI * 0.5, mid), -INF) and _down(ramp, middle, 1.0) == -INF, "nothing in its open slice or round its middle (Inner)")
	var copy := MapOps.mirrored_copy(ramp, 0, ramp.global_position) as MapBlock
	_check(copy.clockwise and copy.shape == MapBlock.Shape.SPIRAL, "a mirrored copy climbs the other way")
	group.add_child(copy)
	await physics_frame
	_check(copy.climb_slope() < 46.0 and ramp.climb_slope() < 46.0, "it is walkable (%.0f degrees)" % ramp.climb_slope())
	var steep := _block(MapBlock.Shape.SPIRAL, Vector3(4, 6, 4), Vector3.ZERO, {"arc": 90.0})
	group.add_child(steep)
	var warned := steep._get_configuration_warnings()
	_check(Array(warned).any(func(w): return w.contains("too steep")), "a steep one warns (%.0f degrees)" % steep.climb_slope())
	_check(_inner_faces(ramp.to_piece(Transform3D.IDENTITY), ramp.shape_lumps()) == 0, "a ramp is drawn with no face left inside it")

	print("  spiral stairs")
	for style in stairs:
		var s: MapBlock = stairs[style]
		var name: String = MapBlock.STEP_STYLE_NAMES[style]
		var p := s.to_piece(Transform3D.IDENTITY)
		var drawn := MapMesher.draw_points(p)
		var walked := MapMesher.hull_points(p)
		_check(drawn != walked and drawn.size() >= 11, "%s: drawn as its steps (%d lumps), walked as a ramp (%d)" % [name, drawn.size(), walked.size()])
		# Half way across the fifth step, the ramp over the front edges is above the tread.
		var step := MapMesher.climb_step(p, 5)
		var f: float = (step[1] + step[2]) * 0.5
		var a := MapMesher.spiral_angle(p, f)
		var r := (10.0 + 3.0) * 0.25
		var tread: float = step[0]
		var got := _down(s, a, r)
		_check(absf(got - MapMesher.climb_height(p, f)) < 0.03 and got > tread + 0.05,
			"%s: walked on the smooth ramp, not the treads (%.2f over a tread at %.2f)" % [name, got, tread])
		var lowest := INF
		var thinnest := INF
		for lump in drawn:
			var box := MapBlock.points_bounds(lump)
			lowest = minf(lowest, box.position.y)
			thinnest = minf(thinnest, box.size.y)
		var hy := s.size.y * 0.5
		match style:
			MapBlock.StepStyle.SOLID:
				_check(drawn.all(func(l): return is_equal_approx(MapBlock.points_bounds(l).position.y, -hy)), "solid: every step goes down to the foot")
			MapBlock.StepStyle.TREADS:
				_check(drawn.all(func(l): return absf(MapBlock.points_bounds(l).size.y - 0.4) < 0.001), "treads: every step a floating tread 0.4 m thick")
			MapBlock.StepStyle.SLAB:
				var high_step: PackedVector3Array = drawn[drawn.size() - 1]
				_check(MapBlock.points_bounds(high_step).position.y > 0.5, "slab: the high steps sit on the slab, well off the foot")
		# Under the high end: room to walk for a slab or treads, none for solid steps.
		var under := _across(s, MapMesher.spiral_angle(p, 0.9), r, -hy + 0.6)
		_check(under == (style == MapBlock.StepStyle.SOLID), "%s: %s under its high end" % [name, "nothing to walk" if style == MapBlock.StepStyle.SOLID else "room to walk"])

	print("  straight stairs")
	for style in flights:
		var s: MapBlock = flights[style]
		var name: String = MapBlock.STEP_STYLE_NAMES[style]
		var p := s.to_piece(Transform3D.IDENTITY)
		var drawn := MapMesher.draw_points(p)
		var walked := MapMesher.hull_points(p)
		_check(drawn.size() == 12 and walked.size() == 2, "%s: one block, drawn as 12 steps, walked as a ramp and its level top (%d, %d lumps)" % [name, drawn.size(), walked.size()])
		var hy := s.size.y * 0.5
		var z_at := func(f: float) -> float: return s.size.z * 0.5 - s.size.z * f
		var step := MapMesher.climb_step(p, 5)
		var f: float = (step[1] + step[2]) * 0.5
		var got := _down_at(s, Vector3(0.4, 0, z_at.call(f)))
		_check(absf(got - MapMesher.climb_height(p, f)) < 0.01 and got > float(step[0]) + 0.05,
			"%s: walked on the smooth ramp over the treads (%.2f over a tread at %.2f)" % [name, got, step[0]])
		var start := MapMesher.climb_height(p, 0.0)
		_check(absf(_down_at(s, Vector3(0, 0, z_at.call(0.01))) - start) < 0.05 and absf(_down_at(s, Vector3(0, 0, z_at.call(0.97))) - hy) < 0.01,
			"%s: the way on starts at floor level (%.2f above its foot), the top step is level with its top" % [name, start + hy])
		var under := _across_at(s, Vector3(0, -hy + 0.5, z_at.call(0.85)))
		_check(under == (style == MapBlock.StepStyle.SOLID), "%s: %s under its high end" % [name, "nothing to walk" if style == MapBlock.StepStyle.SOLID else "room to walk"])
	var rough_p := rough.to_piece(Transform3D.IDENTITY)
	var fifth := MapMesher.climb_step(rough_p, 5)
	var on_tread := _down_at(rough, Vector3(0, 0, rough.size.z * 0.5 - rough.size.z * (float(fifth[1]) + float(fifth[2])) * 0.5))
	_check(absf(on_tread - float(fifth[0])) < 0.01, "not Smooth: the steps themselves are what you stand on (%.2f, a tread at %.2f)" % [on_tread, fifth[0]])

	print("  saved with the map")
	var saved := Node3D.new()
	var keep := stairs[MapBlock.StepStyle.TREADS].duplicate() as MapBlock
	saved.add_child(keep)
	keep.owner = saved
	var scene := PackedScene.new()
	scene.pack(saved)
	var back := scene.instantiate().get_child(0) as MapBlock
	_check(back.shape == MapBlock.Shape.SPIRAL and back.steps == 12 and back.step_style == MapBlock.StepStyle.TREADS \
		and is_equal_approx(back.thickness, 0.4) and is_equal_approx(back.arc, 240.0) and is_equal_approx(back.inner, 3.0),
		"its shape, steps, style, thickness, arc and inner come back")
	var shown := func(b: MapBlock, prop: String) -> bool:
		for p in b.get_property_list():
			if p.name == prop:
				return p.usage & PROPERTY_USAGE_EDITOR != 0
		return false
	var box := _block(MapBlock.Shape.BOX, Vector3.ONE, Vector3.ZERO)
	_check(shown.call(pie, "arc") and shown.call(ring, "arc") and not shown.call(box, "arc") and not shown.call(pie, "steps"),
		"Arc shows for cylinders and tubes; Steps not")
	_check(shown.call(ramp, "steps") and shown.call(ramp, "clockwise") and not shown.call(ramp, "thickness") and shown.call(back, "thickness"),
		"Steps and Clockwise show for spirals, Thickness only with a slab or treads")
	var flight: MapBlock = flights[MapBlock.StepStyle.SOLID]
	_check(shown.call(flight, "steps") and shown.call(flight, "smooth") and shown.call(flight, "step_style") and not shown.call(flight, "clockwise")
		and not shown.call(flight, "arc") and not shown.call(ramp, "smooth"), "stairs show Steps, Smooth and Step Style, not Clockwise or Arc; Smooth only with steps")

	print("  bots")
	root.remove_child(map)
	map.free()
	await _bots()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


## A floor, a spiral ramp up 3 m half way round, and a deck where it ends: bots find a
## way from the floor to the deck.
func _bots() -> void:
	var map := MapRoot.new()
	var floor := _block(MapBlock.Shape.BOX, Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	var ramp := _block(MapBlock.Shape.SPIRAL, Vector3(14, 3, 14), Vector3(0, 1.5, 0), {"arc": 180.0, "sides": 24, "inner": 6.0})
	# It ends at its -x end (anticlockwise from +x by -z): the deck lies beyond it, to -x
	# and +z, 3 m up.
	var deck := _block(MapBlock.Shape.BOX, Vector3(8, 0.5, 10), Vector3(-5, 2.75, 5.0))
	# Straight stairs on a slab, off to +x, up to a deck of their own: the way on starts at
	# z = 3.25 at floor level (the block's foot is the slab's thickness under the floor).
	var flight := _block(MapBlock.Shape.STAIRS, Vector3(3, 3.4, 6.5), Vector3(14, 1.3, 0),
		{"steps": 12, "step_style": MapBlock.StepStyle.SLAB, "thickness": 0.4})
	var deck2 := _block(MapBlock.Shape.BOX, Vector3(6, 0.5, 6), Vector3(14, 2.75, -6.25))
	for b in [floor, ramp, deck, flight, deck2]:
		map.add_child(b)
	root.add_child(map)
	map.build(false)
	await physics_frame
	await physics_frame
	var region := MapScenery.bake_navigation(map)
	map.add_child(region)
	var nav := map.get_world_3d().navigation_map
	# (The navigation server takes the new region in on a later frame: wait for it.)
	var was := NavigationServer3D.map_get_iteration_id(nav)
	for i in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav) != was and NavigationServer3D.map_get_closest_point(nav, Vector3(14, 0, 8)) != Vector3.ZERO:
			break
	var from := Vector3(12, 0, -12)
	var to := Vector3(-5, 3, 7)
	var path := NavigationServer3D.map_get_path(nav, from, to, true)
	var end := path[path.size() - 1] if not path.is_empty() else Vector3.INF
	_check(not path.is_empty() and end.distance_to(to) < 1.0, "a path from the floor up the ramp to the deck (ends %.1f m from it)" % (end.distance_to(to) if not path.is_empty() else INF))
	var up := Vector3(14, 3, -7)
	var stairs_path := NavigationServer3D.map_get_path(nav, Vector3(14, 0, 8), up, true)
	var top := stairs_path[stairs_path.size() - 1] if not stairs_path.is_empty() else Vector3.INF
	_check(not stairs_path.is_empty() and top.distance_to(up) < 1.0, "and one up straight stairs to theirs (ends %.1f m from it)" % top.distance_to(up))
