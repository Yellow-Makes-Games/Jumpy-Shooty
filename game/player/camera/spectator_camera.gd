class_name SpectatorCamera
extends Camera3D
## The free-flying camera a spectator watches through (see Net.spectating). It has no
## body: it flies through walls and floors (noclip), nobody can see or hit it, and it
## sends nothing over the network.
##
## Mouse to look. Move keys fly where you look; Jump rises and Crouch sinks straight up
## and down; hold Sprint to go fast, Dive (or Kick) to creep. Fire (or Mobility) locks
## onto a player and watches them from behind in third person (a FollowCamera, see
## Arena.spectator_follow); Interact flies free again from there.

const SPEED := 12.0         ## metres per second
const FAST := 3.5           ## Sprint multiplies the speed by this
const SLOW := 0.3           ## Dive / Kick multiplies it by this
const ACCEL := 10.0         ## how quickly it gets up to speed and stops (higher is snappier)
const PITCH_LIMIT := 89.0   ## degrees up or down

var yaw := 0.0
var pitch := 0.0
var velocity := Vector3.ZERO
## Tests: move as if these keys were held ({"forward": 1.0, "up": -1.0, "fast": true}).
var scripted := {}


func _init() -> void:
	name = "SpectatorCamera"
	near = 0.05
	far = 800.0


func _ready() -> void:
	fov = Settings.field_of_view
	make_current()


## Starts the view here, looking this way.
func place(at: Vector3, look_yaw: float, look_pitch: float = 0.0) -> void:
	global_position = at
	yaw = look_yaw
	pitch = clampf(look_pitch, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))
	velocity = Vector3.ZERO
	_apply_look()


## Starts the view where `from` looks from (the camera the game was using).
func place_like(from: Camera3D) -> void:
	var euler := from.global_transform.basis.get_euler(EULER_ORDER_YXZ)
	place(from.global_position, euler.y, euler.x)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if Net.arena and not event.is_echo() and captured and not _menu_open():
		var follow: FollowCamera = Net.arena.follow_cam
		if follow == null and (event.is_action_pressed("fire") or event.is_action_pressed("grapple")):
			Net.arena.spectator_follow(1 if event.is_action_pressed("fire") else -1)
			get_viewport().set_input_as_handled()
			return
		if follow != null and event.is_action_pressed("interact"):
			Net.arena.spectator_free()
			get_viewport().set_input_as_handled()
			return
	if not current:
		return   # watching a player: the mouse does not look about
	if event is InputEventMouseMotion and captured:
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		yaw -= event.relative.x * sens
		var dy: float = event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch - dy, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))
		_apply_look()


func _process(delta: float) -> void:
	fov = Settings.field_of_view
	if not current:
		return   # watching a player (the keys are theirs to switch players)
	var wish := wish_velocity()
	velocity = velocity.lerp(wish, clampf(ACCEL * delta, 0.0, 1.0))
	global_position += velocity * delta


## Where the keys held right now ask to fly, in metres per second.
func wish_velocity() -> Vector3:
	var forward := 0.0
	var right := 0.0
	var up := 0.0
	var fast := false
	var slow := false
	if not scripted.is_empty():
		forward = float(scripted.get("forward", 0.0))
		right = float(scripted.get("right", 0.0))
		up = float(scripted.get("up", 0.0))
		fast = bool(scripted.get("fast", false))
		slow = bool(scripted.get("slow", false))
	elif not _menu_open():
		forward = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		right = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		up = Input.get_action_strength("jump") - Input.get_action_strength("crouch")
		fast = Input.is_action_pressed("sprint")
		slow = Input.is_action_pressed("dive") or Input.is_action_pressed("kick")
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)
	var dir := -basis.z * forward + basis.x * right + Vector3.UP * up
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir * SPEED * (FAST if fast else 1.0) * (SLOW if slow else 1.0)


func _apply_look() -> void:
	global_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)


func _menu_open() -> bool:
	return Net.arena != null and Net.arena.menu_open()
