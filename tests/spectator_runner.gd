extends Node
## Spectator checks (started by tests/spectator_test.gd).

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Spectator checks")
	Game.start_bot(1, 10, "construction_site", 2)
	var arena: Node = await _arena()
	_expect(arena != null, "the arena loads")
	if arena == null:
		return _finish()
	await _frames(10)
	var me := Net.my_id()
	_expect(arena.get_player(me) != null and arena.local_player != null, "you start as a player")

	print("  spectating")
	Net.set_spectating(true)
	await _frames(3)
	_expect(Net.spectating() and not Net.players.has(me), "you are a spectator, not a player")
	_expect(Net.players.size() == 2 and Net.has_bots(), "the two bots still play (%d players)" % Net.players.size())
	_expect(arena.get_player(me) == null or arena.get_player(me).is_queued_for_deletion(), "your robot is gone: nobody can see or hit you")
	_expect(arena.local_player == null, "no local player while spectating")
	_expect(not Match.scores.has(me) and not Match.health.has(me), "a spectator has no score or health")
	_expect(not Match.build_results().any(func(r): return r.id == me), "a spectator is not on the scoreboard")
	var cam: SpectatorCamera = arena.spectator_cam
	_expect(cam != null and cam.is_current(), "the spectator camera is the one in use")
	_expect(arena.hud.spectating, "the HUD shows the spectator view")
	Net.set_spectating(true)
	_expect(Net.spectators.size() == 1, "spectating twice changes nothing")
	_expect(not Net.host_set_spectating(Net.BOT_ID_BASE, true), "a bot cannot be made to spectate")

	print("  noclip camera")
	if cam:
		# Straight down through the floor: nothing stops it.
		cam.place(Vector3(0, 5, 0), 0.0, 0.0)
		cam.scripted = {"up": -1.0}
		await _seconds(1.0)
		_expect(cam.global_position.y < 0.0, "it flies down through the ground (y %.1f)" % cam.global_position.y)
		var y := cam.global_position.y
		cam.scripted = {"up": -1.0, "fast": true}
		await _seconds(1.0)
		_expect(y - cam.global_position.y > SpectatorCamera.SPEED * 1.5, "Sprint flies faster (%.1f m in 1 s)" % (y - cam.global_position.y))
		cam.place(Vector3(0, 10, 0), deg_to_rad(90.0), 0.0)
		cam.scripted = {"forward": 1.0}
		await _seconds(1.0)
		_expect(cam.global_position.x < -5.0 and absf(cam.global_position.z) < 0.5, "forward is where it looks (%s)" % cam.global_position)
		cam.scripted = {}

	print("  watching a player")
	arena.spectator_follow(1)
	await _seconds(0.4)
	var fc: FollowCamera = arena.follow_cam
	_expect(fc != null and fc.is_current() and Net.players.has(fc.target), "Fire locks onto a player and watches them (%s)" % (fc.target_name() if fc else "none"))
	if fc:
		var first := fc.target
		var d := fc.global_position.distance_to(arena.get_player(fc.target).global_position)
		_expect(d > 0.5 and d < 6.0, "in third person, from behind them (%.1f m)" % d)
		fc.cycle(1)
		_expect(fc.target != first, "Fire again moves on to the other player")
		_expect(arena.hud.follow_name == Net.player_name(first) or arena.hud.follow_name != "", "the HUD names who you watch")
		arena.spectator_free()
		await _frames(2)
		_expect(arena.follow_cam == null and cam.is_current(), "Interact flies free again")
	arena.spectator_follow(1)
	await _frames(2)

	print("  back in")
	Net.set_spectating(false)
	await _frames(5)
	_expect(not Net.spectating() and Net.players.has(me) and Net.players.size() == 3, "you play again")
	_expect(arena.spectator_cam == null and arena.follow_cam == null and not arena.hud.spectating, "the spectator camera is gone")
	_expect(arena.local_player != null and arena.get_player(me) != null, "your robot is back")
	_expect(Match.scores.has(me) and Match.is_alive(me), "you are scored and alive")
	_finish()


func _finish() -> void:
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _arena() -> Node:
	for i in 600:
		await get_tree().process_frame
		if Net.arena and Net.arena.is_node_ready():
			return Net.arena
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
