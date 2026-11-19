extends Node
## The checks for tests/lobby_bots_test.gd.

var _fails: Array = []


func run() -> void:
	await get_tree().process_frame
	var saved := Game.last_bot.duplicate(true)
	Game.last_bot = {"difficulty": 0, "levels": [0, 3], "bots": 2, "kills": 7, "map": "office", "game": "ffa", "rules": "kills",
		"weapons": [], "mobility": []}
	Game.open_bot_lobby()
	var lobby: Node = null
	for i in 30:
		await get_tree().process_frame
		lobby = get_tree().current_scene
		if lobby and lobby.get("_bot_row") != null:
			break
	_expect(lobby != null and lobby.get("_bot_row") != null, "Vs Bots opens the lobby")
	if lobby == null or lobby.get("_bot_row") == null:
		_finish(saved)
		return
	_expect(not Net.is_online and Game.mode == Game.Mode.BOT, "offline, in Vs Bots")
	var bots := Net.bot_ids()
	_expect(bots.size() == 2 and int(Net.players[bots[0]].difficulty) == 0 and int(Net.players[bots[1]].difficulty) == 3,
		"set up as last time: an Easy bot and an Expert one")
	_expect(int(Net.match_settings.kills) == 7 and str(Net.match_settings.map) == "office", "with last time's rules and map")
	var rows: Dictionary = lobby.get("_rows")
	var level := (rows[bots[0]] as Node).find_child("level_button", true, false) as Button
	_expect(level != null and level.text == "EASY", "each bot shows its difficulty")
	level.pressed.emit()
	await get_tree().process_frame
	_expect(int(Net.players[bots[0]].difficulty) == 1 and str(Net.players[bots[0]].name).ends_with("(Normal)"), "a click makes it the next difficulty")
	# Adding, up to what a free-for-all takes.
	var add := lobby.get("_add_bot") as Button
	var pick := lobby.get("_bot_level") as OptionButton
	pick.select(2)
	add.pressed.emit()
	await get_tree().process_frame
	_expect(Net.bot_ids().size() == 3 and int(Net.players[Net.bot_ids()[2]].difficulty) == 2, "Add bot adds one at the difficulty picked")
	add.pressed.emit()
	await get_tree().process_frame
	_expect(Net.bot_ids().size() == Game.MAX_BOTS and add.disabled, "up to %d in a free-for-all, then no more" % Game.MAX_BOTS)
	Net.match_settings = GunGame.with_mode(Net.match_settings, "ctf", Maps.default_id("ffa"))
	Net.players_changed.emit()
	await get_tree().process_frame
	_expect(not add.disabled, "a team mode takes more")
	Net.match_settings = GunGame.with_mode(Net.match_settings, "ffa", "office")
	# Remove, and Start needs a bot.
	for id in Net.bot_ids().slice(1):
		Net.remove_bot(id)
	await get_tree().process_frame
	rows = lobby.get("_rows")
	var out := (rows[Net.bot_ids()[0]] as Node).find_child("remove", true, false) as Button
	out.pressed.emit()
	await get_tree().process_frame
	var start := lobby.get("_start") as Button
	_expect(Net.bot_ids().is_empty() and start.disabled, "Remove takes a bot out; with none, Start waits for one")
	pick.select(3)
	add.pressed.emit()
	pick.select(1)
	add.pressed.emit()
	await get_tree().process_frame
	_expect(not start.disabled, "with a bot, Start can be pressed")
	# What Start remembers (for the rematch and next time).
	Game.remember_bot_lobby()
	_expect(Game.last_bot.bots == 2 and Game.last_bot.levels == [3, 1] and Game.last_bot.map == "office" and Game.last_bot.rules == "kills",
		"Start remembers the bots and the rules (%s)" % [Game.last_bot])
	_expect(Game.bot_levels() == [3, 1], "the rematch plays the same bots")
	_finish(saved)


func _finish(saved: Dictionary) -> void:
	Net.leave()
	Game.last_bot = saved
	Game.mode = Game.Mode.NONE
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
