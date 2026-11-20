extends Node
## The body of tools/robot/emote_film.gd (a separate file: it uses the game's autoloads).
## Stands in Practice on the Construction Site and works the emote wheel (EmoteWheel) the
## way the key and the mouse do, with a caption for each thing shown: the wheel and a
## wave, pointing where it looks, a laugh, the dance cut short by walking off, a tap
## playing the last one again, and a shot cutting that short.

var _me: Player
var _wheel: EmoteWheel
var _down := {}
var _cam: Camera3D        # --side: a camera of the film's own, in front of the body and to its left
var _caption: Label


func run(view: String) -> void:
	Settings.third_person = false   # (not saved: nothing here calls save_settings)
	Settings.emote_wheel = Emote.DEFAULT_WHEEL.duplicate()
	Game.start_practice("construction_site")
	await _frames(50)
	_me = Net.arena.local_player
	_wheel = Net.arena.hud.wheel
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
	_follow(1.0)
	await _physics(40)
	print("FILM START %d" % Engine.get_process_frames())
	_caption.text = "HOLD B: THE WHEEL  ·  let go on one to play it"
	await _pick(0, 0.9)
	await _physics(60)
	print("FILM during: emoting %s, third person %s" % [_me.emote.active(), _me.rig.is_third_person()])
	await _physics(190)
	print("FILM after: emoting %s, third person %s" % [_me.emote.active(), _me.rig.is_third_person()])
	_caption.text = "POINT  ·  where you are looking"
	_me.input.yaw -= 0.55
	_me.input.pitch = 0.2
	await _physics(40)
	await _pick(2, 0.5)
	await _physics(270)
	_caption.text = "LAUGH"
	await _pick(4, 0.5)
	await _physics(290)
	_caption.text = "DANCE  ·  goes on until you do something else"
	await _pick(5, 0.5)
	await _physics(420)
	_caption.text = "WALKING OFF CUTS IT SHORT"
	_key("move_forward", true)
	await _physics(80)
	_key("move_forward", false)
	print("FILM walked off: emoting %s" % _me.emote.active())
	await _physics(70)
	_caption.text = "A QUICK TAP  ·  the last one again"
	_wheel.open()
	await _physics(8)
	print("FILM tap: %s" % _wheel.release())
	await _physics(220)
	print("FILM before the shot: emoting %s" % _me.emote.active())
	_caption.text = "SHOOTING CUTS IT SHORT"
	_key("fire", true)
	await _physics(12)
	_key("fire", false)
	print("FILM shot: emoting %s" % _me.emote.active())
	await _physics(100)
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## The wheel worked as the key and the mouse work it: up, the pointer out to `slot`
## over `seconds`, held there a moment, and let go.
func _pick(slot: int, seconds: float) -> void:
	_wheel.open()
	await _physics(25)
	var way := EmoteWheel.way_of(slot)
	var steps := maxi(roundi(seconds * 120.0), 1)
	for i in steps:
		_wheel.nudge(way * (90.0 / steps))
		await _physics(1)
	await _physics(45)
	print("FILM picked: %s  (emoting %s, third person %s)" % [_wheel.release(), _me.emote.active(), _me.rig.is_third_person()])


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
		_follow(0.12)


## The camera of its own stays in front of the body and a little to its left, looking back at it.
func _follow(share: float) -> void:
	if _cam == null or not is_instance_valid(_me):
		return
	var feet := _me.global_position
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, _me.input.yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, _me.input.yaw)
	var want := feet + ahead * 3.6 - right * 1.3 + Vector3(0.0, 1.35, 0.0)
	_cam.global_position = want if share >= 1.0 or _cam.global_position.distance_to(want) > 6.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(feet + Vector3(0.0, 1.0, 0.0))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
