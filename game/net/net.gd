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
signal internet_changed                 # host only: internet_state / public_ip changed

const DEFAULT_PORT := 24680
const BOT_ID_BASE := 9001
const MAX_PLAYERS := 16
## One colour per player, all different (the first five are the originals).
const PLAYER_COLORS := [
	Color(0.95, 0.35, 0.25), Color(0.25, 0.65, 0.95), Color(0.40, 0.85, 0.35),
	Color(0.95, 0.80, 0.25), Color(0.75, 0.40, 0.95), Color(0.20, 0.90, 0.85),
	Color(1.00, 0.55, 0.75), Color(0.98, 0.58, 0.15), Color(0.60, 0.95, 0.20),
	Color(0.30, 0.35, 0.95), Color(0.92, 0.92, 0.95), Color(0.65, 0.25, 0.30),
	Color(0.55, 0.75, 0.55), Color(0.95, 0.95, 0.45), Color(0.45, 0.45, 0.50),
	Color(0.70, 0.50, 0.30),
]

## peer id -> { "name": String, "color": int, "character": String (see Characters),
##   "weapon": String (see WeaponData) },
## plus "bot": true and "difficulty" for computer players (ids from BOT_ID_BASE up), which the host simulates.
var players: Dictionary = {}
var in_match := false
var is_online := false
var port := DEFAULT_PORT  ## the port we are hosting on

## Host only: whether friends can reach us over the internet. When we host, the game
## asks the router (UPnP) to open the port and tells us our public address.
## "" (not hosting), "checking", "open" (friends join at public_ip) or "failed".
var internet_state := ""
var public_ip := ""
var _upnp: UPNP = null        # the router we opened the port on, to close it again
var _upnp_thread: Thread = null

## The game and win condition chosen by the host in the lobby.
## game: "ffa" (free-for-all, a 1v1 with two players) or "race" (see Maps and Race).
## mode: "kills" (first to `kills`) or "time" (most kills after `minutes`); free-for-all only.
## race_minutes: a race's time limit.
## map: which map to play (an id from Maps; it must be one for the game).
var match_settings := {"game": "ffa", "mode": "kills", "kills": 15, "minutes": 8, "race_minutes": 10, "map": Maps.default_id()}

## The arena currently running, if any. It registers itself here.
var arena: Node = null

var _local_name := "Player"
var _local_character := Characters.default_id()
var _local_weapon := WeaponData.default_id()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(func(): Match.player_died.connect(_on_player_died)).call_deferred()   # Match is the next autoload


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
func start_offline(player_name: String, character: String, weapon: String = "") -> void:
	leave()
	_local_name = player_name
	_local_character = Characters.valid(character)
	_local_weapon = WeaponData.valid(weapon)
	players = {1: {"name": player_name, "color": 0, "character": _local_character, "weapon": _local_weapon}}
	is_online = false
	players_changed.emit()


func host_direct(player_name: String, character: String, listen_port: int = DEFAULT_PORT, weapon: String = "") -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(listen_port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	_local_character = Characters.valid(character)
	_local_weapon = WeaponData.valid(weapon)
	players = {1: {"name": player_name, "color": 0, "character": _local_character, "weapon": _local_weapon}}
	is_online = true
	players_changed.emit()
	joined_lobby.emit()
	port = listen_port
	print("[net] hosting on port %d" % port)
	_open_router_port()
	return OK


func join_direct(player_name: String, character: String, address: String, weapon: String = "") -> Error:
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
	_local_weapon = WeaponData.valid(weapon)
	is_online = true
	print("[net] joining %s:%d" % [address, join_port])
	return OK


func leave() -> void:
	_close_router_port()
	in_match = false
	is_online = false
	players.clear()
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# ---------------------------------------------------------------------------
# Internet hosting: ask the router to forward our port (UPnP), on a thread because
# finding the router takes a second or two.

func _open_router_port() -> void:
	internet_state = "checking"
	public_ip = ""
	internet_changed.emit()
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(open_port: int) -> void:
	var upnp := UPNP.new()
	var ip := ""
	if upnp.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(open_port, open_port, "Jumpy Shooty", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			ip = upnp.query_external_address()
	_upnp_done.call_deferred(upnp, ip, open_port)


func _upnp_done(upnp: UPNP, ip: String, opened_port: int) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if internet_state != "checking" or opened_port != port:
		if ip != "":
			upnp.delete_port_mapping(opened_port, "UDP")   # we stopped hosting meanwhile
		return
	# A private address here means the internet provider shares one public address
	# between many homes (carrier-grade NAT): friends cannot reach us that way.
	if ip == "" or _is_private(ip):
		internet_state = "failed"
		if ip != "":
			upnp.delete_port_mapping(opened_port, "UDP")
		print("[net] could not open port %d on the router" % opened_port)
	else:
		_upnp = upnp
		internet_state = "open"
		public_ip = ip
		print("[net] router port %d open; public address %s" % [opened_port, ip])
	internet_changed.emit()


func _close_router_port() -> void:
	if _upnp:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null
	internet_state = ""
	public_ip = ""


func _exit_tree() -> void:
	_close_router_port()
	if _upnp_thread:
		_upnp_thread.wait_to_finish()


static func _is_private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return true
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) \
		or (a == 100 and b >= 64 and b <= 127)


# ---------------------------------------------------------------------------
# Connection events

func _on_connected_to_server() -> void:
	_tune_link(1)
	_register.rpc_id(1, _local_name, _local_character, _local_weapon)


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
## For a game of up to 16 players that bandwidth saving isn't needed, and the dropped movement
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
func _register(player_name: String, character: String, weapon: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "The lobby is full.")
		return
	players[id] = {"name": _unique_name(player_name.strip_edges().left(20)), "color": _free_color(),
		"character": Characters.valid(character), "weapon": WeaponData.valid(weapon)}
	print("[net] %d joined as %s (%s, %s)" % [id, players[id].name, players[id].character, players[id].weapon])
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
	if players.has(my_id()) and player_loadout_weapon(my_id()) != _local_weapon:
		set_my_weapon(_local_weapon)


## Pause menu "Loadout": change robot and/or weapon mid-match. It takes effect when
## you next respawn: sent now if you are dead (or racing, where nobody dies), else
## as soon as you die (see _on_player_died).
func set_loadout(character: String, weapon: String) -> void:
	_local_character = Characters.valid(character)
	_local_weapon = WeaponData.valid(weapon)
	if not in_match or not Match.is_alive(my_id()) or Race.active:
		confirm_my_character()


## The robot and weapon you will have after your next respawn.
func pending_character() -> String:
	return _local_character


func pending_weapon() -> String:
	return _local_weapon


func _on_player_died(victim: int, _killer: int) -> void:
	if victim == my_id():
		confirm_my_character()   # a loadout picked while alive applies now, for the respawn


@rpc("any_peer", "call_remote", "reliable")
func _choose_character(character: String) -> void:
	if is_host():
		_apply_character(multiplayer.get_remote_sender_id(), character)


func _apply_character(id: int, character: String) -> void:
	if not players.has(id) or players[id].get("character", "") == Characters.valid(character):
		return
	if in_match and not Race.active and (Match.is_alive(id) or not Match.running):
		return   # mid-fight you can only change robot while waiting to respawn
	players[id]["character"] = Characters.valid(character)
	print("[net] %d picked %s" % [id, players[id].character])
	if is_online:
		_sync_players.rpc(players)
	else:
		players_changed.emit()


## Pick the weapon you take into the match (an id from WeaponData). Works in the lobby,
## and during a fight while you are dead (you come back with it). A pick made while
## you are alive is ignored, and confirm_my_character() sends it again in the next lobby.
func set_my_weapon(weapon: String) -> void:
	_local_weapon = WeaponData.valid(weapon)
	if is_host():
		_apply_weapon(my_id(), _local_weapon)
	else:
		_choose_weapon.rpc_id(1, _local_weapon)


@rpc("any_peer", "call_remote", "reliable")
func _choose_weapon(weapon: String) -> void:
	if is_host():
		_apply_weapon(multiplayer.get_remote_sender_id(), weapon)


func _apply_weapon(id: int, weapon: String) -> void:
	if not players.has(id) or players[id].get("weapon", "") == WeaponData.valid(weapon):
		return
	if in_match and (Match.is_alive(id) or Race.active or not Match.running):
		return   # mid-fight you can only swap while waiting to respawn
	players[id]["weapon"] = WeaponData.valid(weapon)
	print("[net] %d took the %s" % [id, players[id].weapon])
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
	var game := Maps.valid_game(str(match_settings.get("game", "")))
	var map := str(match_settings.get("map", ""))
	if Maps.has(map) and not map.begins_with("res://") and not Maps.fits(map, game):
		map = ""   # a map for another game: race maps only race, arenas only fight
	if not Maps.has(map):
		match_settings["map"] = Maps.default_id(game)
	map = str(match_settings.map)
	match_settings["game"] = game if game in Maps.games_of(map) else Maps.game_of(map)
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
## 1v1 the bot never plays the robot you picked; colours always differ. Each bot
## takes a gun at random (or `weapon`, if given).
func add_bot(difficulty: int, weapon: String = "") -> int:
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
		"weapon": WeaponData.valid(weapon) if weapon != "" else WeaponData.IDS[randi() % WeaponData.IDS.size()],
	}
	players_changed.emit()
	return id


## Takes a computer player out (debug menu, offline only).
func remove_bot(id: int) -> void:
	if is_bot(id) and not is_online:
		players.erase(id)
		players_changed.emit()


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


## The gun a player is using (an id from WeaponData). In a Deathmatch it is the
## weapon in their hands, or "none" before they have picked one up.
func player_weapon(id: int) -> String:
	if not players.has(id):
		return WeaponData.default_id()
	if in_match and is_deathmatch():
		var held := str(players[id].get("held", "none"))
		return held if WeaponData.has(held) else "none"
	return WeaponData.valid(str(players[id].get("weapon", "")))


## The weapon a player chose in the lobby or the loadout (what they spawn with
## outside a Deathmatch).
func player_loadout_weapon(id: int) -> String:
	return WeaponData.valid(str(players[id].get("weapon", ""))) if players.has(id) else WeaponData.default_id()


## Deathmatch: the weapons a player is carrying (picked up since they last died),
## in WeaponData.IDS order.
func player_inventory(id: int) -> Array:
	return players[id].get("inventory", []) if players.has(id) else []


# ---------------------------------------------------------------------------
# Deathmatch inventory (the host decides; everyone is told through `players`)

## Deathmatch: hold one of the weapons you carry ("none": put it away). The host
## checks you have it.
func switch_my_weapon(weapon: String) -> void:
	if is_host():
		_apply_held(my_id(), weapon)
	else:
		_choose_held.rpc_id(1, weapon)


@rpc("any_peer", "call_remote", "reliable")
func _choose_held(weapon: String) -> void:
	if is_host():
		_apply_held(multiplayer.get_remote_sender_id(), weapon)


## Host: `id` holds `weapon` now, if they carry it (bots call this directly).
func _apply_held(id: int, weapon: String) -> void:
	if not players.has(id) or not is_deathmatch() or not Match.is_alive(id):
		return
	if weapon != "none" and not weapon in player_inventory(id):
		return
	if str(players[id].get("held", "none")) == weapon:
		return
	players[id]["held"] = weapon
	_players_updated()


## Host: `id` picked `weapon` up. It goes in their inventory, and in their hands if
## they had nothing in them. Returns false if they already carried it.
func host_give_weapon(id: int, weapon: String) -> bool:
	if not players.has(id) or not WeaponData.has(weapon):
		return false
	var inv: Array = player_inventory(id).duplicate()
	var fresh := not weapon in inv
	if fresh:
		inv.append(weapon)
		inv.sort_custom(func(a, b): return WeaponData.IDS.find(a) < WeaponData.IDS.find(b))
		players[id]["inventory"] = inv
	if not WeaponData.has(str(players[id].get("held", "none"))):
		players[id]["held"] = weapon
		fresh = true
	if fresh:
		_players_updated()
	return fresh


## Host: `id` died (or a Deathmatch is starting): empty hands, nothing carried.
func host_clear_inventory(id: int, tell: bool = true) -> void:
	if not players.has(id):
		return
	players[id]["inventory"] = []
	players[id]["held"] = "none"
	if tell:
		_players_updated()


## Host: everyone hears about a change to `players`.
func _players_updated() -> void:
	if is_online:
		_sync_players.rpc(players)
	else:
		players_changed.emit()


func player_color(id: int) -> Color:
	return PLAYER_COLORS[players[id].color] if players.has(id) else Color.WHITE


# ---------------------------------------------------------------------------
# Match flow

## "ffa", "dm" or "race": what kind of game is set up (one the map can host).
func game_kind() -> String:
	var game := str(match_settings.get("game", ""))
	return game if game in Maps.games_of(map_id()) else Maps.game_of(map_id())


## Deathmatch: everyone starts unarmed and picks weapons up off the map.
func is_deathmatch() -> bool:
	return game_kind() == "dm"


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
