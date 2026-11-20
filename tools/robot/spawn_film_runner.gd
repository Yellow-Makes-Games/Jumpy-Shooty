extends Node
## The body of tools/robot/spawn_film.gd (a separate file: it uses the game's autoloads).
## Knocks the player out and brings them back in a real Practice match, twice, with a
## caption for each, so the arrival (SpawnIn) can be filmed: once standing where they
## arrive, once running off and shooting from the first frame.

const MAP := "construction_site"

var _me: Player
var _down := {}
var _cam: Camera3D        # --side: a camera of its own, ahead of the body and to its left
var _caption: Label


func run(view: String) -> void:
	Settings.third_person = view != "first"   # (not saved: nothing here calls save_settings)
	Game.start_practice(MAP)
	await _frames(50)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.input.pitch = 0.0
	if view == "side":
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = 40.0
		Net.arena.add_child(_cam)
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
	await _out_and_back(false)   # (not filmed: the wait to come back)
	print("FILM START %d" % Engine.get_process_frames())
	_caption.text = "ARRIVING  ·  standing still"
	await _physics(170)
	_caption.text = ""
	print("FILM CUT %d" % Engine.get_process_frames())
	await _out_and_back(true)
	print("FILM RESUME %d" % Engine.get_process_frames())
	_caption.text = "ARRIVING  ·  off and shooting at once"
	await _physics(150)
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


# Knocked out, the wait, and back. moving: with the keys already down as they arrive.
func _out_and_back(moving: bool) -> void:
	_release_all()
	Match._host_kill(_me.peer_id, 0, "fell")
	for i in 120:
		await _physics(1)
		if not _me.alive:
			break
	# The wait, then back (asked for as soon as the game allows it, if it does not bring them back itself).
	var asked := false
	for i in 1200:
		await _physics(1)
		if _me.alive:
			break
		if float(Match.respawn_timers.get(_me.peer_id, 0.0)) <= 0.0 and not asked:
			asked = true
			if moving:
				_key("move_forward", true)
				_key("sprint", true)
				_key("fire", true)
			Match.request_respawn()
	if moving:
		_key("move_forward", true)
		_key("sprint", true)
		_key("fire", true)
	if _cam:
		_follow(1.0)
	print("FILM back at %s (process frame %d), arriving %s" % [_me.global_position, Engine.get_process_frames(), _me._spawn_fx != null])


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
	if not _cam.current:
		_cam.make_current()
	var feet := _me.global_position
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, _me.input.yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, _me.input.yaw)
	var want := feet + ahead * 3.2 - right * 2.2 + Vector3(0.0, 1.4, 0.0)
	_cam.global_position = want if share >= 1.0 or _cam.global_position.distance_to(want) > 6.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(feet + Vector3(0.0, 1.0, 0.0))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
