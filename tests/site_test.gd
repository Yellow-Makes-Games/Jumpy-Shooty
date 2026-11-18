extends "res://tests/course_runner.gd"
## Construction Site checks:
##  - every spawn point is clear and inside the fence;
##  - the bot's navigation mesh reaches every floor of the tower, the crow's nest,
##    the pit, the scaffolding and the hoist tower's planks from every spawn point;
##  - a scripted player can do every route the map is built around with the current
##    movement tuning: wall-jump up the lift shaft, climb floor to floor off the
##    crates, climb the scaffolding and the hoist tower, wall-run the tower's north
##    wall and the fence, slide under the trailer and down the conveyor, vault a
##    barrier, run through a pipe, swing off the tower on the grapple, and jump the
##    gap from the hoist tower;
##  - the crane: its mast is a chimney you wall-jump up (to the deck round its head, or
##    out at the tie gangway from the tower's 20 m steel), the lever in its cab is in
##    reach of someone standing there and sets the crane off, whoever is in the cab or
##    on the slab rides along, and nothing stands in the slab's way or under it.
## Run: godot --headless --path . --script tests/site_test.gd

## Where things are on the map (game/maps/construction_site.tscn). If you move one
## of them in the editor, change its numbers here too, or the route test for it fails.
class S:
	const HALF := 40.0                ## the site is 80 x 80 m
	const TOWER := 16.0               ## the tower is 32 x 32 m
	const NEST := 24.0                ## height of the crow's nest
	const SHAFT_X := 1.5              ## the lift shaft's gap is 3 m wide (x) and 4 m deep (z)
	const SHAFT_Z := 2.0
	const PIT_DEPTH := 3.0            ## the pit in the south-west corner
	const HOIST := Rect2(-28, -8, 5, 5)   ## the hoist tower west of the tower
	const HOIST_TOP := 20.0
	const STEP_UP := 2.2              ## height of the tall crate by an edge of every floor
	const STEP_UPS := [               ## where each crate stands (floor level), from the ground up
		Vector3(7.85, 0, -1),
		Vector3(1.5, 4, 6.85),
		Vector3(6.85, 8, -14),
		Vector3(4.3, 12, -4.15),
		Vector3(-2.15, 16, -10),
		Vector3(0, 20, -5.85),
	]
	const SCAFFOLD_X0 := 16.0         ## the scaffolding on the tower's east face
	const SCAFFOLD_X1 := 18.4
	const CONTAINER_H := 2.6
	const NORTH_STACK_Z := -19.7      ## centre line of the containers north of the tower
	const MAST := Vector3(27, 0, -27) ## the crane's mast: hollow, 2 m square inside, its floor 1 m up
	const MAST_DECK := 30.6           ## the deck round the mast's head (the cab's floor)
	const MAST_TIE := 20.06           ## the gangway from the tower's steel to the mast's south door
	const TIE_FROM := Vector3(15.5, 20.06, -15.5)   ## where the gangway leaves the tower
	const SLAB := Vector3(2.4, 0.6, 6.0)            ## the slab on the crane's hook


func _map_id() -> String:
	return "construction_site"


func _title() -> String:
	return "Construction Site checks"


func _courses() -> Array:
	return [
		_shaft_run(S.NEST, "to the crow's nest"),
		_shaft_run(8.0, "and step out at the 8 m floor"),
		_crate_run("ground", 0, WEST, 4.0),
		_crate_run("4 m", 1, NORTH, 8.0),
		_crate_run("8 m", 2, WEST, 12.0),
		_crate_run("12 m", 3, NORTH, 16.0),
		_crate_run("16 m", 4, WEST, 20.0),
		_crate_run("20 m", 5, SOUTH, S.NEST),
		_scaffold_run(),
		_hoist_run(),
		_hoist_gap_run(),
		_north_wall_run(),
		_fence_run(),
		_trailer_slide_run(),
		_conveyor_run(),
		_barrier_run(),
		_pipe_run(),
		_swing_run(),
		_mast_run(S.MAST_DECK, "to the deck round its head"),
		_mast_run(S.MAST_TIE, "and step out onto the tie gangway"),
		_gangway_run(),
		_cab_run(),
		_slab_run(0, "south-east"),
		_slab_run(2, "north-west"),
	]


# ---------------------------------------------------------------------------
# Spawn points and bot navigation

func _before_courses() -> void:
	print("  spawn points")
	var space := root.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var bad := 0
	for s in map.spawns:
		var pos: Vector3 = s[0]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
		q.exclude = [body.get_rid()]
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0)))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty() or not map.bounds.has_point(Vector2(pos.x, pos.z)):
			print("      blocked or off the ground: %s" % pos)
			bad += 1
	_expect(map.spawns.size() >= 8, "%d spawn points (the arena needs at least 8)" % map.spawns.size())
	_expect(bad == 0, "every spawn point is clear, on the ground and inside the fence")

	print("  bot navigation")
	var region := MapScenery.bake_navigation(level)
	root.add_child(region)
	var nav_map := root.get_world_3d().navigation_map
	# The navigation map picks up a new region a few frames later (it syncs on a thread)
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 4, 10)).y > 3.0:
			break
	var goals := {
		"4 m floor": Vector3(0, 4, 10), "8 m floor": Vector3(12, 8, -12), "12 m floor": Vector3(0, 12, 4.5),
		"16 m floor": Vector3(0, 16, -10), "20 m floor": Vector3(-10, 20, -10), "crow's nest": Vector3(4, S.NEST, 0),
		"pit": Vector3(-32, -S.PIT_DEPTH, 27.5), "top of the conveyor": Vector3(-17, 8, 4),
		"scaffolding at 4 m": Vector3(17.2, 4, 0), "scaffolding at 8 m": Vector3(17.2, 8, 0),
		"hoist tower plank at 4 m": Vector3(-24.2, 4, -6.75), "hoist tower plank at 12 m": Vector3(-24.2, 12, -6.75),
		"inside the lift shaft": Vector3(0, 0, 0),
		"foot of the crane's mast": S.MAST + Vector3(0, 1, 0),
	}
	for goal_name in goals:
		var goal: Vector3 = goals[goal_name]
		var worst := 0.0
		for s in map.spawns:
			var path := NavigationServer3D.map_get_path(nav_map, s[0], goal, true)
			var miss := 99.0 if path.is_empty() else path[path.size() - 1].distance_to(goal)
			worst = maxf(worst, miss)
		_expect(worst < 1.0, "a bot can walk to the %s from every spawn point%s" % [goal_name, "" if worst < 1.0 else " (ends %.1f m short)" % worst])
	region.queue_free()
	_crane_checks()


# ---------------------------------------------------------------------------
# Routes

## Wall-jump up the lift shaft from the ground. `exit` is the crow's nest height
## (climb out of the top) or a floor height (step out of that floor's doorway).
func _shaft_run(exit: float, what: String) -> Dictionary:
	return {
		"name": "lift shaft: wall-jump up %s" % what,
		"start": Vector3(-S.SHAFT_X + 0.45, 0.05, 0), "yaw": NORTH, "max_time": 14.0,
		"drive": func(dt):
			var p := body.global_position
			input.move = Vector2.ZERO
			input.yaw = NORTH
			if body.is_on_floor() and p.y < 0.5 and not _mem.has("started"):
				input.jump_pressed = true
				_mem["started"] = true
				_mem["last_jump"] = 0.0
			_mem["last_jump"] = _mem.get("last_jump", 0.0) + dt
			if p.y > exit - 2.0:
				input.move = Vector2(0, 1)   # push toward the doorway (or the top of the wall)
			elif _mem.has("started") and _mem.last_jump > 0.12 and body.velocity.y < 3.0:
				input.jump_pressed = true
				_mem["last_jump"] = 0.0,
		"done": func(): return body.global_position.y > exit - 0.1 and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			_expect(absf(p.y - exit) < 0.15 and body.is_on_floor() and p.z < -S.SHAFT_Z + 0.3,
				"standing at %.0f m, out of the shaft (feet at %.1f m, after %.1f s)" % [exit, p.y, _time]),
	}


## Stand on the tall crate by a floor edge, jump and climb up to the next floor.
func _crate_run(from: String, index: int, yaw: float, top: float) -> Dictionary:
	var crate: Vector3 = S.STEP_UPS[index]
	return {
		"name": "crate climb: from the %s floor up to %.0f m" % [from, top] if from != "ground" else "crate climb: from the ground up to %.0f m" % top,
		"start": crate + Vector3(0, S.STEP_UP + 0.05, 0), "yaw": yaw, "max_time": 3.0,
		"drive": func(_dt):
			input.yaw = yaw
			input.move = Vector2(0, 1) if body.global_position.y < top - 0.2 else Vector2.ZERO
			if body.is_on_floor() and not _mem.has("jumped") and _time > 0.1:
				input.jump_pressed = true
				_mem["jumped"] = true,
		"done": func(): return false,
		"check": func():
			var y := body.global_position.y
			_expect(absf(y - top) < 0.15 and body.is_on_floor(), "standing on the floor above (feet at %.1f m)" % y),
	}


## Up the east scaffolding from the ground to its 12 m deck, grabbing the end of
## each deck in turn (they are 2 m apart).
func _scaffold_run() -> Dictionary:
	var x := (S.SCAFFOLD_X0 + S.SCAFFOLD_X1) * 0.5
	var edges := [S.TOWER + 3.0, S.TOWER, 12.0, 8.0, 2.0, -2.0]   # z of each deck end, going north
	return {
		"name": "scaffolding: jump and climb deck to deck, ground to 12 m",
		"start": Vector3(x, 0.05, S.TOWER + 6.0), "yaw": NORTH, "max_time": 14.0,
		"drive": func(_dt):
			var p := body.global_position
			var step: int = clampi(int(round(p.y / 2.0)), 0, edges.size())
			input.yaw = NORTH
			input.move = Vector2(clampf(x - p.x, -1.0, 1.0), 1)
			if step < edges.size() and body.is_on_floor() and p.z - edges[step] < 1.2 and p.z > edges[step]:
				input.jump_pressed = true,
		"done": func(): return body.global_position.y > 11.9 and body.is_on_floor(),
		"check": func():
			var y := body.global_position.y
			_expect(y > 11.9 and body.is_on_floor(), "standing on the 12 m deck (feet at %.1f m, after %.1f s)" % [y, _time]),
	}


## Up the hoist tower's spiral of decks, from the ground to the top landing.
func _hoist_run() -> Dictionary:
	var x0: float = S.HOIST.position.x
	var z0: float = S.HOIST.position.y
	var h: float = S.HOIST.size.x * 0.5
	var centres := [Vector3(x0 + h * 0.5, 0, z0 + h * 0.5), Vector3(x0 + h * 1.5, 0, z0 + h * 0.5),
		Vector3(x0 + h * 1.5, 0, z0 + h * 1.5), Vector3(x0 + h * 0.5, 0, z0 + h * 1.5)]   # NW, NE, SE, SW
	return {
		"name": "hoist tower: jump and climb the spiral, ground to 20 m",
		"start": Vector3(x0 + h * 0.5, 0.05, z0 - 2.5), "yaw": SOUTH, "max_time": 22.0,
		"drive": func(_dt):
			var p := body.global_position
			var on: int = clampi(int(round(p.y / 2.0)), 0, 10)   # how many decks up we are
			var next: Vector3 = centres[on % 4]                    # the deck above this one
			var here: Vector3 = centres[(on + 3) % 4]              # the deck we are on (or landing on)
			var speed := Vector2(body.velocity.x, body.velocity.z).length()
			var goal := next
			if on == 0:
				# From the yard: walk up to the first deck and jump for it
				if body.is_on_floor() and _flat(p, next) < h + 0.6:
					input.jump_pressed = true
			elif on == 10:
				goal = here
			elif _mem.get("leaving", -1) == on:
				# Run at the next deck and jump once moving; the grab and climb do the rest
				if body.is_on_floor() and (_flat(p, here) > 0.3 or speed > 4.0):
					input.jump_pressed = true
			else:
				# Just arrived on this deck: walk to its middle and stop before the next jump
				goal = here
				if body.is_on_floor() and _flat(p, here) < 0.4 and speed < 1.0:
					_mem["leaving"] = on
			var to := Vector3(goal.x - p.x, 0, goal.z - p.z)
			input.yaw = _yaw_to(to)
			input.move = Vector2(0, 1) if to.length() > 0.3 else Vector2.ZERO,
		"done": func(): return body.global_position.y > S.HOIST_TOP - 0.1 and body.is_on_floor(),
		"check": func():
			var y := body.global_position.y
			_expect(y > S.HOIST_TOP - 0.1 and body.is_on_floor(), "standing on the top landing (feet at %.1f m, after %.1f s)" % [y, _time]),
	}


## From the hoist tower's top landing across the 7 m gap to the 20 m floor.
func _hoist_gap_run() -> Dictionary:
	var z: float = S.HOIST.position.y + S.HOIST.size.y * 0.75
	var edge: float = S.HOIST.end.x
	return {
		"name": "hoist tower: jump the 7 m gap to the 20 m floor (jump + flip)",
		"start": Vector3(S.HOIST.position.x + 0.5, S.HOIST_TOP + 0.05, z), "yaw": EAST, "max_time": 4.0,
		"drive": func(_dt):
			var p := body.global_position
			input.yaw = EAST
			input.move = Vector2(0, 1)
			input.sprint = true
			if body.is_on_floor() and p.x > edge - 0.5 and not _mem.has("jumped"):
				input.jump_pressed = true
				_mem["jumped"] = true
			elif _mem.has("jumped") and not _mem.has("flipped") and not body.is_on_floor() and body.velocity.y < 1.0:
				input.jump_pressed = true
				_mem["flipped"] = true,
		"done": func(): return _mem.has("jumped") and body.is_on_floor() and _time > 0.5,
		"check": func():
			var p := body.global_position
			_expect(p.x > -S.TOWER and absf(p.y - 20.0) < 0.15, "landed on the 20 m floor (x %.1f, height %.1f)" % [p.x, p.y]),
	}


## From the top of the stacked containers, jump to the tower's north wall and run
## along it to the east.
func _north_wall_run() -> Dictionary:
	return {
		"name": "north wall: jump from the containers and wall-run the tower",
		"start": Vector3(-15.6, S.CONTAINER_H * 2 + 0.05, S.NORTH_STACK_Z - 0.8), "yaw": EAST, "max_time": 5.0,
		"drive": func(_dt):
			var p := body.global_position
			input.move = Vector2(0, 1)
			input.sprint = true
			if motor.state == MovementController.State.WALL_RUN:
				input.yaw = EAST
				_mem["ran_from"] = minf(_mem.get("ran_from", p.x), p.x)
				_mem["ran_to"] = maxf(_mem.get("ran_to", p.x), p.x)
			elif not _mem.has("ran_to"):
				input.yaw = EAST - deg_to_rad(20.0)   # run across the roof at an angle, toward the wall
				if body.is_on_floor() and p.x > -11.2 and not _mem.has("jumped"):
					input.jump_pressed = true
					_mem["jumped"] = true
			,
		"done": func(): return _mem.has("ran_to") and body.is_on_floor(),
		"check": func():
			var ran: float = _mem.get("ran_to", 0.0) - _mem.get("ran_from", 0.0)
			_expect(ran > 8.0, "ran %.1f m along the wall" % ran),
	}


## Wall-run the fence along the north side of the yard.
func _fence_run() -> Dictionary:
	return {
		"name": "fence: wall-run the hoarding",
		"start": Vector3(30, 0.05, -S.HALF + 4.0), "yaw": WEST, "max_time": 4.0,
		"drive": func(_dt):
			var p := body.global_position
			input.move = Vector2(0, 1)
			input.sprint = true
			if motor.state == MovementController.State.WALL_RUN:
				input.yaw = WEST
				_mem["ran_from"] = maxf(_mem.get("ran_from", p.x), p.x)
				_mem["ran_to"] = minf(_mem.get("ran_to", p.x), p.x)
			elif not _mem.has("ran_to"):
				input.yaw = WEST - deg_to_rad(20.0)   # run at an angle, toward the fence
				if body.is_on_floor() and p.z < -S.HALF + 2.0 and not _mem.has("jumped"):
					input.jump_pressed = true
					_mem["jumped"] = true
			,
		"done": func(): return _mem.has("ran_to") and body.is_on_floor(),
		"check": func():
			var ran: float = _mem.get("ran_from", 0.0) - _mem.get("ran_to", 0.0)
			_expect(ran > 8.0, "ran %.1f m along the fence" % ran),
	}


## Sprint through the container gateway and slide under the loaded trailer.
func _trailer_slide_run() -> Dictionary:
	return {
		"name": "trailer: sprint through the container gateway and slide under the trailer",
		"start": Vector3(29.7, 0.05, 25), "yaw": NORTH, "max_time": 4.0,
		"drive": func(_dt):
			var p := body.global_position
			input.yaw = NORTH
			input.move = Vector2(0, 1)
			input.sprint = true
			var low := p.z < 15.5 and p.z > 9.0
			if low and not input.crouch:
				input.crouch_pressed = true
			input.crouch = low,
		"done": func(): return body.global_position.z < 8.0,
		"check": func():
			_expect(_did(MovementController.State.SLIDE), "slid")
			_expect(body.global_position.z < 8.0, "came out the far side (z = %.1f)" % body.global_position.z),
	}


## Slide down the conveyor from the 8 m floor.
func _conveyor_run() -> Dictionary:
	return {
		"name": "conveyor: slide down from the 8 m floor",
		"start": Vector3(-S.TOWER + 4.0, 8.05, 4), "yaw": WEST, "max_time": 5.0,
		"drive": func(_dt):
			var p := body.global_position
			input.yaw = WEST
			input.move = Vector2(0, 1)
			input.sprint = true
			var on_belt := p.x < -S.TOWER - 0.5
			if on_belt and not input.crouch:
				input.crouch_pressed = true
			input.crouch = on_belt,
		"done": func(): return body.global_position.x < -35.0,
		"check": func():
			var p := body.global_position
			_expect(_did(MovementController.State.SLIDE), "slid")
			_expect(p.x < -35.0 and p.y < 0.5, "reached the yard at the bottom (x %.1f, height %.1f)" % [p.x, p.y])
			_expect(_mem.max_speed > 14.0, "the slope sped the slide up (top %.1f m/s)" % _mem.max_speed),
	}


## Sprint at a concrete barrier and vault it.
func _barrier_run() -> Dictionary:
	return {
		"name": "barrier: vault a concrete barrier at a sprint",
		"start": Vector3(-36, 0.05, 2.5), "yaw": SOUTH, "max_time": 2.5,
		"drive": func(_dt):
			input.yaw = SOUTH
			input.move = Vector2(0, 1)
			input.sprint = true,
		"done": func(): return body.global_position.z > 12.0,
		"check": func():
			_expect(_did(MovementController.State.MANTLE), "vaulted")
			_expect(body.global_position.z > 11.0, "kept going (z = %.1f)" % body.global_position.z),
	}


## Run through one of the big pipes in the pit.
func _pipe_run() -> Dictionary:
	return {
		"name": "pipe: sprint through a pipe in the pit",
		"start": Vector3(-34, -S.PIT_DEPTH + 0.05, 33), "yaw": EAST, "max_time": 3.5,
		"drive": func(_dt):
			var p := body.global_position
			input.yaw = EAST
			input.move = Vector2(clampf(p.z - 33.0, -1.0, 1.0) * -1.0, 1)
			input.sprint = true
			if p.x > -29.0 and p.x < -23.0:
				_mem["inside"] = true,
		"done": func(): return body.global_position.x > -21.5,
		"check": func():
			var p := body.global_position
			_expect(p.x > -21.5 and absf(p.z - 33.0) < 1.0, "came out the far end (x %.1f, z %.1f, after %.1f s)" % [p.x, p.z, _time]),
	}


## Run off the 12 m floor, hook the girder over the south terrace and swing out
## over the yard.
func _swing_run() -> Dictionary:
	var hook := Vector3(0, 19.6, 15.5)   # the 20 m girder along the tower's south side
	return {
		"name": "grapple: run off the 12 m floor, hook a girder and swing out over the yard",
		"start": Vector3(0, 12.05, 3.6), "yaw": SOUTH, "max_time": 8.0,
		"drive": func(_dt):
			var p := body.global_position
			var g := motor.grapple
			input.move = Vector2(0, 1)
			input.sprint = true
			if not _mem.has("let_go"):
				if g.attached:
					input.yaw = SOUTH   # keep pushing out over the yard; looking back at the hook would brake the swing
					input.pitch = 0.0
				else:
					_look_at(hook)
				if p.z > 5.6 and body.is_on_floor() and not _mem.has("jumped"):
					input.jump_pressed = true
					_mem["jumped"] = true
				if _mem.has("jumped") and not g.attached and not body.is_on_floor() and g.ready_to_fire():
					input.grapple = true
					input.grapple_pressed = true
				elif g.attached:
					input.grapple = true
					if p.z > hook.z + 1.0 and body.velocity.y > 0.5 * body.velocity.z:
						input.grapple = false
						_mem["let_go"] = true
			else:
				input.grapple = false
				input.yaw = SOUTH
				input.pitch = 0.0,
		"done": func(): return _mem.has("let_go") and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			_expect(_did(MovementController.State.GRAPPLE), "swung on the rope")
			_expect(p.z > 26.0, "flew out over the yard and landed %.0f m from the tower (z %.1f, height %.1f)" % [p.z - S.TOWER, p.z, p.y]),
	}


# ---------------------------------------------------------------------------
# The crane

func _crane() -> CraneEvent:
	for e in root.get_tree().get_nodes_in_group(MapEvent.GROUP):
		if e is CraneEvent:
			return e
	return null


func _lever() -> MapLever:
	for t in root.get_tree().get_nodes_in_group(MapTerminal.GROUP):
		if t is MapLever:
			return t
	return null


## Puts the crane where it stands after `pulls` pulls of the lever, at rest.
func _set_crane(pulls: int) -> void:
	var crane := _crane()
	crane.stop()
	crane.state = pulls
	crane._place()


## What the crane is made of, and that its load has a clear way round.
func _crane_checks() -> void:
	print("  the crane")
	var crane := _crane()
	var lever := _lever()
	_expect(crane != null and lever != null, "the map has a CraneEvent and a MapLever")
	if crane == null or lever == null:
		return
	var jib := crane.get_node_or_null(crane.jib) as MapIsland
	var hook := crane.get_node_or_null(crane.hook) as MapIsland
	_expect(jib != null and hook != null, "the crane's Jib and Hook are MapIslands")
	_expect(lever.get_node_or_null(lever.event) == crane, "the lever's Event is the crane")
	_expect(jib != null and jib.is_ancestor_of(lever), "the lever is inside the jib, so it rides round with the cab")
	_expect(not lever.bots, "bots leave the lever alone (they cannot walk to it)")
	_expect(jib != null and hook != null and jib.over_ground and hook.over_ground, "the Jib and Hook are marked Over Ground (bots still play it as a map with a floor)")
	# The exported game: an export keeps a typed array on this node and drops a packed one
	# (v0.1.48 shipped a crane with no stops), so the scene must hold plain arrays.
	var kept := {}
	var state := (load("res://game/maps/construction_site.tscn") as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) == crane.name:
			for p in state.get_node_property_count(i):
				kept[String(state.get_node_property_name(i, p))] = typeof(state.get_node_property_value(i, p))
	_expect(kept.get("turns") == TYPE_ARRAY and kept.get("heights") == TYPE_ARRAY and kept.get("route") == TYPE_ARRAY,
		"the scene stores the crane's Turns, Heights and Route as typed arrays (an export drops packed ones)")
	_expect(crane.route.size() >= 2 and crane.turns.size() == crane.heights.size(), "it has %d stops and a route of %d moves" % [crane.turns.size(), crane.route.size()])
	if jib == null or hook == null:
		return
	# Every move of the route, sampled: the slab touches nothing, and at each stop in
	# the yard nothing stands under it that someone could be squashed on.
	var space := root.get_world_3d().direct_space_state
	var slab := BoxShape3D.new()
	slab.size = S.SLAB - Vector3(0.1, 0.1, 0.1)
	var home := hook.transform
	var pivot: Vector3 = hook.pivot
	var hits := {}
	var longest := 0.0
	for step in crane.route.size():
		var a := crane._stop(step)
		var b := crane._stop(step + 1)
		var p := crane._parts(a, b)
		var total := p.x + p.y + p.z + crane.pause * 2.0
		longest = maxf(longest, total)
		var t := 0.0
		while t <= total:
			var pose := crane.pose_between(a, b, t)
			var turn := Basis(Vector3.UP, deg_to_rad(pose.x))
			var at := Transform3D(turn * home.basis, pivot + turn * (home.origin - pivot) + Vector3(0, pose.y - S.SLAB.y * 0.5, 0))
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = slab
			q.transform = at
			for hit in space.intersect_shape(q, 8):
				if not hit.collider is AnimatableBody3D:
					hits["%s at %s" % [hit.collider.name, at.origin.snapped(Vector3.ONE * 0.1)]] = true
			t += 0.1
	if not hits.is_empty():
		print("      in the way: %s" % ", ".join(hits.keys().slice(0, 6)))
	_expect(hits.is_empty(), "the slab touches nothing on any move of its route (the longest takes %.1f s)" % longest)
	var under := BoxShape3D.new()
	var low := 0
	for stop in crane.turns.size():
		var turn := Basis(Vector3.UP, deg_to_rad(crane.turns[stop]))
		var top: float = home.origin.y + crane.heights[stop]
		var bottom := top - S.SLAB.y
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pivot + turn * (home.origin - pivot) + Vector3(0, bottom - 0.05, 0), pivot + turn * (home.origin - pivot) + Vector3(0, -6, 0)))
		if below.is_empty() or below.position.y > 6.0:
			continue   # (the stop in the tower's steel bay: nothing to stand on under it)
		var floor_y: float = below.position.y
		_expect(bottom - floor_y >= 1.95, "stop %d rests with standing room under the slab (%.2f m)" % [stop, bottom - floor_y])
		under.size = Vector3(S.SLAB.x + 0.8, bottom - floor_y - 0.3, S.SLAB.z + 0.8)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = under
		q.transform = Transform3D(turn * home.basis, pivot + turn * (home.origin - pivot) + Vector3(0, (bottom + floor_y) * 0.5 + 0.1 - home.origin.y, 0) + Vector3(0, home.origin.y, 0))
		q.transform.origin.y = (bottom + floor_y) * 0.5 + 0.1
		for hit in space.intersect_shape(q, 8):
			if not hit.collider is AnimatableBody3D:
				print("      under the slab at stop %d: %s" % [stop, hit.collider.name])
				low += 1
	_expect(low == 0, "nothing stands under the slab's stops in the yard")


## Wall-jump up the inside of the crane's mast, from its floor. `exit` is the deck
## round its head (out of the top) or the tie gangway (out of the south door).
func _mast_run(exit: float, what: String) -> Dictionary:
	var out_south := exit < S.MAST_DECK - 1.0
	return {
		"name": "crane mast: wall-jump up %s" % what,
		"start": S.MAST + Vector3(-0.55, 1.05, 0), "yaw": NORTH, "max_time": 16.0,
		"drive": func(dt):
			var p := body.global_position
			input.move = Vector2.ZERO
			input.yaw = SOUTH if out_south else NORTH
			if body.is_on_floor() and p.y < 1.5 and not _mem.has("started"):
				input.jump_pressed = true
				_mem["started"] = true
				_mem["last_jump"] = 0.0
			_mem["last_jump"] = _mem.get("last_jump", 0.0) + dt
			if p.y > exit - 2.0:
				input.move = Vector2(0, 1)   # push toward the doorway (or the top of the wall): the climb does the rest
			elif _mem.has("started") and _mem.last_jump > 0.12 and body.velocity.y < 3.0:
				input.jump_pressed = true
				_mem["last_jump"] = 0.0,
		"done": func(): return body.global_position.y > exit - 0.1 and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			var out := p.z > S.MAST.z + 1.0 if out_south else _flat(p, S.MAST) > 0.7
			_expect(absf(p.y - exit) < 0.15 and body.is_on_floor() and out,
				"standing at %.1f m, out of the mast (feet at %.1f m, %.1f m from its middle, after %.1f s)" % [exit, p.y, _flat(p, S.MAST), _time]),
	}


## From the corner of the tower's 20 m steel along the gangway to the mast's door.
func _gangway_run() -> Dictionary:
	var along := Vector3(1, 0, -1).normalized()
	var door := S.MAST + Vector3(0, S.MAST_TIE, 1.75)
	var bend := S.TIE_FROM + along * 13.4
	return {
		"name": "crane: run the tie gangway from the tower's steel to the mast's door",
		"start": S.TIE_FROM + along * 0.3 + Vector3(0, 0.05, 0), "yaw": _yaw_to(along), "max_time": 8.0,
		"drive": func(_dt):
			var p := body.global_position
			if _flat(p, bend) < 0.5:
				_mem["bent"] = true
			var to := (door if _mem.has("bent") else bend) - p
			input.yaw = _yaw_to(to)
			input.move = Vector2(0, 1),
		"done": func(): return _flat(body.global_position, door) < 0.4,
		"check": func():
			var p := body.global_position
			_expect(_flat(p, door) < 0.5 and absf(p.y - S.MAST_TIE) < 0.15 and body.is_on_floor(),
				"standing at the mast's door, 20 m up (%.1f m from it, feet at %.1f m, after %.1f s)" % [_flat(p, door), p.y, _time]),
	}


## Stand in the cab, throw the lever, and ride the jib round to its next stop.
func _cab_run() -> Dictionary:
	var stand := Vector3(0.55, 0.05, 0.65)   # from the lever, in the cab's own frame
	return {
		"name": "crane: throw the lever in the cab and ride the jib round",
		"start": Vector3(0, 0.05, 0), "max_time": 30.0,
		"drive": func(dt):
			var crane := _crane()
			var lever := _lever()
			var ticks: int = _mem.get("ticks", 0)
			_mem["ticks"] = ticks + 1
			input.move = Vector2.ZERO
			if ticks == 0:
				_set_crane(0)
			elif ticks == 5:
				_teleport(lever.global_transform * stand, NORTH)
			elif ticks == 30:
				_mem["reach"] = lever.reaches(body.global_position)
				_mem["ready"] = lever.ready_to_use()
				_mem["lever_from"] = lever.global_position
				lever.host_set_holding(1, true)
				lever.host_step(dt, func(_id: int) -> Variant: return body.global_position)
				lever.host_set_holding(1, false)
				_mem["started"] = crane.running
			elif ticks > 30:
				lever.host_step(dt, func(_id: int) -> Variant: return body.global_position)
				if crane.moving():
					_mem["locked"] = not lever.ready_to_use()
					_mem["part_%d" % crane.part_now()] = true,
		"done": func(): return _mem.get("ticks", 0) > 40 and not _crane().moving(),
		"check": func():
			var crane := _crane()
			var lever := _lever()
			var p := body.global_position
			var off := lever.global_transform.affine_inverse() * p
			var want: Vector3 = S.MAST + Basis(Vector3.UP, deg_to_rad(crane.turns[crane.stop_now()])) * (Vector3(_mem.lever_from) - S.MAST)
			_expect(_mem.get("reach", false) and _mem.get("ready", false), "standing in the cab, the lever is in reach and ready")
			_expect(_mem.get("started", false), "one press sets the crane off")
			_expect(_mem.get("locked", false), "the lever is locked while the crane moves")
			_expect(_mem.has("part_0") and _mem.has("part_1") and _mem.has("part_2"), "it hoists, then turns, then lowers")
			_expect(crane.stop_now() == crane.route[1] and lever.global_position.distance_to(want) < 0.05 and want.distance_to(_mem.lever_from) > 1.0,
				"the cab has gone round to the next stop (%.0f degrees; the lever moved %.1f m)" % [crane.turns[crane.stop_now()], lever.global_position.distance_to(_mem.lever_from)])
			_expect(off.distance_to(stand) < 0.3 and body.is_on_floor(), "and took its operator with it (%.2f m from where they stood, after %.1f s)" % [off.distance_to(stand), _time]),
	}


## Stand on the slab at the tower and ride it to a stop in the yard. `pulls` is how
## many times the lever has been pulled before.
func _slab_run(pulls: int, where: String) -> Dictionary:
	return {
		"name": "crane: ride the slab from the tower's steel to the %s yard" % where,
		"start": Vector3(0, 0.05, 0), "max_time": 30.0,
		"drive": func(_dt):
			var crane := _crane()
			var hook := crane.get_node(crane.hook) as Node3D
			var ticks: int = _mem.get("ticks", 0)
			_mem["ticks"] = ticks + 1
			input.move = Vector2.ZERO
			if ticks == 0:
				_set_crane(pulls)
			elif ticks == 5:
				_mem["from"] = hook.global_position
				_teleport(hook.global_position + Vector3(0, 0.05, 0), NORTH)
			elif ticks == 30:
				crane.host_start()
			elif ticks > 30 and crane.moving():
				_mem["top"] = maxf(_mem.get("top", 0.0), body.global_position.y),
		"done": func(): return _mem.get("ticks", 0) > 40 and not _crane().moving(),
		"check": func():
			var crane := _crane()
			var hook := crane.get_node(crane.hook) as Node3D
			var p := body.global_position
			var stop := crane.stop_now()
			var want: Vector3 = S.MAST + Basis(Vector3.UP, deg_to_rad(crane.turns[stop])) * (Vector3(_mem.from) - S.MAST)
			want.y = _mem.from.y + crane.heights[stop]
			_expect(stop != 0 and hook.global_position.distance_to(want) < 0.05, "the slab has come down in the yard at (%.1f, %.1f, %.1f)" % [want.x, want.y, want.z])
			_expect(p.distance_to(want) < 0.4 and body.is_on_floor(), "with its rider still on it (%.2f m from its middle, carried up to %.1f m on the way, %.1f s)" % [p.distance_to(want), _mem.get("top", 0.0), _time]),
	}
