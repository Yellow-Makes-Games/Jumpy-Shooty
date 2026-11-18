class_name Portals
extends Node3D
## Every player's portals (see PortalGun and Portal), and moving bodies through them.
##
## Each player has at most two: slot 0 (blue) and slot 1 (orange). Once both are
## up, walking (or falling, or flying) into either brings you out of the other, your
## speed carried through and turned to match: in through a wall, out of the floor,
## and you shoot up into the air. Anyone can use anyone's pair.
##
## The portals are placed by the copy that runs their owner (you, or the host for
## a bot) and told to everyone through Net; every copy moves its own players (you
## and its bots) through them. They go when their owner dies or leaves, when they
## pick another mobility tool, and when the wall or floor under them breaks.

const TOUCH := 0.18       ## the body this close to the portal's surface goes through
const EXIT_GAP := 0.6     ## you come out this far in front of the other portal
const EXIT_SPEED := 3.0   ## ...moving out of it at least this fast (out of a floor: EXIT_SPEED_UP)
const EXIT_SPEED_UP := 5.0
## The portal you came out of does nothing until you are this far from it, or off
## to one side: popping out of a floor, you land back on it without going round again.
const SKIP_CLEAR := 2.5

## A player's two portals can be at most this far apart. Putting one up further
## than this from the other closes the other: the new one starts a fresh pair.
const MAX_SPAN := 45.0

## owner id -> [Portal or null, Portal or null]
var _pairs := {}
## The map's own pairs (a PortalSurgeEvent's ring gates, while they are open): [[Portal,
## Portal], ...]. They belong to no player, so nothing above applies to them: no
## MAX_SPAN, and they do not close when anyone dies, changes tools or breaks a wall.
## A player's own pair is not touched by them either. Only the event that owns them
## puts them up and takes them down.
var _map_pairs: Array = []
## A map portal is gone through from its front only (its normal's side), with the
## body's skin no deeper than this behind its face: a ring gate you can walk at from
## both sides has a portal facing each way, and this keeps them apart.
const MAP_BACK := 0.3


func place(owner: int, slot: int, at: Vector3, n: Vector3, up: Vector3) -> void:
	slot = clampi(slot, 0, 1)
	var pair: Array = _pairs.get(owner, [null, null])
	var old: Portal = pair[slot]
	if old and is_instance_valid(old):
		old.queue_free()
	var p := Portal.make(owner, slot, at, n, up, Net.player_color(owner))
	p.name = "Portal_%d_%d" % [owner, slot]
	add_child(p)
	pair[slot] = p
	var other: Portal = pair[1 - slot]
	if other and is_instance_valid(other) and other.frame.origin.distance_to(at) > MAX_SPAN:
		other.queue_free()   # too far apart to link
		pair[1 - slot] = null
	_pairs[owner] = pair
	Sound.play_at("portal_open", at + n * 0.3, "move", 0.0, 0.05)
	if DevArgs.sync_log:
		print("PORTAL %d %d %d %.2f %.2f %.2f" % [Net.my_id(), owner, slot, at.x, at.y, at.z])


func clear(owner: int) -> void:
	for p in _pairs.get(owner, []):
		if p and is_instance_valid(p):
			p.queue_free()
	_pairs.erase(owner)


## A PortalSurgeEvent: these pairs of map portals are open (an empty list: none are).
## The Portal nodes are the event's own; this only moves bodies through them.
func set_map_pairs(pairs: Array) -> void:
	_map_pairs = pairs


func map_pairs() -> Array:
	return _map_pairs


## The portal in `owner`'s `slot`, or null.
func get_portal(owner: int, slot: int) -> Portal:
	var pair: Array = _pairs.get(owner, [null, null])
	var p: Portal = pair[clampi(slot, 0, 1)]
	return p if p and is_instance_valid(p) else null


func owners() -> Array:
	return _pairs.keys()


## Portals sitting on any of these boxes (broken walls or floors) go.
func remove_in(boxes: Array) -> void:
	for owner in _pairs.keys():
		var pair: Array = _pairs[owner]
		for i in 2:
			var p: Portal = pair[i]
			if p == null or not is_instance_valid(p):
				continue
			for box in boxes:
				if (box as AABB).grow(0.1).has_point(p.frame.origin - p.normal * 0.05):
					p.queue_free()
					pair[i] = null
					break


## Leaves out players who left or no longer carry the portal gun.
func prune() -> void:
	for owner in _pairs.keys():
		if not Net.players.has(owner) or Net.player_mobility(owner) != Mobility.PORTAL:
			clear(owner)


## The point of the body's capsule nearest the portal's surface, and how far its
## skin is from it (negative: already through).
static func _nearest(body: Player, p: Portal) -> Array:
	var r := Player.CAPSULE_RADIUS
	var h := body.body_height()
	var a := body.global_position + Vector3(0, r, 0)
	var b := body.global_position + Vector3(0, maxf(h - r, r), 0)
	var da := (a - p.frame.origin).dot(p.normal)
	var db := (b - p.frame.origin).dot(p.normal)
	var point := a if da < db else b
	if absf(da - db) < 0.05:   # side on (a wall portal): the bit of the body level with its middle
		var seg := b - a
		var t := clampf((p.frame.origin - a).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		point = a + seg * t
	return [point, minf(da, db) - r]


## Moves a body through a portal if it is touching one. Returns true if it went.
func check(body: Player) -> bool:
	if body.portal_skip and is_instance_valid(body.portal_skip):
		# Just came out of this one: it does nothing until you have stepped clear of it.
		var near := _nearest(body, body.portal_skip)
		if near[1] < SKIP_CLEAR and body.portal_skip.covers(near[0], 1.3):
			return false
		body.portal_skip = null
	for owner in _pairs:
		var pair: Array = _pairs[owner]
		var a: Portal = pair[0]
		var b: Portal = pair[1]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		for k in 2:
			var from: Portal = a if k == 0 else b
			var to: Portal = b if k == 0 else a
			var near := _nearest(body, from)
			if near[1] > TOUCH or near[1] < -1.0 or not from.covers(near[0]):
				continue
			if body.velocity.dot(from.normal) > 2.0:
				continue   # moving away from it (just walked off it)
			_send_through(body, from, to)
			return true
	for pair in _map_pairs:
		var a: Portal = pair[0]
		var b: Portal = pair[1]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		for k in 2:
			var from: Portal = a if k == 0 else b
			var to: Portal = b if k == 0 else a
			var near := _nearest(body, from)
			if near[1] > TOUCH or near[1] < -MAP_BACK or not from.covers(near[0]):
				continue
			if body.velocity.dot(from.normal) > 2.0:
				continue
			_send_through(body, from, to)
			return true
	return false


func _send_through(body: Player, from: Portal, to: Portal) -> void:
	var n := to.normal
	var vel := from.carry(to, body.velocity)
	var out := vel.dot(n)
	var least := EXIT_SPEED_UP if n.y > 0.5 else EXIT_SPEED
	if out < least:
		vel += n * (least - out)
	var r := Player.CAPSULE_RADIUS
	var h := body.body_height()
	var pos: Vector3
	if n.y > 0.5:
		pos = to.frame.origin + n * EXIT_GAP                       # out of a floor: feet first
	elif n.y < -0.5:
		pos = to.frame.origin + n * EXIT_GAP + Vector3(0, -h, 0)  # out of a ceiling: head first
	else:
		pos = to.frame.origin + n * (EXIT_GAP + r) + Vector3(0, -h * 0.5, 0)
	var look := Basis.from_euler(Vector3(0.0, body.input.yaw, 0.0)) * Vector3.FORWARD
	var turned := from.carry(to, look)
	var yaw := body.input.yaw
	if Vector2(turned.x, turned.z).length() > 0.3:
		yaw = atan2(-turned.x, -turned.z)
	elif absf(n.y) < 0.5:
		yaw = atan2(-n.x, -n.z)   # out of a wall from a floor: face out of it
	body.warp(pos, vel, yaw)
	body.portal_skip = to
	if DevArgs.sync_log:
		print("PORTAL_THROUGH %d %d %d" % [body.peer_id, from.owner_id, from.slot])
