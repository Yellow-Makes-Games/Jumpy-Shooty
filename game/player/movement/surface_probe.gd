class_name SurfaceProbe
extends RefCounted
## Looks at the level around the player: walls beside you (for wall runs and wall
## jumps) and ledges in front of you (for vaults and ledge climbs).
## Only the level (collision layer 1) counts, never other players.

const LEVEL_MASK := 1


## The normal of a wall right beside you, or ZERO. Checks the wall you are already
## on first, then left and right of the way you are moving, then diagonals.
static func find_wall(body: CharacterBody3D, vel: Vector3, current: Vector3, chest_height: float, reach: float) -> Vector3:
	var origin := body.global_position + Vector3(0, chest_height, 0)
	var dirs: Array[Vector3] = []
	if current != Vector3.ZERO:
		dirs.append(-current)
	var h := Vector3(vel.x, 0, vel.z)
	var f := h.normalized() if h.length() > 0.5 else Vector3.FORWARD
	var r := f.cross(Vector3.UP).normalized()
	dirs.append_array([r, -r, (f + r).normalized(), (f - r).normalized(), f])
	var space := body.get_world_3d().direct_space_state
	var length := MovementTuning.BODY_RADIUS + reach
	for d in dirs:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * length, LEVEL_MASK, [body.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and abs(hit.normal.y) < 0.35:
			return Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	return Vector3.ZERO


## Is the floor closer than `height` below the feet?
static func floor_within(body: CharacterBody3D, height: float) -> bool:
	var feet := body.global_position + Vector3(0, 0.05, 0)
	var q := PhysicsRayQueryParameters3D.create(feet, feet - Vector3(0, height, 0), LEVEL_MASK, [body.get_rid()])
	return not body.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Looks for a ledge in front of you in direction `dir`. Returns {} if there is none,
## or {"top": height of the ledge's top surface (world y), "normal": the wall's
## facing, "lip": how high the top is above your feet}.
static func find_ledge(body: CharacterBody3D, dir: Vector3, t: MovementTuning, crouch_height: float) -> Dictionary:
	if dir == Vector3.ZERO:
		return {}
	var space := body.get_world_3d().direct_space_state
	var ex := [body.get_rid()]
	var feet := body.global_position
	var reach := MovementTuning.BODY_RADIUS + t.mantle_reach
	# 1. A wall straight ahead, at knee, waist or chest height.
	var wall := {}
	for h in [0.3, 0.9, 1.5]:
		var from := feet + Vector3(0, h, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, LEVEL_MASK, ex))
		if not hit.is_empty() and abs(hit.normal.y) < 0.3 and hit.normal.dot(dir) < -0.5:
			wall = hit
			break
	if wall.is_empty():
		return {}
	var n := Vector3(wall.normal.x, 0, wall.normal.z).normalized()
	# 2. The top of it: look down from above, just past the wall's face.
	var over: Vector3 = wall.position - n * 0.3
	var from_top := Vector3(over.x, feet.y + t.ledge_max_height + 0.15, over.z)
	var to_low := Vector3(over.x, feet.y + 0.2, over.z)
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(from_top, to_low, LEVEL_MASK, ex))
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var lip: float = top.position.y - feet.y
	# 3. Room to fit on top (crouched), and nothing above us on the way up.
	var cap := CapsuleShape3D.new()
	cap.radius = MovementTuning.BODY_RADIUS - 0.05
	cap.height = crouch_height
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = cap
	room.collision_mask = LEVEL_MASK
	room.exclude = ex
	room.transform = Transform3D(Basis(), Vector3(over.x, top.position.y + crouch_height * 0.5 + 0.05, over.z) - n * 0.15)
	if not space.intersect_shape(room, 1).is_empty():
		return {}
	if body.test_move(body.global_transform, Vector3(0, lip + 0.05, 0)):
		return {}
	return {"top": top.position.y, "normal": n, "lip": lip}
