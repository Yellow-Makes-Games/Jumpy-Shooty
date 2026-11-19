extends Node
## The body of tests/portal_gun_test.gd (a separate file: it uses the game's autoloads).

const HW := Portal.HALF_WIDTH
const HH := Portal.HALF_HEIGHT
## A test wall built in the open air, well off the map: its middle, facing +z.
const YARD := Vector3(140.0, 60.0, 140.0)

var _ok := true
var me: Player
var arena
var portals: Portals
var _wall_at := []


func run() -> void:
	Settings.mobility = Mobility.PORTAL   # (not saved: the test never calls save_settings)
	Game.start_practice("construction_site")
	await _frames(30)
	arena = Net.arena
	portals = arena.portals
	me = arena.local_player
	_check(me.portal_gun != null, "practice on the Construction Site, with the portal gun")
	await _placing()
	await _opening_and_closing()
	await _going_through()
	print("PASS: every check passed" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


# --- Where portals go.

func _placing() -> void:
	print("  placing")
	var space := me.get_world_3d().direct_space_state
	var map: MapRoot = MapRoot.current

	# The ribbed container with the sign on it (the one in the bug report).
	var eye := Vector3(-27.0, 1.5, -26.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, Vector3(-30.3, 1.4, -25.9) + (Vector3(-30.3, 1.4, -25.9) - eye), 1))
	_check(not hit.is_empty(), "found the ribbed container")
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		var wall := Transform3D(Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n), hit.position)
		var ribs: float = map.decor_relief(wall, HW * 1.2, HH * 1.2, PortalFit.MAX_LIFT)
		_check(ribs > 0.03, "its ribs and sign stand out of the wall the shot lands on (%.2f m), and are not solid" % ribs)
		var p := _shoot(0, eye, Vector3(-30.3, 1.4, -25.9))
		_check(p != null, "it takes a portal")
		if p:
			var out := (p.frame.origin - (hit.position as Vector3)).dot(n)
			_check(out >= ribs + PortalFit.SKIN - 0.005 and out <= PortalFit.MAX_LIFT + PortalFit.SKIN + 0.005,
				"the portal stands on the ribs, not in them (%.2f m out from the wall)" % out)
			_check(map.decor_relief(p.frame, HW * 1.2, HH * 1.2, PortalFit.MAX_LIFT) <= 0.0,
				"nothing sticks through its face or its rim")
			_check(p.seat_depth >= ribs and p.seat_depth <= PortalFit.MAX_LIFT + PortalFit.RECESS,
				"a collar joins it to the wall behind (%.2f m deep)" % p.seat_depth)
			_check(_all_held(space, p), "all of it is over the container")
		# At the foot of it: clear of the floor.
		var low := _shoot(0, eye, Vector3(-30.3, 0.2, -25.6))
		_check(low != null and low.frame.origin.y - HH >= 0.0, "shot at the foot of the container, it stands clear of the floor (%.2f)" % ((low.frame.origin.y - HH) if low else -1.0))
	portals.clear(me.peer_id)

	# A wall of our own, in the open: 8 m wide, 6 m high, flat.
	var wall_body := _box(YARD + Vector3(0, 0, -0.25), Vector3(8.0, 6.0, 0.5))
	await _physics(3)
	space = me.get_world_3d().direct_space_state
	var from := YARD + Vector3(0, 0, 6.0)
	var flat := _shoot(0, from, YARD)
	_check(flat != null and flat.frame.origin.distance_to(YARD + Vector3(0, 0, PortalFit.SKIN)) < 0.01,
		"on a flat wall a portal lies on the wall, where it was aimed (%s)" % (str(flat.frame.origin - YARD) if flat else "none"))
	_check(flat != null and flat.seat_depth <= PortalFit.SKIN + 0.005, "...with no collar to speak of")

	# Near its side edge: moved onto the wall.
	var edge := _shoot(0, from, YARD + Vector3(3.8, 0, 0))
	_check(edge != null and edge.frame.origin.x - YARD.x < 3.8 - 0.3 and _all_held(space, edge),
		"shot 20 cm from the edge of the wall, it moves onto the wall (%.2f m in from the edge)" % ((4.0 - (edge.frame.origin.x - YARD.x)) if edge else -1.0))
	# Near the top corner.
	var corner := _shoot(0, from, YARD + Vector3(-3.7, 2.8, 0))
	_check(corner != null and _all_held(space, corner), "and at a corner, in from both edges")

	# A solid beam across the wall, 12 cm proud: the portal stands on it.
	var beam := _box(YARD + Vector3(0, 0.3, 0.06), Vector3(8.0, 0.2, 0.12))
	await _physics(3)
	var on_beam := _shoot(0, from, YARD + Vector3(0, -0.2, 0))
	_check(on_beam != null and absf(on_beam.frame.origin.z - YARD.z - 0.12 - PortalFit.SKIN) < 0.01,
		"a beam across the wall is under the portal, not through it (%.2f m out)" % ((on_beam.frame.origin.z - YARD.z) if on_beam else -1.0))
	_check(on_beam != null and absf(on_beam.seat_depth - 0.12 - PortalFit.SKIN) < 0.01, "...its collar reaches back to the wall (%.2f)" % (on_beam.seat_depth if on_beam else -1.0))
	beam.queue_free()

	# A crate against the wall: the portal moves off it.
	var crate := _box(YARD + Vector3(1.0, 0, 0.5), Vector3(1.0, 1.0, 1.0))
	await _physics(3)
	var by_crate := _shoot(0, from + Vector3(-1.0, 0, 0), YARD + Vector3(0.1, 0, 0))
	var clear := by_crate != null
	if by_crate:
		for d in PortalFit.probe(space, Transform3D(by_crate.frame.basis, by_crate.frame.origin - by_crate.normal * PortalFit.SKIN), HW, HH):
			if is_nan(d) or d == INF:
				clear = false
	_check(clear and by_crate.frame.origin.x < YARD.x + 0.5 - HW * 0.9,
		"shot beside a crate that stands against the wall, it moves off the crate (%.2f m to the side)" % ((YARD.x + 0.1 - by_crate.frame.origin.x) if by_crate else -1.0))
	crate.queue_free()
	wall_body.queue_free()
	portals.clear(me.peer_id)

	# A post too narrow for a portal, stood on the map's floor in front of you: the shot fizzles.
	var w := _wall()
	_check(not w.is_empty(), "found an open stretch of floor, and stood a wall on it")
	if w.is_empty():
		return
	var feet: Vector3 = w[0]
	var dir: Vector3 = w[1]
	var post := _box(feet + dir * 4.0 + Vector3(0, 3.0, 0), Vector3(0.5, 6.0, 0.5))
	post.global_transform = Transform3D(Basis(dir.cross(Vector3.UP), Vector3.UP, -dir), post.global_position)
	me.teleport(feet, atan2(-dir.x, -dir.z))
	me.input.pitch = 0.0
	await _physics(5)
	var spot := PortalGun.find_spot(me, me.eye_position(), dir)
	_check(not spot.has("at") and spot.has("miss") and (spot.miss as Vector3).distance_to(me.eye_position() + dir * 3.75) < 0.05,
		"a post half a metre wide takes no portal (the shot is a miss, at the post)")
	me.portal_gun.cooldown_left = 0.0
	me.input.mobility_dir = dir
	me._try_portal()
	me.input.mobility_dir = Vector3.ZERO
	_check(portals.get_portal(me.peer_id, 0) == null and portals.get_node_or_null("PortalFizzle") != null,
		"shooting it leaves no portal, and a fizzle of sparks on the post")
	_check(me.portal_gun.next_slot == 0 and me.portal_aiming(), "the next shot is still blue; your arm went out for the shot all the same")
	post.queue_free()
	await _physics(3)
	_check(PortalGun.find_spot(me, YARD + Vector3(60.0, 0, 6.0), Vector3(0, 0, -1)).is_empty(), "a shot at the sky is no shot at all")


# --- Opening and closing.

func _opening_and_closing() -> void:
	print("  opening and closing")
	var w := _wall()
	if w.is_empty():
		return
	var feet: Vector3 = w[0]
	var dir: Vector3 = w[1]
	var side := dir.cross(Vector3.UP)
	var eye := feet + Vector3(0, 1.5, 0)
	me.teleport(feet, 0.0)
	await _physics(5)
	var first := _shoot(0, eye, eye + dir * 9.0 - side * 1.5)
	_check(first != null and first.has_look() and not first.is_open() and first.grown() < 0.2, "a new portal starts shut")
	await _frames(int(Portal.OPEN_TIME * 0.6 * 60.0))
	_check(first.grown() > 0.9 and not first.is_open(), "it springs open (%.2f of its size after %.2f s)" % [first.grown(), Portal.OPEN_TIME * 0.6])
	await _frames(int(Portal.OPEN_TIME * 0.5 * 60.0) + 2)
	_check(first.is_open() and absf(first.grown() - 1.0) < 0.001, "and is open after %.2f s" % Portal.OPEN_TIME)
	# Shooting blue again: the old one closes.
	var second := _shoot(0, eye, eye + dir * 9.0 + side * 1.5)
	_check(second != null and second != first and portals.get_portal(me.peer_id, 0) == second, "shot again, blue is the new one at once")
	_check(is_instance_valid(first) and first.closing and not first.update_view(null, null, 64), "the old one is closing: still drawn, no longer a way through")
	await _frames(int(Portal.CLOSE_TIME * 0.75 * 60.0))
	_check(is_instance_valid(first) and first.grown() < 0.9, "it snaps shut (%.2f of its size after %.2f s)" % [first.grown() if is_instance_valid(first) else -1.0, Portal.CLOSE_TIME * 0.75])
	await _frames(int(Portal.CLOSE_TIME * 0.25 * 60.0) + 6)
	_check(not is_instance_valid(first), "and is gone after %.2f s" % Portal.CLOSE_TIME)
	portals.clear(me.peer_id)
	_check(portals.get_portal(me.peer_id, 0) == null and second.closing, "clearing your portals closes them the same way")
	await _frames(int(Portal.CLOSE_TIME * 60.0) + 8)


# --- Going through.

func _going_through() -> void:
	print("  going through")
	var w := _wall()
	if w.is_empty():
		return
	var feet: Vector3 = w[0]
	var dir: Vector3 = w[1]
	var side := dir.cross(Vector3.UP)
	var eye := feet + Vector3(0, 1.5, 0)
	me.teleport(feet, 0.0)
	await _physics(5)

	# Two portals side by side on the same wall; run into blue a little left of its middle.
	var a := _shoot(0, eye, feet + Vector3(0, 0.4, 0) + dir * 9.0 - side * 1.5)
	var b := _shoot(1, eye, feet + Vector3(0, 0.4, 0) + dir * 9.0 + side * 1.5)
	_check(a != null and b != null, "two portals on one wall")
	if a == null or b == null:
		return
	var off := 0.3
	var start := Vector3(a.frame.origin.x, feet.y, a.frame.origin.z) + a.normal * 4.0 + a.frame.basis.x * off
	me.teleport(start, atan2(a.normal.x, a.normal.z))
	me.input.pitch = -0.2
	await _physics(20)
	DevArgs.drives_keys = true
	Input.action_press("move_forward")
	var trips := me.respawn_count()
	var went := await _until_trip(trips, 300)
	_check(went, "running at blue takes you through")
	if went:
		var l := b.to_local_frame(me.global_position + Vector3(0, me.body_height() * 0.5, 0))
		_check(absf(l.x + off) < 0.12, "you come out of orange where you went into blue, as through a doorway (%.2f m off its middle, went in %.2f the other side)" % [l.x, off])
		_check(me.velocity.dot(b.normal) > 6.0, "still running (%.1f m/s out of it)" % me.velocity.dot(b.normal))
		var look := Basis.from_euler(Vector3(me.input.pitch, me.input.yaw, 0.0)) * Vector3.FORWARD
		_check(look.dot(b.normal) > 0.9 and absf(me.input.pitch + 0.2) < 0.02, "looking out of it, as far down as you were")
		_check(me._view_shift.dot(b.normal) < -0.1 and me._view_shift.length() < 1.0, "your view starts at the portal's face and catches you up (%.2f m back)" % -me._view_shift.dot(b.normal))
		_check(b._pulse > 0.5 and a._pulse > 0.5, "both portals flare as you go through")
		var grounded := true
		for i in 8:
			await get_tree().physics_frame
			if not me.is_on_floor():
				grounded = false
		_check(grounded, "from wall to wall along the floor, you stay on your feet")
		await _physics(22)
		# Turn round and walk straight back in.
		me.input.yaw += PI
		trips = me.respawn_count()
		_check(await _until_trip(trips, 200), "turn round and you can walk straight back in")
		await _frames(30)
		_check(me._view_shift.length() < 0.01 and absf(me._portal_roll) < 0.01, "the view has settled")
	Input.action_release("move_forward")
	DevArgs.drives_keys = false
	await _physics(10)

	# Orange onto the floor: a fast fall into it comes out of blue (on the wall) as fast.
	me.teleport(feet, 0.0)
	await _physics(5)
	b = _shoot(1, eye, feet + side * 3.0 - dir * 1.0)
	_check(b != null and b.normal.y > 0.9, "orange onto the floor")
	if b == null:
		return
	me.teleport(b.frame.origin + Vector3(0.0, 12.0, 0.0), 0.0)
	me.velocity = Vector3(0, -45.0, 0)
	me.input.pitch = deg_to_rad(-80.0)
	trips = me.respawn_count()
	went = await _until_trip(trips, 120)
	_check(went, "falling onto orange takes you through")
	if went:
		var speed := me.velocity.dot(a.normal)
		_check(speed > 44.0, "a 45 m/s fall comes out of the wall at full speed (%.1f m/s)" % speed)
		var look := Basis.from_euler(Vector3(me.input.pitch, me.input.yaw, 0.0)) * Vector3.FORWARD
		_check(look.dot(a.normal) > 0.9, "looking down into the floor, you come out looking out of the wall (%.2f)" % look.dot(a.normal))
		_check(absf(me._portal_roll) <= Player.PORTAL_ROLL_MAX + 0.001, "the view is tipped no more than a little as it rights itself")
	await _physics(60)

	# A fall that would just miss the portal's middle is drawn onto it.
	var miss := Vector3(0.75, 0, 0.6)
	me.teleport(b.frame.origin + miss + Vector3(0, 12.0, 0), 0.0)
	me.velocity = Vector3(0, -12.0, 0)
	trips = me.respawn_count()
	var nearest := INF
	for i in 150:
		await get_tree().physics_frame
		if me.respawn_count() != trips:
			break
		var to := me.global_position - b.frame.origin
		if to.y < 1.0:
			nearest = minf(nearest, Vector2(to.x, to.z).length())
	_check(me.respawn_count() != trips and nearest < Vector2(miss.x, miss.z).length() * 0.6,
		"falling %.1f m off the middle of a floor portal, hands off the keys, you are drawn in to it (%.2f m off as you reach it)" % [Vector2(miss.x, miss.z).length(), nearest])
	await _physics(60)

	# A shot through a portal makes it ripple.
	me.teleport(Vector3(a.frame.origin.x, feet.y, a.frame.origin.z) + a.normal * 3.0, 0.0)
	await _frames(60)
	_check(a._pulse <= 0.0 and a._ripple > 0.5, "the portals are at rest")
	var from := me.eye_position()
	var legs: Array = portals.shot_path(me.get_world_3d().direct_space_state, from, (a.frame.origin - from).normalized(), 100.0, 1, [me.get_rid()])
	portals.shots_through([Portals.path_bends(legs)])
	_check(legs.size() == 2 and a._pulse > 0.0 and a._ripple == 0.0 and b._ripple == 0.0, "a shot through them ripples both")


# --- Helpers.

## Shoots a portal from `eye` at `target`, as the gun does; the portal, or null.
func _shoot(slot: int, eye: Vector3, target: Vector3) -> Portal:
	var spot := PortalGun.find_spot(me, eye, (target - eye).normalized())
	if not spot.has("at"):
		return null
	Net.place_portal(me.peer_id, slot, spot.at, spot.normal, spot.up)
	return portals.get_portal(me.peer_id, slot)


## Is the surface there under every point the portal is felt at?
func _all_held(space: PhysicsDirectSpaceState3D, p: Portal) -> bool:
	for d in PortalFit.probe(space, p.frame, HW, HH):
		if is_nan(d) or d == INF:
			return false
	return true


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	arena.add_child(body)
	body.global_position = at
	return body


## A flat wall of our own, 7 m wide and 4 m high, stood on an open stretch of the map's
## floor, 7 m from where you stand facing it: [feet, the way to it, how far].
func _wall() -> Array:
	if not _wall_at.is_empty():
		return _wall_at
	var space := me.get_world_3d().direct_space_state
	for s in arena.layout.spawns:
		var base: Vector3 = s[0]
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3(0, 1, 0), base + Vector3(0, -5, 0), 1))
		if floor_hit.is_empty():
			continue
		var feet: Vector3 = floor_hit.position
		for k in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 16.0)
			var across := dir.cross(Vector3.UP)
			var ok := true
			for side: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
				for h: float in [0.3, 1.5, 3.0, 4.5]:   # nothing in the way...
					var o := feet + Vector3(0, h, 0) + across * side - dir * 1.0
					if not space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dir * 10.0, 1)).is_empty():
						ok = false
				for along: float in [0.0, 2.0, 4.0, 6.0, 8.0]:   # ...and level floor all the way
					var o := feet + across * side + dir * along + Vector3(0, 0.5, 0)
					var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -1.0, 0), 1))
					if under.is_empty() or absf((under.position as Vector3).y - feet.y) > 0.02:
						ok = false
			if not ok:
				continue
			var wall := _box(feet + dir * 7.25 + Vector3(0, 2.0, 0), Vector3(7.0, 4.0, 0.5))
			wall.global_transform = Transform3D(Basis(across, Vector3.UP, -dir), wall.global_position)
			_wall_at = [feet, dir, 7.0]
			return _wall_at
	return []


func _until_trip(trips: int, ticks: int) -> bool:
	for i in ticks:
		await get_tree().physics_frame
		if me.respawn_count() != trips:
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_ok = false
