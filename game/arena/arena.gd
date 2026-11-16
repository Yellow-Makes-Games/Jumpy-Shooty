extends Node3D
## The arena scene: builds the level, spawns one Player per connected peer,
## and hosts the HUD and pause menu.

var layout: MapRoot
var players_root: Node3D
var local_player: Player
var hud: Hud
var pause_menu: PauseMenu


func _ready() -> void:
	layout = Maps.make(Net.map_id())
	layout.name = "Level"
	add_child(layout)
	layout.build()
	if Net.has_bots():
		add_child(MapScenery.bake_navigation(layout))   # only when bots play: it takes a moment
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	hud = Hud.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.visibility_changed.connect(_on_pause_toggled)
	Net.arena = self
	Net.players_changed.connect(_sync_players)
	Match.player_died.connect(_on_player_died)
	Match.player_respawned.connect(_on_player_respawned)
	Match.shot_fired.connect(_on_shot_fired)
	_sync_players()
	_capture_mouse(true)


func _exit_tree() -> void:
	if Net.arena == self:
		Net.arena = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not pause_menu.visible:
		_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	# Falling out of the map, or getting outside its fence, counts as a death.
	var floor_y := layout.kill_height
	var area := layout.bounds
	for p in players_root.get_children():
		if not (p as Player).is_local:
			continue
		var pos: Vector3 = p.global_position
		if pos.y < floor_y or (area.has_area() and not area.has_point(Vector2(pos.x, pos.z))):
			(p as Player).report_fell_once()


func _process(_delta: float) -> void:
	if local_player:
		hud.update_local(local_player)


func get_player(id: int) -> Player:
	return players_root.get_node_or_null("Player_%d" % id) as Player


## Called by Net for every movement snapshot from another player.
func on_snapshot(sender: int, remote_time: float, data: PackedFloat32Array) -> void:
	var p := get_player(sender)
	if p and not p.is_local:
		p.apply_snapshot(remote_time, data)


func _on_player_died(victim: int, _killer: int) -> void:
	var p := get_player(victim)
	if p:
		p.set_dead()


func _on_player_respawned(id: int, _spawn_index: int) -> void:
	var p := get_player(id)
	if p == null:
		return
	if p.is_local:
		var s: Array = _safest_spawn(p)
		p.respawn_at(s[0], s[1])
	else:
		p.expect_respawn()


func _on_shot_fired(shooter: int, muzzle: Vector3, ends: PackedVector3Array, hits: Array) -> void:
	var p := get_player(shooter)
	if shooter == Net.my_id() or (p and p.is_local):
		return  # we (or our bot) already drew this shot the moment it was fired
	if p:
		p.show_shot()
	ShotFx.spawn(self, p.muzzle_position() if p else muzzle, ends, hits, Net.player_weapon(shooter))


## The spawn point furthest from every living opponent of `who`.
func _safest_spawn(who: Player) -> Array:
	var best: Array = layout.spawns[0]
	var best_score := -1.0
	for s in layout.spawns:
		var nearest := INF
		for p in players_root.get_children():
			if p != who and (p as Player).alive:
				nearest = min(nearest, (s[0] as Vector3).distance_to(p.global_position))
		if nearest > best_score:
			best_score = nearest
			best = s
	return best


func _sync_players() -> void:
	for id in Net.players:
		if not players_root.has_node("Player_%d" % id):
			_spawn(id)
	for p in players_root.get_children():
		if not Net.players.has((p as Player).peer_id):
			p.queue_free()
		elif not Match.is_alive((p as Player).peer_id) and (p as Player).alive:
			(p as Player).set_dead()  # joined while they were dead
	hud.set_players(Net.players)


func _spawn(id: int) -> void:
	var p := Player.new()
	var bot := Net.is_bot(id) and Net.is_host()   # the host runs the bots
	var local := id == Net.my_id() or bot
	p.setup(id, local, bot)
	players_root.add_child(p)
	if local:
		if not bot:
			local_player = p
		_respawn(p)


func _respawn(p: Player) -> void:
	var ids := Net.players.keys()
	ids.sort()
	var index: int = max(ids.find(p.peer_id), 0)
	var s: Array = layout.spawns[(index + randi() % 2 * (layout.spawns.size() / 2)) % layout.spawns.size()]
	if not DevArgs.spawn.is_empty() and not p.is_bot:
		s = DevArgs.spawn
	p.teleport(s[0], s[1])
	if s.size() > 2:
		p.input.pitch = s[2]


func _on_pause_toggled() -> void:
	_capture_mouse(not pause_menu.visible)


func _capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
