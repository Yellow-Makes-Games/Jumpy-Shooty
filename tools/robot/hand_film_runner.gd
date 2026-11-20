extends Node
## The body of tools/robot/hand_film.gd (a separate file: it uses the game's autoloads).
## Picks things up and works things in real matches, with the keys worked by this script
## and a caption for each, so the free hand (FreeHand) can be filmed at it:
##   site      Construction Site, a Deathmatch: a weapon off its pad, a second one, a
##             power-up, the crane's lever
##   terminal  Halcyon: its terminal
##   bomb      Construction Site, Search and Destroy against one bot standing still: the
##             bomb planted, then worked at as a defuser would (the hand is driven by this
##             script for that: the player here is on the side that plants)

const STEP := 120   # physics steps a second

var _me: Player
var _down := {}
var _cam: Camera3D        # --side: a camera of its own, ahead of the body and to its left (the free hand's side)
var _beside := false      # ...or, at a console that is in the way, level with the body at its left
var _over := false        # ...or, in the crane's cab, over its left shoulder
var _caption: Label


func run(scene: String, view: String) -> void:
	Settings.third_person = view != "first"   # (not saved: nothing here calls save_settings)
	match scene:
		"terminal":
			Game.start_practice("halcyon")
		"bomb":
			Cheats.freeze_bots = true
			Game.start_bot(1, 10, "construction_site", 1, "snd")
		_:
			DevArgs.game = "dm"
			Game.start_practice("construction_site", "dm")
	await _frames(50)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.input.pitch = 0.0
	if view == "side":
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = 38.0
		Net.arena.add_child(_cam)
		_cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.position.y = 70
	layer.add_child(_caption)
	await _frames(20)
	print("FILM START %d" % Engine.get_process_frames())
	match scene:
		"terminal": await _terminal(false)
		"bomb": await _bomb()
		_:
			await _weapon()
			await _power_up()
			await _terminal(true)
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## A weapon off its pad: walked through, the free hand out to it and snatching it. Then a
## second one, which goes on the body: carried there from the hand.
func _weapon() -> void:
	_caption.text = "A WEAPON OFF ITS PAD"
	for i in Net.arena.pickups.size():
		if Match.pickups_taken.has(i):
			continue
		var pad := Net.arena.pickups[i] as WeaponPickup
		if await _walk_through(pad.spot):
			print("FILM weapon: %s, now holding %s, carrying %s" % [pad.weapon, _me.robot.weapon, _me.stowed])
			await _physics(110)
			_caption.text = "A SECOND WEAPON  ·  it goes on the body"
			for j in Net.arena.pickups.size():
				var other := Net.arena.pickups[j] as WeaponPickup
				if j != i and not Match.pickups_taken.has(j) and other.weapon != pad.weapon and await _walk_through(other.spot):
					print("FILM second weapon: %s, now holding %s, carrying %s" % [other.weapon, _me.robot.weapon, _me.stowed])
					await _physics(110)
					break
			break
	_caption.text = ""


## A power-up: the same, and its colour through the body's lights.
func _power_up() -> void:
	Match.health[_me.peer_id] = 40.0   # (so that a health one is worth taking)
	for i in Net.arena.items.size():
		if Match.items_taken.has(i):
			continue
		var item := Net.arena.items[i] as ItemPickup
		_caption.text = "A POWER-UP  ·  %s" % ItemPickup.INFO[item.kind][0]
		if await _walk_through(item.spot):
			print("FILM power-up: %s, health now %.0f" % [item.kind, Match.health[_me.peer_id]])
			await _physics(110)
			break
	_caption.text = ""


## A terminal (or the crane's lever): stood at, and Interact.
func _terminal(lever: bool) -> void:
	for node in get_tree().get_nodes_in_group(MapTerminal.GROUP):
		var t := node as MapTerminal
		if (t is MapLever) != lever:
			continue
		_caption.text = "THE CRANE'S LEVER" if lever else "A TERMINAL"
		_beside = not lever
		_over = lever
		if _cam:
			_cam.fov = 62.0 if lever else 38.0
		# In front of it, facing it. (A lever is thrown toward its own -z: stood on its +z side.)
		var out := t.global_transform.basis.z if lever else _clear_side(t.global_position)
		out = Vector3(out.x, 0.0, out.z).normalized()
		var feet := t.global_position + out * (0.75 if lever else 1.0)
		_me.teleport(feet + Vector3(0.0, 0.1, 0.0), atan2(out.x, out.z))
		_me.input.pitch = -0.25
		await _physics(90)
		_key("interact", true)
		var held := 0
		for i in 900:
			await _physics(1)
			held += 1
			if t.phase == MapTerminal.Phase.BUSY and held > 20:
				break
		print("FILM %s: held %.2f s, now %s, hand shown %.2f" % ["lever" if lever else "terminal", held / 120.0, MapTerminal.Phase.keys()[t.phase], _me.hand.w])
		_key("interact", false)
		await _physics(150)
		break
	_caption.text = ""


## The bomb: planted on a site (the real thing), then worked at where it sits, as a defuser would.
func _bomb() -> void:
	await _physics(60)
	if Teams.bomb_carrier != _me.peer_id:
		Teams._host_take_bomb(_me.peer_id)
	var site: Vector3 = Teams.sites[0]
	_me.teleport(site + Vector3(0.0, 0.15, 0.0), 0.0)
	_me.input.pitch = 0.0
	_caption.text = "PLANTING  ·  hold Interact for 3 seconds"
	await _physics(80)
	_key("interact", true)
	for i in 600:
		await _physics(1)
		if Teams.phase == Teams.Phase.PLANTED:
			break
		if i == 200:
			_me.input.pitch = 0.3   # (the aim is free the whole time: up...)
		if i == 280:
			_me.input.pitch = 0.0
	print("FILM plant: %s at %s" % [Teams.Phase.keys()[Teams.phase], Teams.bomb_pos])
	_key("interact", false)
	await _physics(100)
	_caption.text = "DEFUSING  ·  hold Interact for 5 seconds"
	for i in 300:
		_me.hand.hold(Teams.bomb_pos + Vector3(0.0, 0.22, 0.0), true, true, true)
		await _physics(1)
	_caption.text = ""
	await _physics(80)


# Walks through `spot` (a pickup, 0.9 m over its pad) from a few metres off, along the
# first way that is clear. False if there is none, or nothing was picked up.
func _walk_through(spot: Vector3) -> bool:
	var space := _me.get_world_3d().direct_space_state
	var floor_at := spot - Vector3(0.0, 0.9, 0.0)
	for k in 8:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
		var from := floor_at - way * 4.6
		var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), spot + way * 2.0, 1))
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.6, 0), from - Vector3(0, 0.4, 0), 1))
		if not blocked.is_empty() or floor_hit.is_empty():
			continue
		var before := Match.pickups_taken.size() + Match.items_taken.size()
		_me.teleport(from + Vector3(0.0, 0.1, 0.0), atan2(-way.x, -way.z))
		_me.input.pitch = 0.0
		await _physics(60)
		_key("move_forward", true)
		for i in 330:
			await _physics(1)
			if Match.pickups_taken.size() + Match.items_taken.size() > before:
				await _physics(40)
				_key("move_forward", false)
				return true
		_key("move_forward", false)
	return false


# The side of a terminal to stand on: the first with a floor and nothing in the way.
func _clear_side(at: Vector3) -> Vector3:
	var space := _me.get_world_3d().direct_space_state
	for k in 8:
		var way := Vector3.BACK.rotated(Vector3.UP, TAU * k / 8.0)
		var feet := at + way * 1.0
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.8, 0), feet - Vector3(0, 0.5, 0), 1))
		var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.2, 0), at + Vector3(0, 1.2, 0) - way * 0.2, 1))
		if not floor_hit.is_empty() and (blocked.is_empty() or (blocked.position as Vector3).distance_to(at + Vector3(0, 1.2, 0)) < 0.8):
			return way
	return Vector3.BACK


func _key(action: String, down: bool) -> void:
	if _down.get(action, false) == down:
		return
	_down[action] = down
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action in _down.keys():
		_key(action, false)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_follow(0.15)


## The camera of its own keeps ahead of the body and to its left, looking back at it.
func _follow(share: float) -> void:
	if _cam == null or not is_instance_valid(_me):
		return
	var feet := _me.global_position
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, _me.input.yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, _me.input.yaw)
	var want := feet + ahead * 2.6 - right * 2.0 + Vector3(0.0, 1.35, 0.0)
	var at := feet + Vector3(0.0, 0.95, 0.0)
	if _beside:
		want = feet + ahead * 0.5 - right * 2.7 + Vector3(0.0, 1.4, 0.0)
		at = feet + ahead * 0.45 + Vector3(0.0, 1.0, 0.0)
	elif _over:
		want = feet - ahead * 0.95 - right * 0.6 + Vector3(0.0, 1.85, 0.0)
		at = feet + ahead * 0.7 + Vector3(0.0, 1.0, 0.0)
	_cam.global_position = want if share >= 1.0 or _cam.global_position.distance_to(want) > 6.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
