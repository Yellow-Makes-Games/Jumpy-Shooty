class_name Blink
extends RefCounted
## Blink: a short teleport where you look (or, for bots, a direction they choose).
##
## You keep the speed you had, and get at least BLINK_PUSH along the blink so it
## feels like a dash; falling speed is cancelled. The body is swept along the way
## first, so a blink stops short of a wall instead of going through it. Three
## charges; each comes back RECHARGE seconds after the last one did.

const RANGE := 11.0
const CHARGES := 3
const RECHARGE := 2.4     ## seconds per charge
const GAP := 0.22         ## seconds between two blinks
const MIN_DISTANCE := 1.2 ## a blink that would go less far than this (a wall in your face) is refused
const BLINK_PUSH := 6.0   ## at least this much speed along the blink afterwards

var charges := CHARGES
var _recharge := 0.0
var _gap := 0.0


func update(delta: float) -> void:
	_gap = maxf(_gap - delta, 0.0)
	if charges < CHARGES:
		_recharge += delta
		if _recharge >= RECHARGE:
			_recharge -= RECHARGE
			charges += 1
	else:
		_recharge = 0.0


func ready() -> bool:
	return charges > 0 and _gap <= 0.0


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
	_recharge = 0.0
	_gap = 0.0


## Where a blink along `dir` from the body's feet ends: the body's own shape swept
## through the level (other players are passed through). Returns INF when there is
## no room to go.
static func destination(body: CharacterBody3D, shape: CollisionShape3D, dir: Vector3) -> Vector3:
	if dir.length_squared() < 0.0001:
		return Vector3.INF
	dir = dir.normalized()
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = shape.global_transform.translated(Vector3(0, 0.06, 0))   # clear of the floor it stands on
	q.motion = dir * RANGE
	q.collision_mask = 1
	q.exclude = [body.get_rid()]
	q.margin = 0.02
	var parts := space.cast_motion(q)
	var safe: float = parts[0] if parts.size() > 0 else 1.0
	var dist := maxf(safe * RANGE - 0.08, 0.0)
	# The sweep misses anything the body already touches when it sets off (a wall
	# you are pressed against): rays through the middle of the body catch those.
	var r := (shape.shape as CapsuleShape3D).radius if shape.shape is CapsuleShape3D else 0.4
	for h in [0.35, 0.5, 0.65]:
		var height := (shape.shape as CapsuleShape3D).height if shape.shape is CapsuleShape3D else 1.8
		var from := body.global_position + Vector3(0, height * h, 0)
		var ray := PhysicsRayQueryParameters3D.create(from, from + dir * (dist + r), 1, [body.get_rid()])
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			dist = minf(dist, from.distance_to(hit.position) - r - 0.1)
	# Never end inside something: back off until the body fits.
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = shape.shape
	fit.collision_mask = 1
	fit.exclude = [body.get_rid()]
	while dist >= MIN_DISTANCE:
		fit.transform = q.transform.translated(dir * dist)
		if space.intersect_shape(fit, 1).is_empty():
			break
		dist -= 0.4
	if dist < MIN_DISTANCE:
		return Vector3.INF
	return body.global_position + dir * dist


## Velocity after a blink along `dir`.
static func carry(vel: Vector3, dir: Vector3) -> Vector3:
	dir = dir.normalized()
	if vel.y < 0.0:
		vel.y = 0.0
	var along := vel.dot(dir)
	if along < BLINK_PUSH:
		vel += dir * (BLINK_PUSH - along)
	return vel
