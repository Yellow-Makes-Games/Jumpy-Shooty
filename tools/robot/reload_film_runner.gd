extends Node
## The body of tools/robot/reload_film.gd (a separate file: it uses the game's autoloads).
## Reloads a gun off the ground in a real Practice match on the Testing Grounds, with the
## keys worked by this script and a caption for each, so the game can be filmed doing it:
## on the rope, in a jump, in a glide, through a flip and on a wall run.

const S := MovementController.State
const EAST := -PI / 2.0
const SOUTH := PI
const LANE_Z := -30.0
const START := Vector3(51, 6.05, LANE_Z)     # the platform at the start of the grapple lane
const BEAM := Vector3(62.0, 14.0, LANE_Z)    # its first beam (tests/course_test.gd)
const WALL_FROM := Vector3(16.85, 1.05, -5.5)   # beside the wall at x = 17.5, to run south along it
const ORDER := ["rope", "jump", "glide", "flip", "wall"]
const CAPTIONS := {"rope": "ON THE ROPE  ·  one hand", "jump": "IN A JUMP  ·  both hands, knees up", "glide": "IN A GLIDE  ·  both hands",
	"flip": "THROUGH A FLIP  ·  it keeps going", "wall": "ON A WALL RUN  ·  one hand"}

var _me: Player
var _down := {}
var _cam: Camera3D        # --side: a camera of its own, ahead of the body and to its gun side
var _caption: Label


## scenes: which of ORDER ("all": every one); view: "first", "third" or "side".
func run(scenes: Array, view: String) -> void:
	Settings.mobility = Mobility.GRAPPLE   # (not saved: nothing here calls save_settings)
	Settings.third_person = view != "first"
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	if view == "side":
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = 38.0
		Net.arena.add_child(_cam)
		_cam.make_current()
		_follow(1.0)
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
	await _frames(30)
	print("FILM START %d" % Engine.get_process_frames())
	for scene in (ORDER if scenes.has("all") else scenes):
		if not ORDER.has(scene):
			continue
		_caption.text = "%s  ·  %s" % [_me.weapon.data.display_name.to_upper(), CAPTIONS[scene]]
		await call("_" + str(scene))
		_release_all()
		_caption.text = ""
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## Hanging under the beam: a reload with the gun hand alone.
func _rope() -> void:
	await _from_start()
	_key("move_forward", true)
	_key("sprint", true)
	while _me.global_position.x < 54.2:
		await _physics(1)
	await _tap("jump")
	await _physics(10)
	_look(BEAM)
	_key("grapple", true)
	_key("sprint", false)
	_key("move_forward", false)
	var hook := _me.motor.grapple
	var on := 0
	var began := -1
	for i in 1500:
		await _physics(1)
		if not hook.attached:
			continue
		on += 1
		_look(Vector3(100.0, 9.0, LANE_Z), 0.08)   # looking along the lane, level
		if on == 70:
			began = on
			_start_reload()
		if began >= 0 and not _me.weapon.is_reloading() and on > began + 30:
			break
	print("FILM rope: reloaded in %.2f s, %s" % [(on - began) / 120.0, S.keys()[_me.motor.state]])
	await _physics(30)
	_key("grapple", false)
	await _land()


## Off the platform: a reload on the way up and down.
func _jump() -> void:
	await _from_start()
	_key("move_forward", true)
	while _me.global_position.x < 53.6:
		await _physics(1)
	await _tap("jump")
	await _physics(6)
	_start_reload()
	print("FILM jump: reloading in %s" % S.keys()[_me.motor.state])
	await _land()
	await _reloaded()


## Off the platform and into a glide: a reload on the way.
func _glide() -> void:
	await _from_start()
	_key("move_forward", true)
	_key("sprint", true)
	while _me.global_position.x < 54.0:
		await _physics(1)
	await _tap("jump")
	await _physics(24)
	_key("glide", true)
	await _physics(14)
	_start_reload()
	print("FILM glide: reloading in %s" % S.keys()[_me.motor.state])
	for i in 600:
		await _physics(1)
		if not _me.weapon.is_reloading() and i > 30:
			break
	await _physics(30)
	_key("glide", false)
	await _land()


## A jump, the reload started, then a flip forward with it going on.
func _flip() -> void:
	await _from_start()
	_key("move_forward", true)
	while _me.global_position.x < 53.6:
		await _physics(1)
	await _tap("jump")
	await _physics(10)
	_start_reload()
	await _physics(16)
	await _tap("jump")
	await _physics(4)
	print("FILM flip: reloading %s in %s" % [_me.weapon.is_reloading(), S.keys()[_me.motor.state]])
	await _land()
	await _reloaded()


## Along the wall: a reload with the gun hand alone.
func _wall() -> void:
	_me.teleport(WALL_FROM, SOUTH)
	_me.input.pitch = 0.0
	_me.weapon.ammo = _me.weapon.data.magazine
	await _physics(40)
	_key("move_forward", true)
	_key("sprint", true)
	await _physics(48)
	_key("jump", true)
	await _physics(4)
	_key("jump", false)
	var ran := 0
	var began := false
	for i in 500:
		await _physics(1)
		if _me.motor.state == S.WALL_RUN:
			ran += 1
			if ran == 8 and not began:
				began = true
				_start_reload()
		elif ran > 0 and i > 60 and _me.is_on_floor():
			break
		elif ran == 0 and i > 150:
			break
	print("FILM wall: ran along it %.2f s, reload begun %s" % [ran / 120.0, began])
	_key("sprint", false)
	_key("move_forward", false)
	await _reloaded()


func _from_start() -> void:
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	_me.weapon.ammo = _me.weapon.data.magazine
	await _physics(40)


# The gun, all but empty, and a reload. (A gun fed a round at a time: three rounds short.)
func _start_reload() -> void:
	var data := _me.weapon.data
	_me.weapon.ammo = maxi(data.magazine - 3, 0) if data.reload_per_round else mini(1, data.magazine - 1)
	_me.weapon.start_reload()   # (R: the key itself is read from an input event, which a script cannot press)
	print("FILM reload at %d" % Engine.get_process_frames())


func _reloaded() -> void:
	for i in 900:
		await _physics(1)
		if not _me.weapon.is_reloading():
			break
	await _physics(40)


func _land() -> void:
	for i in 900:
		await _physics(1)
		if _me.is_on_floor() and i > 20:
			break
	_release_all()


func _look(at: Vector3, share: float = 1.0) -> void:
	var dir := (at - _me.eye_position()).normalized()
	_me.input.yaw = lerp_angle(_me.input.yaw, atan2(-dir.x, -dir.z), share)
	_me.input.pitch = lerpf(_me.input.pitch, asin(clampf(dir.y, -1.0, 1.0)), share)


func _key(action: String, down: bool) -> void:
	if _down.get(action, false) == down:
		return
	_down[action] = down
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_key(action, true)
	await _physics(3)
	_key(action, false)


func _release_all() -> void:
	for action in _down.keys():
		_key(action, false)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_follow(0.15)


## The camera of its own keeps ahead of the body and to its gun side, looking back at it.
func _follow(share: float) -> void:
	if _cam == null or not is_instance_valid(_me):
		return
	var feet := _me.global_position
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, _me.input.yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, _me.input.yaw)
	var want := feet + ahead * 2.5 + right * 1.9 + Vector3(0.0, 1.35, 0.0)
	_cam.global_position = want if share >= 1.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(feet + Vector3(0.0, 1.0, 0.0))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
