class_name WorldGravity
extends RefCounted
## How strong gravity is, as a share of normal. Two things multiply together:
##
##  - `scale`: the whole map's, 1.0 almost always, lower while a map event (see
##    GravityEvent) has turned it down;
##  - the zone a body is in: 1.0 on a map with no zones. A map can say that gravity
##    differs from place to place with MapGravityZone nodes and MapRoot's Gravity
##    Outside (Empyrean Tower: 1.0 inside the tower, 0.4 everywhere outside it).
##
## The movement code multiplies its gravity by both (MovementController keeps each
## body's own number: see MovementController.gravity_scale), so everything that falls
## by the players' rules follows them: jumps, falls, swings, slides downhill, wall
## runs and glides. Bullets, rockets and grenades do not read either: weapons behave
## the same whatever they say. Gravity always pulls straight down.
##
## Only a map event changes `scale`. The arena puts it back to 1.0 when a match starts
## and when the map is unloaded, so a match that ends mid-event never leaks into the
## next one. Zones are a map's own, fixed for as long as it is loaded: MapRoot.build()
## sets them (to none, on a map without any), so every copy of the game works out
## each player's zone by itself and nothing about them travels over the network.

## Seconds a body's gravity takes to go from one zone's to the next: walking through
## a doorway eases, it never snaps.
const BLEND_TIME := 1.0

static var scale := 1.0
## Gravity where no zone is (a share of normal).
static var outside := 1.0
## The map's zones: {inv: Transform3D (the map's frame to the zone's), half: Vector3,
## round: bool, top: float (a round zone's width at the top, as a share of its foot),
## scale: float}. The first one a point is in decides.
static var zones: Array = []


static func reset() -> void:
	scale = 1.0


## MapRoot.build(): the map's zones and its gravity outside them.
static func set_zones(list: Array, outside_scale: float) -> void:
	zones = list
	outside = outside_scale


static func clear_zones() -> void:
	zones = []
	outside = 1.0


## The zone's share of normal gravity at `point` (in the map's frame), before any
## blending and without the map-wide `scale`.
static func zone_at(point: Vector3) -> float:
	for z in zones:
		var local: Vector3 = (z.inv as Transform3D) * point
		var half: Vector3 = z.half
		if absf(local.y) > half.y:
			continue
		if z.round:
			# A cylinder, or a cone cut off flat: its radius at this height.
			var up := (local.y + half.y) / maxf(half.y * 2.0, 0.001)
			var r := half.x * lerpf(1.0, z.top, up)
			if Vector2(local.x, local.z).length() <= r:
				return z.scale
		elif absf(local.x) <= half.x and absf(local.z) <= half.z:
			return z.scale
	return outside
