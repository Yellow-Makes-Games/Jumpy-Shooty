extends Node
## The body of tools/robot/recoil_film.gd (a separate file: it uses the game's autoloads).
## Fires a gun in a real Practice match on the Testing Grounds, with the trigger worked by
## this script, so the game can be filmed doing it.

const EAST := -PI / 2.0
const START := Vector3(51, 6.05, -30.0)   # the platform at the start of the grapple lane: open ground ahead
## Cameras of the film's own: [where from, looking at (both from the feet), field of view].
const CAMERAS := {
	"side": [Vector3(0.7, 1.2, 3.9), Vector3(0.35, 0.98, 0.0), 36.0],     # beside the gun arm: the body in profile
	"front": [Vector3(3.2, 1.5, 2.1), Vector3(0.1, 0.98, 0.0), 40.0],     # ahead and to the gun side
	"back": [Vector3(-2.9, 1.75, 1.3), Vector3(0.6, 1.1, 0.1), 40.0],     # close behind the gun shoulder
}
const STEP := 120                         # physics steps a second

var _me: Player
var _down := {}
var _cam: Camera3D        # --side, --front: a camera of its own, beside the body
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO


func run(scene: String, view: String) -> void:
	Settings.third_person = view != "first"   # (not saved: nothing here calls save_settings)
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	if CAMERAS.has(view):
		# Facing east, the gun arm is on the +z side. Not the first-person body or arms.
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = CAMERAS[view][2]
		_cam_from = CAMERAS[view][0]
		_cam_at = CAMERAS[view][1]
		Net.arena.add_child(_cam)
		_cam.make_current()
		_follow(1.0)
	await _frames(40)
	print("FILM START %d" % Engine.get_process_frames())
	match scene:
		"air": await _air()
		"move": await _shots(true)
		_: await _shots(false)
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## Four shots one at a time, then the trigger held (or pulled as fast as the gun allows).
## A slow gun (a bolt, a pump, a launcher) fires three and leaves it at that.
func _shots(strafing: bool) -> void:
	var data := _me.weapon.data
	var gap := maxi(int((data.fire_interval + 0.3) * STEP), int(0.75 * STEP))
	await _physics(50)
	if strafing:
		_key("move_right", true)
	var slow := not data.automatic and data.fire_interval >= 0.6   # (a slow gun: three shots show all there is)
	for i in (3 if slow else 4):
		await _shot()
		await _physics(gap)
		if strafing and i == 1:
			_key("move_right", false)
			_key("move_left", true)
	_key("move_left", false)
	await _physics(40)
	if data.automatic:
		_key("fire", true)
		await _physics(int(1.6 * STEP))
		_key("fire", false)
	elif not slow:
		var each := maxi(int(data.fire_interval * STEP) + 2, 4)
		for i in clampi(int(1.6 / maxf(data.fire_interval, 0.05)), 2, 8):
			await _shot()
			await _physics(each)
	await _physics(int(1.1 * STEP))
	print("FILM fired %s: kick %.2f, strength %.2f" % [data.id, data.kick, GunRecoil.strength(data.kick)])


## A jump: a shot at the top of it and another on the way down, twice.
func _air() -> void:
	await _physics(50)
	for jump in 2:
		_key("jump", true)
		await _physics(3)
		_key("jump", false)
		while _me.velocity.y > 0.6:
			await _physics(1)
		await _shot()
		await _physics(int(maxf(_me.weapon.data.fire_interval, 0.22) * STEP) + 2)
		await _shot()
		for i in 600:
			await _physics(1)
			if _me.is_on_floor():
				break
		await _physics(70)


func _shot() -> void:
	_key("fire", true)
	await _physics(3)
	_key("fire", false)


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
		if _me.weapon and not _me.weapon.is_reloading() and _me.weapon.ammo <= 1:
			_me.weapon.ammo = _me.weapon.data.magazine   # (the film is of the shots, not the reload)
		_follow(0.25)


## The camera of its own keeps beside the body (`share` of the way there each step).
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
