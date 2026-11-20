extends Node
## The body of tools/robot/swap_film.gd (a separate file: it uses the game's autoloads).
## Takes weapons out and puts them away in a real match on the Testing Grounds, worked by
## this script, so the game can be filmed doing it.

const EAST := -PI / 2.0
const START := Vector3(51, 6.05, -30.0)   # the platform at the start of the grapple lane: open ground ahead
const DM_MAP := "construction_site"
const STEP := 120                         # physics steps a second
## Cameras of the film's own: [where from, looking at (both from the feet), field of view].
const CAMERAS := {
	"side": [Vector3(0.7, 1.2, 3.9), Vector3(0.35, 0.98, 0.0), 36.0],     # beside the gun arm: the body in profile
	"front": [Vector3(3.2, 1.5, 2.1), Vector3(0.1, 0.98, 0.0), 40.0],     # ahead and to the gun side
	"back": [Vector3(-3.1, 1.7, 0.9), Vector3(0.3, 1.05, 0.0), 40.0],     # behind: what is carried on the back
}

var _me: Player
var _down := {}
var _cam: Camera3D
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO


func run(scene: String, view: String, gun: String, other: String) -> void:
	Settings.third_person = view != "first"   # (not saved: nothing here calls save_settings)
	# (The Testing Grounds are not a Deathmatch map: the swap is filmed where you spawn on one that is.)
	if scene == "swap":
		DevArgs.game = "dm"
	Game.start_practice(DM_MAP if scene == "swap" else "testing_grounds", "dm" if scene == "swap" else "")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.teleport(_me.global_position + Vector3(7.0, 0.3, 0.0) if scene == "swap" else START, EAST)   # (out into the open yard)
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
	if scene == "hand":
		await _hand_over(gun, other)
	else:
		await _swap(gun, other)
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## A Deathmatch: `gun` is picked up and comes out, `other` is picked up and rides on the
## body; then other, gun, and other again with a shot a moment into the draw.
func _swap(gun: String, other: String) -> void:
	await _physics(40)
	Net.host_give_weapon(Net.my_id(), gun)
	await _physics(int(1.3 * STEP))
	Net.host_give_weapon(Net.my_id(), other)
	await _physics(int(0.9 * STEP))
	Net.switch_my_weapon(other)
	await _physics(int(1.4 * STEP))
	Net.switch_my_weapon(gun)
	await _physics(int(1.5 * STEP))
	Net.switch_my_weapon(other)
	await _physics(int(0.12 * STEP))
	await _shot()
	await _physics(int(0.9 * STEP))
	Net.switch_my_weapon(gun)
	await _physics(int(1.3 * STEP))
	print("FILM swapped %s (%s) and %s (%s); carried: %s" % [gun, WeaponDraw.kind_of(gun), other, WeaponDraw.kind_of(other), _me.stowed])


## Gun Game's hand-over: what you hold breaks up into light and the next weapon comes out.
func _hand_over(gun: String, other: String) -> void:
	await _physics(40)
	for next in [other, gun, other, gun]:
		_me.change_weapon(next)
		await _physics(int(1.3 * STEP))


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
