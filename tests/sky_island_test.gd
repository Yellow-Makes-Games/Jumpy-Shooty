extends SceneTree
## Sky Island checks (game/maps/sky_island.tscn, built by tools/arena/sky_island_blockout.gd):
##  - listed for free-for-all and Deathmatch, as "Sky Islands" (a real map, so Random
##    can pick it); the old block-out's id (sky_island_layout) now means this map;
##  - 32 moving parts (7 islands, 25 pads) on one 14 s period; 30 spawn points and 15
##    weapon pickups, all inside islands so they ride the bob;
##  - bots' crossings (MapJumpLink): each sets off from a moving part and comes down on
##    another; together they join every island to every other, both ways; a way up off
##    the Hearth only to an island that comes within reach of the boots;
##  - a point taken into the navigation mesh's frame (MapRoot.to_nav) and back comes
##    back where it was, wherever the parts have got to since the mesh was made;
##  - the crossings work, done the way a bot does them: a hop from every pad and island
##    in one row of pads to the next, and the rocket boots down to the Hearth and back up;
##    with the clock stopped, and again with the islands and pads on the move (landing on
##    a pad on its way down or coming up, leaving the Hearth when its link says go).
## Run: godot --headless --path . --script tests/sky_island_test.gd

const ID := "sky_island"

var failures := 0
var map: MapRoot
var space: PhysicsDirectSpaceState3D
var dt := 1.0 / 60.0
var _bodies: Array = []
var _frozen := 0.0     # the map's clock (seconds)
var _running := false  # the clock goes on during a crossing (as in a match)


func _initialize() -> void:
	print("Sky Island checks")
	_run.call_deferred()


func _run() -> void:
	dt = 1.0 / Engine.physics_ticks_per_second
	_expect(Maps.fits(ID, "ffa") and Maps.fits(ID, "dm"), "listed for free-for-all and Deathmatch")
	_expect(Maps.name_of(ID) == "Sky Islands" and ID in Maps.random_ids("ffa"), "named Sky Islands, and Random can pick it")
	_expect(Maps.current("sky_island_layout") == ID and not "sky_island_layout" in Maps.ids(), "the old block-out is gone; its id means this map")
	map = Maps.make(ID)
	root.add_child(map)
	map.clock_source = func(): return _frozen   # (the test moves the clock itself)
	map.build(false)
	for i in 4:
		await physics_frame
	space = root.get_world_3d().direct_space_state
	physics_frame.connect(_tick)
	_parts()
	_links()
	await _nav_frame()
	await _hops()
	await _boots()
	await _moving()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


# ---------------------------------------------------------------------------

func _parts() -> void:
	print("  moving parts, spawns, pickups")
	var periods := {}
	for m in map.movers:
		periods[(m.node as MapMover).period] = true
	_expect(map.movers.size() == 32, "32 moving parts (7 islands, 25 pads): %d" % map.movers.size())
	_expect(periods.size() == 1 and periods.has(14.0), "all on one 14 s period (%s)" % [periods.keys()])
	_expect(map.spawns.size() == 30, "30 spawn points (%d)" % map.spawns.size())
	_expect(map.weapon_spawns.size() == 15, "15 weapon pickups (%d)" % map.weapon_spawns.size())
	var loose := map.weapon_spawns.filter(func(w): return map.standing_on(w[0]) < 0)
	_expect(loose.is_empty(), "every pickup stands on an island (%s)" % [loose])


func _all_links() -> Array:
	return map.find_children("*", "MapJumpLink", true, false)


## The island (or pad) a mover is: its node's name, with the row for a pad.
func _place_name(index: int) -> String:
	if index < 0:
		return "nowhere"
	var node: Node = map.movers[index].node
	return node.name if node.get_parent().name == "Islands" else "%s/%s" % [node.get_parent().name, node.name]


func _links() -> void:
	print("  bots' crossings")
	var links := _all_links()
	_expect(links.size() == 68, "68 crossings (%d): a hop each way between neighbours along each row of pads, the boots to and from the Hearth" % links.size())
	var bad := []
	var edges := {}   # place -> [places]
	for l in links:
		var link := l as MapJumpLink
		var from := map.standing_on(link.takeoff())
		var to := map.standing_on(link.landing_point())
		if from < 0 or to < 0 or from == to:
			bad.append(link.get_path())
			continue
		if not edges.has(from):
			edges[from] = []
		edges[from].append(to)
	_expect(bad.is_empty(), "each sets off from one moving part and comes down on another %s" % [bad])
	# Every island to every other.
	var islands := []
	for i in map.movers.size():
		if (map.movers[i].node as Node).get_parent().name == "Islands":
			islands.append(i)
	var cut := []
	for a in islands:
		var seen := {a: true}
		var todo := [a]
		while not todo.is_empty():
			var p: int = todo.pop_back()
			for q in edges.get(p, []):
				if not seen.has(q):
					seen[q] = true
					todo.append(q)
		for b in islands:
			if not seen.has(b):
				cut.append("%s to %s" % [_place_name(a), _place_name(b)])
	_expect(islands.size() == 7 and cut.is_empty(), "together they join every island to every other %s" % [cut])
	var ups := []
	var downs := 0
	for l in links:
		var link := l as MapJumpLink
		if link.how != MapJumpLink.How.BOOST:
			continue
		var from := _place_name(map.standing_on(link.takeoff()))
		if from == "Hearth":
			ups.append(_place_name(map.standing_on(link.landing_point())))
		else:
			downs += 1
	ups.sort()
	_expect(downs == 6, "the boots down to the Hearth from each outer island (%d)" % downs)
	_expect(ups == ["Bluff", "Garden", "Shelf", "Spire"], "and back up only to the islands that come within reach (%s)" % [ups])


## to_nav and from_nav undo each other, with the parts wherever they are.
func _nav_frame() -> void:
	print("  the navigation mesh's frame")
	_frozen = 2.0
	await _wait(0.1)
	map.remember_nav_poses()
	_frozen = 9.0
	await _wait(0.1)
	var off := []
	var shifted := 0
	for i in map.movers.size():
		var body := map.movers[i].body as AnimatableBody3D
		var p := body.transform * Vector3(0, 0.0, 0)
		if map.standing_on(p) != i:
			continue
		var there := map.to_nav(p)
		if absf(there.y - p.y) > 0.05:
			shifted += 1
		if map.from_nav(there).distance_to(p) > 0.01:
			off.append(_place_name(i))
	_expect(off.is_empty(), "a point on any part, taken into the mesh's frame and back, comes back where it was %s" % [off])
	_expect(shifted > 20, "and the frame is where the parts stood when the mesh was made, not where they are now (%d parts moved since)" % shifted)


# ---------------------------------------------------------------------------
# Crossings, done the way a bot does them (see BotBrain._fly_link)

func _player(pos: Vector3) -> Dictionary:
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_stop_on_slope = true
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	body.add_child(shape)
	root.add_child(body)
	body.global_position = pos
	var p := {"body": body, "motor": MovementController.new(), "input": PlayerInput.new(), "t": 0.0}
	_bodies.append(p)
	return p


func _clear_players() -> void:
	for p in _bodies:
		(p.body as Node).free()
	_bodies = []


func _tick() -> void:
	if _running:
		_frozen += dt
	for p in _bodies:
		var body: CharacterBody3D = p.body
		if body.global_position.y < map.kill_height:
			continue
		p.t += dt
		_cross(p)
		(p.motor as MovementController).step(body, p.input, dt)
		(p.input as PlayerInput).clear_edges()


func _wait(seconds: float) -> void:
	for i in int(ceil(seconds / dt)):
		await physics_frame


## One frame of a crossing: settle, sprint at the landing, jump where the floor runs
## out; for the boots, fire them toward the landing (steeper the higher it is) and
## glide on until it is close enough to drop onto.
func _cross(p: Dictionary) -> void:
	var body: CharacterBody3D = p.body
	var input: PlayerInput = p.input
	var link: MapJumpLink = p.link
	var land := link.landing_point()
	var pos := body.global_position
	var to := Vector3(land.x - pos.x, 0, land.z - pos.z)
	input.move = Vector2.ZERO
	input.glide = false
	if p.t < 0.3:
		return   # (settle on the floor first)
	var face := to if to.length() > 0.5 else Vector3.FORWARD.rotated(Vector3.UP, input.yaw)
	input.yaw = atan2(-face.x, -face.z)
	input.pitch = 0.0
	if not body.is_on_floor():
		p["left"] = true
	elif p.has("left"):
		p["down"] = true
	if p.has("down"):
		return
	var dir := to.normalized() if to.length() > 0.4 else Vector3.ZERO
	if not p.has("left"):
		input.sprint = true
		var ahead := pos + to.normalized() * 0.5 + Vector3(0, 0.3, 0)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead - Vector3(0, 1.2, 0), 1)).is_empty():
			input.jump_pressed = true
		p["rise"] = link.rise_at_landing()
	elif link.how == MapJumpLink.How.BOOST:
		input.sprint = false
		if not p.has("boosted"):
			var lift := deg_to_rad(clampf((float(p.rise) + 2.5) * 7.0, 10.0, 60.0))
			input.boost_pressed = true
			input.boost_dir = to.normalized() * cos(lift) + Vector3.UP * sin(lift)
			p["boosted"] = true
		var speed := Vector2(body.velocity.x, body.velocity.z).length()
		var above := pos.y - land.y
		if body.velocity.y < 0.5 and above > 0.3 and to.length() > speed * sqrt(2.0 * maxf(above, 0.1) / 22.0) + 1.0:
			input.glide = true
			input.glide_pressed = not p.has("gliding")
			p["gliding"] = true
	var flat_speed := Vector3(body.velocity.x, 0, body.velocity.z)
	if p.has("left") and flat_speed.length() > 1.0 and to.length() < flat_speed.length() * 0.55:
		dir = -flat_speed.normalized()
	var local := dir.rotated(Vector3.UP, -input.yaw)
	input.move = Vector2(local.x, -local.z).limit_length(1.0)


## Sets off from `link` with the clock at `t` (frozen there, or running on from there
## with `running`, the player standing at the takeoff from 0.3 s before); true if it
## comes down on the part the link lands on.
func _try(link: MapJumpLink, t: float, running := false) -> bool:
	_running = false
	_frozen = t - (0.3 if running else 0.0)
	await _wait(0.05)
	var p := _player(link.takeoff() + Vector3(0, 0.05, 0))
	p["link"] = link
	_running = running
	var want := map.standing_on(link.landing_point())
	for i in int(ceil(6.0 / dt)):
		await physics_frame
		if p.has("down") or (p.body as Node3D).global_position.y < map.kill_height:
			break
	var at := (p.body as Node3D).global_position
	var made := p.has("down") and map.standing_on(at) == want
	_running = false
	_clear_players()
	return made


## Crossings with the parts on the move, the way they are in a match: every hop in
## the row once at each of four moments a quarter of the bob apart (so some land on a
## pad on its way down, some on one coming up), and the boots up off the Hearth at the
## first moment each link says go.
func _moving() -> void:
	print("  crossings with the islands and pads on the move")
	var row := map.find_child("ShelfToBluff", true, false)
	var tried := 0
	var failed := []
	for t in [0.0, 3.5, 7.0, 10.5]:
		for l in _all_links():
			var link := l as MapJumpLink
			if link.how != MapJumpLink.How.HOP:
				continue
			var from := map.standing_on(link.takeoff())
			var to := map.standing_on(link.landing_point())
			var in_row := func(i: int) -> bool: return row.is_ancestor_of(map.movers[i].node) or ["Shelf", "Bluff"].has(_place_name(i))
			if not (in_row.call(from) and in_row.call(to)):
				continue
			tried += 1
			if not await _try(link, t, true):
				failed.append("%s to %s at %.1f s" % [_place_name(from), _place_name(to), t])
	_expect(tried == 40 and failed.is_empty(), "every hop in the row makes it with the pads moving (%d tried) %s" % [tried, failed])
	var up_failed := []
	var ups := 0
	for l in _all_links():
		var link := l as MapJumpLink
		if link.how != MapJumpLink.How.BOOST or _place_name(map.standing_on(link.takeoff())) != "Hearth":
			continue
		ups += 1
		for start in [0.0, 7.0]:
			var go := -1.0
			for k in 112:
				_frozen = start + k * 0.125
				await physics_frame
				if link.ready_now():
					go = _frozen
					break
			if go < 0.0 or not await _try(link, go, true):
				up_failed.append("%s (%s)" % [_place_name(map.standing_on(link.landing_point())), "never ready" if go < 0.0 else "at %.2f s" % go])
	_expect(ups == 4 and up_failed.is_empty(), "the boots up off the Hearth make it with the islands moving, at the first moment each says go (twice) %s" % [up_failed])


func _hops() -> void:
	print("  hops along a row of pads (both ways), at two moments of the bob")
	var row := map.find_child("ShelfToBluff", true, false)
	var tried := 0
	var failed := []
	for t in [1.0, 8.0]:
		for l in _all_links():
			var link := l as MapJumpLink
			if link.how != MapJumpLink.How.HOP:
				continue
			var from := map.standing_on(link.takeoff())
			var to := map.standing_on(link.landing_point())
			var in_row := func(i: int) -> bool: return row.is_ancestor_of(map.movers[i].node) or ["Shelf", "Bluff"].has(_place_name(i))
			if not (in_row.call(from) and in_row.call(to)):
				continue
			tried += 1
			if not await _try(link, t):
				failed.append("%s to %s at %.0f s" % [_place_name(from), _place_name(to), t])
	_expect(tried == 20 and failed.is_empty(), "every hop between the Shelf, its four pads and the Bluff makes it (%d tried) %s" % [tried, failed])


func _boots() -> void:
	print("  the rocket boots to and from the Hearth")
	var down_failed := []
	var up_failed := []
	var ups := 0
	for l in _all_links():
		var link := l as MapJumpLink
		if link.how != MapJumpLink.How.BOOST:
			continue
		var from := _place_name(map.standing_on(link.takeoff()))
		var to := _place_name(map.standing_on(link.landing_point()))
		if from != "Hearth":
			if not await _try(link, 3.0):
				down_failed.append(from)
			continue
		# Up: at the first moment (in quarter seconds) the link says go.
		var go := -1.0
		for k in 56:
			_frozen = k * 0.25
			await physics_frame
			if link.ready_now():
				go = k * 0.25
				break
		ups += 1
		if go < 0.0 or not await _try(link, go):
			up_failed.append("%s (%s)" % [to, "never ready" if go < 0.0 else "at %.2f s" % go])
	_expect(down_failed.is_empty(), "down to the Hearth from every outer island %s" % [down_failed])
	_expect(ups == 4 and up_failed.is_empty(), "back up to each island that has a way up, at a moment it says go %s" % [up_failed])


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
