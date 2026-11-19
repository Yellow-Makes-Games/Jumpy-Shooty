extends Node
## The body of tools/robot/glide_film.gd (a separate file: it uses the game's autoloads).
## Plays the bullet glide in a real Practice match on the Testing Grounds, off a ledge put
## up high for it, with the keys worked by this script, so the game can be filmed doing it.

const S := MovementController.State
const LEDGE := Vector3(-30, 32, 18)     # the top of the ledge put up for the film (over the open end of the yard)
const HEADING := -PI / 2.0              # facing +x, off the ledge's far edge

var _me: Player
var _down := {}
var _side: Camera3D   # --side: a camera off to the side of the flight, following along


func run(scene: String, third: bool, side: bool = false) -> void:
	Settings.third_person = third or side   # (not saved: nothing here calls save_settings)
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	var ledge := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 1, 6)
	shape.shape = box
	ledge.add_child(shape)
	var look := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	look.mesh = mesh
	ledge.add_child(look)
	Net.arena.add_child(ledge)
	ledge.global_position = LEDGE - Vector3(0, 0.5, 0)
	_me.teleport(LEDGE + Vector3(-5, 0.05, 0), HEADING)
	if side:
		# Off to the side of the flight (it goes along +x), a little behind and above:
		# the whole body in profile. Not the first-person body or arms.
		_side = Camera3D.new()
		_side.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_side.fov = 50.0
		Net.arena.add_child(_side)
		_side.make_current()
		_follow(1.0)
	await _frames(30)
	print("FILM START %d" % Engine.get_process_frames())
	match scene:
		"release": await _release()
		_: await _glide()
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## Run off the ledge, jump at its edge, glide from the top of the jump; turn and shoot to
## the side and then behind while it flies on along its track; hold on into the weakened
## dive; let go well above the floor: the backflip out of it.
func _glide() -> void:
	await _physics(40)
	await _run_and_jump()
	while _me.velocity.y > 0.3:
		await _physics(1)
	_key("glide", true)
	var t := 0
	var shots := 0
	var low := 0.0
	while t < 120 * 8:
		await _physics(1)
		t += 1
		var secs := t / 120.0
		# Look ahead, then round to the right side, then back over the shoulder, then ahead again.
		var turn := 0.0
		if secs > 1.0 and secs < 2.2:
			turn = -smoothstep(1.0, 1.5, secs) * PI * 0.5
		elif secs >= 2.2 and secs < 3.2:
			turn = -PI * 0.5 - smoothstep(2.2, 2.6, secs) * PI * 0.45
		elif secs >= 3.2:
			turn = -PI * 0.95 * (1.0 - smoothstep(3.2, 3.6, secs))
		_me.input.yaw = HEADING + turn
		_me.input.pitch = lerpf(_me.input.pitch, -0.12, 0.05)
		if secs > 1.5 and shots < 6 and t % 40 == 0:
			shots += 1
			_tap("fire")
		low = _ground_below()
		if secs > 4.0 or low < 12.0:
			break
	print("FILM at %s" % _me.global_position)
	print("FILM glided %.2f s, %d shots, %.1f m above the floor, falling %.1f, speed %.1f" % [t / 120.0, shots, low, _me.velocity.y,
		Vector2(_me.velocity.x, _me.velocity.z).length()])
	_key("glide", false)
	await _land()


## A short glide let go early: a closer look at the backflip.
func _release() -> void:
	await _physics(40)
	await _run_and_jump()
	while _me.velocity.y > 0.3:
		await _physics(1)
	_key("glide", true)
	await _physics(120)
	_key("glide", false)
	await _land()


func _run_and_jump() -> void:
	_key("move_forward", true)
	_key("sprint", true)
	while _me.global_position.x < LEDGE.x + 5.4:
		await _physics(1)
	_key("jump", true)
	await _physics(3)
	_key("jump", false)
	_key("move_forward", false)
	_key("sprint", false)


func _land() -> void:
	for i in 900:
		await _physics(1)
		if _me.is_on_floor() and i > 30:
			break
	await _physics(80)
	print("FILM landed at %s on floor %s alive %s" % [_me.global_position, _me.is_on_floor(), _me.alive])


## How far the floor is below the player (metres; far when there is none).
func _ground_below() -> float:
	var from := _me.global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 200, 0), 0xFFFFFFFF, [_me.get_rid()])
	var hit := _me.get_world_3d().direct_space_state.intersect_ray(q)
	return from.y - (hit.position as Vector3).y if not hit.is_empty() else 200.0


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
		_follow(0.08)


## The side camera keeps alongside the body (`share` of the way there each step).
func _follow(share: float) -> void:
	if _side == null or not is_instance_valid(_me):
		return
	var at := _me.global_position + Vector3(0, 0.9, 0)
	var want := at + Vector3(-2.0, 1.2, 7.5)
	_side.global_position = want if share >= 1.0 else _side.global_position.lerp(want, share)
	_side.look_at(at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
