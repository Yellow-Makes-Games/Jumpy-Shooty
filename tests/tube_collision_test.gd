extends SceneTree
## A solid tube block collides as the ring you see (MapRoot.collision_shapes, from
## MapMesher.tube_hulls), not as the box round it:
##  - nothing to hit straight down through its hole, or just outside a flat side
##    where the old box's corner was, or at the box's corner itself;
##  - something to hit all round its ring, at its top, right out to its outer corners
##    and in to its inner flat sides (so the flat sides line up with the drawn ones);
##  - a shot across the hole stops at the inner wall's flat side;
##  - every corner of its collision is a corner of its drawn mesh, and the reverse,
##    and it is still drawn as before (by _prism, not from hulls);
##  - with no hole it is bumped into as a cylinder; with a hole as wide as itself, as a
##    1 cm wall at its outside;
##  - on a moving part, MapRoot.mover_ground_at finds no ground in its hole.
## Run: godot --headless --path . --script tests/tube_collision_test.gd

const SIDES := 12
const OUTER := 6.0    # diameter
const INNER := 4.0    # the hole's diameter
const HEIGHT := 2.0

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _tube(inner: float) -> MapBlock:
	var b := MapBlock.new()
	b.shape = MapBlock.Shape.TUBE
	b.size = Vector3(OUTER, HEIGHT, OUTER)
	b.inner = inner
	b.sides = SIDES
	return b


func _run() -> void:
	await process_frame
	print("Tube collision checks")
	var map := MapRoot.new()
	# The tube sits in a turned, moved group, so its collision has to follow its frame.
	var group := Node3D.new()
	group.position = Vector3(20, 0, -5)
	group.rotation.y = 0.4
	map.add_child(group)
	var tube := _tube(INNER)
	tube.position = Vector3(0, HEIGHT * 0.5, 0)
	group.add_child(tube)
	# The same tube on a moving part that stays put (for mover_ground_at), well away.
	var mover := MapMover.new()
	mover.position = Vector3(-40, 0, 0)
	map.add_child(mover)
	var riding := _tube(INNER)
	riding.position = Vector3(0, HEIGHT * 0.5, 0)
	mover.add_child(riding)
	root.add_child(map)
	map.build(false)
	await physics_frame
	await physics_frame
	var space := map.get_world_3d().direct_space_state
	var xf := tube.global_transform

	var r := OUTER * 0.5
	var ri := INNER * 0.5
	var step := TAU / SIDES
	var flat := cos(step * 0.5)   # a flat side's middle, as a share of the corner's reach
	var side_mid := step * 1.5    # 45 degrees: the middle of the side from corner 1 to 2
	var corner := step            # 30 degrees: corner 1

	# Straight down through the tube, at `reach` metres out at `angle` (its own frame).
	var down := func(angle: float, reach: float) -> Dictionary:
		var at := Vector3(cos(angle) * reach, 0, sin(angle) * reach)
		var q := PhysicsRayQueryParameters3D.create(xf * (at + Vector3(0, HEIGHT, 0)), xf * (at - Vector3(0, HEIGHT, 0)))
		return space.intersect_ray(q)

	_check(down.call(0.0, 0.0).is_empty(), "nothing to hit down through the middle of the hole")
	# (Off the seams: a ray running exactly along the face two lumps share can slip
	# between them, as it can between any two convex shapes. Anything with some width
	# cannot: the sphere below.)
	var ring_hits := 0
	var tops_ok := true
	for i in 24:
		var hit: Dictionary = down.call(TAU * (i + 0.5) / 24.0, (r + ri) * 0.5)
		if not hit.is_empty():
			ring_hits += 1
			tops_ok = tops_ok and absf((xf.affine_inverse() * (hit.position as Vector3)).y - HEIGHT * 0.5) < 0.01
	_check(ring_hits == 24 and tops_ok, "the ring is there to stand on all the way round, at its top (%d of 24)" % ring_hits)
	# A ball dropped on the seam between two sides lands on the ring, at every seam.
	var ball := SphereShape3D.new()
	ball.radius = 0.2
	var landed := 0
	for i in SIDES:
		var seam := Vector3(cos(step * i), 0, sin(step * i)) * (r + ri) * 0.5
		var drop := PhysicsShapeQueryParameters3D.new()
		drop.shape = ball
		drop.transform = Transform3D(Basis(), xf * (seam + Vector3(0, HEIGHT, 0)))
		drop.motion = xf.basis * Vector3(0, -HEIGHT * 2.0, 0)
		var travel := space.cast_motion(drop)
		var stop := (xf.affine_inverse() * (drop.transform.origin + drop.motion * travel[0])).y
		if travel[0] < 1.0 and absf(stop - (HEIGHT * 0.5 + ball.radius)) < 0.02:
			landed += 1
	_check(landed == SIDES, "a ball dropped on each seam between two sides lands on the ring's top (%d of %d)" % [landed, SIDES])
	_check(not down.call(side_mid, r * flat - 0.03).is_empty(), "the ring reaches out to a flat side's middle (%.3f m)" % (r * flat))
	_check(down.call(side_mid, r * flat + 0.03).is_empty(), "nothing just outside a flat side, where the old box's corner was")
	_check(not down.call(corner, r - 0.02).is_empty(), "the ring reaches out to its corners (corner 1 at 30 degrees, as drawn)")
	var box_corner := Vector2(r, r) * 0.97
	_check(down.call(atan2(box_corner.y, box_corner.x), box_corner.length()).is_empty(), "nothing at the old box's corner")
	_check(down.call(side_mid, ri * flat - 0.03).is_empty(), "nothing just inside the inner wall's flat side")
	_check(not down.call(side_mid, ri * flat + 0.03).is_empty(), "the inner wall's flat side is where it is drawn (%.3f m)" % (ri * flat))
	_check(down.call(corner, ri - 0.02).is_empty(), "the hole reaches out to the inner corners")
	# Across the hole, at half height: the shot stops at the inner wall's flat side.
	var out := Vector3(cos(side_mid), 0, sin(side_mid))
	var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(xf * Vector3.ZERO, xf * (out * OUTER)))
	var gap := (xf.affine_inverse() * (across.position as Vector3)).length() if not across.is_empty() else -1.0
	_check(absf(gap - ri * flat) < 0.01, "a shot from the middle stops at the inner wall, %.3f m out (%.3f)" % [ri * flat, gap])

	# What you bump into is what you see: the same corners, in the block's own frame.
	var piece := tube.to_piece(Transform3D.IDENTITY)
	var shapes := map.collision_shapes(piece)
	var corners := PackedVector3Array()
	var convex := true
	for s in shapes:
		convex = convex and s is ConvexPolygonShape3D
		if s is ConvexPolygonShape3D:
			corners.append_array((s as ConvexPolygonShape3D).points)
	_check(shapes.size() == SIDES and convex and corners.size() == SIDES * 8, "one convex lump of 8 corners per side (%d lumps)" % shapes.size())
	var mesh: ArrayMesh = MapMesher.build([piece])[piece.kind]
	var drawn: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(_all_near(corners, drawn) and _all_near(drawn, corners), "every collision corner is a drawn corner, and every drawn corner a collision corner")
	_check(MapMesher.hull_points(piece).is_empty() and drawn.size() == SIDES * 4 * 6, "still drawn by _prism as before: four faces a side, no hulls (%d vertices)" % drawn.size())

	# A tube with no hole is drawn as a cylinder and bumped into as one.
	var solid := _tube(0.0)
	var solid_shapes := map.collision_shapes(solid.to_piece(Transform3D.IDENTITY))
	_check(solid_shapes.size() == 1 and solid_shapes[0] is CylinderShape3D, "a tube with no hole collides as a cylinder")
	solid.free()
	# A hole as wide as the tube (or wider) leaves a 1 cm wall at its outside.
	var thin := _tube(OUTER + 1.0)
	var thin_shapes := map.collision_shapes(thin.to_piece(Transform3D.IDENTITY))
	var near := INF
	var far := 0.0
	for s in thin_shapes:
		if not s is ConvexPolygonShape3D:
			continue
		for p in (s as ConvexPolygonShape3D).points:
			near = minf(near, Vector2(p.x, p.z).length())
			far = maxf(far, Vector2(p.x, p.z).length())
	_check(thin_shapes.size() == SIDES and absf(far - r) < 0.001 and absf(near - (r - 0.01)) < 0.001,
		"a hole as wide as the tube leaves a 1 cm wall at its outside (%.3f to %.3f m)" % [near, far])
	thin.free()

	# On a moving part: ground on the ring, none in the hole.
	var mxf := riding.global_transform
	var top := Vector3(0, HEIGHT * 0.5, 0)
	_check(map.mover_ground_at(mxf * top, 0.0) == -1, "a moving tube has no ground to give in its hole")
	_check(map.mover_ground_at(mxf * (top + Vector3((r + ri) * 0.5, 0, 0)), 0.0) == 1, "a moving tube's ring is ground")

	map.free()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


## Is every point of `a` within a millimetre of some point of `b`?
func _all_near(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	for p in a:
		var found := false
		for q in b:
			if p.distance_to(q) < 0.001:
				found = true
				break
		if not found:
			return false
	return true
