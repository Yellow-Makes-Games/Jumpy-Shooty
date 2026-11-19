class_name PortalGun
extends RefCounted
## The portal gun: each press shoots the next portal of your pair (blue, then
## orange, then blue again...) onto the surface you aim at. The portals themselves
## live in the arena (see Portals) so everyone sees and can use them.

const RANGE := 80.0
const COOLDOWN := 0.35
const CLEARANCE := 1.6   ## open air needed in front of a surface to put a portal on it

var next_slot := 0
var cooldown_left := 0.0


func update(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func ready() -> bool:
	return cooldown_left <= 0.0


func readiness() -> float:
	return 1.0 - cooldown_left / COOLDOWN


func reset() -> void:
	next_slot = 0
	cooldown_left = 0.0


## Where a portal shot along `dir` from `from` would land: {} if nothing in range
## takes one, else {"at", "normal", "up"} (up: the portal's own up, along the surface).
## A shot that reaches a surface which takes no portal (too small, too broken, no room
## in front of it) gives {"miss": where it hit, "normal"}: nothing to place, something
## to show (see Portals.fizzle).
##
## The portal does not go exactly where the shot lands: it is fitted to the surface
## round there (PortalFit), moved off what stands in its way and back from an edge,
## and stood on whatever sticks out of the surface under it.
static func find_spot(body: CollisionObject3D, from: Vector3, dir: Vector3) -> Dictionary:
	var space := body.get_world_3d().direct_space_state
	dir = dir.normalized()
	var mine: Array[RID] = [body.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, 1, mine)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	var at: Vector3 = hit.position
	var miss := {"miss": at, "normal": n}
	var up: Vector3
	if absf(n.y) < 0.7:   # a wall: upright, like a doorway
		up = (Vector3.UP - n * n.y).normalized()
	else:                 # a floor or ceiling: its top points away from the shooter
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length_squared() < 0.0001:
			flat = Vector3.FORWARD
		up = (flat - n * flat.dot(n)).normalized()
	# A portal low on a wall would sink into the floor: lift it clear.
	if absf(n.y) < 0.7:
		var down := PhysicsRayQueryParameters3D.create(at + n * 0.3, at + n * 0.3 + Vector3.DOWN * Portal.HALF_HEIGHT, 1, mine)
		var floor_hit := space.intersect_ray(down)
		if not floor_hit.is_empty():
			at.y += Portal.HALF_HEIGHT - (at.y - floor_hit.position.y) + 0.05
	var fitted := PortalFit.fit(space, at, n, up, Portal.HALF_WIDTH, Portal.HALF_HEIGHT, mine)
	if fitted.is_empty():
		return miss
	at = fitted.at
	# Room in front of it to come out.
	var clear := PhysicsRayQueryParameters3D.create(at + n * 0.05, at + n * CLEARANCE, 1 | (1 << 1), mine)
	if not space.intersect_ray(clear).is_empty():
		return miss
	return {"at": at, "normal": n, "up": up}
