extends SceneTree
## Cirrus checks (game/maps/cirrus.tscn), and the systems it brought: MapIsland,
## MapSpan and LayoutEvent.
##  - listed for free-for-all (which Gun Game is played on) and Deathmatch; about
##    80 x 80 m of floor; the kill height is below everything;
##  - 16 or more spawn points, all on building islands (none on the quad or the
##    tower), each clear and on a floor in BOTH layouts; about 16 weapon pickups of
##    10 or more kinds, each with room to stand in both layouts, none on a walkway
##    that draws in, the three heavy ones high up;
##  - the bell: a MapTerminal at the top of the tower that takes one press within
##    2 m. In range it rings; out of range it does not; it cannot be rung during the
##    move or the 60 s after; each ring flips Hub and Ring; the layout stays with no
##    more rings; a new match starts in Hub;
##  - moving islands: someone standing on an island (anywhere on it, and at every
##    spawn point) is carried through the move and ends where they stood on it;
##    someone on a skyway falls; nobody ends up inside a wall or a floor; pickups
##    stay over their spots;
##  - routes. Hub: every building, floor by floor, and the bell can be walked to
##    from the quad, and neighbouring islands are too far apart to jump but the
##    rocket boots cross. Ring: every island can be walked to from every other over
##    the bridges, the quad cannot, the grapple gets you up to it, and the rocket
##    boots do not (from the ring's decks and bridges, with every trick);
##  - bots: a crossing up to the quad and one back down for every island;
##  - falling off kills: nothing to land on between or under the islands;
##  - the labs' glass breaks, and no other glass does: also once the islands have moved.
## Run: godot --headless --fixed-fps 60 --path . --script tests/cirrus_test.gd

const ID := "cirrus"
const ISLANDS := ["Observatory", "Labs", "LectureHall", "Cafeteria", "Library"]
const QUAD_RADIUS := 11.0
const DROP := 15.0          ## how far the islands sink in the Ring layout
const BELL := Vector3(0, 24, 0)

## Places a bot must be able to walk to in each building, in the island's own frame
## (-z toward the quad, y = 0 its deck).
const ROOMS := {
	"Observatory": {"hall": Vector3(4, 0, 3), "terrace": Vector3(-6.0, 4.3, 0.6), "inside the dome": Vector3(-0.4, 4.3, 3.6)},
	"Labs": {"corridor": Vector3(4, 0, 0.2), "lab 1": Vector3(-7.0, 0, 5.6), "lab 2": Vector3(0, 0, 4), "lab 3": Vector3(7, 0, 5.5),
		"upper floor": Vector3(8.2, 4, 5.9), "balcony": Vector3(2.1, 4, -2.5)},
	"LectureHall": {"stage": Vector3(7.6, 0.6, 5.0), "concourse": Vector3(-5.8, 4, 2.6), "projection booth": Vector3(-8.5, 6.6, 6.9),
		"west balcony": Vector3(-10.5, 4, 6.5)},
	"Cafeteria": {"hall": Vector3(5.8, 0, 7.0), "west balcony": Vector3(-8.2, 4, 3.5), "back balcony": Vector3(8, 4, 6.6)},
	"Library": {"stacks": Vector3(-7.9, 0, 6.6), "reading room": Vector3(-0.9, 0, 4.4), "4 m mezzanine": Vector3(-7, 4, 2),
		"8 m mezzanine": Vector3(7, 8, 5)},
}
## Where riders stand on each island for the move (island frame): the plaza, the
## forecourt, a back corner, the side walkway, and against the building's front wall.
const RIDERS := {"plaza": Vector3(0, 0, -5), "forecourt": Vector3(0, 0, -11), "back corner": Vector3(10.9, 0, 7.6),
	"side walkway": Vector3(-10.75, 0, 4), "by the front wall": Vector3(5.5, 0, -2.3)}

var failures := 0
var map: MapRoot
var event: LayoutEvent
var bell: MapTerminal
var space: PhysicsDirectSpaceState3D
var dt := 1.0 / 120.0
var _bodies: Array = []   # {body, motor, input, ...}: test players stepped by _tick()
var _region: NavigationRegion3D


func _initialize() -> void:
	print("Cirrus checks")
	_run.call_deferred()


func _run() -> void:
	dt = 1.0 / Engine.physics_ticks_per_second
	_expect(Maps.fits(ID, "ffa") and Maps.fits(ID, "dm") and Maps.game_of(ID) == "ffa",
		"listed for free-for-all (and so Gun Game) and Deathmatch")
	map = Maps.make(ID)
	map.destructible = true
	root.add_child(map)
	var started := Time.get_ticks_msec()
	map.build(false)
	print("    built in %d ms" % (Time.get_ticks_msec() - started))
	event = map.get_node_or_null("Layout") as LayoutEvent
	for node in map.find_children("*", "", true, false):
		if node is MapTerminal:
			bell = node
	for i in 4:
		await physics_frame
	space = root.get_world_3d().direct_space_state
	physics_frame.connect(_tick)
	_rules()
	_spawns("Hub")
	_pickups("Hub")
	_hazard("Hub")
	_glass()
	await _bell_rules()
	await _hub_routes()
	await _hub_gaps()
	await _the_move()
	_spawns("Ring")
	_pickups("Ring")
	_hazard("Ring")
	await _ring_routes()
	await _ring_quad()
	_glass_after_move()
	await _back_again()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


# ---------------------------------------------------------------------------
# What the map is

func _rules() -> void:
	print("  size and rules")
	_expect(event != null and bell != null, "has a layout event and a bell to ring")
	var islands := map.movers.filter(func(m): return m.node is MapIsland)
	_expect(islands.size() == 5 and islands.all(func(m): return m.body != null), "five building islands, each a moving body")
	var far := 0.0
	for m in islands:
		var box: AABB = m.bounds
		for corner in 8:
			var p: Vector3 = (m.base as Transform3D) * box.get_endpoint(corner)
			far = maxf(far, Vector2(p.x, p.z).length())
	_expect(far * 2.0 >= 74.0 and far * 2.0 <= 90.0, "about 80 x 80 m of floor (%.0f m across)" % (far * 2.0))
	_expect(map.bounds.has_area() and map.bounds.size.x > far * 2.0 + 10.0, "the bounds leave room for the sky round it (%.0f m)" % map.bounds.size.x)
	var low := INF
	for m in islands:
		low = minf(low, ((m.base as Transform3D) * (m.bounds as AABB)).position.y - DROP)
	_expect(map.kill_height < low - 6.0, "the kill height (%.0f m) is below everything, also in the Ring layout (lowest rock %.0f m)" % [map.kill_height, low])
	_expect(event.layouts.size() == 2 and event.layouts[0] == "Hub" and event.layouts[1] == "Ring", "two layouts: Hub and Ring")
	_expect(is_equal_approx(event.move_time, 4.0) and is_equal_approx(event.cooldown, 60.0), "the move takes 4 s, and the bell rests 60 s after")
	_expect(event.state == 0 and is_zero_approx(event.blend), "it starts in Hub")
	var spans := map.spans.map(func(s): return s.node as MapSpan)
	var skyways := spans.filter(func(s): return s.out_in == 0)
	var bridges := spans.filter(func(s): return s.out_in == 1)
	_expect(skyways.size() == 5 and bridges.size() == 10, "five skyways (out in Hub) and ten bridge halves (out in Ring)")
	_expect(skyways.all(func(s): return _all_solid(s, true)) and bridges.all(func(s): return _all_solid(s, false)),
		"in Hub the skyways are out and solid, the bridges drawn in")


func _all_solid(span: MapSpan, want: bool) -> bool:
	for i in span.segment_count():
		if span.segment_solid(i) != want:
			return false
	return span.segment_count() > 0


func _spawns(layout: String) -> void:
	print("  spawn points (%s)" % layout)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var bad := []
	var off_island := []
	var per_island := {}
	for s in map.spawns:
		var pos: Vector3 = s[0]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
		q.collision_mask = 1
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0), 1))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty() or not map.bounds.has_point(Vector2(pos.x, pos.z)):
			bad.append(pos.snapped(Vector3(0.1, 0.1, 0.1)))
		var on := map.mover_under(pos)
		if on < 0 or not map.movers[on].node is MapIsland:
			off_island.append(pos.snapped(Vector3(0.1, 0.1, 0.1)))
		else:
			per_island[on] = per_island.get(on, 0) + 1
		# It faces open space: nothing within 3 m of its eyes the way it looks.
		var ahead := Vector3(-sin(s[1]), 0, -cos(s[1]))
		var eye := pos + Vector3(0, 1.6, 0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + ahead * 3.0, 1)).is_empty():
			bad.append("faces a wall: %s" % pos.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(map.spawns.size() >= 16, "%d spawn points (16 or more)" % map.spawns.size())
	_expect(bad.is_empty(), "every spawn point is clear, on a floor, inside the bounds and faces open space %s" % [bad])
	_expect(off_island.is_empty(), "all on building islands, none on the quad or the tower %s" % [off_island])
	_expect(per_island.size() == 5, "every island has some (%s)" % [per_island.values()])


func _pickups(layout: String) -> void:
	print("  weapon pickups (%s)" % layout)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var kinds := {}
	var bad := []
	var on_span := []
	var high := {}
	for w in map.weapon_spawns:
		var pos: Vector3 = w[0]
		kinds[w[1]] = true
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), pos + Vector3(0, 0.97, 0))
		q.collision_mask = 1
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 0.8, 0), 1))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty():
			bad.append("%s %s" % [w[1], pos.snapped(Vector3(0.1, 0.1, 0.1))])
		elif (below.collider as Object).has_meta("span"):
			on_span.append(w[1])
		if w[1] in ["rocket_launcher", "railgun", "anti_materiel"]:
			var deck := 0.0 if map.mover_under(pos) < 0 or layout == "Hub" else -DROP
			high[w[1]] = pos.y - deck
	_expect(map.weapon_spawns.size() >= 14 and map.weapon_spawns.size() <= 18, "%d pickups (about 16)" % map.weapon_spawns.size())
	_expect(kinds.size() >= 10 and kinds.keys().all(func(k): return WeaponData.has(k)), "%d different weapons, all real" % kinds.size())
	_expect(bad.is_empty(), "every pickup is over a floor with room to stand %s" % [bad])
	_expect(on_span.is_empty(), "none is on a skyway or a bridge (they draw in) %s" % [on_span])
	_expect(high.size() == 3 and high.values().all(func(h): return h >= 11.0),
		"the three heavy weapons are high up: the dome's cap, the library's perch, the tower's upper ledge (%s)" % [high])


## Falling off kills: under the gaps between the islands, and round the outside, there
## is nothing to land on above the kill height.
func _hazard(layout: String) -> void:
	print("  falling off (%s)" % layout)
	var landed := []
	var swing := 0.0 if layout == "Hub" else 36.0
	var deck := 0.0 if layout == "Hub" else -DROP
	for i in 5:
		var between := deg_to_rad(180.0 + i * 72.0 + 36.0 + swing)   # half way between two islands
		for r in [24.0, 30.0, 36.0, 44.0]:
			var from := Vector3(sin(between) * r, deck + 1.0, cos(between) * r)
			if layout == "Ring" and r < 34.0:
				continue   # (the bridge is there, and the stepping stone above the forecourt)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, map.kill_height, from.z)))
			if not hit.is_empty():
				landed.append(from.snapped(Vector3(0.1, 0.1, 0.1)))
		var out := deg_to_rad(180.0 + i * 72.0 + swing)   # beyond an island's back edge
		var behind := Vector3(sin(out) * 44.0, deck + 1.0, cos(out) * 44.0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(behind, Vector3(behind.x, map.kill_height, behind.z))).is_empty():
			landed.append(behind.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(landed.is_empty(), "nothing to land on between the islands or behind them, down to the kill height %s" % [landed])


func _glass() -> void:
	print("  glass")
	var d := map.destruction
	_expect(d != null and d.breakable_count() > 0, "the map has breakable pieces")
	if d == null:
		return
	var kinds := {}
	var riding := 0
	for panel in d.panels:
		kinds[panel.kind] = true
		if panel.get("frame") != null:
			riding += 1
	_expect(kinds.keys() == ["glass_lab"], "only the labs' glass breaks (%s)" % [kinds.keys()])
	_expect(riding == d.panels.size() and riding >= 6, "every pane rides its island (%d panes)" % riding)
	_expect(not map.palette.breakable.has("glass_window") and not map.palette.breakable.has("glass_sky"),
		"the cafeteria's windows, the skylight and the dome's glass are not breakable kinds")
	var pieces := map.collect_pieces()
	var other := pieces.filter(func(p): return p.kind in ["glass_window", "glass_sky"] and p.solid)
	_expect(other.size() >= 6 and other.all(func(p): return p.get("breakable", false) == false), "and each such pane is set never to break (%d)" % other.size())
	var c := _breakable_cell()
	_expect(c >= 0, "a lab pane can be shot")
	if c >= 0:
		var hit := _shoot_at(d.cell_center(c))
		_expect(hit == c, "a shot at a pane lands on that pane")
		d.damage(c, 30.0)
		var changed := d.flush()
		if not changed.is_empty():
			d.apply(changed[0], changed[1])
		_expect(d.is_broken(c), "and a pistol shot's worth of damage breaks it")


func _breakable_cell() -> int:
	var d := map.destruction
	for c in d.cells.size():
		if not d.cells[c].protected and not d.is_broken(c):
			return c
	return -1


## Which breakable cell a shot from the corridor side at `point` lands on, or -1.
func _shoot_at(point: Vector3) -> int:
	for from in [point + Vector3(0, 0.2, 0) + Vector3(1.2, 0, 0), point + Vector3(0, 0.2, 0) + Vector3(0, 0, 1.2),
			point + Vector3(0, 0.2, 0) - Vector3(1.2, 0, 0), point + Vector3(0, 0.2, 0) - Vector3(0, 0, 1.2)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point))
		if not hit.is_empty() and (hit.collider as Object).has_meta("panel"):
			return map.destruction.cell_at(hit.collider, hit.position, hit.normal)
	return -1


func _glass_after_move() -> void:
	print("  glass (Ring)")
	var c := _breakable_cell()
	_expect(c >= 0, "there is still a whole pane")
	if c < 0:
		return
	var d := map.destruction
	var at := d.cell_center(c)
	_expect(map.mover_under(at) >= 0 and at.y < -DROP + 4.5, "the panes went with their island (one is at %s)" % at.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(_shoot_at(at) == c, "and a shot still lands on the pane it is aimed at")


# ---------------------------------------------------------------------------
# The bell

func _bell_rules() -> void:
	print("  the bell")
	_expect(bell.global_position.distance_to(BELL) < 0.5, "it hangs at the top of the clock tower (%s)" % bell.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(is_zero_approx(bell.channel_time) and is_equal_approx(bell.range, 2.0), "one press, within 2 m")
	_expect(bell.get_node_or_null(bell.event) == event, "it sets off the layout event")
	_expect(not event.ready_kinds.is_empty() and event.ready_kinds[0] == "bell" and map.palette.glow.get("bell", 0.0) > 0.0,
		"the bell itself glows to show it is ready (no HUD)")
	# Stepped by hand, so the checks do not depend on how fast the test runs.
	event.set_physics_process(false)
	bell.set_physics_process(false)
	var near := BELL + Vector3(1.3, 0, 0.6)
	var far := BELL + Vector3(3.2, 0, 0)
	_expect(bell.reaches(near) and not bell.reaches(far), "beside the bell is in range, 3.2 m away is not")
	var where := {1: far}
	bell.host_set_holding(1, true)
	_bell_step(0.5, where)
	_expect(not event.running and event.state == 0, "a press from out of range does nothing")
	bell.host_set_holding(1, false)
	where = {1: near}
	bell.host_set_holding(1, true)
	_bell_step(dt, where)
	_expect(event.running and event.state == 1 and event.layout_name() == "Ring", "a press in range rings it at once: the map starts for Ring")
	_expect(bell.phase == MapTerminal.Phase.BUSY and not bell.ready_to_use(), "and the bell is locked")
	bell.host_set_holding(1, false)
	_bell_step(2.0, where)
	_expect(event.moving() and event.blend > 0.3 and event.blend < 0.7, "two seconds in, the islands are half way (%.2f)" % event.blend)
	_expect(map.shifting, "the map says its parts are on the move")
	bell.host_set_holding(1, true)
	_bell_step(0.2, where)
	bell.host_set_holding(1, false)
	_expect(event.state == 1 and event.elapsed > 2.0, "it cannot be rung during the move")
	_bell_step(2.2, where)
	_expect(not event.moving() and is_equal_approx(event.blend, 1.0) and not map.shifting, "after 4 s it has arrived: Ring")
	bell.host_set_holding(1, true)
	_bell_step(0.2, where)
	bell.host_set_holding(1, false)
	_bell_step(30.0, where)
	_expect(event.state == 1 and event.running, "nor in the cooldown")
	_bell_step(30.2, where)
	_expect(not event.running and bell.ready_to_use(), "64 s after the ring it is ready again")
	_bell_step(120.0, where)
	_expect(event.state == 1 and is_equal_approx(event.blend, 1.0), "left alone, the map stays in Ring: no timer brings it back")
	bell.host_set_holding(1, true)
	_bell_step(dt, where)
	bell.host_set_holding(1, false)
	_expect(event.running and event.state == 0 and event.layout_name() == "Hub", "the next ring heads back to Hub")
	_bell_step(4.2, where)
	_expect(is_zero_approx(event.blend) and event.state == 0, "and gets there")
	# A new match always starts in Hub, whatever the last one left.
	event.elapsed = event.length() + 1.0
	_bell_step(dt, where)
	event.host_start(0)
	_bell_step(5.0, where)
	_expect(event.state == 1, "(rung again: Ring)")
	event._on_match_started()
	_expect(event.state == 0 and not event.running and is_zero_approx(event.blend), "a new match starts in Hub")
	bell.host_step(dt, func(_id: int) -> Variant: return null)
	_expect(bell.ready_to_use(), "with the bell ready")
	# What someone who joins is told puts their copy in the same layout.
	event.take_state(1)
	event.apply_state(false, 0.0)
	_expect(is_equal_approx(event.blend, 1.0), "a copy told 'Ring, not moving' (someone joining late) is in Ring at once")
	event.take_state(0)
	event.apply_state(true, 1.0)
	_expect(event.moving() and event.blend > 0.5 and event.blend < 1.0, "and one told 'on the way to Hub, 1 s in' is part-way there")
	event.take_state(0)
	event.apply_state(false, 0.0)
	_expect(is_zero_approx(event.blend), "(back in Hub for the rest of the checks)")
	for i in 6:
		await physics_frame


func _bell_step(seconds: float, where: Dictionary) -> void:
	var left := seconds
	while left > 0.0001:
		var step := minf(dt * 2.0, left)
		left -= step
		bell.host_step(step, func(id: int) -> Variant: return where.get(id))
		event._physics_process(step)


# ---------------------------------------------------------------------------
# Test players

func _player(pos: Vector3) -> Dictionary:
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_stop_on_slope = true
	body.collision_layer = 2
	body.collision_mask = 1   # (the level only: test players do not bump each other)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	body.add_child(shape)
	root.add_child(body)
	body.global_position = pos
	var p := {"body": body, "motor": MovementController.new(), "input": PlayerInput.new(), "plan": Callable(), "t": 0.0}
	_bodies.append(p)
	return p


func _clear_players() -> void:
	for p in _bodies:
		(p.body as Node).free()
	_bodies = []


## Every physics frame: each test player follows its plan (a function that fills in
## its input), then moves by the game's own movement code.
func _tick() -> void:
	for p in _bodies:
		var body: CharacterBody3D = p.body
		if body.global_position.y < map.kill_height:
			continue   # fell out of the map
		p.t += dt
		if (p.plan as Callable).is_valid():
			(p.plan as Callable).call(p)
		(p.motor as MovementController).step(body, p.input, dt)
		(p.input as PlayerInput).clear_edges()
		p["peak"] = maxf(p.get("peak", -INF), body.global_position.y)
		if body.is_on_floor() and p.t > 0.3:
			p["stood"] = maxf(p.get("stood", -INF), body.global_position.y)


func _wait(seconds: float) -> void:
	for i in int(ceil(seconds / dt)):
		await physics_frame


func _island(island_name: String) -> MapIsland:
	return map.get_node(island_name) as MapIsland


func _body_of(island: MapIsland) -> AnimatableBody3D:
	for m in map.movers:
		if m.node == island:
			return m.body
	return null


func _inside_something(body: CharacterBody3D) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), body.global_position + Vector3(0, 0.95, 0))
	q.collision_mask = 1
	return not space.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------------------
# Routes on foot: the bots' navigation mesh

func _bake() -> void:
	if _region:
		_region.free()
	_region = MapScenery.bake_navigation(map)
	root.add_child(_region)
	# Wait until the navigation server has taken it in: a spawn point (they move with
	# the islands) has mesh under it.
	var nav := root.get_world_3d().navigation_map
	var probe: Vector3 = map.spawns[0][0]
	for i in 600:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav) > 0 and i > 6 and NavigationServer3D.map_get_closest_point(nav, probe).distance_to(probe) < 1.0:
			break
	for i in 4:
		await physics_frame


## How far short of `to` a walk from `from` ends (0 = it gets there).
func _short(from: Vector3, to: Vector3) -> float:
	var nav := root.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(nav, from, to, true)
	return 99.0 if path.is_empty() else path[path.size() - 1].distance_to(to)


func _walks(from: Vector3, to: Vector3) -> bool:
	return _short(from, to) < 1.0 and _short(to, from) < 1.0


func _rooms() -> Dictionary:
	var goals := {}
	for island_name in ROOMS:
		var body := _body_of(_island(island_name))
		for room in ROOMS[island_name]:
			goals["%s: %s" % [island_name, room]] = body.transform * (ROOMS[island_name][room] as Vector3)
	return goals


func _hub_routes() -> void:
	print("  routes on foot (Hub)")
	await _bake()
	var quad := Vector3(0, 0, -7.0)
	var missed := []
	var goals := _rooms()
	for i in map.spawns.size():
		goals["spawn %d" % (i + 1)] = map.spawns[i][0]
	goals["the bell"] = BELL + Vector3(1.3, 0, -1.0)
	goals["the tower's ground floor"] = Vector3(0, 0, -2.0)
	for goal_name in goals:
		if not _walks(quad, goals[goal_name]):
			missed.append("%s (%.1f m short)" % [goal_name, maxf(_short(quad, goals[goal_name]), _short(goals[goal_name], quad))])
	_expect(missed.is_empty(), "from the quad a bot can walk to the bell, every spawn point and every floor of every building (%d places) %s" % [goals.size(), missed])
	var exits := []
	for island_name in ISLANDS:
		var body := _body_of(_island(island_name))
		# Two ways out of each building: its front door, and a side or back way.
		var inside: Vector3 = body.transform * ((ROOMS[island_name] as Dictionary).values()[0] as Vector3)
		var front: Vector3 = body.transform * Vector3(0, 0, -5.0)
		var side: Vector3 = body.transform * Vector3(10.75, 0, 4.0)
		if not (_walks(inside, front) and _walks(inside, side)):
			exits.append(island_name)
	_expect(exits.is_empty(), "every building can be left by the front and by the side %s" % [exits])


## Hub: neighbours are too far apart for a jump (even with a dive, or with a flip),
## and the rocket boots cross.
func _hub_gaps() -> void:
	print("  the gaps between neighbours (Hub)")
	var results := {}
	for technique in ["jump", "jump and dive", "jump and flip", "rocket boots"]:
		var from_body := _body_of(_island("Library"))
		var to_body := _body_of(_island("Observatory"))
		# From the Library's bridge pad (its west one faces the Observatory) straight at the
		# Observatory's, already at a sprint.
		var start: Vector3 = from_body.transform * Vector3(-12.0 + 0.809 * 1.6, 0.1, -2.0 + 0.588 * 1.6)
		var aim: Vector3 = to_body.transform * Vector3(12.0 - 0.809 * 1.2, 0, -2.0 + 0.588 * 1.2)
		var p := _player(start)
		p["technique"] = technique
		p["aim"] = aim
		p["sprinting"] = true
		p["plan"] = _leap_plan
		results[technique] = p
	await _wait(6.0)
	var landed := {}
	for technique in results:
		var body: CharacterBody3D = results[technique].body
		landed[technique] = body.global_position.y > -3.0 and map.mover_under(body.global_position) >= 0 \
			and map.movers[map.mover_under(body.global_position)].node.name == "Observatory"
	var edge_gap: float = results["jump"].get("gap", 0.0)
	_expect(not landed["jump"] and not landed["jump and dive"] and not landed["jump and flip"],
		"a sprinting jump falls short, with a dive too, with a flip too (%s)" % [landed])
	_expect(landed["rocket boots"], "a jump with the rocket boots makes it across")
	_expect(edge_gap > 14.5 and edge_gap < 20.0, "about 16 m of open air to cross (%.1f m)" % edge_gap)
	_clear_players()


## A test player's plan: sprint at `aim`, jump at the edge, then the technique's trick.
func _leap_plan(p: Dictionary) -> void:
	var body: CharacterBody3D = p.body
	var input: PlayerInput = p.input
	var to: Vector3 = (p.aim as Vector3) - body.global_position
	if not p.has("jumped"):
		input.yaw = atan2(-to.x, -to.z)
	input.pitch = 0.0
	var flat := Vector3(to.x, 0, to.z).normalized()
	if not p.has("jumped"):
		if p.t < 0.4:
			return   # (settle on the floor first)
		if p.has("standing"):
			# A jump on the spot: the boots do the rest.
			input.jump_pressed = true
			p["jumped"] = p.t
			return
		if p.has("sprinting") and not p.has("launched"):
			p["launched"] = true
			body.velocity = flat * 11.5   # (as if it had run up to here)
		input.move = Vector2(0, 1)
		input.sprint = true
		var ahead := body.global_position + flat * 0.45 + Vector3(0, 0.3, 0)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead - Vector3(0, 1.2, 0), 1)).is_empty():
			input.jump_pressed = true
			p["jumped"] = p.t
			# (how far it is to the other side from here, for the report)
			var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0, -0.3, 0), body.global_position + Vector3(0, -0.3, 0) + flat * 40.0, 1))
			p["gap"] = body.global_position.distance_to(across.position) if not across.is_empty() else 99.0
		return
	input.move = Vector2(0, 1)
	input.sprint = true
	var since: float = p.t - float(p.jumped)
	var technique: String = p.technique
	if technique.begins_with("rocket boots"):
		input.pitch = deg_to_rad(float(p.get("pitch", 20.0)))
		if not p.has("boosted") and since >= dt * 1.5:
			input.boost_pressed = true
			p["boosted"] = true
		if p.has("flip_at") and not p.has("flipped") and since >= float(p.flip_at):
			input.pitch = 0.0
			input.jump_pressed = true
			p["flipped"] = true
		if p.has("glide_at") and since >= float(p.glide_at):
			input.glide = true
			if not p.has("glided"):
				input.glide_pressed = true
				p["glided"] = true
	elif technique == "jump and dive" and not p.has("dived") and since >= 0.25:
		input.dive_pressed = true
		p["dived"] = true
	elif technique == "jump and flip" and not p.has("flipped") and since >= 0.33:
		input.jump_pressed = true
		p["flipped"] = true


# ---------------------------------------------------------------------------
# The move

func _the_move() -> void:
	print("  the move to Ring")
	_clear_players()
	event.set_physics_process(true)
	var riders := []
	for island_name in ISLANDS:
		var body := _body_of(_island(island_name))
		for spot in RIDERS:
			var p := _player(body.transform * ((RIDERS[spot] as Vector3) + Vector3(0, 0.05, 0)))
			p["island"] = body
			p["local"] = RIDERS[spot]
			p["name"] = "%s, %s" % [island_name, spot]
			riders.append(p)
	for i in map.spawns.size():
		var p := _player(map.spawns[i][0])
		p["island"] = map.movers[map.mover_under(map.spawns[i][0])].body
		p["name"] = "spawn %d" % (i + 1)
		riders.append(p)
	# One player walking the Observatory's skyway, and one standing on the quad.
	var walker := _player(Vector3(0, 0.1, -15.0))
	var on_quad := _player(Vector3(6.0, 0.05, 6.0))
	await _wait(0.6)
	for p in riders:
		p["local"] = ((p.island as AnimatableBody3D).transform.affine_inverse() * (p.body as CharacterBody3D).global_position)
	var settled := riders.all(func(p): return (p.body as CharacterBody3D).is_on_floor())
	_expect(settled and walker.body.is_on_floor(), "before the bell: %d riders stand on their islands, one on a skyway" % riders.size())
	var pickup_before := {}
	for i in map.weapon_spawns.size():
		var on := map.mover_under(map.weapon_spawns[i][0])
		if on >= 0:
			pickup_before[i] = (map.movers[on].body as AnimatableBody3D).transform.affine_inverse() * (map.weapon_spawns[i][0] as Vector3)
	event.host_start(0)
	_expect(event.running and event.state == 1, "the bell rings")
	var worst := 0.0
	var worst_who := ""
	var airborne := 0
	var steps := int(ceil((event.move_time + 0.5) / dt))
	var mid_checked := false
	for i in steps:
		await physics_frame
		for p in riders:
			var want: Vector3 = (p.island as AnimatableBody3D).transform * (p.local as Vector3)
			var off := want.distance_to((p.body as CharacterBody3D).global_position)
			if off > worst:
				worst = off
				worst_who = p.name
			if not (p.body as CharacterBody3D).is_on_floor():
				airborne += 1
		if not mid_checked and event.elapsed >= 2.0:
			mid_checked = true
			_expect(event.blend > 0.3 and event.blend < 0.7 and map.shifting, "half way through, the islands are half way (%.2f) and the map says it is moving" % event.blend)
	_expect(not event.moving() and is_equal_approx(event.blend, 1.0), "4 s later the islands have arrived")
	_expect(worst < 0.35, "every rider was carried all the way: never more than %.2f m from where they stood on their island (%s)" % [worst, worst_who])
	_expect(airborne == 0, "and never left its floor")
	var stuck := riders.filter(func(p): return _inside_something(p.body)).map(func(p): return p.name)
	_expect(stuck.is_empty(), "nobody ended up inside a wall or a floor %s" % [stuck])
	var obs := _body_of(_island("Observatory")).transform.origin
	_expect(absf(obs.y + DROP) < 0.05 and absf(Vector2(obs.x, obs.z).length() - 27.0) < 0.1,
		"the islands swung round, pulled in 5 m and sank 15 m (the Observatory's is at %s)" % obs.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(walker.body.global_position.y < -20.0, "the player on the skyway fell when it drew in (now at %.0f m)" % walker.body.global_position.y)
	_expect(on_quad.body.is_on_floor() and absf(on_quad.body.global_position.y) < 0.2, "the player on the quad stayed put: the quad does not move")
	var moved_wrong := []
	for i in pickup_before:
		var on := map.mover_under(map.weapon_spawns[i][0])
		if on < 0 or ((map.movers[on].body as AnimatableBody3D).transform.affine_inverse() * (map.weapon_spawns[i][0] as Vector3)).distance_to(pickup_before[i]) > 0.05:
			moved_wrong.append(map.weapon_spawns[i][1])
	_expect(pickup_before.size() >= 10 and moved_wrong.is_empty(), "the %d pickups on islands went with them %s" % [pickup_before.size(), moved_wrong])
	var spans := map.spans.map(func(s): return s.node as MapSpan)
	_expect(spans.filter(func(s): return s.out_in == 0).all(func(s): return _all_solid(s, false))
		and spans.filter(func(s): return s.out_in == 1).all(func(s): return _all_solid(s, true)),
		"the skyways are drawn in and the bridges are out and solid")
	# A remote player drawn a tenth of a second late is put back on the island.
	_expect(map.carried(Vector3(100, 0, 100), 0.1) == Vector3(100, 0, 100), "(a point on no island is left where it is)")
	_clear_players()


func _back_again() -> void:
	print("  the move back to Hub")
	_clear_players()
	event.elapsed = event.length() - 0.05   # (skip the cooldown)
	await _wait(0.2)
	_expect(not event.running, "the bell is ready again")
	var riders := []
	for island_name in ISLANDS:
		var body := _body_of(_island(island_name))
		for spot in RIDERS:
			var p := _player(body.transform * ((RIDERS[spot] as Vector3) + Vector3(0, 0.05, 0)))
			p["island"] = body
			p["name"] = "%s, %s" % [island_name, spot]
			riders.append(p)
	# One player on a bridge: it draws in under them.
	var lib := _body_of(_island("Library"))
	var on_bridge := _player(lib.transform * Vector3(12.0 + 0.809 * 3.0, 0.1, -2.0 - 0.588 * 3.0))
	await _wait(0.6)
	for p in riders:
		p["local"] = ((p.island as AnimatableBody3D).transform.affine_inverse() * (p.body as CharacterBody3D).global_position)
	_expect(on_bridge.body.is_on_floor() and absf(on_bridge.body.global_position.y + DROP) < 0.3, "a player stands on a bridge")
	event.host_start(0)
	var worst := 0.0
	for i in int(ceil((event.move_time + 0.5) / dt)):
		await physics_frame
		for p in riders:
			var want: Vector3 = (p.island as AnimatableBody3D).transform * (p.local as Vector3)
			worst = maxf(worst, want.distance_to((p.body as CharacterBody3D).global_position))
	_expect(event.state == 0 and is_zero_approx(event.blend), "rung again: back in Hub")
	_expect(worst < 0.35, "the riders were carried back up (never more than %.2f m off)" % worst)
	_expect(riders.all(func(p): return not _inside_something(p.body)), "and nobody is inside anything")
	_expect(on_bridge.body.global_position.y < -20.0, "the player on the bridge fell when it drew in")
	var obs := _body_of(_island("Observatory")).transform.origin
	_expect(obs.distance_to(Vector3(0, 0, -32)) < 0.05, "the islands are exactly where they started")
	_clear_players()


# ---------------------------------------------------------------------------
# Ring

func _ring_routes() -> void:
	print("  routes on foot (Ring)")
	await _bake()
	var decks := {}
	for island_name in ISLANDS:
		decks[island_name] = _body_of(_island(island_name)).transform * Vector3(0, 0, -5.0)
	var missed := []
	for a in ISLANDS:
		for b in ISLANDS:
			if a < b and not _walks(decks[a], decks[b]):
				missed.append("%s - %s" % [a, b])
	_expect(missed.is_empty(), "every island can be walked to from every other, over the bridges %s" % [missed])
	var rooms := _rooms()
	var lost := []
	var from: Vector3 = decks["Library"]
	for goal_name in rooms:
		if not _walks(from, rooms[goal_name]):
			lost.append(goal_name)
	for i in map.spawns.size():
		if not _walks(from, map.spawns[i][0]):
			lost.append("spawn %d" % (i + 1))
	_expect(lost.is_empty(), "and so can every floor of every building and every spawn point %s" % [lost])
	var quad := Vector3(0, 0, -7.0)
	var reaches := ISLANDS.filter(func(n): return _short(decks[n], quad) < 3.0 or _short(quad, decks[n]) < 3.0)
	_expect(reaches.is_empty(), "the quad cannot be walked to from any island %s" % [reaches])
	_expect(_walks(quad, BELL + Vector3(1.3, 0, -1.0)), "(the bell can still be walked to from the quad)")
	# The bots' crossings: up by grapple, down by a run off the rim, for every island.
	var up := {}
	var down := {}
	var bad := []
	for node in get_nodes_in_group(MapJumpLink.GROUP):
		var link := node as MapJumpLink
		if not link.usable():
			bad.append("%s is not usable in Ring" % link.name)
			continue
		var takeoff := link.takeoff()
		var landing := link.landing_point()
		if link.how == MapJumpLink.How.GRAPPLE:
			var on := map.mover_under(takeoff)
			if on >= 0 and _walks(decks[map.movers[on].node.name], takeoff) and _short(quad, landing) < 1.5 and link.hook_point() != Vector3.INF:
				up[map.movers[on].node.name] = true
		else:
			var on := map.mover_under(landing)
			if on >= 0 and _walks(quad, takeoff) and _short(decks[map.movers[on].node.name], landing) < 1.5:
				down[map.movers[on].node.name] = true
	_expect(bad.is_empty(), "the crossings are for the Ring layout %s" % [bad])
	_expect(up.size() == 5 and down.size() == 5, "bots have a way up to the quad from every island (%d) and a way down to each (%d)" % [up.size(), down.size()])


## Ring: the grapple gets you up to the quad; the rocket boots do not.
func _ring_quad() -> void:
	print("  up to the quad (Ring)")
	_clear_players()
	# The grapple, from each island: hook the mast its crossing names, ride, let go.
	var grapplers := {}
	for node in get_nodes_in_group(MapJumpLink.GROUP):
		var link := node as MapJumpLink
		if link.how != MapJumpLink.How.GRAPPLE:
			continue
		var p := _player(link.takeoff() + Vector3(0, 0.05, 0))
		p["hook"] = link.hook_point()
		p["plan"] = _grapple_plan
		grapplers[map.movers[map.mover_under(link.takeoff())].node.name] = p
	# The rocket boots, with every trick, from the nearest and the highest places on the
	# ring's decks and bridges: none may land on the quad or its stepping stones.
	var lib := _body_of(_island("Library"))
	# [where, running up to the edge (else a jump on the spot)]
	var takeoffs := {
		"a run off the forecourt's tip": [lib.transform * Vector3(0, 0.1, -10.5), true],
		"the forecourt's tip": [lib.transform * Vector3(0, 0.1, -12.4), false],
		"the plaza's corner": [lib.transform * Vector3(6.6, 0.1, -7.1), false],
		"the middle of a bridge": [lib.transform * Vector3(12.0 + 0.809 * 4.0, 0.1, -2.0 - 0.588 * 4.0), false],
	}
	var boosters := []
	for spot in takeoffs:
		for pitch in [40.0, 50.0, 58.0, 66.0, 74.0, 82.0, 88.0]:
			for flip_at in [-1.0, 0.7, 1.0, 1.3, 1.6]:
				for glide in [false, true]:
					if glide and flip_at < 0.0:
						continue
					var p := _player(takeoffs[spot][0])
					p["technique"] = "rocket boots"
					p["aim"] = Vector3.ZERO
					p["sprinting" if takeoffs[spot][1] else "standing"] = true
					p["pitch"] = pitch
					if flip_at > 0.0:
						p["flip_at"] = flip_at
					if glide:
						p["glide_at"] = flip_at + 0.3
					p["plan"] = _leap_plan
					p["name"] = "%s, %d degrees%s%s" % [spot, int(pitch), ", flip" if flip_at > 0.0 else "", ", glide" if glide else ""]
					boosters.append(p)
	await _wait(7.0)
	var up := {}
	for island_name in grapplers:
		var body: CharacterBody3D = grapplers[island_name].body
		var at := body.global_position
		up[island_name] = body.is_on_floor() and at.y > -0.5 and Vector2(at.x, at.z).length() < QUAD_RADIUS + 0.5
	_expect(up.size() == 5 and up.values().all(func(ok): return ok), "the grapple gets you up to the quad from every island %s" % [up])
	var made_it := boosters.filter(func(p): return float(p.get("stood", -INF)) > -3.0).map(func(p): return p.name)
	var best := -INF
	for p in boosters:
		best = maxf(best, float(p.get("peak", -INF)))
	_expect(boosters.all(func(p): return p.has("boosted")), "(%d rocket-boot jumps were tried, the highest reaching %.1f m below the quad)" % [boosters.size(), -best])
	_expect(made_it.is_empty(), "the rocket boots do not: no jump from the ring's decks or bridges lands on the quad or a stepping stone %s" % [made_it])
	_expect(best < -1.5, "they fall at least 1.5 m short of the lawn's height (the best got to %.1f m)" % best)
	_clear_players()


## A test player's plan: aim at the hook, hold the grapple until close under it, let go.
func _grapple_plan(p: Dictionary) -> void:
	var body: CharacterBody3D = p.body
	var input: PlayerInput = p.input
	var g: Grapple = (p.motor as MovementController).grapple
	if p.t < 0.3:
		return
	if not p.has("fired"):
		var aim := ((p.hook as Vector3) - (body.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0))).normalized()
		input.yaw = atan2(-aim.x, -aim.z)
		input.pitch = asin(aim.y)
		input.grapple = true
		input.grapple_pressed = true
		p["fired"] = true
		return
	if g.attached and g.rope_origin(body).distance_to(g.anchor) < 5.5:
		input.grapple = false
	if not input.grapple and not body.is_on_floor():
		input.move = Vector2(0, 1)   # drift on in over the lawn


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
