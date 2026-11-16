extends "res://tests/course_runner.gd"
## Office checks:
##  - every spawn point is clear, on a floor and inside the building;
##  - the bot's navigation mesh reaches every floor, the bridge, the offices, the
##    server room and the meeting rooms from every spawn point;
##  - a scripted player can do every route the map is built around with the current
##    movement tuning: wall-jump up the lift shaft, climb the archive shelf and the
##    filing stack to the floor above, wall-run the north wall, vault the reception
##    desk, slide under the server room shutter, and swing across the atrium on the
##    grapple.
## Run: godot --headless --path . --script tests/office_test.gd

## Where things are on the map (game/maps/office.tscn). If you move one of them in
## the editor, change its numbers here too, or the route test for it fails.
class O:
	const W := 24.0                   ## the building is 48 x 36 m (inside the outer walls)
	const D := 18.0
	const SHAFT_X := 1.5              ## the lift shaft's gap is 3 m wide (x), against the north wall
	const SHAFT_FRONT := -14.0        ## the shaft's open side (doorways on every floor)
	const SHELF := Vector3(-8.3, 3.0, 3.0)     ## top of the archive shelf by the west balcony
	const FILING := Vector3(3.5, 8.0, -7.3)    ## top of the filing stack under the north balcony
	const RECEPTION_Z := 3.4          ## the reception desk in the atrium
	const SHUTTER := Vector2(-12.5, 10.0)      ## server room shutter: x of its middle, z of the wall
	const HOOK := Vector3(0, 14.8, -4.5)       ## a skylight beam over the atrium
	const ATRIUM_X := 9.0             ## the atrium is 18 m wide (x)


func _map_id() -> String:
	return "office"


func _title() -> String:
	return "Office checks"


func _courses() -> Array:
	return [
		_shaft_run(5.0, "and step out at the 5 m floor"),
		_shaft_run(10.0, "and step out at the 10 m floor"),
		_climb_run("archive shelf: from the lobby up to the 5 m floor", O.SHELF, WEST, 5.0),
		_climb_run("filing stack: from the 5 m floor up to 10 m", O.FILING, NORTH, 10.0),
		_north_wall_run(),
		_reception_run(),
		_shutter_run(),
		_swing_run(),
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
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0)))
		if not space.intersect_shape(q, 1).is_empty() or below.is_empty() or not map.bounds.has_point(Vector2(pos.x, pos.z)):
			print("      blocked or off the floor: %s" % pos)
			bad += 1
	_expect(map.spawns.size() >= 8, "%d spawn points (the arena needs at least 8)" % map.spawns.size())
	_expect(bad == 0, "every spawn point is clear, on a floor and inside the building")

	print("  bot navigation")
	var region := MapScenery.bake_navigation(level)
	root.add_child(region)
	var nav_map := root.get_world_3d().navigation_map
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 10, 0)).y > 9.0:
			break
	var goals := {
		"atrium": Vector3(0, 0, -3), "café": Vector3(-15, 0, -11.2),
		"5 m open-plan desks": Vector3(-16.5, 5, -12.4), "5 m kitchen": Vector3(0, 5, 15.5),
		"5 m west meeting room": Vector3(-18, 5, 12.3), "5 m north balcony": Vector3(-5, 5, -7),
		"10 m corridor": Vector3(0, 10, -10), "bridge over the atrium": Vector3(0, 10, 0),
		"west corner office": Vector3(-11.5, 10, -14), "server room": Vector3(-12.5, 10, 14.5),
		"boardroom": Vector3(8, 10, 14),
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


# ---------------------------------------------------------------------------
# Routes

## Wall-jump up the lift shaft from the lobby and step out of a floor's doorway.
func _shaft_run(exit: float, what: String) -> Dictionary:
	var mid_z := O.SHAFT_FRONT - 2.0
	return {
		"name": "lift shaft: wall-jump up %s" % what,
		"start": Vector3(-O.SHAFT_X + 0.45, 0.05, mid_z), "yaw": SOUTH, "max_time": 12.0,
		"drive": func(dt):
			var p := body.global_position
			input.move = Vector2.ZERO
			input.yaw = SOUTH
			if body.is_on_floor() and p.y < 0.5 and not _mem.has("started"):
				input.jump_pressed = true
				_mem["started"] = true
				_mem["last_jump"] = 0.0
			_mem["last_jump"] = _mem.get("last_jump", 0.0) + dt
			if p.y > exit - 1.5:
				input.move = Vector2(0, 1)   # push out through the doorway
			elif _mem.has("started") and _mem.last_jump > 0.12 and body.velocity.y < 3.0:
				input.jump_pressed = true
				_mem["last_jump"] = 0.0,
		"done": func(): return body.global_position.y > exit - 0.1 and body.is_on_floor() and body.global_position.z > O.SHAFT_FRONT + 0.5,
		"check": func():
			var p := body.global_position
			_expect(absf(p.y - exit) < 0.15 and body.is_on_floor() and p.z > O.SHAFT_FRONT,
				"standing on the %.0f m floor, out of the shaft (feet at %.1f m, after %.1f s)" % [exit, p.y, _time]),
	}


## Stand on something tall by a balcony edge, jump and climb to the floor above.
func _climb_run(what: String, top_of: Vector3, yaw: float, floor_y: float) -> Dictionary:
	return {
		"name": what,
		"start": top_of + Vector3(0, 0.05, 0), "yaw": yaw, "max_time": 3.0,
		"drive": func(_dt):
			input.yaw = yaw
			input.move = Vector2(0, 1) if body.global_position.y < floor_y - 0.2 else Vector2.ZERO
			if body.is_on_floor() and not _mem.has("jumped") and _time > 0.1:
				input.jump_pressed = true
				_mem["jumped"] = true,
		"done": func(): return false,
		"check": func():
			var y := body.global_position.y
			_expect(absf(y - floor_y) < 0.15 and body.is_on_floor(), "standing on the floor above (feet at %.1f m)" % y),
	}


## Wall-run the north wall of the lobby, past the café.
func _north_wall_run() -> Dictionary:
	return {
		"name": "north wall: wall-run along the lobby windows",
		"start": Vector3(-22, 0.05, -15.0), "yaw": EAST, "max_time": 4.0,
		"drive": func(_dt):
			var p := body.global_position
			input.move = Vector2(0, 1)
			input.sprint = true
			if motor.state == MovementController.State.WALL_RUN:
				input.yaw = EAST
				_mem["ran_from"] = minf(_mem.get("ran_from", p.x), p.x)
				_mem["ran_to"] = maxf(_mem.get("ran_to", p.x), p.x)
			elif not _mem.has("ran_to"):
				input.yaw = EAST + deg_to_rad(20.0)   # run at an angle, toward the wall
				if body.is_on_floor() and p.z < -O.D + 2.0 and not _mem.has("jumped"):
					input.jump_pressed = true
					_mem["jumped"] = true
			,
		"done": func(): return _mem.has("ran_to") and body.is_on_floor(),
		"check": func():
			var ran: float = _mem.get("ran_to", 0.0) - _mem.get("ran_from", 0.0)
			_expect(ran > 8.0, "ran %.1f m along the wall" % ran),
	}


## Sprint through the security gates and vault the reception desk.
func _reception_run() -> Dictionary:
	return {
		"name": "reception: sprint through the gates and vault the desk",
		"start": Vector3(1, 0.05, 15), "yaw": NORTH, "max_time": 3.0,
		"drive": func(_dt):
			input.yaw = NORTH
			input.move = Vector2(0, 1)
			input.sprint = true,
		"done": func(): return body.global_position.z < 0.0,
		"check": func():
			_expect(_did(MovementController.State.MANTLE), "vaulted")
			_expect(body.global_position.z < 0.5, "kept going into the atrium (z = %.1f)" % body.global_position.z),
	}


## Sprint at the server room's half-closed shutter and slide under it.
func _shutter_run() -> Dictionary:
	return {
		"name": "server room: slide under the shutter",
		"start": Vector3(O.SHUTTER.x, 10.05, 3), "yaw": SOUTH, "max_time": 3.0,
		"drive": func(_dt):
			var p := body.global_position
			input.yaw = SOUTH
			input.move = Vector2(0, 1)
			input.sprint = true
			var low := p.z > O.SHUTTER.y - 3.0 and p.z < O.SHUTTER.y + 1.5
			if low and not input.crouch:
				input.crouch_pressed = true
			input.crouch = low,
		"done": func(): return body.global_position.z > O.SHUTTER.y + 2.0,
		"check": func():
			_expect(_did(MovementController.State.SLIDE), "slid")
			_expect(body.global_position.z > O.SHUTTER.y + 2.0, "came out inside the server room (z = %.1f)" % body.global_position.z),
	}


## Run off the 10 m east balcony, hook a skylight beam and swing across the atrium.
func _swing_run() -> Dictionary:
	return {
		"name": "grapple: swing across the atrium from the 10 m balcony",
		"start": Vector3(14, 10.05, O.HOOK.z), "yaw": WEST, "max_time": 6.0,
		"drive": func(_dt):
			var p := body.global_position
			var g := motor.grapple
			input.move = Vector2(0, 1)
			input.sprint = true
			if not _mem.has("let_go"):
				if g.attached:
					input.yaw = WEST
					input.pitch = 0.0
				else:
					_look_at(O.HOOK)
				if p.x < O.ATRIUM_X + 0.6 and body.is_on_floor() and not _mem.has("jumped"):
					input.jump_pressed = true
					_mem["jumped"] = true
				if _mem.has("jumped") and not g.attached and not body.is_on_floor() and g.ready_to_fire():
					input.grapple = true
					input.grapple_pressed = true
				elif g.attached:
					input.grapple = true
					if p.x < O.HOOK.x - 2.0 and body.velocity.y > 0.0:
						input.grapple = false
						_mem["let_go"] = true
			else:
				input.grapple = false
				input.yaw = WEST
				input.pitch = 0.0,
		"done": func(): return _mem.has("let_go") and body.is_on_floor(),
		"check": func():
			var p := body.global_position
			_expect(_did(MovementController.State.GRAPPLE), "swung on the rope")
			_expect(p.x < -O.ATRIUM_X and p.y > 4.9, "landed across the atrium on the west side (x %.1f, height %.1f)" % [p.x, p.y]),
	}
