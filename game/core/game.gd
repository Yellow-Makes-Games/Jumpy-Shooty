extends Node
## Moves the game between screens: main menu, lobby, arena.
## Listens to the network so every player changes screen at the same moment.

const MAIN_MENU := "res://game/ui/main_menu.tscn"
const LOBBY := "res://game/ui/lobby_menu.tscn"
const ARENA := "res://game/arena/arena.tscn"

enum Mode { NONE, PRACTICE, BOT, ONLINE }

var mode: Mode = Mode.NONE
## A message to show on the main menu (for example "The host left").
var pending_notice := ""


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.match_ended.connect(_on_match_ended)
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


func goto_main_menu(notice: String = "") -> void:
	if notice != "":
		pending_notice = notice
	mode = Mode.NONE
	_release_mouse()
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)


func goto_lobby() -> void:
	_release_mouse()
	get_tree().change_scene_to_file.call_deferred(LOBBY)


func start_practice() -> void:
	mode = Mode.PRACTICE
	Net.start_offline(local_name())
	Net.in_match = true
	get_tree().change_scene_to_file.call_deferred(ARENA)


func host_online() -> Error:
	mode = Mode.ONLINE
	var port := DevArgs.port if DevArgs.port > 0 else Net.DEFAULT_PORT
	return Net.host_direct(local_name(), port)


func join_online(address: String) -> Error:
	mode = Mode.ONLINE
	return Net.join_direct(local_name(), address)


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
	goto_main_menu(reason)


func _on_match_started() -> void:
	get_tree().change_scene_to_file.call_deferred(ARENA)


func _on_match_ended() -> void:
	if mode == Mode.ONLINE:
		goto_lobby()
	else:
		goto_main_menu()


func _on_players_changed() -> void:
	if DevArgs.autostart > 0 and Net.is_host() and not Net.in_match and Net.players.size() >= DevArgs.autostart:
		print("[dev] autostart with %d players" % Net.players.size())
		Net.host_start_match()


func _run_dev_args() -> void:
	if DevArgs.practice:
		start_practice()
	elif DevArgs.host:
		var err := host_online()
		if err != OK:
			push_error("Could not host: %s" % error_string(err))
	elif DevArgs.join_address != "":
		var err := join_online(DevArgs.join_address)
		if err != OK:
			push_error("Could not join: %s" % error_string(err))


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
