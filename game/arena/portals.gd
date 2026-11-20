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
const EXIT_SKIN := 0.1    ## you come out with this much air between you and the other portal's face
const EXIT_GAP := 0.6     ## ...or this much, where there is no room for you nearer than that
const EXIT_SPEED := 3.0   ## ...moving out of it at least this fast (out of a floor: EXIT_SPEED_UP)
const EXIT_SPEED_UP := 5.0
## The portal you came out of does nothing until you are clear of it: this far from a
## floor's (popping out of a floor, you land back on it without going round again), or
## off to one side of it; a step away from one on a wall or a ceiling, which you can
## turn round and walk straight back into.
const SKIP_CLEAR := 2.5
const SKIP_CLEAR_WALL := 0.45

## Falling toward a floor portal of a linked pair with your hands off the keys, you are
## eased over its middle on the way down, so a long drop into one (or a fall that goes
## round and round through two) does not clip the rim. Only while you fall at least
## FUNNEL_SPEED with little sideways speed, from at most FUNNEL_HEIGHT above it, inside
## a cone that widens with height; any steering of your own turns it off.
const FUNNEL_HEIGHT := 14.0
const FUNNEL_SPEED := 7.0
const FUNNEL_SIDEWAYS := 8.0
const FUNNEL_PULL := 18.0   ## m/s2 at most

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

## Seeing through portals (see Portal.update_view): every copy draws its own view, so
## nothing goes over the network. Only a linked pair's portals open a view, and only
## those in front of the camera, in its field of view and within VIEW_RANGE: the
## nearest MAX_VIEWS of them. Each renders the arena again, at about the size it
## takes on screen (VIEW_MIN_PX to VIEW_MAX_PX tall, in VIEW_STEP_PX steps so it is
## not resized every frame). Any other portal shows its plain glowing face.
const VIEW_RANGE := 90.0
const MAX_VIEWS := 4
const VIEW_MIN_PX := 96
const VIEW_MAX_PX := 720
const VIEW_STEP_PX := 48
## Tests: off where nothing is drawn (a headless run).
var views_enabled := DisplayServer.get_name() != "headless"


func _init() -> void:
	process_priority = 100   # after every camera has moved this frame


func _process(_delta: float) -> void:
	update_views(get_viewport().get_camera_3d() if is_inside_tree() else null)


## Turns each portal's view on or off for what `cam` (the main view's camera) sees.
func update_views(cam: Camera3D) -> void:
	var wanted := []   # [distance, portal, its partner]
	if views_enabled and cam and is_instance_valid(cam):
		cam.set_cull_mask_value(Portal.FLAT_LAYER, false)   # the main view sees the windows
		var eye := cam.global_position
		var planes := cam.get_frustum()
		for owner in _pairs:
			var pair: Array = _pairs[owner]
			var a: Portal = pair[0]
			var b: Portal = pair[1]
			if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
				continue
			for k in 2:
				var p: Portal = a if k == 0 else b
				var d := eye.distance_to(p.frame.origin)
				if d > VIEW_RANGE or (eye - p.frame.origin).dot(p.normal) < 0.03:
					continue
				if not _in_frustum(planes, p.frame.origin, maxf(p.half_width, p.half_height) * 1.1):
					continue
				wanted.append([d, p, b if k == 0 else a])
	wanted.sort_custom(func(x, y): return x[0] < y[0])
	var on := {}
	if not wanted.is_empty():
		var screen_h := float(get_viewport().get_visible_rect().size.y)
		var tan_half := tan(deg_to_rad(cam.fov) * 0.5)
		for i in mini(wanted.size(), MAX_VIEWS):
			var p: Portal = wanted[i][1]
			if p.update_view(cam, wanted[i][2], view_pixels(wanted[i][0], p.half_height, tan_half, screen_h)):
				on[p] = true
	for owner in _pairs:
		for p in _pairs[owner]:
			if p and is_instance_valid(p) and not on.has(p):
				p.set_live(false)


## How tall (pixels) a portal's view is rendered: about as tall as it is on screen.
static func view_pixels(dist: float, half_h: float, tan_half: float, screen_h: float) -> int:
	var px := screen_h * half_h / (maxf(dist, 0.5) * maxf(tan_half, 0.05))
	var stepped := int(ceil(px / VIEW_STEP_PX)) * VIEW_STEP_PX
	return clampi(stepped, VIEW_MIN_PX, mini(VIEW_MAX_PX, int(maxf(screen_h, VIEW_MIN_PX))))


## Is a sphere at least partly inside the camera's frustum? (Its planes face out.)
static func _in_frustum(planes: Array, at: Vector3, radius: float) -> bool:
	for pl in planes:
		if (pl as Plane).distance_to(at) > radius:
			return false
	return true


## The portal views live right now (tests).
func live_views() -> Array:
	var out := []
	for owner in _pairs:
		for p in _pairs[owner]:
			if p and is_instance_valid(p) and p.live:
				out.append(p)
	return out


## `on`: the moving part of the map it sits on, if any (the portal rides it); null: found
## here (see carrier_at), so a copy told only where it is still has it ride. `shot`: it
## was just shot there (the gun's bolt and the sound of it opening), not one that was
## already up when this copy joined.
func place(owner: int, slot: int, at: Vector3, n: Vector3, up: Vector3, on: Node3D = null, shot: bool = true) -> void:
	slot = clampi(slot, 0, 1)
	var pair: Array = _pairs.get(owner, [null, null])
	var old: Portal = pair[slot]
	if old and is_instance_valid(old):
		old.close()
	var p := Portal.make(owner, slot, at, n, up, Net.player_color(owner))
	p.name = "Portal_%d_%d" % [owner, slot]
	add_child(p)
	p.ride(on if on else carrier_at(at, n))
	if is_inside_tree():
		var seat := PortalFit.seat(get_world_3d().direct_space_state, p.frame, p.half_width, p.half_height)
		p.set_seat(seat[0], seat[1])
	pair[slot] = p
	var other: Portal = pair[1 - slot]
	if other and is_instance_valid(other) and other.frame.origin.distance_to(at) > MAX_SPAN:
		other.close()   # too far apart to link
		pair[1 - slot] = null
	_pairs[owner] = pair
	if shot:
		Sound.play_at("portal_open", at + n * 0.3, "move", 0.0, 0.05)
		var who := _player(owner)
		if who:
			who.show_portal_shot(at, slot, true)
	if DevArgs.sync_log:
		print("PORTAL %d %d %d %.2f %.2f %.2f seat %.2f" % [Net.my_id(), owner, slot, at.x, at.y, at.z, p.seat_depth])


## `owner`'s shot reached a surface that takes no portal (PortalGun.find_spot's "miss"):
## the bolt flies there and fizzles out.
func fizzle(owner: int, slot: int, at: Vector3, n: Vector3) -> void:
	Portal.fizzle(self, at, n, Portal.COLORS[clampi(slot, 0, 1)])
	Sound.play_at("portal_fizzle", at + n * 0.2, "move", 0.0, 0.08)
	var who := _player(owner)
	if who:
		who.show_portal_shot(at, slot, false)


## The player `id` in this arena, if this is an arena and they are in it.
func _player(id: int) -> Player:
	var arena = Net.arena
	if arena == null or not is_instance_valid(arena) or not arena.has_method("get_player"):
		return null
	return arena.get_player(id) as Player


## A portal at `at` facing `n` on a moving part of the map (anything that moves and can
## be stood on or hooked: an AnimatableBody3D): that part, else null.
func carrier_at(at: Vector3, n: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var space := get_world_3d().direct_space_state
	# (It may stand proud of the part: on a rib, a sign. See PortalFit.)
	var q := PhysicsRayQueryParameters3D.create(at + n * 0.15, at - n * (PortalFit.MAX_LIFT + PortalFit.RECESS + 0.1), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit.collider is AnimatableBody3D:
		return hit.collider
	return null


## A portal that sits on a moving part, as a message can carry it: [path to the part
## from the arena (or ""), the portal's frame on it]. See place_on.
func carrier_of(p: Portal, arena: Node) -> Array:
	if p == null or p.carrier == null or not is_instance_valid(p.carrier) or arena == null:
		return ["", Transform3D.IDENTITY]
	return [str(arena.get_path_to(p.carrier)), p.carrier_frame]


## A portal put up on a moving part elsewhere: `path` (from the arena) and its frame on
## it, so it lands on the same spot of the part wherever the part has got to here.
## Falls back to where it was (at, n, up) if this copy has no such part.
func place_on(owner: int, slot: int, at: Vector3, n: Vector3, up: Vector3, arena: Node, path: String, local: Transform3D, shot: bool = true) -> void:
	var on: Node3D = arena.get_node_or_null(NodePath(path)) as Node3D if path != "" and arena else null
	if on:
		var xf := (on.global_transform * local).orthonormalized()
		place(owner, slot, xf.origin, xf.basis.z, xf.basis.y, on, shot)
	else:
		place(owner, slot, at, n, up, null, shot)


## Portals on moving parts go where their part has gone; ones whose part has gone close.
func follow_carriers() -> void:
	for owner in _pairs:
		var pair: Array = _pairs[owner]
		for i in 2:
			var p: Portal = pair[i]
			if p and is_instance_valid(p) and not p.follow():
				p.queue_free()
				pair[i] = null


func _physics_process(_delta: float) -> void:
	follow_carriers()


func clear(owner: int) -> void:
	for p in _pairs.get(owner, []):
		if p and is_instance_valid(p):
			p.close()
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


## Is `body` going into `from`: its skin within TOUCH of the face in front of the oval
## (or it will be within `delta` seconds, moving as it is), no deeper than `back`
## behind the face, and not on its way out of it?
func _entering(body: Player, from: Portal, delta: float, back: float) -> bool:
	var into := -body.velocity.dot(from.normal)
	if into < -2.0:
		return false   # moving away from it (just walked off it)
	var near := _nearest(body, from)
	var d: float = near[1]
	if d < -back or d > TOUCH + maxf(into, 0.0) * delta:
		return false
	var at: Vector3 = near[0]
	if d > TOUCH and into > 0.0:
		at += body.velocity * ((d - TOUCH) / into)   # where it will be as it touches
	return from.covers(at)


## Moves a body through a portal if it is touching one, or about to: called before the
## body's own step of `delta` seconds, so one falling or flying fast goes through
## with all its speed instead of first landing on (or hitting) the wall round the
## portal and losing it. Returns true if it went.
func check(body: Player, delta: float = 0.0) -> bool:
	follow_carriers()   # (the map's parts have moved this step: be where they are)
	if body.portal_skip and is_instance_valid(body.portal_skip) and not body.portal_skip.closing:
		# Just came out of this one: it does nothing until you have stepped clear of it.
		var skip: Portal = body.portal_skip
		var near := _nearest(body, skip)
		var clear := SKIP_CLEAR if skip.normal.y > 0.5 else SKIP_CLEAR_WALL
		if near[1] < clear and skip.covers(near[0], 1.3):
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
			if _entering(body, from, delta, 1.0):
				_send_through(body, from, b if k == 0 else a)
				return true
	for pair in _map_pairs:
		var a: Portal = pair[0]
		var b: Portal = pair[1]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		for k in 2:
			var from: Portal = a if k == 0 else b
			if _entering(body, from, delta, MAP_BACK):
				_send_through(body, from, b if k == 0 else a)
				return true
	return false


## Eases a falling body over the middle of the floor portal under it (see FUNNEL_HEIGHT).
## Called before the body's step, like check.
func funnel(body: Player, delta: float) -> void:
	var fall := -body.velocity.y
	if fall < FUNNEL_SPEED or body.is_on_floor() or body.input.move.length() > 0.2:
		return
	if Vector2(body.velocity.x, body.velocity.z).length() > FUNNEL_SIDEWAYS:
		return
	for owner in _pairs:
		var pair: Array = _pairs[owner]
		if pair[0] == null or pair[1] == null or not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
			continue
		for p: Portal in pair:
			if p.normal.y < 0.9 or p == body.portal_skip:
				continue
			var l := p.to_local_frame(body.global_position)
			if l.z < 0.3 or l.z > FUNNEL_HEIGHT or not p.covers(body.global_position, 1.0 + l.z * 0.12):
				continue
			# The sideways speed that brings it over the middle as it gets there.
			var off := p.frame.basis.x * l.x + p.frame.basis.y * l.y
			var want := -off / maxf(l.z / fall, 0.15)
			var sideways := body.velocity - p.normal * body.velocity.dot(p.normal)
			body.velocity += (want - sideways).limit_length(FUNNEL_PULL * delta)
			return


## The linked portal a body at `from` (the middle of it) has just gone into to come out
## at `to`, and its partner: [in, out], or [] if no pair is there (it blinked, or it
## went by a map gate). For the looks of someone else's trip: a copy is told only
## where they were and where they are now.
func trip(from: Vector3, to: Vector3) -> Array:
	var best := []
	var best_d := 3.0
	for owner in _pairs:
		var pair: Array = _pairs[owner]
		if pair[0] == null or pair[1] == null or not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
			continue
		for k in 2:
			var a: Portal = pair[k]
			var b: Portal = pair[1 - k]
			var d := maxf(a.frame.origin.distance_to(from), b.frame.origin.distance_to(to))
			if d < best_d:
				best_d = d
				best = [a, b]
	return best


# ---------------------------------------------------------------------------
# Shots through portals. Bullets, pellets, rockets and grenades go in one portal
# of a linked pair and come out of the other, turned to match, like players do (the
# map's ring gates still let them fly on: see PortalSurgeEvent).

## A shot can go through at most this many portals.
const MAX_HOPS := 4
## It comes out this far in front of the other portal.
const SHOT_EXIT := 0.03


## Where a straight move from `a` to `b` goes into a linked portal from its front, the
## nearest along it: {} if none, else {"t" (0..1 along it), "at", "from", "to" (its partner)}.
func crossing(a: Vector3, b: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	for owner in _pairs:
		var pair: Array = _pairs[owner]
		var p0: Portal = pair[0]
		var p1: Portal = pair[1]
		if p0 == null or p1 == null or not is_instance_valid(p0) or not is_instance_valid(p1):
			continue
		for k in 2:
			var from: Portal = p0 if k == 0 else p1
			var da := (a - from.frame.origin).dot(from.normal)
			var db := (b - from.frame.origin).dot(from.normal)
			if da < 0.0 or db > 0.0 or da == db:
				continue
			var t := da / (da - db)
			if t >= best_t:
				continue
			var at := a + (b - a) * t
			if not from.covers(at):
				continue
			best_t = t
			best = {"t": t, "at": at, "from": from, "to": p1 if k == 0 else p0}
	return best


## A shot's path from `from` along `dir` for `reach` metres, through any portals in
## its way: legs [{a, b, dir, hit}], each but the last ending going into a portal and
## the next starting out of its partner. The last ends where the ray (`mask`, leaving
## out `exclude`) hits something (its result in `hit`) or runs out of reach.
func shot_path(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, reach: float, mask: int, exclude: Array[RID] = []) -> Array:
	var legs := []
	dir = dir.normalized()
	var left := reach
	for hop in MAX_HOPS + 1:
		var end := from + dir * left
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, mask, exclude))
		var stop: Vector3 = end if hit.is_empty() else hit.position
		var x := crossing(from, stop + dir * 0.05) if hop < MAX_HOPS else {}
		if x.is_empty() or from.distance_to(x.at) > from.distance_to(stop) + 0.05:
			legs.append({"a": from, "b": stop, "dir": dir, "hit": hit})
			break
		legs.append({"a": from, "b": x.at, "dir": dir, "hit": {}})
		left -= from.distance_to(x.at)
		var into: Portal = x.from
		var out: Portal = x.to
		from = into.carry_point(out, x.at) + out.normal * SHOT_EXIT
		dir = into.carry(out, dir).normalized()
		if left <= 0.0:
			legs.append({"a": from, "b": from, "dir": dir, "hit": {}})
			break
	return legs


## The points where a path (shot_path) goes in and comes out of portals: [in, out, in,
## out...], empty for a straight shot. What the shot effect draws its tracer through.
static func path_bends(legs: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(1, legs.size()):
		if legs[i].has("through"):
			continue   # (it went through a wall there, not a portal: see MapDestruction.pierce)
		out.append(legs[i - 1].b)
		out.append(legs[i].a)
	return out


## Shots went through portals at these points (`vias`: per pellet, a path_bends): the
## portals they went into and came out of ripple. Every copy draws it from the shot it
## was told about.
func shots_through(vias: Array) -> void:
	for bends in vias:
		for at: Vector3 in bends:
			for owner in _pairs:
				for p: Portal in _pairs[owner]:
					if p != null and is_instance_valid(p) and absf((at - p.frame.origin).dot(p.normal)) < 0.2 and p.covers(at):
						p.ripple()


## Through `from` and out of `to`, like a doorway between them: the body comes out at
## the same spot on the other oval it went in at (as near as it fits there), moving
## and looking the way it was, turned to match. So what you saw through the portal as
## you went in is what you see as you come out.
func _send_through(body: Player, from: Portal, to: Portal) -> void:
	var n := to.normal
	var r := Player.CAPSULE_RADIUS
	var h := body.body_height()
	# Speed: carried through, and at least a push out of it.
	var vel := from.carry(to, body.velocity)
	var out := vel.dot(n)
	var least := EXIT_SPEED_UP if n.y > 0.5 else EXIT_SPEED
	if out < least:
		vel += n * (least - out)
	# Place: where the middle of the body was on the oval it went into, on the other
	# one, kept far enough inside it for the (upright) body to come out whole.
	var b := to.frame.basis
	var l := from.to_local_frame(body.global_position + Vector3(0, h * 0.5, 0))
	var spine := h * 0.5 - r
	var room_x := maxf(to.half_width - r - spine * absf(b.x.y), 0.0)
	var room_y := maxf(to.half_height - r - spine * absf(b.y.y), 0.0)
	var side := Vector2(clampf(-l.x, -room_x, room_x), clampf(l.y, -room_y, room_y))
	var reach := r + spine * absf(n.y)   # how far the body reaches toward the surface
	var mid := to.frame * Vector3(0.0, 0.0, reach + EXIT_GAP)
	for spot in [[side, EXIT_SKIN], [side * 0.5, EXIT_SKIN], [Vector2.ZERO, EXIT_SKIN], [side, EXIT_GAP]]:
		var at: Vector3 = to.frame * Vector3(spot[0].x, spot[0].y, reach + spot[1])
		if body.fits_at(at - Vector3(0, h * 0.5, 0)):
			mid = at
			break
	var pos := mid - Vector3(0, h * 0.5, 0)
	# The view: carried through whole. Which way you look (up and down too: in through
	# a floor looking down, out of a wall looking along it) and, for a moment, how the
	# view is tipped, which then rights itself.
	var view := Basis.from_euler(Vector3(body.input.pitch, body.input.yaw, 0.0))
	var ahead := from.carry(to, view * Vector3.FORWARD)
	var top := from.carry(to, view * Vector3.UP)
	var yaw := body.input.yaw
	if Vector2(ahead.x, ahead.z).length() > 0.05:
		yaw = atan2(-ahead.x, -ahead.z)
	else:   # looking straight up or down: the top of the view says which way you face
		var facing := top * (-1.0 if ahead.y > 0.0 else 1.0)
		yaw = atan2(-facing.x, -facing.z)
	var pitch := clampf(asin(clampf(ahead.y, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
	var upright := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var roll := atan2(-top.dot(upright.x), top.dot(upright.y))
	# Running through from one wall to another along the floor, you stay on your feet.
	var on_floor := false
	if body.is_on_floor() and absf(n.y) < 0.5 and is_inside_tree():
		var below := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.15, 0), pos - Vector3(0, 0.3, 0), 1)
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(below)
		on_floor = not floor_hit.is_empty() and (floor_hit.normal as Vector3).y > 0.7
	# Where your eyes would be had you walked through a doorway (never behind the
	# portal's face): the view starts there and catches the body up (Player.view_carried).
	var seen := to.to_local_frame(from.carry_point(to, body.eye_position()))
	seen.z = maxf(seen.z, VIEW_FRONT)
	body.warp(pos, vel, yaw, pitch, on_floor, [from, to])
	body.portal_skip = to
	body.view_carried(to.frame * seen, roll, vel.length())
	if DevArgs.sync_log:
		print("PORTAL_THROUGH %d %d %d" % [body.peer_id, from.owner_id, from.slot])


## Coming out, your view is never nearer than this to the portal's face (the camera
## must not look through the surface the portal is on).
const VIEW_FRONT := 0.16
