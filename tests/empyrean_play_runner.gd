extends Node
## The body of tests/empyrean_play_test.gd. A separate file because it uses the game's
## autoloads (Net, Match, Game), which only exist once the test's SceneTree is running.

const TIER := 30.5

var _ok := true
var arena: Node
var me: Player
var surge: PortalSurgeEvent
var terminal: MapTerminal


static func at(r: float, deg: float, y: float) -> Vector3:
	return Vector3(r * sin(deg_to_rad(deg)), y, r * cos(deg_to_rad(deg)))


func run() -> void:
	Game.start_practice("empyrean")
	await _frames(40)
	arena = Net.arena
	_check(arena != null and arena.layout != null and arena.layout.name == "Level", "practice starts on Empyrean Tower")
	me = arena.local_player
	surge = arena.layout.get_node("PortalSurge") as PortalSurgeEvent
	terminal = get_tree().get_nodes_in_group(MapTerminal.GROUP)[0] as MapTerminal
	_check(not arena.layout.bounds.has_area() and WorldGravity.zones.size() >= 1 and is_equal_approx(WorldGravity.outside, 0.4), "no bounds; gravity zones set, 0.4 outside")
	await _gravity()
	await _lift()
	await _surge()
	await _deaths()
	print("PASS" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _settle(pos: Vector3, yaw: float = 0.0, frames: int = 30) -> void:
	me.teleport(pos, yaw)
	await _frames(frames)


func _gravity() -> void:
	print("gravity")
	await _settle(at(12.0, 75.0, TIER + 0.1))
	_check(is_equal_approx(me.motor.gravity_scale, 1.0), "standing in the Grand Library: 1.0 (%.2f)" % me.motor.gravity_scale)
	await _settle(at(33.0, 120.0, TIER * 3 + 0.1))
	_check(is_equal_approx(me.motor.gravity_scale, 0.4), "standing on the docking ring: 0.4 (%.2f)" % me.motor.gravity_scale)
	# Out through the Library's great arch: the field does not stop you, and gravity eases.
	var wall_r := 30.5 - 10.5 * (TIER / 183.0)
	await _settle(at(wall_r - 4.0, 75.0, TIER + 0.1))
	var out := at(1.0, 75.0, 0.0).normalized()
	var seen := []
	var crossed := -1
	for i in 150:
		me.velocity = Vector3(out.x * 8.0, me.velocity.y, out.z * 8.0)
		await get_tree().physics_frame
		var r := Vector2(me.global_position.x, me.global_position.z).length()
		if crossed < 0 and r > wall_r - 0.4:
			crossed = i
		if crossed >= 0:
			seen.append(me.motor.gravity_scale)
		if r > wall_r + 4.0:
			break
	var r_end := Vector2(me.global_position.x, me.global_position.z).length()
	_check(r_end > wall_r + 2.0, "walking at the force field takes you straight through it, onto the balcony (%.1f m out)" % (r_end - wall_r))
	_check(seen.size() > 10 and seen[5] > 0.9 and seen[seen.size() - 1] < 1.0, "gravity is still near 1.0 a few steps past the field and easing down after (%.2f, then %.2f)" % [seen[5] if seen.size() > 5 else -1.0, seen[-1] if seen.size() else -1.0])
	me.velocity = Vector3.ZERO
	await _frames(150)
	_check(is_equal_approx(me.motor.gravity_scale, 0.4), "a second or so later it is 0.4 (%.2f)" % me.motor.gravity_scale)


func _lift() -> void:
	print("tractor-beam lift")
	var lifts := get_tree().get_nodes_in_group(MapLiftWell.GROUP)
	var lift := lifts[0] as MapLiftWell
	await _settle(lift.global_position + Vector3(0, 0.1, 0), 0.0, 5)
	var y0 := me.global_position.y
	var t0 := Time.get_ticks_msec()
	var speeds := []
	for i in 240:
		await get_tree().physics_frame
		if i > 40:
			speeds.append(me.velocity.y)
	var rose := me.global_position.y - y0
	_check(rose > 12.0, "standing in %s you are carried up (%.1f m in 2 s of game time)" % [lift.get_parent().name, rose])
	_check(speeds.min() > 8.5 and speeds.max() < 9.5, "at about 9 m/s (%.2f to %.2f)" % [speeds.min(), speeds.max()])
	_check(me.motor.state == MovementController.State.AIR and me.weapon != null, "riding it you are simply in the air, gun in hand")


func _hold(on: bool) -> void:
	Net.terminal_hold(terminal.index(), on, me.peer_id)


func _surge() -> void:
	print("portal surge")
	var gates := surge.gates()
	var engine_gate: MapRingGate
	var far_gate: MapRingGate
	for g in gates:
		if (g as MapRingGate).pair == 1:
			if (g as MapRingGate).global_position.y < 10.0:
				engine_gate = g
			else:
				far_gate = g
	_check(gates.size() == 8 and engine_gate != null and far_gate != null, "eight ring gates; pair 1 joins the Engine and the Observatory")
	# Dormant: walking through the ring is walking through a ring.
	var front := engine_gate.global_transform.basis.z
	await _settle(engine_gate.global_position + front * 2.0 - Vector3(0, 1.6, 0), 0.0, 20)
	for i in 110:
		me.velocity = Vector3(-front.x * 6.0, me.velocity.y, -front.z * 6.0)
		await get_tree().physics_frame
	_check(me.global_position.y < 10.0 and (me.global_position - engine_gate.global_position).dot(front) < -1.0 and not engine_gate.open,
		"a dormant gate does not teleport: you walk through the ring and out the back")
	# The altar: letting go early cancels.
	var beside := terminal.global_position + Vector3(1.3, 0.1, 0)
	await _settle(beside)
	_check(terminal.reaches(me.global_position) and terminal.ready_to_use(), "beside the altar, in range, and it is ready")
	_hold(true)
	await _wait(1.0)
	_check(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.progress > 0.3 and not surge.running, "holding interact: the channel fills (%.2f after 1 s)" % terminal.progress)
	_hold(false)
	await _wait(0.2)
	_check(terminal.phase == MapTerminal.Phase.READY and not surge.running, "letting go early cancels it")
	# Leaving the range cancels.
	_hold(true)
	await _wait(1.0)
	me.teleport(terminal.global_position + Vector3(4.5, 0.1, 0), 0.0)
	await _wait(0.2)
	_check(terminal.phase == MapTerminal.Phase.READY and not surge.running, "leaving the range (knocked away) cancels it")
	_hold(false)
	await _settle(beside, 0.0, 10)
	# Damage does not cancel; 2 s completes it.
	_hold(true)
	await _wait(1.0)
	Match._host_damage(9001, me.peer_id, 20.0)
	await _wait(0.2)
	_check(terminal.phase == MapTerminal.Phase.CHANNEL, "taking damage does not cancel it")
	_check(not surge.running, "(not yet started at 1.2 s)")
	await _wait(1.1)
	_hold(false)
	_check(surge.running and terminal.phase == MapTerminal.Phase.BUSY, "a 2 s hold starts the Portal Surge")
	_check(not surge.passable() and gates.all(func(g): return not (g as MapRingGate).open), "the gates take time to power up: nothing teleports yet")
	await _wait(2.3)
	_check(surge.passable() and gates.all(func(g): return (g as MapRingGate).open and (g as MapRingGate).power > 0.99), "2 s later all four pairs are open")
	_check(arena.portals.map_pairs().size() >= 4, "the arena's Portals node has the map's pairs (%d)" % arena.portals.map_pairs().size())
	# It cannot be used again while it runs.
	_hold(true)
	await _wait(0.5)
	_check(terminal.phase == MapTerminal.Phase.BUSY and not terminal.ready_to_use(), "the altar cannot be used while the surge runs")
	_hold(false)
	# Through the Engine's gate: out of the Observatory's, speed carried, facing out of it.
	await _settle(engine_gate.global_position + front * 2.5 - Vector3(0, 1.6, 0), atan2(front.x, front.z), 10)   # (looking into the gate)
	var went := false
	for i in 90:
		me.velocity = Vector3(-front.x * 9.0, me.velocity.y, -front.z * 9.0)
		await get_tree().physics_frame
		if me.global_position.y > 100.0:
			went = true
			break
	var out_dir := far_gate.global_transform.basis.z
	_check(went and me.global_position.distance_to(far_gate.global_position) < 4.0, "walking into the Engine's gate brings you out of the Observatory's")
	var along := Vector3(me.velocity.x, 0, me.velocity.z).dot(out_dir)
	_check(along > 7.5 and along < 10.5, "your speed is carried through, pointing out of that gate (%.1f m/s of 9)" % along)
	var facing := Basis.from_euler(Vector3(0, me.input.yaw, 0)) * Vector3.FORWARD
	_check(facing.dot(out_dir) > 0.9, "you come out facing the way the gate faces (%.2f)" % facing.dot(out_dir))
	_check(me.alive, "(and alive)")
	# ...and back the other way (two-way).
	await _frames(40)
	await _settle(far_gate.global_position + out_dir * 2.5 - Vector3(0, 1.6, 0), 0.0, 10)
	went = false
	for i in 90:
		me.velocity = Vector3(-out_dir.x * 9.0, me.velocity.y, -out_dir.z * 9.0)
		await get_tree().physics_frame
		if me.global_position.y < 20.0:
			went = true
			break
	_check(went and me.global_position.distance_to(engine_gate.global_position) < 4.0, "and back: the Observatory's gate brings you out of the Engine's")
	# A rocket through an open gate: straight on, out the back of the same gate.
	var from := engine_gate.global_position + front * 6.0
	var rocket := Projectile.make(990, WeaponData.by_id("rocket_launcher"), from, -front, Vector3.INF, Color.WHITE)
	arena.add_child(rocket)
	rocket.set_physics_process(false)
	for i in 14:
		rocket._physics_process(1.0 / 60.0)
	var flown: Vector3 = rocket.global_position - from
	_check(flown.dot(-front) > 6.5 and rocket.global_position.y < 10.0 and absf(flown.dot(front.cross(Vector3.UP))) < 0.2,
		"a rocket fired through the open gate flies straight on and out its back (%.1f m, still in the Engine)" % flown.dot(-front))
	rocket.queue_free()
	# The portal gun's portals work beside the map's, and neither touches the other.
	arena.portals.place(me.peer_id, 0, at(20.0, 60.0, 2.0), Vector3(-1, 0, 0), Vector3.UP)
	arena.portals.place(me.peer_id, 1, at(20.0, 60.0, TIER * 4 + 2.0), Vector3(-1, 0, 0), Vector3.UP)
	_check(arena.portals.get_portal(me.peer_id, 0) == null and arena.portals.get_portal(me.peer_id, 1) != null,
		"the portal gun's own rules still hold during the surge (a second portal 122 m off closes the first)")
	arena.portals.place(me.peer_id, 0, at(20.0, 60.0, 2.0), Vector3(-1, 0, 0), Vector3.UP)
	arena.portals.place(me.peer_id, 1, at(20.0, 90.0, 2.0), Vector3(-1, 0, 0), Vector3.UP)
	_check(arena.portals.get_portal(me.peer_id, 0) != null and arena.portals.get_portal(me.peer_id, 1) != null and arena.portals.map_pairs().size() >= 4,
		"a player's pair goes up while the gates are open, and the gates stay open")
	arena.portals.clear(me.peer_id)
	_check(arena.portals.map_pairs().size() >= 4 and surge.passable(), "closing the player's pair leaves the map's alone (they are exempt from the gun's rules: 150 m apart and still joined)")
	# 30 s: the host's clock, stepped by hand so the test need not wait.
	surge.set_physics_process(false)
	var left := surge.open_time + surge.duration - surge.elapsed - 0.5
	while left > 0.0:
		surge._physics_process(minf(0.1, left))
		left -= 0.1
	_check(surge.passable(), "just before 30 s: still open")
	for i in 12:
		surge._physics_process(0.1)
	_check(not surge.passable() and surge.running and arena.portals.map_pairs().is_empty() and gates.all(func(g): return not (g as MapRingGate).open),
		"after 30 s they collapse: nothing teleports any more")
	await _settle(engine_gate.global_position + front * 2.0 - Vector3(0, 1.6, 0), 0.0, 10)
	for i in 60:
		me.velocity = Vector3(-front.x * 6.0, me.velocity.y, -front.z * 6.0)
		await get_tree().physics_frame
	_check(me.global_position.y < 10.0, "(walking into the Engine's gate again goes nowhere)")
	for i in 30:
		surge._physics_process(0.1)
	_check(surge.running and surge.level == 0.0 and not terminal.ready_to_use(), "then the cooldown: the altar stays locked")
	for i in 590:
		surge._physics_process(0.1)
	surge.set_physics_process(true)
	await _wait(0.3)
	_check(not surge.running and terminal.ready_to_use(), "60 s after they closed it is ready again")


func _deaths() -> void:
	print("the core, the burn layer, flying off")
	var died := []
	Match.player_died.connect(func(victim, _killer): died.append(victim))
	# Off sideways and upward: not a death.
	await _settle(Vector3(900.0, 400.0, -700.0), 0.0, 20)
	_check(me.alive and Match.is_alive(me.peer_id), "900 m out and 400 m up: still alive (no bounds)")
	# Below the burn layer: a death.
	me.teleport(Vector3(120.0, arena.layout.kill_height - 3.0, 40.0), 0.0)
	await _frames(20)
	_check(not Match.is_alive(me.peer_id) and died.has(me.peer_id) and Match.death_cause.get(me.peer_id, "") == "fell", "below the burn layer: a death (a fall)")
	await _back()
	# The Engine's core: a death, the same kind.
	died.clear()
	await _settle(Vector3(6.5, 0.1, 0.0), 0.0, 10)
	_check(Match.is_alive(me.peer_id), "6.5 m from the core, on the Engine's floor: safe")
	me.teleport(Vector3(1.5, 1.0, 0.0), 0.0)
	await _frames(12)
	_check(not Match.is_alive(me.peer_id) and died.has(me.peer_id) and Match.death_cause.get(me.peer_id, "") == "fell", "touching the Engine's core: a death, handled like a fall")
	await _back()
	me.teleport(Vector3(2.0, 12.0, 2.0), 0.0)     # falling into it from the shaft
	await _frames(90)
	_check(not Match.is_alive(me.peer_id), "falling down the shaft onto the core: a death")


## Waits out the respawn delay and comes back.
func _back() -> void:
	for i in 600:
		await get_tree().process_frame
		if Match.is_alive(me.peer_id) and me.alive:
			break
	await _frames(5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_ok = false
