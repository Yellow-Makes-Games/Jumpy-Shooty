extends Node3D
## The arena scene: builds the level, spawns one Player per connected peer,
## and hosts the HUD, the pause menu and (offline) the debug menu.

var layout: MapRoot
var players_root: Node3D
var local_player: Player
var hud: Hud
var pause_menu: PauseMenu
var debug_menu: DebugMenu
## The map's target dummies (TargetDummy), in the order of their index.
var dummies: Array = []
## Race maps: the drawn checkpoint gates, in the order racers pass them.
var gates: Array = []
## Deathmatch: the map's floating weapons (WeaponPickup), in the order of their index.
var pickups: Array = []
## Deathmatch: the map's power-ups (ItemPickup), in the order of their index.
var items: Array = []
## Everyone's portals (portal gun: see Portals).
var portals: Portals
## Seconds until the bots' navigation mesh is redone after walls or floors broke.
var _nav_rebake := 0.0
var _nav_baking := false
const NAV_REBAKE_DELAY := 0.6


func _ready() -> void:
	WorldGravity.reset()   # whatever the last match's map event left behind
	layout = Maps.make(Net.map_id())
	layout.name = "Level"
	add_child(layout)
	layout.destructible = not Race.active and Maps.game_of(Net.map_id()) != "race"
	layout.build()
	if layout.destruction:
		layout.destruction.cells_changed.connect(_on_cells_changed)
	if Race.active:
		layout.clock_source = func(): return Race.time + Race.COUNTDOWN   # moving parts in step on every copy
		_build_gates()
	elif Net.has_bots():
		ensure_navigation()   # only when bots play: it takes a moment (racing bots follow the map's route instead)
	_spawn_dummies()
	if Net.is_deathmatch():
		_spawn_pickups()
		if Net.powerups_on():
			_spawn_items()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	portals = Portals.new()
	portals.name = "Portals"
	add_child(portals)
	hud = Hud.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.visibility_changed.connect(_on_pause_toggled)
	debug_menu = DebugMenu.new()
	add_child(debug_menu)
	debug_menu.toggled.connect(_on_pause_toggled)
	Net.arena = self
	Net.players_changed.connect(_sync_players)
	Match.player_died.connect(_on_player_died)
	Match.player_respawned.connect(_on_player_respawned)
	Match.shot_fired.connect(_on_shot_fired)
	Match.projectile_fired.connect(_on_projectile_fired)
	Match.exploded.connect(_on_exploded)
	Match.pickup_changed.connect(_on_pickup_changed)
	Match.item_changed.connect(_on_item_changed)
	_sync_players()
	_capture_mouse(true)
	if layout.destruction:
		Match.request_breaks()   # joining a match in progress: what is broken already
	Net.request_map_state()      # ...and where the map's terminals and events are


func _exit_tree() -> void:
	if Net.arena == self:
		Net.arena = null
	Match.pickups_taken.clear()
	WorldGravity.reset()      # a map event never outlives the map
	Match.items_taken.clear()
	Engine.time_scale = 1.0   # the debug menu's slow motion ends with the match
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _menu_open():
		_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	# Falling out of the map, or getting outside its fence, counts as a death.
	var floor_y := layout.kill_height
	var area := layout.bounds
	for p in players_root.get_children():
		if not (p as Player).is_local or (p == local_player and Cheats.flying()):
			continue
		var pos: Vector3 = p.global_position
		if pos.y < floor_y or (area.has_area() and not area.has_point(Vector2(pos.x, pos.z))):
			(p as Player).report_fell_once()


func _process(delta: float) -> void:
	if _nav_rebake > 0.0:
		_nav_rebake -= delta
		if _nav_rebake <= 0.0:
			_rebake_navigation()
	if local_player:
		hud.update_local(local_player)
		if Race.active:
			var passed := Race.gates_passed(local_player.peer_id)
			for i in gates.size():
				RaceGate.set_state(gates[i], i == passed, i < passed)


func _build_gates() -> void:
	var root := Node3D.new()
	root.name = "Gates"
	add_child(root)
	for c in layout.checkpoints:
		var g := RaceGate.make(c.opening, c.finish, c.number)
		g.transform = c.xf
		root.add_child(g)
		gates.append(g)


func get_player(id: int) -> Player:
	return players_root.get_node_or_null("Player_%d" % id) as Player


## Called by Net for every movement snapshot from another player.
func on_snapshot(sender: int, remote_time: float, data: PackedFloat32Array) -> void:
	var p := get_player(sender)
	if p and not p.is_local:
		p.apply_snapshot(remote_time, data)


func _on_player_died(victim: int, _killer: int) -> void:
	portals.clear(victim)   # your portals go when you die
	var p := get_player(victim)
	if p:
		p.set_dead()
		if DevArgs.swap_on_death and p == local_player and not p.racing:
			p.dev_swap_after_death()


func _on_player_respawned(id: int, _spawn_index: int) -> void:
	var p := get_player(id)
	if p == null:
		return
	if p.is_local:
		var s: Array = _safest_spawn(p)
		p.respawn_at(s[0], s[1])
	else:
		p.expect_respawn()


## A rocket or grenade is on its way: draw it (and, for someone else's, their gun firing).
func _on_projectile_fired(id: int, shooter: int, weapon_id: String, origin: Vector3, direction: Vector3) -> void:
	var p := get_player(shooter)
	var muzzle := Vector3.INF
	var color := Color(1.0, 0.6, 0.3)
	if p:
		muzzle = p.muzzle_position()
		color = RobotModel.trim_color(Net.player_color(shooter))
		if shooter != Net.my_id() and not p.is_local:
			p.show_shot()
	add_child(Projectile.make(id, WeaponData.by_id(weapon_id), origin, direction, muzzle, color))


func _on_exploded(id: int, at: Vector3, weapon_id: String) -> void:
	var node := get_node_or_null("Projectile_%d" % id)
	if node:
		node.queue_free()
	var w := WeaponData.by_id(weapon_id)
	ShotFx.explosion(self, at, w.splash_radius)
	Sound.play_at("explosion", at, "fire", 0.0, 0.05)
	var d := at.distance_to(Sound.listener_position())
	if d > 40.0 and d < INF:
		Sound.play_at("explosion_far", at, "far", 0.0, 0.05)
	if local_player and local_player.rig:
		local_player.shake(clampf(1.0 - d / (w.splash_radius * 5.0), 0.0, 1.0))


func _on_shot_fired(shooter: int, muzzle: Vector3, ends: PackedVector3Array, hits: Array) -> void:
	var p := get_player(shooter)
	if shooter == Net.my_id() or (p and p.is_local):
		return  # we (or our bot) already drew this shot the moment it was fired
	if p:
		p.show_shot()
	ShotFx.spawn(self, p.muzzle_position() if p else muzzle, ends, hits, Net.player_weapon(shooter))
	Sound.shot_landed(p.muzzle_position() if p else muzzle, ends, hits, false)


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
		else:
			var p := get_player(id)
			if p.mobility != Net.player_mobility(id):
				p.set_mobility(Net.player_mobility(id))   # picked while waiting to respawn
			if p.character != Net.player_character(id):
				rebuild_player(id)   # a new robot from the loadout (picked while waiting to respawn)
			elif not p.racing and p.robot.weapon != Net.player_weapon(id):
				if Net.is_deathmatch():
					p.equip(Net.player_weapon(id))   # switched weapons (or picked one up); a dead body waits for its respawn
				elif p.alive and Match.is_alive(id):
					p.change_weapon(Net.player_weapon(id))   # Gun Game: a kill hands you the next weapon now
				else:
					rebuild_player(id)   # swapped weapons while waiting to respawn: rebuilt holding the new one
	for p in players_root.get_children():
		if not Net.players.has((p as Player).peer_id):
			p.queue_free()
		elif not Match.is_alive((p as Player).peer_id) and (p as Player).alive:
			(p as Player).set_dead()  # joined while they were dead
	portals.prune()
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
	if Race.active:
		s = layout.spawns[index % layout.spawns.size()]   # everyone has their own place on the start line
	if not DevArgs.spawn.is_empty() and not p.is_bot:
		s = DevArgs.spawn
	p.teleport(s[0], s[1])
	if s.size() > 2:
		p.input.pitch = s[2]


func _on_pause_toggled() -> void:
	Sound.play("ui_click" if _menu_open() else "ui_back")
	_capture_mouse(not _menu_open())


func _menu_open() -> bool:
	return pause_menu.visible or debug_menu.is_open()


## The navigation mesh bots walk on. Baked when the match starts with bots, or
## when the debug menu adds the first one.
func ensure_navigation() -> void:
	if not has_node("Navigation"):
		add_child(MapScenery.bake_navigation(layout))


## Walls or floors cracked or broke: let go of ropes hooked onto the broken bits, and
## (host, with bots) redo the bots' map of where they can walk.
func _on_cells_changed(cells: PackedInt32Array, stages: PackedByteArray) -> void:
	var gone: Array = []
	for i in cells.size():
		if stages[i] >= MapDestruction.BROKEN:
			gone.append(layout.destruction.cell_box(cells[i]).grow(0.15))
	if gone.is_empty():
		return
	portals.remove_in(gone)
	for p in players_root.get_children():
		var player := p as Player
		if not player.is_local or player.motor == null or not player.motor.grapple.attached:
			continue
		for box in gone:
			if (box as AABB).has_point(player.motor.grapple.anchor):
				player.motor.grapple.release()
				break
	if Net.is_host() and has_node("Navigation"):
		_nav_rebake = NAV_REBAKE_DELAY   # a burst of breaks is redone once


func _rebake_navigation() -> void:
	if _nav_baking:
		_nav_rebake = NAV_REBAKE_DELAY   # still busy with the last one: go again after
		return
	var region := get_node_or_null("Navigation") as NavigationRegion3D
	if region == null:
		return
	_nav_baking = true
	MapScenery.rebake_navigation(region, layout, func(info: String):
		_nav_baking = false
		if DevArgs.sync_log:
			print("NAV_REBAKE " + info))


## Debug menu: rebuilds a player from Net.players (after changing their robot or
## gun), keeping where they stand and look.
func rebuild_player(id: int) -> void:
	var old := get_player(id)
	if old == null:
		return
	var pos := old.global_position
	var yaw := old.input.yaw
	var pitch := old.input.pitch
	var respawns := old.respawn_count()
	players_root.remove_child(old)
	old.queue_free()
	_spawn(id)
	var p := get_player(id)
	if p == null:
		return
	p.set_respawn_count(respawns)   # so the next respawn still reads as one everywhere
	if p.is_local:
		p.teleport(pos, yaw)
		p.input.pitch = pitch
	if not Match.is_alive(id):
		p.set_dead()
		if not p.is_local:
			p.expect_dead()


func _spawn_dummies() -> void:
	var root := Node3D.new()
	root.name = "Dummies"
	add_child(root)
	for d in layout.dummies:
		var marker: MapDummy = d[2]
		var dummy := TargetDummy.new().setup(dummies.size(), d[0], d[1], marker.character, marker.gun, marker.caption)
		root.add_child(dummy)
		dummies.append(dummy)


func _spawn_pickups() -> void:
	var root := Node3D.new()
	root.name = "Pickups"
	add_child(root)
	for w in layout.weapon_spawns:
		var p := WeaponPickup.make(pickups.size(), w[0], w[1])
		root.add_child(p)
		pickups.append(p)


func _spawn_items() -> void:
	var root := Node3D.new()
	root.name = "Items"
	add_child(root)
	for it in layout.item_spawns:
		var p := ItemPickup.make(items.size(), it[0], it[1])
		root.add_child(p)
		items.append(p)


## The host says a power-up was taken (by `by`) or is back.
func _on_item_changed(index: int, taken: bool, by: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: ItemPickup = items[index]
	item.set_taken(taken)
	if not taken:
		Sound.play_at("ui_click", item.spot, "move", -6.0)
	elif by == Net.my_id():
		Sound.play("ui_confirm")
	elif by != 0:
		Sound.play_at("ui_confirm", item.spot, "move")


## The host says a weapon was taken (by `by`) or is back.
func _on_pickup_changed(index: int, taken: bool, by: int, weapon: String) -> void:
	if index < 0 or index >= pickups.size():
		return
	var pickup: WeaponPickup = pickups[index]
	pickup.set_taken(taken)
	if not taken:
		Sound.play_at("ui_click", pickup.spot, "move", -6.0)
		return
	if by == 0:
		return   # just catching up on what is gone (joined mid-match)
	var p := get_player(by)
	if p and p.is_local:
		p.picked_up(weapon)   # a full magazine, whether it is new or one you carry
		if p == local_player:
			Sound.play("equip_" + weapon)
			return
	Sound.play_at("equip_" + weapon, pickup.spot, "move")


func _capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
