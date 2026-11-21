class_name Blink
extends RefCounted
## Blink: a short teleport where you look (or, for bots, a direction they choose).
##
## You keep the speed you had, and get at least BLINK_PUSH along the blink so it
## feels like a dash; falling speed is cancelled. The body is swept along the way
## first, so a blink stops short of a wall instead of going through it.
##
## Three charges, which come back one at a time, RECHARGE seconds each. They can
## be used in quick succession (GAP apart), but each blink adds STRAIN, which
## drains away at STRAIN_RECOVER a second, and the strain left when you blink
## shortens it: every point of strain takes STRAIN_FALLOFF off the range, down to
## MIN_REACH of it. So three blinks in a burst go about 11, 8 and 5.5 m; spaced a
## second apart they all go the full 11 m.

const RANGE := 11.0
const CHARGES := 3
const RECHARGE := 2.2         ## seconds per charge (they come back one at a time)
const GAP := 0.15             ## seconds between two blinks
const MIN_DISTANCE := 1.2     ## a blink that would go less far than this (a wall in your face) is refused
const BLINK_PUSH := 6.0       ## at least this much speed along the blink afterwards
const STRAIN_PER_BLINK := 1.0 ## strain each blink adds
const STRAIN_RECOVER := 1.0   ## strain that drains away each second
const STRAIN_MAX := 3.0
const STRAIN_FALLOFF := 0.3   ## the share of the range each point of strain takes off
const MIN_REACH := 0.45       ## a blink never goes less than this share of RANGE

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
## body's own shape swept through the level (other players are passed through).
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
