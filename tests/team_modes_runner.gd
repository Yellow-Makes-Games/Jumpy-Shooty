extends Node
## Team mode checks (Search and Destroy, Capture the Flag; see Teams), started by
## tests/team_modes_test.gd:
##  - the menus' mode switch sets each one up as an arena mode with rules of its own,
##    and Vs Bots takes up to seven bots for them (4v4);
##  - every arena map gets two bases far apart, spawn points on both sides and two bomb
##    sites well apart on the defenders' side;
##  - teams: you are Red and the bots alternate, everyone wears their team's colour,
##    teammates can't hurt each other and the other team can;
##  - Search and Destroy, played out in a real Vs Bots match (bots frozen, players moved
##    by the test): an attacker carries the bomb; holding interact on a site plants it;
##    a defender holding interact at it defuses it and wins the round; the next round
##    puts everyone back; a dead carrier drops the bomb and nobody respawns in a round;
##    knocking out a whole team wins the round; the fuse running out blows it up;
##  - Capture the Flag, the same way: walking over the other team's flag takes it,
##    bringing it home scores, a dead carrier drops it, the owner walking over it sends
##    it home, and the match ends at the capture target with the right winner.

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Team mode checks")
	_modes()
	await _maps()
	await _snd()
	await _ctf()
	Cheats.freeze_bots = false
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _modes() -> void:
	print("  modes")
	var ffa := {"game": "ffa", "mode": "kills", "kills": 15, "map": Maps.default_id()}
	for m in ["snd", "ctf"]:
		var on := GunGame.with_mode(ffa, m, Maps.default_id())
		_expect(on.mode == m and on.game == "ffa" and GunGame.mode_of(on) == m, "the mode switch sets up %s on an arena (%s)" % [m, on])
		_expect(m in GunGame.MODES and m in GunGame.RULES, "%s is on the mode switch, with rules of its own" % m)
		_expect(GunGame.mode_of(GunGame.with_mode(on, "ffa", Maps.default_id())) == "ffa", "switching %s back gives a shoot-out" % m)
	_expect(Game.max_bots("snd") == 7 and Game.max_bots("ctf") == 7 and Game.max_bots("kills") == Game.MAX_BOTS, "team modes take up to 7 bots (4v4)")


func _maps() -> void:
	print("  map plans")
	for id in Maps.ids_for("ffa"):
		var map := Maps.make(id)
		get_tree().root.add_child(map)
		map.build(false)
		var plan := Teams.plan_map(map.spawns)
		var a: Vector3 = plan.bases[0]
		var b: Vector3 = plan.bases[1]
		var span := a.distance_to(b)
		_expect(span > 25.0, "%s: the bases are far apart (%.0f m)" % [id, span])
		_expect(plan.sides[0].size() >= 2 and plan.sides[1].size() >= 2, "%s: spawn points on both sides (%d / %d)" % [id, plan.sides[0].size(), plan.sides[1].size()])
		var near_a: Array = plan.sides[0].filter(func(s): return s[0].distance_to(a) < s[0].distance_to(b))
		_expect(near_a.size() == plan.sides[0].size(), "%s: side 0's spawn points are at side 0's end" % id)
		var sites: Array = plan.sites
		_expect(sites.size() == 2 and sites[0].distance_to(sites[1]) > 12.0, "%s: two bomb sites well apart (%.0f m)" % [id, sites[0].distance_to(sites[1]) if sites.size() == 2 else 0.0])
		_expect(sites.all(func(s): return s.distance_to(b) < s.distance_to(a)), "%s: the sites are on the defenders' side" % id)
		map.queue_free()
		await get_tree().process_frame


## A Vs Bots match with these rules: you plus three frozen bots (2v2), once the arena is up.
func _start(rules: String, map: String) -> void:
	Cheats.freeze_bots = true
	Game.start_bot(1, 10, map, 3, rules, "ffa")
	for i in 240:
		await get_tree().physics_frame
		if Net.arena != null and Teams.map_ready and Net.arena.players_root.get_child_count() == 4:
			break
	for i in 10:
		await get_tree().physics_frame


func _put(id: int, at: Vector3) -> void:
	var p: Player = Net.arena.get_player(id)
	p.teleport(at, 0.0)
	p.velocity = Vector3.ZERO


func _hold(id: int, on: bool) -> void:
	Teams._host_hold(id, on)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Waits (up to `seconds`) until `ok` is true.
func _until(ok: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if ok.call():
			return true
		await get_tree().process_frame
	return ok.call()


func _snd() -> void:
	print("  Search and Destroy")
	await _start("snd", "construction_site")
	_expect(Teams.is_snd() and Net.arena != null, "a Vs Bots match is Search and Destroy")
	_expect(Teams.team_of(1) == 0 and Teams.members(0).size() == 2 and Teams.members(1).size() == 2, "you are Red, and the teams are 2v2 (%s / %s)" % [Teams.members(0), Teams.members(1)])
	_expect(Net.player_color(1) == Teams.COLORS[0] and Net.player_color(Teams.members(1)[0]) == Teams.COLORS[1], "everyone wears their team's colour")
	_expect(Match.time_left == INF and Match.kill_target == 0, "it runs on rounds, not a clock or kills")
	var red: Array = Teams.members(0)
	var blue: Array = Teams.members(1)
	# Friendly fire.
	var hp: float = Match.health[red[1]]
	Match._host_damage(red[0], red[1], 40.0)
	_expect(Match.health[red[1]] == hp, "a teammate's hit does no damage")
	Match._host_damage(blue[0], red[1], 40.0)
	_expect(Match.health[red[1]] == hp - 40.0, "the other team's does")
	Match.host_heal(red[1])
	# Spawns on each side.
	var p_red: Player = Net.arena.get_player(red[0])
	var p_blue: Player = Net.arena.get_player(blue[0])
	_expect(p_red.global_position.distance_to(Teams.bases[0]) < p_red.global_position.distance_to(Teams.bases[1]), "the attackers start at their end")
	_expect(p_blue.global_position.distance_to(Teams.bases[1]) < p_blue.global_position.distance_to(Teams.bases[0]), "the defenders start at theirs")
	for team in [red, blue]:
		var a: Player = Net.arena.get_player(team[0])
		var b: Player = Net.arena.get_player(team[1])
		var apart := a.global_position.distance_to(b.global_position)
		_expect(apart > 1.0 and apart < 7.0, "a team starts together, side by side (%.1f m apart)" % apart)
	_expect(Teams.paint_for(red[0]).is_equal_approx(Teams.team_color(0).darkened(0.12)) and Teams.paint_for(blue[0]).is_equal_approx(Teams.team_color(1).darkened(0.12)),
		"robots are painted in their team's colour")
	# The bomb.
	var carrier := Teams.bomb_carrier
	_expect(carrier in red, "an attacker has the bomb (%d)" % carrier)
	if not carrier in red:
		return
	_put(carrier, Teams.sites[0])
	_hold(carrier, true)
	var planted := await _until(func(): return Teams.phase == Teams.Phase.PLANTED, Teams.PLANT_TIME + 3.0)
	_hold(carrier, false)
	_expect(planted and Teams.bomb_site == 0 and Teams.bomb_carrier == 0, "holding interact on site A plants the bomb there")
	_expect(absf(Teams.fuse_left - Teams.FUSE) < 3.0, "the fuse is running (%.1f s)" % Teams.fuse_left)
	var defuser: int = blue[0]
	_put(defuser, Teams.bomb_pos + Vector3(0.6, 0, 0))
	_hold(defuser, true)
	var defused := await _until(func(): return Teams.phase == Teams.Phase.OVER, Teams.DEFUSE_TIME + 3.0)
	_hold(defuser, false)
	_expect(defused and Teams.round_reason == "defused" and Teams.round_winner == 1 and Teams.score == [0, 1], "a defender holding interact at it defuses it: Blue wins the round (%s, %s)" % [Teams.round_reason, Teams.score])
	var next := await _until(func(): return Teams.round_number == 2 and Teams.phase == Teams.Phase.LIVE, Teams.ROUND_END_TIME + 3.0)
	_expect(next and Teams.bomb_carrier in red, "round 2 starts with the bomb on an attacker")
	# A dead carrier drops it, and nobody comes back in a round.
	carrier = Teams.bomb_carrier
	Match._host_damage(blue[0], carrier, 500.0)
	_expect(Teams.bomb_carrier == 0 and Teams.bomb_pos != Vector3.INF, "the carrier's death drops the bomb")
	_expect(not Match.respawn_timers.has(carrier), "nobody respawns during a round")
	var mate: int = red[0] if red[1] == carrier else red[1]
	_put(mate, Teams.bomb_pos)
	var picked := await _until(func(): return Teams.bomb_carrier == mate, 2.0)
	_expect(picked, "another attacker walking over it picks it up")
	# Knocking out the other team.
	Match._host_damage(blue[0], mate, 500.0)
	var over := await _until(func(): return Teams.phase == Teams.Phase.OVER, 2.0)
	_expect(over and Teams.round_reason == "eliminated" and Teams.score == [0, 2], "knocking out every attacker wins Blue the round (%s)" % [Teams.score])
	await _until(func(): return Teams.round_number == 3 and Teams.phase == Teams.Phase.LIVE, Teams.ROUND_END_TIME + 3.0)
	_expect(red.all(func(id): return Match.is_alive(id)), "the next round brings everyone back")
	# The bomb going off.
	carrier = Teams.bomb_carrier
	_put(carrier, Teams.sites[1])
	_hold(carrier, true)
	await _until(func(): return Teams.phase == Teams.Phase.PLANTED, Teams.PLANT_TIME + 3.0)
	_hold(carrier, false)
	# Out for the round: you watch someone still in it.
	Match._host_damage(blue[0], 1, 500.0)
	var watching := await _until(func(): return Net.arena.follow_cam != null and Net.arena.follow_cam.target != 0, 15.0)
	var fc: FollowCamera = Net.arena.follow_cam
	_expect(watching and fc.target != 1 and Match.is_alive(fc.target) and fc.current, "dead for the round, you spectate a living player in third person (%s)" % (fc.target_name() if fc else "none"))
	if watching:
		var first := fc.target
		fc.cycle(1)
		_expect(fc.target != first and Match.is_alive(fc.target), "Fire moves on to another player")
		await _wait(0.3)
		var tp: Player = Net.arena.get_player(fc.target)
		var d := fc.global_position.distance_to(tp.global_position)
		_expect(d > 0.5 and d < 6.0, "the camera sits behind them (%.1f m)" % d)
	Teams.fuse_left = 0.05
	var boom := await _until(func(): return Teams.phase == Teams.Phase.OVER, 2.0)
	_expect(boom and Teams.round_reason == "exploded" and Teams.score == [1, 2], "the fuse running out blows the site: Red wins the round (%s)" % [Teams.score])
	_expect(not Match.is_alive(carrier), "the blast takes out whoever is next to it")
	await _until(func(): return Teams.round_number == 4 and Match.is_alive(1), Teams.ROUND_END_TIME + 3.0)
	await _wait(0.2)
	_expect(Net.arena.follow_cam == null and Net.arena.local_player.rig.camera.current, "the next round gives you your own view back")


func _ctf() -> void:
	print("  Capture the Flag")
	await _start("ctf", "office")
	_expect(Teams.is_ctf() and not Teams.no_respawn(), "a Vs Bots match is Capture the Flag, with respawns")
	_expect(Match.time_left > 60.0 and Match.time_left < 1e8, "it has a match clock (%.0f s)" % Match.time_left)
	var red: Array = Teams.members(0)
	var blue: Array = Teams.members(1)
	var runner: int = red[1]
	for i in Teams.CAPTURES_TO_WIN:
		_put(runner, Teams.flag_home(1))
		var took := await _until(func(): return Teams.flag_carried_by(runner) == 1, 2.0)
		if i == 0:
			_expect(took, "walking over Blue's flag takes it")
			# Dropped and sent home.
			Match._host_damage(blue[0], runner, 500.0)
			var dropped := await _until(func(): return int(Teams.flags[1].state) == Teams.Flag.DROPPED, 1.0)
			_expect(dropped and Match.respawn_timers.has(runner), "the carrier's death drops it (and they respawn as usual)")
			_put(blue[1], Teams.flags[1].pos)
			var home := await _until(func(): return int(Teams.flags[1].state) == Teams.Flag.HOME, 2.0)
			_expect(home, "Blue walking over their dropped flag sends it home")
			runner = red[0] if runner == red[1] else red[1]
			_put(runner, Teams.flag_home(1))
			await _until(func(): return Teams.flag_carried_by(runner) == 1, 2.0)
		_put(runner, Teams.flag_home(0))
		var scored := await _until(func(): return Teams.score[0] == i + 1 or not Match.running, 2.0)
		if i == 0:
			_expect(scored and int(Teams.flags[1].state) == Teams.Flag.HOME, "bringing it to Red's flag scores, and Blue's flag goes home (%s)" % [Teams.score])
	var ended := await _until(func(): return not Match.running, 2.0)
	_expect(ended and Teams.score[0] == Teams.CAPTURES_TO_WIN, "the match ends at %d captures (%s)" % [Teams.CAPTURES_TO_WIN, Teams.score])
	var rows: Array = Match.last_results
	_expect(not rows.is_empty() and rows[0].get("teams", "") == "ctf" and int(rows[0].team) == 0 and rows[0].team_won,
		"the results put the winning team (Red) first")
