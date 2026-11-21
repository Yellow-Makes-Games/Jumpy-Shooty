extends Node
## The body of tools/combat/karate_film.gd (a separate file: it uses the game's autoloads).

const EAST := -PI / 2.0
const START := Vector3(46.6, 0.05, 2.0)   # 2.4 m short of the 5 m dummy, facing it
const CAMERAS := {
	"side": [Vector3(0.9, 1.3, 4.6), Vector3(1.2, 1.0, 0.0), 42.0],     # side-on to the fight
	"front": [Vector3(4.2, 1.7, 2.6), Vector3(0.6, 1.0, 0.0), 44.0],    # ahead and to the right
	"back": [Vector3(-3.4, 1.9, 1.4), Vector3(1.0, 1.1, 0.0), 44.0],
}
const STEP := 120

var _me: Player
var _down := {}
var _cam: Camera3D
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO


func run(scene: String, view: String, pick: Vector2i) -> void:
	Settings.third_person = view != "first"
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	_me.dev_pick = MeleeSwing.pick_of(pick.x, pick.y)
	DevArgs.drives_keys = true
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	if CAMERAS.has(view):
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = CAMERAS[view][2]
		_cam_from = CAMERAS[view][0]
		_cam_at = CAMERAS[view][1]
		Net.arena.add_child(_cam)
		_cam.make_current()
		_follow(1.0)
	await _physics(int(2.8 * STEP))   # (long enough for the guard to drop: the first swing snaps it up)
	print("FILM START %d" % Engine.get_process_frames())
	if scene in ["all", "combo"]:
		await _combo()
	if scene in ["all", "heavy"]:
		await _back_to_start()
		await _heavy()
	if scene in ["all", "air"]:
		await _back_to_start()
		await _air(false)
	if scene == "moves":   # the rest of the full wind-ups, one after another: ground then air
		for g in [0, 1, 3]:
			_me.dev_pick = MeleeSwing.pick_of(g, 0)
			await _back_to_start()
			await _heavy()
		for a in [0, 2]:
			_me.dev_pick = MeleeSwing.pick_of(0, a)
			await _back_to_start()
			await _air(false)
	if scene == "slam":
		await _back_to_start()
		await _air(true)
	await _physics(int(3.2 * STEP))   # standing: the guard drops
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## The six-hit combo, each blow as soon as the last allows.
func _combo() -> void:
	for i in 6:
		while not _me.weapon.can_fire():
			await _physics(1)
		_key("fire", true)
		await _physics(int(0.07 * STEP))
		_key("fire", false)
		await _physics(int(0.05 * STEP))
	await _physics(int(1.2 * STEP))


func _heavy() -> void:
	while not _me.weapon.can_fire():
		await _physics(1)
	_key("fire", true)
	await _physics(int((_me.weapon.data.charge_time + 0.45) * STEP))
	_key("fire", false)
	await _physics(int(1.6 * STEP))


func _air(slam: bool) -> void:
	_key("jump", true)
	await _physics(3)
	_key("jump", false)
	await _physics(int(0.08 * STEP))
	_key("fire", true)
	if slam:
		_key("crouch", true)
	await _physics(int((_me.weapon.data.charge_time + 0.1) * STEP))
	_key("fire", false)
	for i in 600:
		await _physics(1)
		if _me.is_on_floor():
			break
	_key("crouch", false)
	await _physics(int(0.8 * STEP))


## Back in front of the dummy (the blows lunge you forward).
func _back_to_start() -> void:
	await _physics(int(0.3 * STEP))
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	await _physics(int(0.5 * STEP))


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
		_follow(0.25)


func _follow(share: float) -> void:
	if _cam == null or not is_instance_valid(_me):
		return
	var feet := _me.global_position
	var want := feet + _cam_from
	_cam.global_position = want if share >= 1.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(feet + _cam_at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
