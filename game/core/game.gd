extends Node
## Moves the game between screens: main menu, lobby, arena.
## Listens to the network so every player changes screen at the same moment.

const MAIN_MENU := "res://game/ui/main_menu.tscn"
const LOBBY := "res://game/ui/lobby_menu.tscn"
const ARENA := "res://game/arena/arena.tscn"
const RESULTS := "res://game/ui/results_menu.tscn"

enum Mode { NONE, PRACTICE, BOT, ONLINE }

## Most bots in one offline match: you plus these fill a five-player free-for-all.
const MAX_BOTS := 4

var mode: Mode = Mode.NONE
## A message to show on the main menu (for example "The host left").
var pending_notice := ""
## The last bot match's settings, for a rematch. "bots": how many bots (1 is a 1v1).
## "game": "ffa", "dm" or "race" (one the map can host).
var last_bot := {"difficulty": 1, "kills": 10, "map": Maps.default_id(), "bots": 1, "game": "ffa"}
## The map and kind of game last picked for practice.
var last_practice_map := Maps.default_id()
var last_practice_game := "ffa"
## The map last picked for each kind of game, so the menus remember both.
var last_map := {"ffa": Maps.default_id("ffa"), "dm": Maps.default_id("dm"), "race": Maps.default_id("race")}


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Match.match_over.connect(_on_match_over)
	Net.session_ended.connect(_on_session_ended)
	Net.joined_lobby.connect(_on_joined_lobby)
	Net.join_failed.connect(_on_join_failed)
	Net.players_changed.connect(_on_players_changed)
	_run_dev_args.call_deferred()


func local_name() -> String:
	if DevArgs.player_name != "":
		return DevArgs.player_name
	if Settings.player_name != "":
		return Settings.player_name
	return "Player"


## The robot this copy of the game plays as.
func local_character() -> String:
	return DevArgs.character if DevArgs.character != "" else Settings.character


## The mobility tool this copy of the game takes into a match.
func local_mobility() -> String:
	return DevArgs.mobility if DevArgs.mobility != "" else Settings.mobility


## The gun this copy of the game takes into a match.
func local_weapon() -> String:
	return DevArgs.weapon if DevArgs.weapon != "" else Settings.weapon


func goto_main_menu(notice: String = "") -> void:
	if notice != "":
		pending_notice = notice
	mode = Mode.NONE
	_release_mouse()
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)


func goto_lobby() -> void:
	_release_mouse()
	get_tree().change_scene_to_file.call_deferred(LOBBY)


func start_practice(map: String = "", game: String = "") -> void:
	mode = Mode.PRACTICE
	if map != "":
		last_practice_map = map
		last_practice_game = _game_for(map, game)
		last_map[last_practice_game] = map
	Net.start_offline(local_name(), local_character(), local_weapon(), local_mobility())
	Net.match_settings["map"] = _map_choice(last_practice_map)
	Net.match_settings["game"] = _game_for(Net.match_settings.map, DevArgs.game if DevArgs.game != "" else last_practice_game)
	Net.match_settings["weapons"] = DevArgs.allowed_weapons.duplicate()   # practice: every weapon (unless a test says)
	Net.match_settings["mobility"] = DevArgs.allowed_mobility.duplicate()   # ...and every mobility tool
	Net.host_start_match()


## `game` if the map can host it, else the map's own kind of game.
func _game_for(map: String, game: String) -> String:
	return game if game in Maps.games_of(map) else Maps.game_of(map)


## An offline match against computer players: a 1v1 with one bot, or a
## free-for-all with up to MAX_BOTS (you plus four bots is a full five).
## gun_game: Gun Game rules instead of first to `kills_to_win` (see GunGame).
## game: "dm" for a Deathmatch ("" keeps the last one, or follows the map).
## rules: "kills", or a free-for-all mode with rules of its own ("gungame", "killcam": GunGame.RULES).
## weapons: the weapons allowed in a shoot-out (see LobbySettings; [] all of them,
## null keeps the last choice). mobility: the same for mobility tools.
## killcam: the Killcam mode's {"killcam_points", "killcam_minutes"} (see KillcamMode;
## {} keeps the last choice).
func start_bot(difficulty: int, kills_to_win: int, map: String = "", bots: int = 0, rules: String = "kills", game: String = "",
		weapons = null, mobility = null, killcam: Dictionary = {}) -> void:
	if not rules in GunGame.RULES:
		rules = "kills"
	mode = Mode.BOT
	if bots <= 0:
		bots = int(last_bot.get("bots", 1))
	bots = clampi(bots, 1, MAX_BOTS)
	var picked: String = map if map != "" else last_bot.map
	if game == "":
		game = str(last_bot.get("game", ""))
	if weapons == null:
		weapons = last_bot.get("weapons", [])
	if not DevArgs.allowed_weapons.is_empty():
		weapons = DevArgs.allowed_weapons
	if mobility == null:
		mobility = last_bot.get("mobility", [])
	if not DevArgs.allowed_mobility.is_empty():
		mobility = DevArgs.allowed_mobility
	var killcam_points := KillcamMode.clean_points(killcam.get("killcam_points", last_bot.get("killcam_points")))
	if DevArgs.points_target > 0:
		killcam_points = KillcamMode.clean_points(DevArgs.points_target)
	var killcam_minutes := KillcamMode.clean_minutes(killcam.get("killcam_minutes", last_bot.get("killcam_minutes")))
	last_bot = {"difficulty": difficulty, "kills": kills_to_win, "map": picked, "bots": bots, "game": _game_for(picked, game),
		"rules": rules, "weapons": LobbySettings.normalized_weapons(weapons), "mobility": LobbySettings.normalized_mobility(mobility),
		"killcam_points": killcam_points, "killcam_minutes": killcam_minutes}
	last_map[last_bot.game] = picked
	Net.start_offline(local_name(), local_character(), local_weapon(), local_mobility())
	var playing := _map_choice(last_bot.map)
	Net.match_settings = LobbySettings.clean({"game": _game_for(playing, DevArgs.game if DevArgs.game != "" else last_bot.game),
		"mode": rules, "kills": kills_to_win, "minutes": 8, "race_minutes": 10, "map": playing,
		"weapons": last_bot.weapons, "mobility": last_bot.mobility,
		"killcam_points": killcam_points, "killcam_minutes": killcam_minutes})
	for i in bots:
		Net.add_bot(difficulty, DevArgs.bot_weapon, DevArgs.bot_mobility)
	Net.host_start_match()


## Same bots and rules again (from the results screen).
func rematch_bot() -> void:
	start_bot(last_bot.difficulty, last_bot.kills, "", last_bot.bots, str(last_bot.get("rules", "kills")), str(last_bot.get("game", "")))


## The map to play: the one picked in the menu, unless --map=ID overrides it.
func _map_choice(picked: String) -> String:
	if DevArgs.map != "":
		return DevArgs.map
	if DevArgs.race:
		return Maps.default_id("race")
	return picked if Maps.has(picked) else Maps.default_id()


func host_online() -> Error:
	mode = Mode.ONLINE
	var port := DevArgs.port if DevArgs.port > 0 else Net.DEFAULT_PORT
	var err := Net.host_direct(local_name(), local_character(), port, local_weapon(), local_mobility())
	if err == OK and (DevArgs.map != "" or DevArgs.race):
		var with_map := Net.match_settings.duplicate()
		with_map["map"] = _map_choice("")
		with_map["game"] = _game_for(with_map.map, DevArgs.game)
		Net.set_match_settings(with_map)
	elif err == OK and DevArgs.game != "":
		var with_game := Net.match_settings.duplicate()
		with_game["game"] = DevArgs.game
		with_game["map"] = Maps.default_id(DevArgs.game)
		Net.set_match_settings(with_game)
	if err == OK and DevArgs.rules != "":
		var s := Net.match_settings.duplicate()
		var kind := DevArgs.rules.get_slice(":", 0)
		var amount := float(DevArgs.rules.get_slice(":", 1))
		s.mode = kind if kind == "time" or kind in GunGame.RULES else "kills"
		if kind == "time":
			s.minutes = amount
		elif not kind in GunGame.RULES:
			s.kills = int(amount)
		Net.set_match_settings(s)
	if err == OK and not (DevArgs.allowed_weapons.is_empty() and DevArgs.allowed_mobility.is_empty() and DevArgs.lobby_size == 0 \
			and DevArgs.points_target == 0):
		var s := Net.match_settings.duplicate()   # tests: lobby settings, in one go
		if DevArgs.lobby_size > 0:
			s["max_players"] = DevArgs.lobby_size
		if not DevArgs.allowed_weapons.is_empty():
			s["weapons"] = DevArgs.allowed_weapons.duplicate()
		if not DevArgs.allowed_mobility.is_empty():
			s["mobility"] = DevArgs.allowed_mobility.duplicate()
		if DevArgs.points_target > 0:
			s["killcam_points"] = DevArgs.points_target
		Net.set_match_settings(s)
	return err


## Joins the lobby with this code, or at this address (see LobbyCode.parse; check its
## "error" first to tell the player what is wrong: a bad code returns ERR_INVALID_DATA).
## spectate: join to watch with a free camera (see Net.set_spectating).
func join_online(code_or_address: String, spectate: bool = false) -> Error:
	var where := LobbyCode.parse(code_or_address)
	if where.error != "":
		return ERR_INVALID_DATA
	mode = Mode.ONLINE
	return Net.join_direct(local_name(), local_character(), "%s:%d" % [where.host, where.port], local_weapon(), local_mobility(),
		spectate or DevArgs.spectate)


func leave_to_menu() -> void:
	Net.leave()
	goto_main_menu()


func quit_game() -> void:
	Net.leave()
	get_tree().quit()


# ---------------------------------------------------------------------------

func _on_joined_lobby() -> void:
	if not Net.in_match:
		goto_lobby()


func _on_join_failed(reason: String) -> void:
	goto_main_menu(reason)


func _on_session_ended(reason: String) -> void:
	if DevArgs.sync_log:
		print("SESSION_ENDED %s" % reason)
	goto_main_menu(reason)


func _on_match_started() -> void:
	get_tree().change_scene_to_file.call_deferred(ARENA)


func _on_match_over(_results: Array) -> void:
	Net.in_match = false
	_release_mouse()
	get_tree().change_scene_to_file.call_deferred(RESULTS)


func _on_players_changed() -> void:
	# Dev/test: start as soon as enough players have joined. After a match the lobby
	# restarts on its own timer instead (so a change in the lobby does not cut it short).
	if DevArgs.autostart > 0 and Net.is_host() and not Net.in_match and Net.players.size() >= DevArgs.autostart \
			and Match.last_results.is_empty():
		print("[dev] autostart with %d players" % Net.players.size())
		Net.host_start_match(true)


func _run_dev_args() -> void:
	if DevArgs.bot >= 0:
		start_bot(DevArgs.bot, DevArgs.kill_target if DevArgs.kill_target > 0 else 10, "", DevArgs.bots, DevArgs.rules)
		if DevArgs.spectate:
			Net.set_spectating(true)   # watch the bots
	elif DevArgs.practice:
		start_practice()
	elif DevArgs.host:
		var err := host_online()
		if err != OK:
			push_error("Could not host: %s" % error_string(err))
		elif DevArgs.spectate:
			Net.set_spectating(true)
	elif DevArgs.join_address != "":
		var err := join_online(DevArgs.join_address)
		if err == ERR_INVALID_DATA:
			push_error("Could not join %s: %s" % [DevArgs.join_address, LobbyCode.parse(DevArgs.join_address).error])
		elif err != OK:
			push_error("Could not join: %s" % error_string(err))


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
