class_name PortalFit
extends RefCounted
## Fitting a portal onto the surface it was shot at (see PortalGun.find_spot).
##
## A portal is a flat oval; walls and floors are not always flat. Shot at a ribbed
## container, a wall with a sign on it, the foot of a pillar or the edge of a roof, a
## portal put exactly where the shot landed has the ribs, the sign or the floor poking
## through it, or hangs half in the air. So the surface under the whole oval is felt
## out first, with a ray at each of a few points across it (spots()):
##
##  - the portal is moved along the surface, a little at a time, off whatever stands
##    in its way (a floor, a corner, a crate against the wall) and back onto the
##    surface where part of it hangs over an edge;
##  - it then stands on the highest thing under it: what sticks out of the surface up
##    to MAX_LIFT (a rib, a beam, a kerb, a sign) is under the portal, not through it.
##    That counts what is too narrow for the rays to find (the whole oval is lowered
##    onto the surface as one shape) and the map's decoration (blocks that are drawn
##    but not solid: nothing solid finds those, the map is asked: MapRoot.decor_relief);
##  - a surface too small or too broken for a portal takes none.
##
## The portal draws a collar from its face back to the surface (Portal.set_seat), so
## one standing proud of a wall is not seen floating off it.

## A portal stands at most this far out from the surface it was shot at (metres):
## what sticks out further is in its way.
const MAX_LIFT := 0.3
## The surface may lie this far behind where the shot landed (a panel set back, a
## groove) and still hold the portal up there: further is a hole, or the edge.
const RECESS := 0.3
## The rays start this far in front of the surface: what stands within it, in front
## of the oval, is in the way.
const PROBE_OUT := 0.5
## The portal's face is this far in front of the highest thing under it.
const SKIN := 0.02
## Looking for a better place: steps of this many metres, at most this many.
const STEP := 0.2
const STEPS := 8
## This many of the 8 points half way out must be on the surface.
const INNER_NEEDED := 5
## A place where nothing sticks out more than this is flat.
const FLAT_ENOUGH := 0.02

const _INNER := 8
const _OUTER := 12
const _BLOCKED := INF   # (a depth: something stands in the way there)


## The points across the oval the surface is felt at, as shares of its half width
## and height: the middle, a ring half way out, a ring at the edge.
static func spots() -> PackedVector2Array:
	var out := PackedVector2Array([Vector2.ZERO])
	for i in _INNER:
		out.append(Vector2.from_angle(TAU * i / _INNER) * 0.5)
	for i in _OUTER:
		out.append(Vector2.from_angle(TAU * (i + 0.5) / _OUTER) * 0.93)
	return out


## How far the surface is in front of `frame`'s plane (x right, y up, z out) at each
## of spots(): negative behind it, NAN where there is none within RECESS behind,
## _BLOCKED where something stands more than MAX_LIFT in front.
static func probe(space: PhysicsDirectSpaceState3D, frame: Transform3D, half_w: float, half_h: float, exclude: Array[RID] = []) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := frame.basis.z
	for s in spots():
		var p := frame * Vector3(s.x * half_w, s.y * half_h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(p + n * PROBE_OUT, p - n * RECESS, 1, exclude)
		q.hit_from_inside = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			out.append(NAN)
			continue
		var d := ((hit.position as Vector3) - p).dot(n)
		# (Starting inside something solid: a floor, the wall round a corner.)
		if (hit.normal as Vector3).length_squared() < 0.25 or d > MAX_LIFT:
			out.append(_BLOCKED)
		else:
			out.append(d)
	return out


static func _weight(i: int) -> float:
	return 30.0 if i == 0 else (2.0 if i <= _INNER else 1.0)


## How bad a place is (0: nothing in the way, nothing hanging over), and which way to move off what is wrong
## with it (in the oval's own x and y, metres; zero: nowhere better to go).
static func _judge(depths: PackedFloat32Array, half_w: float, half_h: float) -> Array:
	var pts := spots()
	var cost := 0.0
	var push := Vector2.ZERO
	for i in depths.size():
		var d := depths[i]
		var bad := 0.0
		if is_nan(d):
			bad = 3.0
		elif d == _BLOCKED:
			bad = 4.0
		if bad > 0.0:
			cost += bad * _weight(i)
			push -= Vector2(pts[i].x * half_w, pts[i].y * half_h) * bad * _weight(i)
	return [cost, push]


## Fits a portal of this size onto the surface at `at` (where the shot landed), facing
## `n`, its top toward `up`. {} if it does not take one, else {"at": the middle of the
## portal's face, "lift": how far that is in front of where the surface was at the
## shot, "moved": how far along the surface it was moved}.
static func fit(space: PhysicsDirectSpaceState3D, at: Vector3, n: Vector3, up: Vector3, half_w: float, half_h: float, exclude: Array[RID] = []) -> Dictionary:
	n = n.normalized()
	var y := (up - n * up.dot(n)).normalized()
	var x := y.cross(n).normalized()
	var basis := Basis(x, y, n)
	var best_at := at
	var best_cost := INF
	var best: PackedFloat32Array
	var here := at
	var dir := Vector2.ZERO
	for step in STEPS + 1:
		var depths := probe(space, Transform3D(basis, here), half_w, half_h, exclude)
		var judged := _judge(depths, half_w, half_h)
		var cost: float = judged[0] + here.distance_to(at) * 0.5   # (nearer where it was aimed is better)
		if cost < best_cost:
			best_cost = cost
			best_at = here
			best = depths
		var push: Vector2 = judged[1]
		if judged[0] <= 0.0 or push.length() < 0.05:
			if judged[0] <= 0.0 and step > 0:
				# Clear: half a step back toward where it was aimed, if that is clear too.
				var back := here - (x * dir.x + y * dir.y) * STEP * 0.5
				var again := probe(space, Transform3D(basis, back), half_w, half_h, exclude)
				if _judge(again, half_w, half_h)[0] <= 0.0:
					best_at = back
					best = again
			break
		dir = push.normalized()
		here += (x * dir.x + y * dir.y) * STEP
	if best.is_empty() or is_nan(best[0]) or best[0] == _BLOCKED:
		return {}
	if not _holds(best):
		return {}
	var lift := _proud(space, best, Transform3D(basis, best_at), half_w, half_h, exclude)
	if lift > FLAT_ENOUGH * 2.0:
		# It would stand proud of the surface, on something under its edge (the rail
		# along the foot of a wall, a kerb), or something thin sticks right through it
		# (a rod out of the wall): a flat place a little to one side is better.
		# (On a surface that is ribbed all over there is none, and it stays.)
		var hard: float = _judge(best, half_w, half_h)[0]
		var found := false
		for dist: float in [0.15, 0.3, 0.45]:
			for way: Vector3 in [x, -x, y, -y]:
				var there := best_at + way * dist
				var depths := probe(space, Transform3D(basis, there), half_w, half_h, exclude)
				if is_nan(depths[0]) or depths[0] == _BLOCKED or not _holds(depths) or _judge(depths, half_w, half_h)[0] > hard:
					continue
				var proud := _proud(space, depths, Transform3D(basis, there), half_w, half_h, exclude)
				if proud <= FLAT_ENOUGH:
					best_at = there
					lift = proud
					found = true
					break
			if found:
				break
	if lift == _BLOCKED:
		return {}
	return {"at": best_at + n * (lift + SKIN), "lift": lift, "moved": best_at.distance_to(at)}


## Is enough of the oval on the surface, with nothing big standing in it?
static func _holds(depths: PackedFloat32Array) -> bool:
	var held := 0
	for i in range(1, _INNER + 1):
		if depths[i] == _BLOCKED:
			return false   # something big stands in the oval
		if not is_nan(depths[i]):
			held += 1
	return held >= INNER_NEEDED   # (fewer: too small a surface)


## How far out from `frame`'s plane a portal there has to stand to clear what is
## under it: the highest of what the rays found (`depths`), of anything solid between
## the rays (a beam or a pipe narrower than the gaps between them: the whole oval is
## lowered onto the surface as one flat shape, and stops on the first thing it meets)
## and of the map's decoration (drawn, not solid: nothing solid finds it; under the rim
## too). _BLOCKED: something thin stands right through it, further out than MAX_LIFT.
static func _proud(space: PhysicsDirectSpaceState3D, depths: PackedFloat32Array, frame: Transform3D, half_w: float, half_h: float, exclude: Array[RID] = []) -> float:
	var lift := 0.0
	for d in depths:
		if not is_nan(d) and d != _BLOCKED:
			lift = maxf(lift, d)
	var n := frame.basis.z
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _oval(half_w, half_h)
	q.transform = Transform3D(frame.basis, frame.origin + n * (MAX_LIFT + SKIN))
	q.collision_mask = 1
	q.exclude = exclude
	q.margin = 0.0
	if not space.intersect_shape(q, 1).is_empty():
		return _BLOCKED
	q.motion = -n * (MAX_LIFT + SKIN)
	var solid := (MAX_LIFT + SKIN) * (1.0 - space.cast_motion(q)[0])
	if solid > lift + 0.01:   # (the rays are the finer measure where they agree)
		lift = minf(solid, MAX_LIFT)
	var map := MapRoot.current
	if map != null and is_instance_valid(map):
		lift = maxf(lift, map.decor_relief(frame, half_w * 1.2, half_h * 1.2, MAX_LIFT))
	return lift


static var _ovals := {}


## The oval as a thin flat shape (x and y its half width and height, z its normal).
static func _oval(half_w: float, half_h: float) -> ConvexPolygonShape3D:
	var key := Vector2(half_w, half_h)
	if not _ovals.has(key):
		var pts := PackedVector3Array()
		for i in 20:
			var a := TAU * i / 20.0
			for z: float in [-0.004, 0.004]:
				pts.append(Vector3(cos(a) * half_w, sin(a) * half_h, z))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		_ovals[key] = shape
	return _ovals[key]


## How a portal at `frame` sits on what is behind it: [how far back the surface goes
## under the oval (metres behind the face, at least SKIN: how deep its collar is),
## how far back it is at the middle (INF: nothing there)].
static func seat(space: PhysicsDirectSpaceState3D, frame: Transform3D, half_w: float, half_h: float) -> Array:
	var n := frame.basis.z
	var reach := MAX_LIFT + RECESS + SKIN + 0.1
	var deepest := SKIN
	var middle := INF
	var pts := spots()
	for i in pts.size():
		var p := frame * Vector3(pts[i].x * half_w, pts[i].y * half_h, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + n * 0.01, p - n * reach, 1))
		if hit.is_empty():
			continue
		var d := (p - (hit.position as Vector3)).dot(n)
		deepest = maxf(deepest, d)
		if i == 0:
			middle = d
	return [deepest, middle]
