extends SceneTree
## Neon Arcade comes apart: the arcade and the four neighbours you can go into break small
## and come down a section at a time, and the filling station's canopy comes off its columns.
## Run: godot --headless --path . --script tests/neon_arcade_destruction_test.gd
##
##  - brick, plaster, floors, roofs and glass break, and nothing of a building is kept
##    from breaking; a window goes at one shot, a brick takes a few, a rocket makes a hole;
##  - the arcade, the noodle bar, the record shop, the diner and the laundromat each have
##    a collapse of their own, held up by their walls (and the arcade by its six pillars
##    too); the canopy has one held up by four columns;
##  - small arms do nothing to a pillar, three rockets blow one out, and one pillar gone
##    brings nothing down;
##  - enough of a corner's wall gone brings down that corner of the arcade and nothing of
##    its neighbours, and nobody spawns under what fell;
##  - a neighbour comes down the same way, on its own; the canopy falls when a column goes;
##  - someone who joins afterwards has the very same heaps and the same walls gone.

const ROCKET := [1.6, 262.0]   # a rocket's blast on a column: how far, and how hard
const BREAKS := ["brick", "roof", "mezz_floor", "partition", "glass", "glass_rail", "brick_red", "brick_tan", "diner_wall", "stucco",
	"floor_wood", "canopy"]
const HELD_BY_WALLS := ["ArcadeFrame", "NoodleBarFrame", "RecordShopFrame", "DinerFrame", "LaundromatFrame"]

var failures := 0
var map: MapRoot
var heaps := {}   # the host's heaps: a collapse's number -> what MapCollapse.settled says of it


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _apply(d: MapDestruction) -> int:
	var change := d.flush()
	if change.is_empty():
		return 0
	return d.apply(change[0], change[1]).size()


## Everything the collapses make of the damage so far: the events that started.
func _flush_all() -> Array:
	var started := []
	for c in map.collapses:
		var out := c.flush()
		if out.is_empty():
			continue
		c.apply_columns(out.columns[0], out.columns[1])
		for ev: Dictionary in out.events:
			c.start(ev)
			c.host(int(ev.id))
			started.append(ev)
	return started


func _frame(name: String) -> MapCollapse:
	for c in map.collapses:
		if c.frame.name == name:
			return c
	return null


## Breaks the stretch of wall at a crossing of `c`, a piece at a time from its middle
## out, up to `share` of what brings it down (1: just enough).
func _break_wall(c: MapCollapse, corner: Vector2i, storey: int, short_by: int = 0) -> int:
	var d := map.destruction
	var seg: Dictionary = c.segments[c._columns[corner][storey]]
	var mid := (seg.box as AABB).get_center()
	var order := Array(seg.cells as PackedInt32Array)
	order.sort_custom(func(p, q): return d.cell_center(p).distance_squared_to(mid) < d.cell_center(q).distance_squared_to(mid))
	var need := ceili(order.size() * c.frame.wall_share)
	for n in need - short_by:
		d.damage(order[n], 10000.0)
	_apply(d)
	return need


func _run() -> void:
	await process_frame
	map = Maps.make("neon_arcade")
	map.destructible = true
	root.add_child(map)
	map.build()
	for i in 4:
		await physics_frame
	var d := map.destruction
	for other in map.collapses:
		other.settled.connect(func(id: int, key: String): heaps[id] = key)

	print("  what breaks")
	var kinds := {}
	var guarded := 0
	var pane := {}
	var brick := {}
	for panel: Dictionary in d.panels:
		kinds[panel.kind] = true
		var n: Vector3i = panel.n
		var count := n.x * n.y * n.z
		if panel.kind != "canopy":
			for cell in range(int(panel.first), int(panel.first) + count):
				if d.cells[cell].protected:
					guarded += 1
		if pane.is_empty() and panel.kind == "glass":
			pane = panel
		if brick.is_empty() and panel.kind == "brick" and count > 40:
			brick = panel
	var missing := BREAKS.filter(func(kind): return not kinds.has(kind))
	_check(missing.is_empty(), "brick, plaster, floors, roofs and glass break %s" % [missing])
	_check(d.cells.size() > 15000, "the block is made of pieces that break (%d)" % d.cells.size())
	_check(guarded == 0, "nothing of a building is kept from breaking (%d pieces are)" % guarded)
	_check(not pane.is_empty() and not brick.is_empty(), "there is a window and a brick wall to try")
	if pane.is_empty() or brick.is_empty():
		quit(1)
		return
	d.damage(int(pane.first), 30.0)
	var size: Vector3i = pane.n
	_check(_apply(d) == size.x * size.y * size.z, "a window goes at one shot, the whole pane (%d)" % (size.x * size.y * size.z))
	var first := int(brick.first) + 5
	d.damage(first, 17.0)
	_check(_apply(d) == 0, "one rifle round does not break a brick")
	for n in 8:
		d.damage(first, 17.0)
	_check(_apply(d) == 1, "a few more do, and only that one")
	d.damage_area(d.cell_center(int(brick.first) + 20), 1.575, 262.0)
	var hole := _apply(d)
	_check(hole >= 6, "a rocket makes a hole in a brick wall (%d pieces)" % hole)
	_check(_flush_all().is_empty(), "none of that brings anything down")

	print("  what holds them up")
	_check(map.collapses.size() == 6, "six things can come down (%d)" % map.collapses.size())
	var arcade := _frame("ArcadeFrame")
	var canopy := _frame("CanopyFrame")
	var noodle := _frame("NoodleBarFrame")
	if map.collapses.size() != 6 or arcade == null or canopy == null or noodle == null:
		quit(1)
		return
	for name: String in HELD_BY_WALLS:
		var c := _frame(name)
		var walls := c.segments.filter(func(seg): return seg.has("cells")).size() if c else 0
		_check(c != null and c.frame.held_by_walls and walls >= 6 and c.bays.size() >= 2,
			"%s: %d bays on %d stretches of wall" % [name, c.bays.size() if c else 0, walls])
	var pillars := arcade.segments.filter(func(seg): return not seg.has("cells")).size()
	_check(arcade.bays.size() == 12 and pillars == 12, "the arcade's six pillars hold it up too, a storey at a time (%d)" % pillars)
	_check(canopy.segments.size() == 4 and canopy.bays.size() == 1, "the canopy stands on four columns")

	print("  a pillar")
	var storeys: Array = arcade._columns[Vector2i(1, 1)]
	var pillar: AABB = arcade.segments[storeys[1]].box
	var foot := Vector3(pillar.get_center().x + 0.45, 1.2, pillar.get_center().z)
	for n in 200:
		arcade.hit(foot, 17.0)
	_check(arcade.flush().is_empty(), "two hundred rifle rounds do nothing to a pillar")
	arcade.blast(foot, ROCKET[0], ROCKET[1])
	var out := arcade.flush()
	_check(not out.is_empty() and (out.events as Array).is_empty(), "one rocket cracks it")
	if not out.is_empty():
		arcade.apply_columns(out.columns[0], out.columns[1])
	arcade.blast(foot, ROCKET[0], ROCKET[1])
	arcade.blast(foot, ROCKET[0], ROCKET[1])
	out = arcade.flush()
	var gone := not out.is_empty() and (out.columns[1] as PackedByteArray).has(MapCollapse.DESTROYED)
	_check(gone, "three blow it out")
	_check(not out.is_empty() and (out.events as Array).is_empty(), "and with the walls and the other pillars standing, nothing falls")
	if not out.is_empty():
		arcade.apply_columns(out.columns[0], out.columns[1])

	print("  a corner of the arcade comes down")
	var corner := Vector2i(0, 3)   # the alley and Main Street
	_check(arcade.has_column(corner, 1), "the corner has a stretch of wall on its ground storey")
	if not arcade.has_column(corner, 1):
		quit(1)
		return
	var need := _break_wall(arcade, corner, 1, 1)
	_check(_flush_all().is_empty(), "with %d of its pieces gone the wall still holds" % (need - 1))
	_break_wall(arcade, corner, 1)
	var started := _flush_all()
	_check(started.size() == 1 and map.collapse_of(int(started[0].id)) == arcade, "one more and that corner is coming down, and nothing of a neighbour")
	if started.size() != 1:
		quit(1)
		return
	var units: PackedInt32Array = started[0].units
	var fell := {}
	for unit in units:
		fell[unit / 16] = true
	_check(units.size() >= 2 and fell.size() <= 4, "from the ground up, and not the whole arcade (%d of 12 bays)" % fell.size())
	var e: Dictionary = arcade.events[0]
	for n in 400:
		await physics_frame
		if int(e.state) == MapCollapse.FALLING:
			break
	_check(int(e.state) == MapCollapse.FALLING and (e.pieces as Array).size() > 10, "after the warning it lets go (%d pieces)" % (e.pieces as Array).size())
	var fallen := 0
	for unit in units:
		for cell: int in arcade._unit_cells.get(unit, PackedInt32Array()):
			if int(d.cells[cell].stage) == MapDestruction.FALLEN:
				fallen += 1
	_check(fallen > 100, "its walls, floor and roof are no longer part of the arcade (%d pieces of them)" % fallen)
	var bay: Dictionary = arcade.bays[fell.keys()[0]]
	var under := Vector3((arcade.frame.lines_x[bay.i] + arcade.frame.lines_x[int(bay.i) + 1]) * 0.5, 0.3,
		(arcade.frame.lines_z[bay.j] + arcade.frame.lines_z[int(bay.j) + 1]) * 0.5)
	_check(arcade.blocked(under) and map.under_rubble(under), "nobody is put under the corner that fell")
	_check(not map.under_rubble(Vector3(15.0, 0.3, -10.0)), "but they are at the far end of the arcade")

	print("  a neighbour, and the canopy")
	var end := Vector2i(2, 2)   # the noodle bar's corner on the alley and Main Street
	_check(noodle.has_column(end, 1), "the noodle bar's corner has a stretch of wall")
	if noodle.has_column(end, 1):
		_break_wall(noodle, end, 1)
		started = _flush_all()
		_check(started.size() == 1 and map.collapse_of(int(started[0].id)) == noodle and arcade.events.size() == 1,
			"enough of it gone brings down that end of the noodle bar, and nothing more of the arcade")
	var column: AABB = canopy.segments[0].box
	var at := Vector3(column.get_center().x + 0.4, 1.2, column.get_center().z)
	canopy.hit(at, 17.0)
	_check(canopy.flush().is_empty(), "a rifle round does nothing to one of the canopy's columns")
	for n in 3:
		canopy.blast(at, ROCKET[0], ROCKET[1])
	started = _flush_all()
	_check(started.size() == 1 and map.collapse_of(int(started[0].id)) == canopy, "three rockets blow it out, and the canopy is coming down")

	print("  someone who joins afterwards")
	for n in 3600:   # (120 steps a second: a fall is called over 22 s after it began at the latest)
		if map.collapses.all(func(o): return o.events.all(func(ev): return int(ev.state) == MapCollapse.DOWN)):
			break
		await physics_frame
	_check(heaps.size() == 3, "all three falls come to rest on the host (%d)" % heaps.size())
	var view := SubViewport.new()   # (a world of its own)
	view.own_world_3d = true
	view.size = Vector2i(16, 16)
	root.add_child(view)
	var late: MapRoot = Maps.make("neon_arcade")
	late.destructible = true
	view.add_child(late)
	late.build()
	var theirs := {}
	for other in late.collapses:
		other.settled.connect(func(id: int, key: String): theirs[id] = key)
	# (As MatchState does it: what is broken, then each collapse's state.)
	var all := d.snapshot()
	late.destruction.apply(all[0], all[1])
	for other in map.collapses:
		late.collapses[other.index].restore(other.state())
	for n in 120:
		await physics_frame
	_check(late.destruction.state_key() == d.state_key(), "they have the same walls and floors gone (%s)" % late.destruction.state_key())
	_check(theirs == heaps and not theirs.is_empty(), "and the very same heaps, each building's its own (%s)" % [theirs])
	print("neon arcade destruction: %s" % ("FAILED (%d)" % failures if failures else "ok"))
	quit(1 if failures else 0)
