extends SceneTree
## Cirrus checks (game/maps/cirrus.tscn), and the systems it brought: MapIsland,
## LayoutEvent and MapJumpLink.
##  - listed for free-for-all (which Gun Game is played on) and Deathmatch; about
##    135 x 135 m; the kill height is below everything that is up; no writing, no
##    walkways, nothing to press;
##  - 16 or more spawn points on building islands and five on the quad for when no
##    island has room, each clear and on a floor; about 20 weapon pickups of 10 or
##    more kinds, the three heavy ones high up;
##  - open sky: 24.4 m (80 ft) from the quad to an island. A jump, a dive or a flip
##    falls short; the rocket boots cross; the grapple crosses both ways in every
##    arrangement;
##  - the clock: a turn is 60 s (a tick or a tock each second), the bell, 8 s of
##    warning in which nothing moves and the islands about to go sag, then a 4 s
##    move. Two islands are up at a time; the others fall away under the kill height
##    with whoever is on them, the ones that stay carry their riders, new ones come
##    up. What comes next is drawn at random: never the same islands twice running,
##    never the same kind twice running, every kind and every island in the pool. A
##    new match starts with every island home; someone who joins part-way is put
##    where everyone else is; the clock's hands count it down;
##  - spawn points: only on islands that are up and staying, the quad's when there
##    is none;
##  - routes on foot: every floor of every building from its own deck, the belfry
##    from the quad; bots have a crossing each way for every island that is up, and
##    none to or from one that is down;
##  - falling off kills: nothing to land on between or under the islands;
##  - what breaks: the labs' glass in panes, the buildings' stone walls, floors and
##    roofs in small pieces, each riding its island: also once the island has moved
##    (tests/cirrus_destruction_test.gd: the marks, the rubble, and the mending).
## Run: godot --headless --fixed-fps 60 --path . --script tests/cirrus_test.gd

const ID := "cirrus"
const ISLANDS := ["Observatory", "Labs", "LectureHall", "Cafeteria", "Library"]
const QUAD_RADIUS := 14.3
const GAP := 24.4           ## open sky from the quad's rim to an island's tip
const ISLAND_AT := 49.7     ## how far an island's own origin is from the middle, at home
const TIP := Vector3(0, 0, -11.0)   ## the middle of an island's tip, in its own frame
const BELFRY := Vector3(0, 26.1, 0)

## Places a bot must be able to walk to in each building, in the island's own frame
## (-z toward the quad, y = 0 its deck).
const ROOMS := {
	"Observatory": {"hall": Vector3(9, 0, 2), "terrace": Vector3(-9.0, 5.8, 2.0), "inside the dome": Vector3(1.5, 5.8, 6.0)},
	"Labs": {"corridor": Vector3(4, 0, 1.5), "lab 1": Vector3(-9.0, 0, 9.6), "lab 2": Vector3(0, 0, 8), "lab 3": Vector3(9, 0, 9),
		"upper floor": Vector3(11, 5.5, 9), "balcony": Vector3(3.6, 5.5, -2.8)},
	"LectureHall": {"stage": Vector3(11.6, 0.6, 8.6), "concourse": Vector3(-10.8, 5.5, 3.4), "projection booth": Vector3(-12.2, 8.8, 11.6),
		"west balcony": Vector3(-15.5, 5.5, 8.4)},
	"Cafeteria": {"hall": Vector3(9, 0, 11.6), "west balcony": Vector3(-12, 5.5, 6), "back balcony": Vector3(11, 5.5, 11.5)},
	"Library": {"stacks": Vector3(-12.4, 0, 10.6), "reading room": Vector3(-0.6, 0, 7.5), "5.5 m mezzanine": Vector3(-10, 5.5, 3),
		"11 m mezzanine": Vector3(10, 11, 6)},
}
## Where riders stand on an island for a move (island frame): the plaza, the deck's
## tip, a back corner, the side walkway, and against the building's front wall.
const RIDERS := {"plaza": Vector3(0, 0, -7), "tip": Vector3(0, 0, -9.5), "back corner": Vector3(15.4, 0, 12.5),
	"side walkway": Vector3(-15.4, 0, 6), "by the front wall": Vector3(6, 0, -2.6)}

var failures := 0
var map: MapRoot
var event: LayoutEvent
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
	for i in 4:
		await physics_frame
	space = root.get_world_3d().direct_space_state
	physics_frame.connect(_tick)
	_rules()
	_spawns("every island home")
	_pickups("every island home")
	_hazard()
	_glass()
	_pool()
	await _clock_rules()
	await _routes()
	await _gap()
	await _the_move()
	_spawns("two islands up")
	_pickups("two islands up")
	await _crossings()
	await _grapples()
	await _glass_after_move()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


# ---------------------------------------------------------------------------
# What the map is

func _rules() -> void:
	print("  size and rules")
	_expect(event != null, "has a layout event")
	var all := map.find_children("*", "", true, false)
	_expect(all.filter(func(n): return n is MapTerminal).is_empty(), "nothing to press: no terminal, the clock changes the map")
	_expect(all.filter(func(n): return n is Label3D).is_empty(), "no writing anywhere on the map")
	_expect(map.spans.is_empty(), "no walkways: open sky between the quad and every island")
	var islands := map.movers.filter(func(m): return m.node is MapIsland)
	_expect(islands.size() == 5 and islands.all(func(m): return m.body != null), "five building islands, each a moving body")
	var far := 0.0
	var low := INF
	for m in islands:
		var box: AABB = m.bounds
		for corner in 8:
			var p: Vector3 = (m.base as Transform3D) * box.get_endpoint(corner)
			far = maxf(far, Vector2(p.x, p.z).length())
		low = minf(low, ((m.base as Transform3D) * box).position.y)
	_expect(far * 2.0 >= 125.0 and far * 2.0 <= 150.0, "about 135 x 135 m with every island home (%.0f m across)" % (far * 2.0))
	_expect(map.bounds.has_area() and map.bounds.size.x > (far + event.far_out) * 2.0 + 20.0, "the bounds leave room round the furthest an island goes (%.0f m)" % map.bounds.size.x)
	var lowest := low - maxf(event.split_height, 9.0)
	_expect(map.kill_height < lowest - 5.0 and map.kill_height > -event.down + 40.0,
		"the kill height (%.0f m) is below an island at its lowest (%.0f m) and far above one that is down (%.0f m)" % [map.kill_height, lowest, -event.down])
	_expect(map.bots_grapple, "bots all carry the grapple here: it is the only way round they are told of")
	_expect(event.up_count == 2 and is_equal_approx(event.hold_time, 60.0) and is_equal_approx(event.windup_time, 8.0) and is_equal_approx(event.move_time, 4.0),
		"two islands up at a time; an arrangement lasts 60 s, the warning 8 s, the move 4 s")
	_expect(event.state == 0 and islands.all(func(m): return (m.node as MapIsland).up and not (m.node as MapIsland).is_parked()),
		"with the clock stopped every island is up, at home")
	_expect(event.sets().size() == 10, "ten pairs of islands to draw from")
	# The shapes that are not boxes: the spire, the dome, the slopes, the arches.
	var shapes := {}
	for piece in map.collect_pieces():
		shapes[piece.shape] = shapes.get(piece.shape, 0) + 1
	_expect(shapes.get("cone", 0) > 0 and shapes.get("dome", 0) > 0 and shapes.get("wedge", 0) > 0 and shapes.get("arch", 0) > 0 and shapes.get("bevel", 0) > 0,
		"built with slopes, cones, domes, arches and bevelled boxes, not only boxes (%s)" % [shapes])




func _spawns(layout: String) -> void:
	print("  spawn points (%s)" % layout)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var bad := []
	var off_island := []
	var per_island := {}
	var on_quad := 0
	var closed := 0
	for s in map.spawns:
		var pos: Vector3 = s[0]
		if map.spawn_open(pos) < 0:
			closed += 1
			continue   # (its island is down: nobody is put there)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
		q.collision_mask = 1
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0), 1))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty() or not map.bounds.has_point(Vector2(pos.x, pos.z)):
			bad.append(pos.snapped(Vector3(0.1, 0.1, 0.1)))
		var on := map.mover_under(pos)
		if on >= 0 and map.movers[on].node is MapIsland:
			per_island[on] = per_island.get(on, 0) + 1
		elif Vector2(pos.x, pos.z).length() < QUAD_RADIUS and absf(pos.y) < 0.5:
			on_quad += 1
		else:
			off_island.append(pos.snapped(Vector3(0.1, 0.1, 0.1)))
		# It faces open space: nothing within 3 m of its eyes the way it looks.
		var ahead := Vector3(-sin(s[1]), 0, -cos(s[1]))
		var eye := pos + Vector3(0, 1.6, 0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + ahead * 3.0, 1)).is_empty():
			bad.append("faces a wall: %s" % pos.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(map.spawns.size() - on_quad >= 16, "%d spawn points on islands (16 or more), %d on the quad" % [map.spawns.size() - on_quad, on_quad])
	_expect(bad.is_empty(), "every spawn point in use is clear, on a floor, inside the bounds and faces open space %s" % [bad])
	_expect(off_island.is_empty() and on_quad == 5, "all on building islands, but for five on the quad's lawn for when no island has room %s" % [off_island])
	if closed == 0:
		_expect(per_island.size() == 5, "every island has some (%s)" % [per_island.values()])
	else:
		_expect(per_island.size() == 2 and closed >= 8, "only the two islands that are up have any in use (%d are closed)" % closed)
		var open := map.open_spawns()
		_expect(open.size() == map.spawns.size() - on_quad - closed and open.all(func(o): return map.spawn_open(o[0]) > 0),
			"and those are the ones players are put at (%d)" % open.size())


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
		if pos.y < map.kill_height:
			continue   # (gone down with its island: it comes back when the island does)
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
			var on := map.island_at(pos)
			high[w[1]] = pos.y - (on.global_position.y if on else 0.0)
	_expect(map.weapon_spawns.size() >= 18 and map.weapon_spawns.size() <= 23, "%d pickups (about 20)" % map.weapon_spawns.size())
	_expect(kinds.size() >= 10 and kinds.keys().all(func(k): return WeaponData.has(k)), "%d different weapons, all real" % kinds.size())
	_expect(bad.is_empty(), "every pickup is over a floor with room to stand %s" % [bad])
	_expect(on_span.is_empty(), "none is on a skyway or a bridge (they draw in) %s" % [on_span])
	_expect((high.size() == 3 or layout != "every island home") and high.values().all(func(h): return h >= 11.0),
		"the three heavy weapons are high up: the dome's cap, the library's perch, the tower's upper ledge (%s)" % [high])


## Falling off kills: under the open sky between the quad and the islands, between
## the islands and round the outside, there is nothing to land on above the kill height.
func _hazard() -> void:
	print("  falling off")
	var landed := []
	for i in 5:
		var toward := deg_to_rad(180.0 + i * 72.0)             # along an island's own line
		var between := deg_to_rad(180.0 + i * 72.0 + 36.0)     # half way between two islands
		for spot in [[toward, 20.0], [toward, 27.0], [toward, 34.0], [toward, 76.0], [between, 24.0], [between, 36.0], [between, 50.0], [between, 64.0]]:
			var from := Vector3(sin(spot[0]) * spot[1], 1.0, cos(spot[0]) * spot[1])
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, map.kill_height, from.z))).is_empty():
				landed.append(from.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(landed.is_empty(), "nothing to land on between the quad and the islands, between the islands or behind them, down to the kill height %s" % [landed])


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
	var found := kinds.keys()
	found.sort()
	_expect(found == ["floor_tile", "floor_wood", "glass_lab", "glass_sky", "glass_window", "stone", "stone_warm"],
		"the glass, the stone walls and the floors break (%s)" % [found])
	_expect(riding >= 150 and riding < d.panels.size(), "the islands' ride with them, the quad's stand still (%d of %d)" % [riding, d.panels.size()])
	var glass := d.panels.filter(func(p): return p.material == "glass")
	_expect(glass.size() >= 12 and glass.all(func(p): return p.n == Vector3i.ONE), "glass goes a pane at a time (%d panes)" % glass.size())
	var c := _breakable_cell("glass_lab")
	_expect(c >= 0, "a lab pane can be shot")
	if c >= 0:
		var hit := _shoot_at(d.cell_center(c))
		_expect(hit == c, "a shot at a pane lands on that pane")
		d.damage(c, 30.0)
		var changed := d.flush()
		if not changed.is_empty():
			d.apply(changed[0], changed[1])
		_expect(d.is_broken(c), "and a pistol shot's worth of damage breaks it")


func _breakable_cell(kind: String) -> int:
	var d := map.destruction
	for c in d.cells.size():
		if not d.cells[c].protected and not d.is_broken(c) and d.panels[d.cells[c].panel].kind == kind:
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
	print("  glass (the Labs moved)")
	# The Labs up, far out and low.
	_rest(LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.FAR, 1, 1))
	for i in 8:
		await physics_frame
	var c := _breakable_cell("glass_lab")
	_expect(c >= 0, "there is still a whole pane")
	if c < 0:
		return
	var d := map.destruction
	var at := d.cell_center(c)
	var on := map.island_at(at)
	_expect(on != null and on.name == "Labs" and at.y < -4.5 and Vector2(at.x, at.z).length() > ISLAND_AT, "the panes went with their island (one is at %s)" % at.snapped(Vector3(0.1, 0.1, 0.1)))
	_expect(_shoot_at(at) == c, "and a shot still lands on the pane it is aimed at")


# ---------------------------------------------------------------------------
# The clock and the pool

func _island_node(island_name: String) -> MapIsland:
	return map.get_node(island_name) as MapIsland


## The number of the pair made of these two islands (1.. in event.sets()).
func _pair(a: String, b: String) -> int:
	var want := [ISLANDS.find(a), ISLANDS.find(b)]
	want.sort()
	return event.sets().find(want) + 1


## Puts the map in an arrangement, at rest, the clock stopped.
func _rest(config: int) -> void:
	event.running = false
	event.elapsed = 0.0
	event.state = config | (config << LayoutEvent.BITS)
	event._place()


## What comes next is drawn at random, within the rules.
func _pool() -> void:
	print("  the pool of arrangements")
	event.rng.seed = 20261118
	var config := event.pick_first()
	_expect(LayoutEvent.kind_of(config) == LayoutEvent.Kind.SWAP and event.up_in(config).size() == 2 and LayoutEvent.look_of(config) == 0,
		"a match begins with two islands up, at their homes, in the afternoon (%s)" % event.describe(config))
	var kinds := {}
	var seen_up := {}
	var same_set := 0
	var same_kind := 0
	var same_look := 0
	var wrong_count := 0
	var firsts := {}
	for i in 40:
		firsts[event.pick_first() & 15] = true
	for i in 400:
		var after := event.pick_after(config)
		kinds[LayoutEvent.kind_of(after)] = kinds.get(LayoutEvent.kind_of(after), 0) + 1
		for up in event.up_in(after):
			seen_up[up] = true
		same_set += int((after & 15) == (config & 15))
		same_kind += int(LayoutEvent.kind_of(after) == LayoutEvent.kind_of(config))
		same_look += int(LayoutEvent.look_of(after) == LayoutEvent.look_of(config))
		wrong_count += int(event.up_in(after).size() != 2)
		config = after
	_expect(firsts.size() >= 8, "the first pair is drawn at random too (%d different pairs in 40 starts)" % firsts.size())
	_expect(wrong_count == 0, "always exactly two islands up")
	_expect(same_set == 0, "never the same two islands twice running: at least one comes up fresh every time")
	_expect(same_kind == 0, "never the same kind of arrangement twice running")
	_expect(same_look == 0, "afternoon and sunset by turns")
	_expect(kinds.size() == 5 and kinds.values().all(func(n): return n >= 40), "all five kinds come up (Swap, Drift, Close, Far, Split: %s in 400)" % [kinds.values()])
	_expect(seen_up.size() == 5, "and every island gets its turn")
	# What each kind does to an island that is up.
	var pair := _pair("Observatory", "Labs")
	var obs := ISLANDS.find("Observatory")
	var labs := ISLANDS.find("Labs")
	_expect(event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.SWAP, 3, 0), obs) == Vector3.ZERO, "Swap: at home")
	var drift := [event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.DRIFT, 0, 0), obs), event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.DRIFT, 1, 0), obs)]
	_expect(absf(drift[0].x) == 36.0 and drift[1].x == -drift[0].x and drift[0].y == 0.0 and drift[0].z == 0.0, "Drift: 36 degrees round the quad, either way")
	var close := event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.CLOSE, 0, 0), obs)
	_expect(is_equal_approx(close.z, -GAP / 2.0) and close.y == 0.0, "Close: half the gap nearer (%.1f m)" % -close.z)
	var far := [event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.FAR, 0, 0), obs), event.rest_pose(LayoutEvent.pack(pair, LayoutEvent.Kind.FAR, 1, 0), obs)]
	_expect(far[0].z > 8.0 and far[0].y > 5.0 and far[1].y < -5.0, "Far: %.1f m further out, and high (%.0f m) or low (%.0f m)" % [far[0].z, far[0].y, far[1].y])
	var split := LayoutEvent.pack(pair, LayoutEvent.Kind.SPLIT, 0, 0)
	_expect(event.rest_pose(split, obs).y == -event.rest_pose(split, labs).y and absf(event.rest_pose(split, obs).y) == 8.0, "Split: one 8 m up, the other 8 m down")


func _clock_rules() -> void:
	print("  the clock")
	var cues := {}
	var order := []
	event.cue.connect(func(what: String):
		cues[what] = cues.get(what, 0) + 1
		if what not in ["tick", "tock"]:
			order.append(what))
	var all := map.find_children("*", "", true, false)
	var hands := all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.COUNTDOWN)
	var bells := all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.SWING)
	_expect(hands.size() == 4 and bells.size() == 1, "a countdown hand on each of the tower's four clock faces, and one bell that swings")
	_expect((bells[0] as Node3D).global_position.y > BELFRY.y + 3.0, "the bell hangs in the belfry, over head height")
	var islands := ISLANDS.map(func(n): return _island_node(n))
	# Stepped by hand, so the checks do not depend on how fast the test runs.
	event.set_physics_process(false)
	_expect(not event.running and event.state == 0, "with no match on, the clock stands still")
	event.host_start()
	var first := event.now()
	var second := event.next()
	_expect(event.running and not event.moving() and not event.warning(), "a match starts it")
	var up_now := islands.filter(func(i): return i.up)
	_expect(up_now.size() == 2 and islands.filter(func(i): return i.is_parked()).size() == 3,
		"at once two islands are up and three are gone (%s)" % event.describe(first))
	_expect((first & 15) != (second & 15) and event.up_in(second).size() == 2, "and what comes next is already decided: %s" % event.describe(second))
	var doomed := event.up_in(first).filter(func(i): return not event.up_in(second).has(i)).map(func(i): return islands[i])
	_expect(is_equal_approx(event.time_to_bell(), 60.0), "60 s to the bell")
	_clock_step(15.2)
	event._process(0.016)
	_expect(hands.all(func(h): return is_equal_approx((h as MapSpinner).angle, -TAU * 0.25)), "15 s in, the clocks' hands are a quarter of the way round (clockwise)")
	_clock_step(44.6)
	_expect(not map.warning and not map.shifting and cues.get("toll", 0) == 0 and islands.all(func(i): return not i.doomed),
		"for 60 s nothing happens: 59.8 s in there is no bell yet and no island is marked")
	_expect(cues.get("tick", 0) == 30 and cues.get("tock", 0) == 29, "a tick or a tock every second, by turns (%d and %d)" % [cues.get("tick", 0), cues.get("tock", 0)])
	_clock_step(0.4)
	_expect(cues.get("toll", 0) == 1 and event.warning() and map.warning and not map.shifting, "at 60 s the bell goes and the warning begins")
	_expect(not doomed.is_empty() and doomed.all(func(i): return i.doomed and i.up) and islands.filter(func(i): return i.doomed).size() == doomed.size(),
		"the islands that are about to go are marked, and no others (%s)" % [doomed.map(func(i): return i.name)])
	event._process(0.016)
	_expect(hands.all(func(h): return is_zero_approx((h as MapSpinner).angle)), "with the hands at twelve")
	_clock_step(0.3)
	event._process(0.3)
	_expect(absf((bells[0] as MapSpinner).angle) > 0.05, "and the bell swinging")
	var before: Vector3 = (doomed[0] as MapIsland).pose_of((doomed[0] as MapIsland).pose_a).origin
	_clock_step(7.4)
	_expect(event.warning() and event.windup > 0.9 and cues.get("move", 0) == 0, "7.9 s after the bell it is still only a warning (%.2f)" % event.windup)
	_expect((doomed[0] as MapIsland).dip > 0.3 and (doomed[0] as MapIsland).dip < 1.0 and up_now.all(func(i): return not i.is_parked()),
		"a doomed island has sagged a little (%.1f m) and is still there to get off" % (doomed[0] as MapIsland).dip)
	_clock_step(0.2)
	_expect(event.moving() and map.shifting and not map.warning and cues.get("move", 0) == 1, "8 s after the bell the islands go")
	_clock_step(0.9)
	var fallen_1 := -(doomed[0] as MapIsland).offset_at(0.0).origin.y
	_clock_step(1.6)
	var fallen_2 := -(doomed[0] as MapIsland).offset_at(0.0).origin.y
	_expect(fallen_1 < 12.0 and fallen_2 > 40.0 and fallen_2 > -map.kill_height,
		"a doomed island falls slowly at first, then fast: %.0f m after 1 s, %.0f m after 2.6 s (the kill height is %.0f m down)" % [fallen_1, fallen_2, -map.kill_height])
	_clock_step(1.6)
	_expect(event.running and event.now() == second and not event.moving() and not map.shifting, "4 s after they went everything has arrived, and the next turn has begun")
	_expect(order == ["toll", "move", "lock"], "the bell, the move, the clunk, in that order %s" % [order])
	var up_then := islands.filter(func(i): return i.up)
	_expect(up_then.size() == 2 and up_then.map(func(i): return ISLANDS.find(i.name)) == event.up_in(second) and doomed.all(func(i): return i.is_parked() and not i.up),
		"the new pair is up, the old ones are gone")
	_expect((event.next() & 15) != (second & 15), "and the arrangement after this one is decided")
	for turn in 3:
		_clock_step(event.length())
	_expect(cues.get("toll", 0) == 4 and islands.filter(func(i): return i.up).size() == 2, "left alone it goes on, turn after turn, always two up")
	# A new match: every island home, the clock at nought.
	event._on_match_started()
	_expect(event.state == 0 and not event.running and islands.all(func(i): return i.up and not i.is_parked()), "a new match begins with every island home and the clock at nought")
	# What someone who joins is told puts their copy where everyone else's is.
	var a := LayoutEvent.pack(_pair("Labs", "Library"), LayoutEvent.Kind.FAR, 1, 1)
	var b := LayoutEvent.pack(_pair("Cafeteria", "Library"), LayoutEvent.Kind.DRIFT, 0, 0)
	event.take_state(a | (b << LayoutEvent.BITS))
	event.apply_state(true, 10.0)
	_expect(_island_node("Labs").up and _island_node("Library").up and _island_node("Observatory").is_parked() and is_equal_approx(event.blend, 1.0),
		"a copy told an arrangement and '10 s in' (someone joining late) has those two islands up, at sunset, at once")
	_expect(absf(_island_node("Labs").offset_at(0.0).origin.y + 9.0) < 0.01, "standing as that arrangement has them (Far and low: 9 m down)")
	event.take_state(a | (b << LayoutEvent.BITS))
	event.apply_state(true, event.hold_time + event.windup_time + 2.0)
	_expect(event.moving() and not _island_node("Labs").up and _island_node("Library").up and not _island_node("Cafeteria").is_parked(),
		"and one told '2 s into the move' has the Labs falling, the Library staying and the Cafeteria on its way up")
	event.take_state(0)
	event.apply_state(false, 0.0)
	_expect(not event.running and islands.all(func(i): return i.up), "(every island home, the clock stopped, for the next checks)")
	for i in 6:
		await physics_frame


func _clock_step(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var step := minf(dt * 2.0, left)
		left -= step
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


func _routes() -> void:
	print("  routes on foot (every island home)")
	await _bake()
	var missed := []
	var count := 0
	for island_name in ISLANDS:
		var body := _body_of(_island(island_name))
		var plaza: Vector3 = body.transform * Vector3(0, 0, -7.0)
		var goals := {"its tip": body.transform * (TIP + Vector3(0, 0, 1.6)), "its side walkway": body.transform * Vector3(15.4, 0, 6.0)}
		for room in ROOMS[island_name]:
			goals[room] = body.transform * (ROOMS[island_name][room] as Vector3)
		for i in map.spawns.size():
			if map.island_at(map.spawns[i][0]) == _island(island_name):
				goals["spawn %d" % (i + 1)] = map.spawns[i][0]
		for goal_name in goals:
			count += 1
			if not _walks(plaza, goals[goal_name]):
				missed.append("%s: %s (%.1f m short)" % [island_name, goal_name, maxf(_short(plaza, goals[goal_name]), _short(goals[goal_name], plaza))])
	_expect(missed.is_empty(), "on every island a bot can walk from the plaza to its tip, its side, every floor of its building and every spawn point (%d places) %s" % [count, missed])
	var quad := Vector3(0, 0, -7.0)
	var on_quad := {"the belfry": BELFRY + Vector3(1.3, 0, -1.0), "the tower's ground floor": Vector3(0, 0, -2.0)}
	for i in map.spawns.size():
		if map.spawn_open(map.spawns[i][0]) == 0:
			on_quad["spawn %d" % (i + 1)] = map.spawns[i][0]
	var lost := on_quad.keys().filter(func(k): return not _walks(quad, on_quad[k]))
	_expect(lost.is_empty(), "on the quad: up to the belfry, into the tower and to its five spawn points %s" % [lost])
	var joined := ISLANDS.filter(func(n): return _short(quad, _body_of(_island(n)).transform * Vector3(0, 0, -7.0)) < 3.0)
	_expect(joined.is_empty(), "no island can be walked to from the quad: it is open sky %s" % [joined])


## The open sky between the quad and an island: too far for a jump (even with a dive,
## or with a flip), and the rocket boots cross.
func _gap() -> void:
	print("  the open sky between the quad and an island")
	var results := {}
	var to_body := _body_of(_island("Observatory"))
	for technique in ["jump", "jump and dive", "jump and flip", "rocket boots"]:
		# From the quad's lawn straight at the Observatory's tip, already at a sprint.
		var p := _player(Vector3(0, 0.1, -(QUAD_RADIUS - 2.4)))
		p["technique"] = technique
		p["aim"] = to_body.transform * (TIP + Vector3(0, 0, 3.0))
		p["sprinting"] = true
		p["plan"] = _leap_plan
		results[technique] = p
	await _wait(6.0)
	var landed := {}
	for technique in results:
		var body: CharacterBody3D = results[technique].body
		landed[technique] = body.global_position.y > -3.0 and map.island_at(body.global_position) == _island("Observatory")
	var edge_gap: float = results["jump"].get("gap", 0.0)
	_expect(not landed["jump"] and not landed["jump and dive"] and not landed["jump and flip"],
		"a sprinting jump falls short, with a dive too, with a flip too (%s)" % [landed])
	_expect(landed["rocket boots"], "a jump with the rocket boots makes it across")
	_expect(edge_gap > GAP - 1.5 and edge_gap < GAP + 2.5, "about 24.4 m (80 ft) of open air to cross (%.1f m)" % edge_gap)
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

## One change, run by the event's own clock: Observatory and Labs are up; the next
## arrangement is Observatory and Lecture Hall, drifted 36 degrees. So the Observatory
## stays and swings round, the Labs fall away and the Lecture Hall comes up.
func _the_move() -> void:
	print("  a move: one island stays, one goes, one comes")
	_clear_players()
	var from := LayoutEvent.pack(_pair("Observatory", "Labs"), LayoutEvent.Kind.SWAP, 0, 0)
	var to := LayoutEvent.pack(_pair("Observatory", "LectureHall"), LayoutEvent.Kind.DRIFT, 1, 1)
	event.state = from | (to << LayoutEvent.BITS)
	event.running = true
	event.elapsed = 1.0
	event._place()
	event.set_physics_process(true)
	await _wait(0.3)
	var stays := _body_of(_island("Observatory"))
	var goes := _body_of(_island("Labs"))
	var riders := []
	var doomed := []
	for spot in RIDERS:
		var p := _player(stays.transform * ((RIDERS[spot] as Vector3) + Vector3(0, 0.05, 0)))
		p["island"] = stays
		p["name"] = "Observatory, %s" % spot
		riders.append(p)
		var q := _player(goes.transform * ((RIDERS[spot] as Vector3) + Vector3(0, 0.05, 0)))
		q["name"] = "Labs, %s" % spot
		doomed.append(q)
	for i in map.spawns.size():
		if map.island_at(map.spawns[i][0]) == _island("Observatory"):
			var p := _player(map.spawns[i][0])
			p["island"] = stays
			p["name"] = "spawn %d" % (i + 1)
			riders.append(p)
	var on_quad := _player(Vector3(8.0, 0.05, 8.0))
	await _wait(0.6)
	for p in riders:
		p["local"] = ((p.island as AnimatableBody3D).transform.affine_inverse() * (p.body as CharacterBody3D).global_position)
	_expect(riders.all(func(p): return (p.body as CharacterBody3D).is_on_floor()) and doomed.all(func(p): return (p.body as CharacterBody3D).is_on_floor()),
		"before the move: %d riders stand on the island that stays, %d on the one that goes" % [riders.size(), doomed.size()])
	_expect(map.open_spawns().all(func(o): return map.island_at(o[0]) in [_island("Observatory"), _island("Labs")]), "players are being put on the two islands that are up")
	var pickup_before := {}
	for i in map.weapon_spawns.size():
		if map.island_at(map.weapon_spawns[i][0]) == _island("Observatory"):
			pickup_before[i] = stays.transform.affine_inverse() * (map.weapon_spawns[i][0] as Vector3)
	# (the clock is put to just before the end of the warning: the 68 s before are the clock checks')
	event.elapsed = event.hold_time + event.windup_time - 0.3
	await _wait(0.2)
	_expect(event.warning() and _island("Labs").doomed and not _island("Observatory").doomed, "the bell has gone: the Labs are doomed, the Observatory is not")
	_expect(map.doomed_at(doomed[0].body.global_position) and not map.doomed_at(riders[0].body.global_position), "and the map says so of anyone standing there")
	_expect(map.open_spawns().all(func(o): return map.island_at(o[0]) == _island("Observatory")), "nobody is put on the doomed island any more")
	var worst := 0.0
	var worst_who := ""
	var airborne := 0
	var steps := int(ceil((event.move_time + 0.7) / dt))
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
		if not mid_checked and event.moving() and event.progress >= 0.5:
			mid_checked = true
			_expect(map.shifting and not _island("Labs").up and not _island("LectureHall").up and not _island("LectureHall").is_parked(),
				"half way through, the Labs are falling and the Lecture Hall is on its way up; neither counts as up")
			_expect(_island("Observatory").gliding and map.open_spawns().all(func(o): return map.island_at(o[0]) == null),
				"players are put on the quad, not over the island that stayed while it glides into them")
	_expect(not event.moving() and event.now() == to and not map.shifting, "4 s later everything has arrived")
	_expect(worst < 0.35, "every rider on the island that stayed was carried all the way: never more than %.2f m from where they stood on it (%s)" % [worst, worst_who])
	_expect(airborne == 0, "and never left its floor")
	var stuck := riders.filter(func(p): return _inside_something(p.body)).map(func(p): return p.name)
	_expect(stuck.is_empty(), "none of them ended up inside a wall or a floor %s" % [stuck])
	var obs := stays.transform.origin
	_expect(absf(obs.y) < 0.05 and absf(Vector2(obs.x, obs.z).length() - ISLAND_AT) < 0.1 and absf(absf(rad_to_deg(atan2(obs.x, -obs.z))) - 36.0) < 0.5,
		"the Observatory swung 36 degrees round the quad (it is at %s)" % obs.snapped(Vector3(0.1, 0.1, 0.1)))
	var survivors := doomed.filter(func(p): return (p.body as CharacterBody3D).global_position.y > map.kill_height).map(func(p): return p.name)
	_expect(survivors.is_empty(), "everyone who stayed on the Labs went down with them, below the kill height %s" % [survivors])
	_expect(_island("Labs").is_parked() and not _island("Labs").up and goes.transform.origin.y < map.kill_height - 50.0, "the Labs are parked far below, out of sight and out of the way")
	_expect(on_quad.body.is_on_floor() and absf(on_quad.body.global_position.y) < 0.2, "the player on the quad stayed put: the quad does not move")
	var hall := _body_of(_island("LectureHall")).transform.origin
	_expect(_island("LectureHall").up and absf(hall.y) < 0.05, "the Lecture Hall is up, and counts as up")
	var moved_wrong := []
	for i in pickup_before:
		if (stays.transform.affine_inverse() * (map.weapon_spawns[i][0] as Vector3)).distance_to(pickup_before[i]) > 0.05:
			moved_wrong.append(map.weapon_spawns[i][1])
	_expect(pickup_before.size() >= 3 and moved_wrong.is_empty(), "the %d pickups on the Observatory went with it %s" % [pickup_before.size(), moved_wrong])
	_expect(map.carried(Vector3(100, 0, 100), 0.1) == Vector3(100, 0, 100), "(a point on no island is left where it is)")
	_clear_players()
	event.set_physics_process(false)
	_rest(to)
	for i in 6:
		await physics_frame


# ---------------------------------------------------------------------------
# Crossings

## With Observatory and Lecture Hall up (drifted): bots have a crossing each way for
## both, and none for the islands that are down.
func _crossings() -> void:
	print("  bots' crossings (two islands up)")
	await _bake()
	var quad := Vector3(0, 0, -7.0)
	var up := {}
	var down_usable := []
	var bad := []
	for node in get_nodes_in_group(MapJumpLink.GROUP):
		var link := node as MapJumpLink
		var island := link.island()
		if island == null:
			bad.append("%s is on no island" % link.name)
			continue
		if not island.up:
			if link.usable():
				down_usable.append("%s/%s" % [island.name, link.name])
			continue
		var plaza: Vector3 = _body_of(island).transform * Vector3(0, 0, -7.0)
		var takeoff := link.takeoff()
		var landing := link.landing_point()
		var ok := link.usable() and link.hook_point() != Vector3.INF and link.hook_point().distance_to(takeoff) < 45.0
		if link.leaves:
			ok = ok and _walks(plaza, takeoff) and _short(quad, landing) < 1.5 and Vector2(landing.x, landing.z).length() < QUAD_RADIUS
		else:
			ok = ok and _walks(quad, takeoff) and absf(Vector2(takeoff.x, takeoff.z).length() - (QUAD_RADIUS - 1.7)) < 0.1 and _short(plaza, landing) < 1.5
		if ok:
			up["%s %s" % [island.name, "off" if link.leaves else "on"]] = true
		else:
			bad.append("%s/%s" % [island.name, link.name])
	_expect(bad.is_empty() and up.size() == 4, "a way off and a way on for each island that is up, each from floor a bot can walk to, each hook within the grapple's reach (%s) %s" % [up.keys(), bad])
	_expect(down_usable.is_empty(), "and none to or from an island that is down %s" % [down_usable])
	_expect(get_nodes_in_group(MapJumpLink.GROUP).size() == 10, "(ten crossings in all: two for each island)")


## The grapple crosses, both ways, however the islands stand: every kind of
## arrangement, high and low. Each test player stands where a crossing starts, hooks
## what it names, rides the rope and lets go.
func _grapples() -> void:
	print("  the grapple across, in every arrangement")
	var pair := _pair("Cafeteria", "Library")
	var cases := {
		"Swap": LayoutEvent.pack(pair, LayoutEvent.Kind.SWAP, 0, 0),
		"Drift": LayoutEvent.pack(pair, LayoutEvent.Kind.DRIFT, 0, 0),
		"Close": LayoutEvent.pack(pair, LayoutEvent.Kind.CLOSE, 0, 0),
		"Far and high": LayoutEvent.pack(pair, LayoutEvent.Kind.FAR, 0, 0),
		"Far and low": LayoutEvent.pack(pair, LayoutEvent.Kind.FAR, 1, 0),
		"Split": LayoutEvent.pack(pair, LayoutEvent.Kind.SPLIT, 0, 0),
	}
	for case_name in cases:
		_clear_players()
		_rest(cases[case_name])
		for i in 6:
			await physics_frame
		var flyers := []
		for node in get_nodes_in_group(MapJumpLink.GROUP):
			var link := node as MapJumpLink
			if not link.usable():
				continue
			var p := _player(link.takeoff() + Vector3(0, 0.05, 0))
			p["hook"] = link.hook_point()
			p["plan"] = _grapple_plan
			p["link"] = link
			flyers.append(p)
		await _wait(7.0)
		var failed := []
		for p in flyers:
			var link: MapJumpLink = p.link
			var body: CharacterBody3D = p.body
			var at := body.global_position
			var made_it := body.is_on_floor()
			if link.leaves:
				made_it = made_it and at.y > -0.5 and at.y < 1.5 and Vector2(at.x, at.z).length() < QUAD_RADIUS + 0.5
			else:
				made_it = made_it and map.island_at(at) == link.island() and at.y > link.island().global_position.y - 0.5
			if not made_it:
				failed.append("%s/%s (ended at %s)" % [link.island().name, link.name, at.snapped(Vector3(0.1, 0.1, 0.1))])
		_expect(flyers.size() == 4 and failed.is_empty(), "%s: off both islands to the quad and from the quad onto both %s" % [case_name, failed])
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
	var hook: Vector3 = p.hook
	var over := Vector2(body.global_position.x - hook.x, body.global_position.z - hook.z).length() < 3.0
	if g.attached and (g.rope_origin(body).distance_to(g.anchor) < 5.5 or over):
		input.grapple = false
	if not input.grapple:
		# Let go: steer for the landing, and stand still once down near it.
		var land: Vector3 = (p.link as MapJumpLink).landing_point() if p.has("link") else hook
		var to := Vector3(land.x - body.global_position.x, 0, land.z - body.global_position.z)
		input.pitch = 0.0
		if to.length() > 1.2:
			input.yaw = atan2(-to.x, -to.z)
		var speed := Vector3(body.velocity.x, 0, body.velocity.z)
		var overshooting := speed.length() > 1.0 and to.length() < speed.length() * 0.55
		input.move = Vector2(0, -1 if overshooting else 1) if to.length() > 1.2 else Vector2.ZERO


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
