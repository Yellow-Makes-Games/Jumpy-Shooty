extends SceneTree
## Low gravity checks (GravityEvent and WorldGravity):
##  - the multiplier eases from 1.0 to 0.3 in 2 s, holds for 30 s, eases back in 2 s,
##    and the event stays busy through the 60 s cooldown after;
##  - a jump reaches about 1.2 m at normal gravity and about 4 m at 0.3, with the
##    real movement code; wall runs and glides are lighter too;
##  - rockets and grenades fly exactly the same path either way: the host's copy
##    (Match) and the one everyone sees (Projectile);
##  - the event turns MapSpinners (the centrifuge) down to half speed and back;
##  - gravity zones (MapGravityZone, Empyrean Tower): 1.0 inside a zone and the map's
##    Gravity Outside (0.4) everywhere else, eased over about a second when a body
##    crosses, multiplied with a map event's, never touching projectiles, and exactly
##    1.0 again on a map without zones;
##  - gravity is back at 1.0 when the match ends mid-event, when the next match
##    starts, and when the map is unloaded.
## Run: godot --headless --path . --script tests/gravity_test.gd

const STEP := 1.0 / 60.0

var failures := 0
var body: CharacterBody3D
var motor: MovementController
var input: PlayerInput


func _initialize() -> void:
	print("Low gravity checks")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_timeline()
	_spinner()
	await _jumps()
	_light_moves()
	_projectiles()
	await _zones()
	_cleanup()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


func _event() -> GravityEvent:
	var e := GravityEvent.new()
	e.name = "LowGravity"
	root.add_child(e)
	e.set_physics_process(false)   # stepped by hand
	return e


func _step(e: GravityEvent, seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(STEP, left)
		left -= dt
		e._physics_process(dt)


func _timeline() -> void:
	print("  the event's schedule")
	var e := _event()
	_expect(is_equal_approx(e.ease_time, 2.0) and is_equal_approx(e.duration, 30.0) and is_equal_approx(e.cooldown, 60.0)
		and is_equal_approx(e.gravity_scale, 0.3), "2 s eases, 30 s at 30%, 60 s cooldown")
	_expect(is_equal_approx(e.length(), 94.0), "94 s from start until it can be fired again")
	_expect(is_equal_approx(WorldGravity.scale, 1.0) and not e.busy(), "before it starts: gravity 1.0")
	e.host_start(1)
	_expect(e.running and e.busy(), "it starts when the host says so")
	_step(e, 1.0)
	_expect(WorldGravity.scale < 0.95 and WorldGravity.scale > 0.45, "1 s in: easing down (%.2f)" % WorldGravity.scale)
	var before := WorldGravity.scale
	_step(e, STEP)
	_expect(absf(WorldGravity.scale - before) < 0.02, "it eases, it never snaps (%.3f a step)" % absf(WorldGravity.scale - before))
	_step(e, 1.0)
	_expect(is_equal_approx(WorldGravity.scale, 0.3), "2 s in: 0.3 (%.3f)" % WorldGravity.scale)
	_step(e, 15.0)
	_expect(is_equal_approx(WorldGravity.scale, 0.3) and e.active(), "17 s in: still 0.3")
	_step(e, 14.9)
	_expect(is_equal_approx(WorldGravity.scale, 0.3), "just before 32 s: still 0.3 (%.3f)" % WorldGravity.scale)
	_step(e, 1.1)
	_expect(WorldGravity.scale > 0.45 and WorldGravity.scale < 0.95, "33 s in: easing back (%.2f)" % WorldGravity.scale)
	_step(e, 1.1)
	_expect(is_equal_approx(WorldGravity.scale, 1.0), "34 s in: back to 1.0 (%.3f)" % WorldGravity.scale)
	_expect(e.busy() and not e.active(), "and the cooldown has begun: still busy")
	_step(e, 58.0)
	_expect(e.busy(), "92 s in: still cooling down")
	_step(e, 2.5)
	_expect(not e.busy() and is_equal_approx(WorldGravity.scale, 1.0), "after 94 s: ready again, gravity 1.0")
	e.host_start(1)
	_expect(e.running, "and it can be started again")
	e.free()
	_expect(is_equal_approx(WorldGravity.scale, 1.0), "(freed: gravity 1.0)")


func _spinner() -> void:
	print("  the centrifuge")
	var map := MapRoot.new()
	var ring := MapSpinner.new()
	ring.speed = 6.0
	map.add_child(ring)
	var block := MapBlock.new()
	block.position = Vector3(80, 0, 0)
	ring.add_child(block)
	var e := GravityEvent.new()
	map.add_child(e)
	root.add_child(map)
	e.set_physics_process(false)
	map.build(false)
	_expect(map.spinners.size() == 1 and map.get_node("Collision").get_child_count() == 0, "a spinner's blocks are never solid")
	ring._process(1.0)
	_expect(is_equal_approx(ring.angle, deg_to_rad(6.0)), "it turns at its speed (6 degrees in a second)")
	e.host_start()
	_step(e, 1.0)
	_expect(ring.speed_scale < 0.95 and ring.speed_scale > 0.55, "1 s into the event it is slowing (%.2f)" % ring.speed_scale)
	_step(e, 1.5)
	_expect(is_equal_approx(ring.speed_scale, 0.5), "then it turns at half speed")
	var before := ring.angle
	ring._process(1.0)
	_expect(is_equal_approx(ring.angle - before, deg_to_rad(3.0)), "(3 degrees in a second)")
	_step(e, 32.0)
	_expect(is_equal_approx(ring.speed_scale, 1.0), "and back to full speed when gravity returns")
	map.free()


func _jumps() -> void:
	print("  jump height (the real movement code)")
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1, 30, 60)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(-20.5, 15, 0)
	root.add_child(wall)
	body = CharacterBody3D.new()
	body.floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	root.add_child(body)
	var normal := await _jump_height(1.0)
	var low := await _jump_height(0.3)
	_expect(absf(normal - 1.2) < 0.15, "normal gravity: about 1.2 m (%.2f m)" % normal)
	_expect(absf(low - 4.0) < 0.3, "30%% gravity: about 4 m (%.2f m)" % low)
	WorldGravity.reset()


## Stands the body on the floor, jumps once and returns how high its feet got.
func _jump_height(scale: float, from: Vector3 = Vector3(0, 0.05, 0)) -> float:
	WorldGravity.scale = scale
	motor = MovementController.new()
	input = PlayerInput.new()
	body.global_position = from
	body.velocity = Vector3.ZERO
	var top := 0.0
	var jumped := false
	for i in 1200:
		await physics_frame
		var dt := 1.0 / Engine.physics_ticks_per_second
		if not jumped and i > 20 and body.is_on_floor():
			input.jump_pressed = true
			input.jump_held = true
			jumped = true
		motor.step(body, input, dt)   # (moves the body too)
		input.clear_edges()
		top = maxf(top, body.global_position.y)
		if jumped and i > 40 and body.is_on_floor():
			break
	return top


func _light_moves() -> void:
	print("  wall runs and glides")
	var t := MovementTuning.new()
	_expect(is_equal_approx(t.gravity, 22.0), "the tuning's own gravity is untouched (22)")
	# The same step of a glide and of a wall run, at normal and at low gravity.
	var falls := {}
	for scale in [1.0, 0.3]:
		WorldGravity.scale = scale
		var m := MovementController.new()
		m.call("_update_gravity", body, 0.0)   # (what step() does first: this body's gravity)
		m.state = MovementController.State.GLIDE
		m.set("_glide_left", 1.0)
		var floated: Vector3 = m.call("_glide", Vector3(5, 0, 0), 0.1)
		m.state = MovementController.State.WALL_RUN
		m.wall_normal = Vector3(1, 0, 0)
		var ran: Vector3 = m.call("_wall_run", Vector3(0, 0, 8), 0.1)
		falls[scale] = [floated.y, ran.y]
	WorldGravity.reset()
	_expect(is_equal_approx(falls[0.3][0], falls[1.0][0] * 0.3), "a glide sinks 30%% as fast (%.2f against %.2f m/s after 0.1 s)" % [falls[0.3][0], falls[1.0][0]])
	_expect(is_equal_approx(falls[0.3][1], falls[1.0][1] * 0.3), "a wall run drops 30%% as fast (%.2f against %.2f m/s)" % [falls[0.3][1], falls[1.0][1]])


func _projectiles() -> void:
	print("  rockets and grenades")
	for id in ["grenade_launcher", "rocket_launcher"]:
		var data := WeaponData.by_id(id)
		var paths := {}
		for scale in [1.0, 0.3]:
			WorldGravity.scale = scale
			var p := Projectile.make(1, data, Vector3(0, 40, 0), Vector3(1, 0.4, 0), Vector3.INF, Color.WHITE)
			root.add_child(p)
			p.set_physics_process(false)
			for i in 45:
				p._physics_process(STEP)
			paths[scale] = p.global_position
			p.free()
		_expect((paths[1.0] as Vector3).is_equal_approx(paths[0.3]), "a %s round flies the same path at 0.3 (%s)" % [data.id.replace("_", " "), paths[0.3]])
	# The host's own copy of a grenade (the one that decides where it lands).
	var rules := root.get_node_or_null("/root/Match")
	var net := root.get_node_or_null("/root/Net")
	if rules == null or net == null:
		return
	var stand_in := GDScript.new()   # the little of the arena that Match asks for
	stand_in.source_code = "extends Node3D\nvar dummies := []\nfunc get_player(_id: int) -> Node:\n\treturn null\n"
	stand_in.reload()
	var world := Node3D.new()
	world.set_script(stand_in)
	root.add_child(world)
	var ends := {}
	for scale in [1.0, 0.3]:
		WorldGravity.scale = scale
		net.arena = world
		rules.running = true
		rules.set("_projectiles", {1: {"pos": Vector3(0, 40, 0), "vel": Vector3(20, 8, 0), "shooter": 99, "weapon": "grenade_launcher", "t": 0.0}})
		for i in 30:
			rules._physics_process(STEP)
		var left: Dictionary = rules.get("_projectiles")
		ends[scale] = left[1].pos if left.has(1) else Vector3.INF
		rules.set("_projectiles", {})
		rules.running = false
		net.arena = null
	world.free()
	_expect(ends[1.0] != Vector3.INF and (ends[1.0] as Vector3).is_equal_approx(ends[0.3]), "the host's grenade lands the same at 0.3 (%s)" % ends[0.3])
	var drop: float = 40.0 + 8.0 * 0.5 - (ends[1.0] as Vector3).y
	_expect(drop > 1.0, "(and it does drop by its own gravity: %.1f m in half a second)" % drop)
	WorldGravity.reset()


## A map with gravity zones: a tower that tapers (a round zone, half as wide at the
## top) with normal gravity inside and 40% everywhere outside it.
func _zones() -> void:
	print("  gravity zones")
	var map := MapRoot.new()
	map.gravity_outside = 0.4
	var zone := MapGravityZone.new()
	zone.shape = MapGravityZone.Shape.ROUND
	zone.size = Vector3(20, 30, 20)
	zone.top = 0.5
	zone.position = Vector3(0, 15, 0)
	map.add_child(zone)
	root.add_child(map)
	map.build(false)
	_expect(is_equal_approx(WorldGravity.zone_at(Vector3(0, 1, 0)), 1.0), "inside the tower: 1.0")
	_expect(is_equal_approx(WorldGravity.zone_at(Vector3(9.5, 1, 0)), 1.0) and is_equal_approx(WorldGravity.zone_at(Vector3(10.5, 1, 0)), 0.4),
		"the wall line at its foot is the edge (10 m out)")
	_expect(is_equal_approx(WorldGravity.zone_at(Vector3(4.5, 29, 0)), 1.0) and is_equal_approx(WorldGravity.zone_at(Vector3(6, 29, 0)), 0.4),
		"it tapers with the tower (5 m out at the top)")
	_expect(is_equal_approx(WorldGravity.zone_at(Vector3(0, 31, 0)), 0.4) and is_equal_approx(WorldGravity.zone_at(Vector3(300, 500, -900)), 0.4),
		"above it and far off in the sky: 0.4")
	# A body standing inside, then outside (the floor from the jump test is under both).
	motor = MovementController.new()
	input = PlayerInput.new()
	body.velocity = Vector3.ZERO
	body.global_position = Vector3(0, 0.05, 0)
	for i in 30:
		await physics_frame
		motor.step(body, input, STEP)
	_expect(is_equal_approx(motor.gravity_scale, 1.0), "a player inside: 1.0 (%.3f)" % motor.gravity_scale)
	# Walks out through the wall line: the change eases over about a second.
	body.global_position = Vector3(14, 0.05, 0)
	await physics_frame
	motor.step(body, input, STEP)
	var first := motor.gravity_scale
	_expect(first > 0.97, "a step past the doorway: hardly changed (%.3f): it never snaps" % first)
	var biggest := 0.0
	var before := first
	var took := 0.0
	for i in 240:
		await physics_frame
		motor.step(body, input, STEP)
		biggest = maxf(biggest, absf(motor.gravity_scale - before))
		before = motor.gravity_scale
		if took == 0.0 and is_equal_approx(motor.gravity_scale, 0.4):
			took = (i + 2) * STEP
	_expect(is_equal_approx(motor.gravity_scale, 0.4), "a player outside: 0.4 (%.3f)" % motor.gravity_scale)
	_expect(absf(took - 1.0) < 0.1, "the blend takes about 1 s (%.2f s)" % took)
	_expect(biggest < 0.02, "and no step of it jumps (%.3f at most)" % biggest)
	# A respawn or a teleport (motor.reset()) takes the new place's gravity at once.
	motor.reset()
	body.global_position = Vector3(0, 0.05, 0)
	await physics_frame
	motor.step(body, input, STEP)
	_expect(is_equal_approx(motor.gravity_scale, 1.0), "respawned inside: 1.0 at once")
	motor.reset()
	body.global_position = Vector3(14, 0.05, 0)
	await physics_frame
	motor.step(body, input, STEP)
	_expect(is_equal_approx(motor.gravity_scale, 0.4), "respawned outside: 0.4 at once")
	# Jumps: about 1.2 m inside, about 3 m outside (1.2 / 0.4).
	var inside := await _jump_height(1.0, Vector3(0, 0.05, 0))
	var outside := await _jump_height(1.0, Vector3(14, 0.05, 0))
	_expect(absf(inside - 1.2) < 0.15, "a jump inside: about 1.2 m (%.2f m)" % inside)
	_expect(absf(outside - 3.0) < 0.3, "a jump outside: about 3 m (%.2f m)" % outside)
	# A map event multiplies with the zone (Halcyon's 0.3 here: 0.3 inside, 0.12 outside).
	var e := _event()
	e.host_start()
	_step(e, 10.0)
	motor.reset()
	body.global_position = Vector3(0, 0.05, 0)
	motor.step(body, input, STEP)
	_expect(is_equal_approx(motor.gravity_scale, 0.3), "mid-event, inside: 0.3 (%.3f)" % motor.gravity_scale)
	motor.reset()
	body.global_position = Vector3(14, 0.05, 0)
	motor.step(body, input, STEP)
	_expect(is_equal_approx(motor.gravity_scale, 0.12), "mid-event, outside: 0.3 x 0.4 = 0.12 (%.3f)" % motor.gravity_scale)
	e.free()
	# Projectiles do not read zones: the same path inside and outside.
	for id in ["grenade_launcher", "rocket_launcher"]:
		var data := WeaponData.by_id(id)
		var ends := []
		for from in [Vector3(0, 10, 0), Vector3(40, 10, 0)]:   # in the tower, out in the sky
			var p := Projectile.make(1, data, from, Vector3(0, 0.4, 1), Vector3.INF, Color.WHITE)
			root.add_child(p)
			p.set_physics_process(false)
			for i in 20:
				p._physics_process(STEP)
			ends.append(p.global_position - from)
			p.free()
		_expect((ends[0] as Vector3).is_equal_approx(ends[1]), "a %s round flies the same path inside and outside" % data.id.replace("_", " "))
	# The zones go with the map; a map without any is exactly 1.0 everywhere.
	map.free()
	_expect(WorldGravity.zones.is_empty() and is_equal_approx(WorldGravity.outside, 1.0), "the map is unloaded: no zones left behind")
	var plain := MapRoot.new()
	root.add_child(plain)
	WorldGravity.set_zones([{"inv": Transform3D.IDENTITY, "half": Vector3(5, 5, 5), "round": false, "top": 1.0, "scale": 0.4}], 0.4)   # (as if left over)
	plain.build(false)
	motor.reset()
	body.global_position = Vector3(14, 0.05, 0)
	motor.step(body, input, STEP)
	_expect(is_equal_approx(WorldGravity.zone_at(Vector3(14, 1, 0)), 1.0) and is_equal_approx(WorldGravity.zone_at(Vector3.ZERO), 1.0)
		and motor.gravity_scale == 1.0, "a map with no zones: exactly 1.0 everywhere")
	plain.free()
	WorldGravity.reset()


func _cleanup() -> void:
	print("  gravity always comes back")
	var rules := root.get_node_or_null("/root/Match")
	var net := root.get_node_or_null("/root/Net")
	var e := _event()
	e.host_start()
	_step(e, 10.0)
	_expect(is_equal_approx(WorldGravity.scale, 0.3), "mid-event: 0.3")
	# (Not by emitting the real signals: the game itself would change screens on them.)
	if rules:
		_expect(rules.match_over.is_connected(e._on_match_over), "the event listens for the end of the match")
	e._on_match_over([])
	_expect(is_equal_approx(WorldGravity.scale, 1.0) and not e.running, "the match ends mid-event: 1.0 at once, event over")
	e.host_start()
	_step(e, 10.0)
	if net:
		_expect(net.match_started.is_connected(e._on_match_started), "and for the start of the next one")
	e.stop()
	_expect(is_equal_approx(WorldGravity.scale, 1.0) and not e.running, "the next match starts: 1.0, event over")
	e.host_start()
	_step(e, 10.0)
	_expect(is_equal_approx(WorldGravity.scale, 0.3), "mid-event again: 0.3")
	e.free()
	_expect(is_equal_approx(WorldGravity.scale, 1.0), "the map is unloaded mid-event: 1.0")
	WorldGravity.scale = 0.3
	WorldGravity.reset()
	_expect(is_equal_approx(WorldGravity.scale, 1.0), "(the arena's own reset puts it at 1.0 whatever it was)")


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
