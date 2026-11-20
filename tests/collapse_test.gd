extends SceneTree
## A building coming down (MapCollapse), on the Construction Site, as several players
## see it.
## Run: godot --headless --path . --fixed-fps 60 --script tests/collapse_test.gd
##
## Four copies of the map, each in a world of its own: the host, a player who hears the
## host's news a tenth of a second late, one who hears none of it, and one who joins
## half way through the fall. Small arms only mark a column and three rockets blow a
## storey out; the corner bay then falls, all five floors of it, and nothing changes in
## the walls until it lets go. Every copy's pieces start a hair apart (machines differ):
## the one that hears the news stays close to the host all the way down, much closer
## than the one that does not, and once the host calls the rest every copy has the very
## same heap. Someone under it is crushed, someone across the site is not; the host's
## news stays small; a copy that joins afterwards gets the same heap at once.

const LAG := 12   # physics frames (a tenth of a second) between the host and the others

var failures := 0
var _queue: Array = []   # [frame, Callable]
var _frame := 0
var late: MapRoot = null   # joins half way down (here, not in _run: a lambda keeps its own copy of a local)


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


## A copy of the map; `apart`: in a world of its own.
func _make(apart: bool) -> MapRoot:
	var map: MapRoot = Maps.make("construction_site")
	map.destructible = true
	if apart:
		var view := SubViewport.new()
		view.own_world_3d = true
		view.size = Vector2i(16, 16)
		root.add_child(view)
		view.add_child(map)
	else:
		root.add_child(map)
	map.build()
	return map


func _later(what: Callable) -> void:
	_queue.append([_frame + LAG, what])


func _event(map: MapRoot) -> Dictionary:
	return map.collapse.events[0] if not map.collapse.events.is_empty() else {}


func _state(map: MapRoot) -> int:
	var e := _event(map)
	return int(e.state) if not e.is_empty() else -1


## Where each piece of a copy's fall is now, under its age (in frames).
func _note(map: MapRoot, track: Dictionary) -> void:
	var e := _event(map)
	if e.is_empty() or int(e.state) != MapCollapse.FALLING:
		return
	var at := PackedVector3Array()
	for p: Dictionary in e.pieces:
		at.append((p.body as RigidBody3D).transform * (p.c as Vector3) if p.body != null else Vector3.ZERO)
	track[roundi(float(e.age) * 120.0)] = at


## How far apart two copies' big pieces were at the same age: [mean, worst] in metres.
func _gap(a: Dictionary, b: Dictionary, big: PackedInt32Array) -> Array:
	var sum := 0.0
	var n := 0
	var worst := 0.0
	for key: int in a:
		if not b.has(key):
			continue
		var one: PackedVector3Array = a[key]
		var two: PackedVector3Array = b[key]
		for i in big:
			var d := one[i].distance_to(two[i])
			sum += d
			n += 1
			worst = maxf(worst, d)
	return [sum / maxf(n, 1.0), worst]


## How far apart two copies' heaps are: the most any shape is out (metres, or how its axes differ), or -1 if they do not line up.
func _heaps_apart(a: MapRoot, b: MapRoot) -> float:
	var one: Node = (_event(a).heap as Node).get_node("Collision")
	var two: Node = (_event(b).heap as Node).get_node("Collision")
	if one.get_child_count() != two.get_child_count() or one.get_child_count() == 0:
		return -1.0
	var worst := 0.0
	for i in one.get_child_count():
		var x: Transform3D = (one.get_child(i) as Node3D).transform
		var y: Transform3D = (two.get_child(i) as Node3D).transform
		worst = maxf(worst, x.origin.distance_to(y.origin))
		worst = maxf(worst, (x.basis.x - y.basis.x).length() + (x.basis.y - y.basis.y).length())
	return worst


func _run() -> void:
	await process_frame
	seed(20261120)   # (how the host cuts the bay up: the same every run)
	var host := _make(false)
	var near := _make(true)    # hears the host's news, late
	var alone := _make(true)   # hears nothing until the rest
	var c := host.collapse
	_check(c != null and near.collapse != null, "the Construction Site has a frame that can come down")
	if c == null:
		print("FAILED: 1")
		quit(1)
		return
	for n in 5:
		await physics_frame
	var fixed := 0
	for bay: Dictionary in c.bays:
		fixed += 1 if bay.fixed else 0
	_check(c.bays.size() == 9 and fixed == 1, "nine bays, and only the one the lift core stands in cannot fall")
	_check(c.segments.size() >= 40, "the columns are taken a storey at a time (%d storeys)" % c.segments.size())

	# Small arms mark a column and no more; heavy rounds crack it; nothing falls yet.
	var far_column: int = c._columns[Vector2i(3, 3)][0]
	var far_box: AABB = c.segments[far_column].box
	for n in 200:
		c.hit(far_box.get_center() + Vector3(0.45, 0, 0), 17.0)
	_check(c.flush().is_empty(), "two hundred rifle rounds do nothing to a column")
	for n in 2:
		c.hit(far_box.get_center() + Vector3(0.45, 0, 0), 112.0)
	var out := c.flush()
	_check(not out.is_empty() and (out.events as Array).is_empty() and int(out.columns[1][0]) == 1, "two sniper rounds crack it, and nothing falls")

	# Three rockets at the foot of the north-west corner column.
	var seg: int = c._columns[Vector2i(0, 0)][0]
	var foot: Vector3 = (c.segments[seg].box as AABB).get_center() + Vector3(-0.5, 0, -0.5)
	c.by = 7
	c.with = "rocket_launcher"
	c.blast(foot, 1.6, 262.0)
	out = c.flush()
	_check(not out.is_empty() and (out.events as Array).is_empty(), "one rocket cracks the corner column, and nothing falls")
	c.blast(foot, 1.6, 262.0)
	c.blast(foot, 1.6, 262.0)
	out = c.flush()
	var events: Array = out.get("events", [])
	_check(events.size() == 1 and (events[0].units as PackedInt32Array).size() == c.levels(), "three blow it out, and the corner bay is to fall: all %d floors" % c.levels())
	if events.size() != 1:
		print("FAILED: %d" % failures)
		quit(1)
		return
	var bay := c.bay_at(Vector3(-10.5, 0, -10.5))
	var all_in_bay := true
	for unit: int in events[0].units:
		all_in_bay = all_in_bay and unit / 16 == bay
	_check(all_in_bay, "...and only that bay")

	# The host tells everyone, and referees.
	var event: Dictionary = events[0]
	var columns: Array = out.columns
	c.apply_columns(columns[0], columns[1])
	c.start(event)
	c.host(int(event.id))
	for other: MapRoot in [near, alone]:
		_later(func() -> void:
			other.collapse.apply_columns(columns[0], columns[1])
			other.collapse.start(event))
	var sent := [0, 0]
	var by_second := {}
	c.news_out.connect(func(id: int, age: float, data: PackedByteArray) -> void:
		sent[0] += data.size()
		sent[1] += 1
		by_second[int(age)] = int(by_second.get(int(age), 0)) + data.size()
		_later(func() -> void:
			near.collapse.news(id, age, data)
			if late:
				late.collapse.news(id, age, data)))
	c.rest_out.connect(func(id: int, data: PackedByteArray) -> void:
		print("  the host calls the rest (%d bytes)" % data.size())
		_later(func() -> void:
			near.collapse.rest(id, data)
			alone.collapse.rest(id, data)
			if late:
				late.collapse.rest(id, data)))

	var cells: PackedInt32Array = c._unit_cells.get(event.units[0], PackedInt32Array())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tracks := {host: {}, near: {}, alone: {}}
	var was := {host: -1, near: -1, alone: -1}
	var untouched := true
	var crushed := {}
	var spared := true
	var big := PackedInt32Array()
	var began := {}        # piece -> where its middle was when the building let go (host)
	var early_high := 0    # pieces from the top half that had moved half a second in
	var early_low := 0     # ...and from the bottom floor
	var early_checked := false
	var started := Time.get_ticks_msec()
	var fell_for := 0.0
	for f in 120 * 30:
		await physics_frame
		_frame += 1
		while not _queue.is_empty() and int(_queue[0][0]) <= _frame:
			(_queue.pop_front()[1] as Callable).call()
		for map: MapRoot in [host, near, alone]:
			var state := _state(map)
			if state == MapCollapse.WAITING and not cells.is_empty():
				untouched = untouched and int(map.destruction.cells[cells[0]].stage) == 0
			if state == MapCollapse.FALLING and int(was[map]) != MapCollapse.FALLING and map != host:
				# Machines differ: every piece of this copy starts up to a millimetre out.
				for p: Dictionary in _event(map).pieces:
					if p.body != null:
						(p.body as RigidBody3D).transform.origin += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.001
			if state == MapCollapse.FALLING and int(was[map]) != MapCollapse.FALLING and map == host:
				var pieces: Array = _event(host).pieces
				for i in pieces.size():
					if pieces[i].body != null and pieces[i].big:
						big.append(i)
				var fallen := true
				for cell in cells:
					fallen = fallen and int(host.destruction.cells[cell].stage) == MapDestruction.FALLEN
				_check(untouched, "nothing changes in the walls and floors until it lets go")
				_check(fallen and not cells.is_empty(), "...and then they are gone from the building (%d pieces fall, %d of them big)" % [pieces.size(), big.size()])
				for i in pieces.size():
					if pieces[i].body != null:
						began[i] = (pieces[i].body as RigidBody3D).transform * (pieces[i].c as Vector3)
			was[map] = state
			_note(map, tracks[map])
		if _state(host) == MapCollapse.FALLING:
			fell_for = float(_event(host).age)
			if not early_checked and fell_for >= 0.5:
				early_checked = true
				var pieces: Array = _event(host).pieces
				for i: int in began:
					var from: Vector3 = began[i]
					var now: Vector3 = (pieces[i].body as RigidBody3D).transform * (pieces[i].c as Vector3)
					if now.distance_to(from) > 0.02:
						if from.y > 12.0:
							early_high += 1
						elif from.y < 5.0:
							early_low += 1
			for x: float in [-13.5, -10.5, -7.5]:   # (people standing all over the ground floor of the bay)
				for z: float in [-13.5, -10.5, -7.5]:
					if crushed.is_empty():
						crushed = c.crushes(Vector3(x, 0.0, z), 1.8)
			spared = spared and c.crushes(Vector3(10.5, 0.0, 10.5), 1.8).is_empty()
			if late == null and fell_for >= 2.0:
				# Someone joins: they are told what is broken, and where the fall has got to.
				var told := c.state()
				late = _make(true)
				late.collapse.restore(told)
				_check(_state(late) == MapCollapse.FALLING, "a player who joins two seconds into the fall has it in the air too")
		if _state(host) == MapCollapse.DOWN and _state(near) == MapCollapse.DOWN and _state(alone) == MapCollapse.DOWN \
				and late != null and _state(late) == MapCollapse.DOWN:
			break
	print("  the fall took %.1f s on the host (%d ms to run four copies of it)" % [fell_for, Time.get_ticks_msec() - started])
	_check(early_checked and early_low >= 5 and early_high == 0,
		"it crumbles from the bottom up: half a second in, %d pieces of the bottom floor are on their way and none from the top half" % early_low)
	_check(_state(host) == MapCollapse.DOWN and _state(near) == MapCollapse.DOWN, "it comes to rest, and becomes part of the level")
	if _state(host) != MapCollapse.DOWN or _state(near) != MapCollapse.DOWN or _state(alone) != MapCollapse.DOWN or late == null \
			or _state(late) != MapCollapse.DOWN:
		print("  states: host %d, with news %d, without %d, late %d" % [_state(host), _state(near), _state(alone), _state(late) if late else -9])
		print("FAILED: %d" % maxi(failures, 1))
		quit(1)
		return

	# How close the copies stayed on the way down.
	var with_news := _gap(tracks[host], tracks[near], big)
	var without := _gap(tracks[host], tracks[alone], big)
	print("  big pieces, against the host's at the same moment of the fall: %.2f m off on average with its news (worst %.1f), %.2f m without (worst %.1f)"
		% [with_news[0], with_news[1], without[0], without[1]])
	_check(float(with_news[0]) < 0.25, "a player who hears the host's news sees the pieces fall where the host has them (%.0f cm off on average)" % (float(with_news[0]) * 100.0))
	_check(float(with_news[0]) < float(without[0]) * 0.5, "...much closer than one who hears none")

	# And where it ends up.
	_check(_heaps_apart(host, near) >= 0.0 and _heaps_apart(host, near) < 0.002, "the heap is the same for both (%.4f)" % _heaps_apart(host, near))
	_check(_heaps_apart(host, alone) >= 0.0 and _heaps_apart(host, alone) < 0.002, "...and for one who heard only the rest (%.4f)" % _heaps_apart(host, alone))
	_check(_heaps_apart(host, late) >= 0.0 and _heaps_apart(host, late) < 0.002, "...and for one who joined half way down (%.4f)" % _heaps_apart(host, late))
	_check(_event(host).pieces.is_empty() and (_event(host).heap as Node).get_node("Collision") is StaticBody3D, "the heap is one body that does not move")
	_check(not crushed.is_empty() and int(crushed.get("by", 0)) == 7 and String(crushed.get("with", "")) == "rocket_launcher",
		"someone standing under the bay is crushed, and whoever blew the column gets the kill")
	_check(spared, "someone across the site is not")
	_check(c.blocked(Vector3(-10.5, 0.2, -10.5)) and not c.blocked(Vector3(10.5, 0.2, 10.5)) and near.collapse.blocked(Vector3(-10.5, 0.2, -10.5)),
		"nobody spawns in or under the bay that fell")

	# What the host had to send.
	var peak := 0
	for second: int in by_second:
		peak = maxi(peak, int(by_second[second]))
	print("  host's news: %d KB in %d messages over %.1f s, %.1f KB in its busiest second" % [sent[0] / 1024, sent[1], fell_for, peak / 1024.0])
	_check(peak < 28 * 1024, "the host's news stays under 28 KB a second for each player, even as everything lets go")

	# Someone who joins afterwards.
	var after := _make(true)
	after.collapse.restore(c.state())
	_check(_state(after) == MapCollapse.DOWN and _heaps_apart(host, after) >= 0.0 and _heaps_apart(host, after) < 0.002,
		"a player who joins afterwards finds the same heap")
	var after_fallen := true
	for cell in cells:
		after_fallen = after_fallen and int(after.destruction.cells[cell].stage) == MapDestruction.FALLEN
	_check(after_fallen, "...and the bay gone")

	# Higher up: only what stands on the storey that went.
	var storeys: Array = c._columns[Vector2i(3, 0)]
	var top := storeys.size() - 1
	while top > 0 and int(storeys[top]) < 0:
		top -= 1
	for n in 3:
		c.blast((c.segments[storeys[top]].box as AABB).get_center(), 1.6, 262.0)
	out = c.flush()
	var lowest := 99
	for e: Dictionary in out.get("events", []):
		for unit: int in e.units:
			lowest = mini(lowest, unit % 16)
	_check(top > 0 and lowest == top, "a column blown out at floor %d brings down that floor and up, and leaves what is below" % (top + 1))

	# Steel: a girder is one hidden block with its flanges and web drawn on it. It comes
	# away whole, with all of them, and is never cut up.
	c.apply_columns(out.columns[0], out.columns[1])
	for e: Dictionary in out.get("events", []):
		c.start(e)
	var steel: Dictionary = c.events[c.events.size() - 1]
	_check((steel.pieces as Array).is_empty() and int(steel.planned) == 0, "nothing is cut up in the frame the column goes: that is spread over the warning")
	for f in 120 * 3:
		await physics_frame
		if int(steel.state) == MapCollapse.FALLING:
			break
	var beams := 0
	var whole := true
	for i in (steel.specs as Array).size():
		var spec: Dictionary = steel.specs[i]
		if spec.kind == "loose" and String(spec.piece.kind) == "steel":
			beams += 1
			whole = whole and steel.pieces[i].body != null and (spec.piece.get("with", []) as Array).size() == 3
	var strays := 0   # steel left to stand, or to vanish, on its own
	for square: Dictionary in c.bays:
		for floor_things: Array in square.loose:
			for piece: Dictionary in floor_things:
				if String(piece.kind) == "steel" and not piece.solid:
					strays += 1
	_check(int(steel.state) == MapCollapse.FALLING and beams >= 3 and whole and strays == 0,
		"the steel there comes away whole: %d beams and posts, each one piece with its flanges and web" % beams)

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
