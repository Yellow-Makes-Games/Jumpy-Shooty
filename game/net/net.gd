extends Node
## Multiplayer core: hosting, joining, the lobby player list, and the messages
## that run a match. One player hosts (peer id 1) and everyone else connects to them.
##
## The connection itself comes from a "transport". Today that is direct IP (ENet),
## used for LAN play and for running several copies on one PC. Steam slots in as a
## second transport later without changing anything else in this file.
##
## Gameplay messages are routed through this autoload (always at /root/Net) rather
## than through arena nodes, so a message that arrives while a peer is still loading
## the arena is safely ignored instead of erroring.

signal players_changed
signal joined_lobby                     # we are connected and registered
signal join_failed(reason: String)
signal session_ended(reason: String)    # host left, or we were refused
signal match_started

const DEFAULT_PORT := 24680
const BOT_ID_BASE := 9001
const MAX_PLAYERS := 5
const PLAYER_COLORS := [
	Color(0.95, 0.35, 0.25), Color(0.25, 0.65, 0.95), Color(0.40, 0.85, 0.35),
	Color(0.95, 0.80, 0.25), Color(0.75, 0.40, 0.95),
]

## peer id -> { "name": String, "color": int, "character": String (see Characters) },
## plus "bot": true and "difficulty" for computer players (ids from BOT_ID_BASE up), which the host simulates.
var players: Dictionary = {}
var in_match := false
var is_online := false
var port := DEFAULT_PORT  ## the port we are hosting on

## Win condition chosen by the host in the lobby.
## mode: "kills" (first to `kills`) or "time" (most kills after `minutes`).
## map: which map to play (an id from Maps).
var match_settings := {"mode": "kills", "kills": 15, "minutes": 8, "map": Maps.default_id()}

## The arena currently running, if any. It registers itself here.
var arena: Node = null

var _local_name := "Player"
var _local_character := Characters.default_id()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


static func now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func host_id() -> int:
	return 1


# ---------------------------------------------------------------------------
# Starting and stopping sessions

## Play alone (bot mode and practice). Uses the offline peer, so the same code
## paths run with this player as "host".
func start_offline(player_name: String, character: String) -> void:
	leave()
	_local_name = player_name
	_local_character = Characters.valid(character)
	players = {1: {"name": player_name, "color": 0, "character": _local_character}}
	is_online = false
	players_changed.emit()


func host_direct(player_name: String, character: String, listen_port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(listen_port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	_local_character = Characters.valid(character)
	players = {1: {"name": player_name, "color": 0, "character": _local_character}}
	is_online = true
	players_changed.emit()
	joined_lobby.emit()
	port = listen_port
	print("[net] hosting on port %d" % port)
	return OK


func join_direct(player_name: String, character: String, address: String) -> Error:
	leave()
	var join_port := DEFAULT_PORT
	if ":" in address:
		join_port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	if address.strip_edges() == "":
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, join_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	_local_character = Characters.valid(character)
	is_online = true
	print("[net] joining %s:%d" % [address, join_port])
	return OK


func leave() -> void:
	in_match = false
	is_online = false
	players.clear()
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# ---------------------------------------------------------------------------
# Connection events

func _on_connected_to_server() -> void:
	_tune_link(1)
	_register.rpc_id(1, _local_name, _local_character)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("Could not reach the host.")


func _on_server_disconnected() -> void:
	print("[net] host disconnected")
	leave()
	session_ended.emit("The host left, so the match ended.")


func _on_peer_connected(id: int) -> void:
	# The new peer registers itself; see _register. Here the host only tunes the link.
	if is_host():
		_tune_link(id)


## ENet normally starts dropping unreliable packets when ping wobbles ("throttling").
## For a 5-player game that bandwidth saving isn't needed, and the dropped movement
## updates make players stutter, so we switch throttling off.
func _tune_link(id: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		var link: ENetPacketPeer = peer.get_peer(id)
		if link:
			link.throttle_configure(5000, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if players.erase(id):
		print("[net] %d left" % id)
		_broadcast_players.call_deferred()


func _broadcast_players() -> void:
	if is_host() and is_online:
		_sync_players.rpc(players)


# ---------------------------------------------------------------------------
# Lobby

@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String, character: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "The lobby is full.")
		return
	players[id] = {"name": _unique_name(player_name.strip_edges().left(20)), "color": _free_color(),
		"character": Characters.valid(character)}
	print("[net] %d joined as %s (%s)" % [id, players[id].name, players[id].character])
	_sync_settings.rpc_id(id, match_settings)
	_sync_players.rpc(players)
	if in_match:
		_late_join.rpc_id(id)


@rpc("authority", "call_local", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	var was_registered := players.has(my_id())
	players = new_players
	players_changed.emit()
	if not was_registered and players.has(my_id()) and not is_host():
		joined_lobby.emit()


## Pick the robot you play as. Works in the lobby; the host tells everyone. A change
## made once the match has started is ignored (it applies from the next lobby on).
func set_my_character(character: String) -> void:
	_local_character = Characters.valid(character)
	if is_host():
		_apply_character(my_id(), _local_character)
	else:
		_choose_character.rpc_id(1, _local_character)


## Call when the lobby opens: if a pick was ignored because the match had just
## started, send it again now.
func confirm_my_character() -> void:
	if players.has(my_id()) and player_character(my_id()) != _local_character:
		set_my_character(_local_character)


@rpc("any_peer", "call_remote", "reliable")
func _choose_character(character: String) -> void:
	if is_host():
		_apply_character(multiplayer.get_remote_sender_id(), character)


func _apply_character(id: int, character: String) -> void:
	if in_match or not players.has(id) or players[id].get("character", "") == Characters.valid(character):
		return
	players[id]["character"] = Characters.valid(character)
	print("[net] %d picked %s" % [id, players[id].character])
	if is_online:
		_sync_players.rpc(players)
	else:
		players_changed.emit()


## Host only: change the win condition and tell everyone.
func set_match_settings(settings: Dictionary) -> void:
	if not is_host():
		return
	_sync_settings.rpc(settings)


@rpc("authority", "call_local", "reliable")
func _sync_settings(settings: Dictionary) -> void:
	match_settings = settings
	if not Maps.has(str(match_settings.get("map", ""))):
		match_settings["map"] = Maps.default_id()
	players_changed.emit()  # lobby screens refresh on this


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	leave()
	session_ended.emit(reason)


func _unique_name(wanted: String) -> String:
	if wanted == "":
		wanted = "Player"
	var taken := []
	for p in players.values():
		taken.append(p.name)
	var candidate := wanted
	var n := 2
	while candidate in taken:
		candidate = "%s %d" % [wanted, n]
		n += 1
	return candidate


func _free_color() -> int:
	var used := []
	for p in players.values():
		used.append(p.color)
	for i in PLAYER_COLORS.size():
		if not i in used:
			return i
	return 0


## Names for computer players, so several bots can be told apart on the scoreboard.
const BOT_NAMES := ["Gizmo", "Sprocket", "Bolt", "Piston"]   # never the name of a robot you can play


## Adds a computer player (offline matches only for now). Returns its id.
## Bots take turns through the robots, starting with the one after yours, so in a
## 1v1 the bot never plays the robot you picked; colours always differ.
func add_bot(difficulty: int) -> int:
	var id := BOT_ID_BASE
	while players.has(id):
		id += 1
	var index := id - BOT_ID_BASE
	var character := player_character(my_id())
	for i in index + 1:
		character = Characters.next(character)
	players[id] = {
		"name": "%s (%s)" % [BOT_NAMES[index % BOT_NAMES.size()], BotDifficulty.NAMES[difficulty]],
		"color": _free_color(), "bot": true, "difficulty": difficulty,
		"character": character,
	}
	players_changed.emit()
	return id


func is_bot(id: int) -> bool:
	return players.has(id) and players[id].get("bot", false)


func has_bots() -> bool:
	for id in players:
		if is_bot(id):
			return true
	return false


func player_name(id: int) -> String:
	return players[id].name if players.has(id) else "?"


## The robot a player is playing as (an id from Characters).
func player_character(id: int) -> String:
	return Characters.valid(str(players[id].get("character", ""))) if players.has(id) else Characters.default_id()


func player_color(id: int) -> Color:
	return PLAYER_COLORS[players[id].color] if players.has(id) else Color.WHITE


# ---------------------------------------------------------------------------
# Match flow

## The id of the map being played (or about to be).
func map_id() -> String:
	return str(match_settings.get("map", Maps.default_id()))


func host_start_match() -> void:
	if not is_host():
		return
	_start_match.rpc()


@rpc("authority", "call_local", "reliable")
func _start_match() -> void:
	in_match = true
	match_started.emit()


@rpc("authority", "call_remote", "reliable")
func _late_join() -> void:
	in_match = true
	match_started.emit()


# ---------------------------------------------------------------------------
# Player state. Each player sends its own movement snapshot ~30 times a second.
# The host relays it to everyone else (Godot's server relay).

## time: the sender's clock (seconds, full precision). data: see Player.make_snapshot().
func send_snapshot(time: float, data: PackedFloat32Array) -> void:
	if not is_online or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_snapshot.rpc(time, data)


@rpc("any_peer", "call_remote", "unreliable", 1)
func _snapshot(time: float, data: PackedFloat32Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if DevArgs.net_sim_enabled():
		_sim_receive(sender, time, data)
	else:
		_deliver_snapshot(sender, time, data)


func _deliver_snapshot(sender: int, time: float, data: PackedFloat32Array) -> void:
	if arena and is_instance_valid(arena):
		arena.on_snapshot(sender, time, data)


# ---------------------------------------------------------------------------
# Bad-network simulation for testing (--net-sim=LATENCY_MS,JITTER_MS,LOSS_PERCENT).
# Delays and drops incoming movement snapshots so we can check that other players
# still look smooth on a poor connection.

var _sim_queue: Array = []  # [deliver_at, sender, time, data]


func _sim_receive(sender: int, time: float, data: PackedFloat32Array) -> void:
	if randf() * 100.0 < DevArgs.net_sim_loss:
		return
	var delay := (DevArgs.net_sim_latency + randf() * DevArgs.net_sim_jitter) / 1000.0
	_sim_queue.append([now() + delay, sender, time, data])


func _process(_delta: float) -> void:
	if _sim_queue.is_empty():
		return
	var t := now()
	var keep: Array = []
	for item in _sim_queue:
		if item[0] <= t:
			_deliver_snapshot(item[1], item[2], item[3])
		else:
			keep.append(item)
	_sim_queue = keep
