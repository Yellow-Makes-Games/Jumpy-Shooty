class_name Blink
extends RefCounted
## Blink: a short teleport where you look (or, for bots, a direction they choose).
##
## You keep the speed you had, and get at least BLINK_PUSH along the blink so it
## feels like a dash; falling speed is cancelled.
##
## A blink goes through walls: aimed at a wall, it goes its full reach and lands on
## the far side, pulled back towards you until the body fits somewhere open. It only
## goes through walls (steep faces), not floors, ceilings or ramps, so looking a little
## down or up as you blink never drops you a storey. It never lands outside the map:
## out of its fence, over nothing (no ground under it before the map's kill height) or
## in a hazard; with nowhere like that past the wall, it stops short of the wall.
##
## Three charges, which come back one at a time, RECHARGE seconds each. They can
## be used in quick succession (GAP apart), but each blink adds STRAIN, which
## drains away at STRAIN_RECOVER a second, and the strain left when you blink
## shortens it: every point of strain takes STRAIN_FALLOFF off the range, down to
## MIN_REACH of it. So three blinks in a burst go about 7.5, 5.6 and 3.8 m; spaced a
## second apart they all go the full 7.5 m.

const RANGE := 7.5
const CHARGES := 3
const RECHARGE := 5.0         ## seconds per charge (they come back one at a time)
const GAP := 0.15             ## seconds between two blinks
const MIN_DISTANCE := 1.2     ## a blink that would go less far than this (a wall in your face) is refused
const BLINK_PUSH := 6.0       ## at least this much speed along the blink afterwards
const STRAIN_PER_BLINK := 1.0 ## strain each blink adds
const STRAIN_RECOVER := 1.0   ## strain that drains away each second
const STRAIN_MAX := 3.0
const STRAIN_FALLOFF := 0.3   ## the share of the range each point of strain takes off
const MIN_REACH := 0.45       ## a blink never goes less than this share of RANGE
const WALL_STEEP := 0.5       ## a face whose normal points up or down less than this is a wall (blinked through)
const THROUGH_STEP := 0.3     ## how far a blink through a wall pulls back each time the spot is not open

var charges := CHARGES
var strain := 0.0
var _recharge := 0.0
var _gap := 0.0


func update(delta: float) -> void:
	_gap = maxf(_gap - delta, 0.0)
	strain = maxf(strain - STRAIN_RECOVER * delta, 0.0)
	if charges < CHARGES:
		_recharge += delta
		if _recharge >= RECHARGE:
			_recharge -= RECHARGE
			charges += 1
	else:
		_recharge = 0.0


func ready() -> bool:
	return charges > 0 and _gap <= 0.0


## 0..1: the share of RANGE the next blink goes, after the strain of the last few.
func strength() -> float:
	return clampf(1.0 - STRAIN_FALLOFF * strain, MIN_REACH, 1.0)


## How far (m) the next blink goes in the open.
func reach() -> float:
	return RANGE * strength()


## Spend a charge on a blink that went (call it after the blink: its reach was
## worked out from the strain before it).
func spend() -> void:
	charges -= 1
	_gap = GAP
	strain = minf(strain + STRAIN_PER_BLINK, STRAIN_MAX)


## A blink that had no room to go: no charge, but the same short gap.
func refuse() -> void:
	_gap = GAP


## 0..1: charges, with the one coming back counted in part (the HUD's bar).
func readiness() -> float:
	if charges >= CHARGES:
		return 1.0
	return (charges + _recharge / RECHARGE) / float(CHARGES)


## How far the next charge has come back, 0..1 (1 when full).
func recharge_progress() -> float:
	return 1.0 if charges >= CHARGES else _recharge / RECHARGE


func reset() -> void:
	charges = CHARGES
	strain = 0.0
	_recharge = 0.0
	_gap = 0.0


## Where a blink along `dir` from the body's feet ends, going at most `reach` m: the
## body's own shape swept through the level (other players are passed through). A
## wall in the way is blinked through when there is open ground past it (see the top).
## Returns INF when there is no room to go.
static func destination(body: CharacterBody3D, shape: CollisionShape3D, dir: Vector3, reach := RANGE) -> Vector3:
	if dir.length_squared() < 0.0001:
		return Vector3.INF
	dir = dir.normalized()
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = shape.global_transform.translated(Vector3(0, 0.06, 0))   # clear of the floor it stands on
	q.motion = dir * reach
	q.collision_mask = 1
	q.exclude = [body.get_rid()]
	q.margin = 0.02
	var parts := space.cast_motion(q)
	var safe: float = parts[0] if parts.size() > 0 else 1.0
	var dist := maxf(safe * reach - 0.08, 0.0)
	var wall := false   # stopped by a wall (not a floor, ceiling or ramp)
	if safe < 1.0:
		var touch := PhysicsShapeQueryParameters3D.new()
		touch.shape = shape.shape
		touch.transform = q.transform.translated(dir * reach * (parts[1] as float))
		touch.collision_mask = 1
		touch.exclude = [body.get_rid()]
		touch.margin = 0.05
		var info := space.get_rest_info(touch)
		wall = not info.is_empty() and absf((info.normal as Vector3).y) < WALL_STEEP
	# The sweep misses anything the body already touches when it sets off (a wall
	# you are pressed against): rays through the middle of the body catch those.
	var r := (shape.shape as CapsuleShape3D).radius if shape.shape is CapsuleShape3D else 0.4
	var height := (shape.shape as CapsuleShape3D).height if shape.shape is CapsuleShape3D else 1.8
	for h in [0.35, 0.5, 0.65]:
		var from := body.global_position + Vector3(0, height * h, 0)
		var ray := PhysicsRayQueryParameters3D.create(from, from + dir * (dist + r), 1, [body.get_rid()])
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var near := from.distance_to(hit.position) - r - 0.1
			if near < dist:
				dist = near
				wall = absf((hit.normal as Vector3).y) < WALL_STEEP
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = shape.shape
	fit.collision_mask = 1
	fit.exclude = [body.get_rid()]
	# Through a wall: the full reach, pulled back until the body fits on open ground
	# inside the map, but never to this side of the wall.
	if wall:
		var d := reach
		while d > dist + r * 2.0:
			fit.transform = q.transform.translated(dir * d)
			if space.intersect_shape(fit, 1).is_empty() and in_map(body, body.global_position + dir * d):
				return body.global_position + dir * d
			d -= THROUGH_STEP
	# Never end inside something: back off until the body fits.
	dist = maxf(dist, 0.0)
	while dist >= MIN_DISTANCE:
		fit.transform = q.transform.translated(dir * dist)
		if space.intersect_shape(fit, 1).is_empty():
			break
		dist -= 0.4
	if dist < MIN_DISTANCE:
		return Vector3.INF
	return body.global_position + dir * dist


## Can a blink through a wall land with its feet at `feet`: inside the map's fence,
## out of its hazards, and over ground (something under it before the kill height)?
static func in_map(body: CharacterBody3D, feet: Vector3) -> bool:
	var floor_y := -60.0
	var layout: Node = Net.arena.layout if Net.arena and Net.arena.get("layout") else null
	if layout:
		floor_y = layout.kill_height
		var area: Rect2 = layout.bounds
		if area.has_area() and not area.has_point(Vector2(feet.x, feet.z)):
			return false
		if layout.has_method("body_in_hazard") and not layout.hazards.is_empty() and layout.body_in_hazard(feet):
			return false
	if feet.y <= floor_y:
		return false
	var down := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.2, 0), Vector3(feet.x, floor_y, feet.z), 1, [body.get_rid()])
	return not body.get_world_3d().direct_space_state.intersect_ray(down).is_empty()


## Velocity after a blink along `dir`.
static func carry(vel: Vector3, dir: Vector3) -> Vector3:
	dir = dir.normalized()
	if vel.y < 0.0:
		vel.y = 0.0
	var along := vel.dot(dir)
	if along < BLINK_PUSH:
		vel += dir * (BLINK_PUSH - along)
	return vel
