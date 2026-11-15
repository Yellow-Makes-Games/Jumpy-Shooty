class_name Player
extends CharacterBody3D
## A player in the arena. The same scene is used for:
##  - the local player: reads input, runs movement, sends snapshots;
##  - remote players: shown from snapshots, smoothed by SnapshotBuffer.
## Bots (phase 1) will be local players whose input comes from the AI.

const SEND_RATE := 30.0  ## snapshots per second
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8

var peer_id := 1
var is_local := false

var input := PlayerInput.new()
var motor: MovementController
var rig: CameraRig
var visual: Node3D
var buffer := SnapshotBuffer.new()

var _send_timer := 0.0
var _scripted_time := 0.0
var _remote_state := 0


func _init() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	collision_layer = 1 << 1   # layer 2: players
	collision_mask = 1 | (1 << 1)


func setup(id: int, local: bool) -> void:
	peer_id = id
	is_local = local
	name = "Player_%d" % id
	set_multiplayer_authority(id)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = CAPSULE_HEIGHT * 0.5
	add_child(shape)

	visual = _build_placeholder_body(Net.player_color(id))
	add_child(visual)

	if is_local:
		motor = MovementController.new()
		rig = CameraRig.new()
		add_child(rig)
		rig.setup(self)
		_set_layer_recursive(visual, CameraRig.BODY_LAYER)
	else:
		_add_name_tag(Net.player_name(id))


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if DevArgs.scripted_input:
		_scripted_input(delta)
	else:
		read_local_input()
	motor.step(self, input, delta)
	input.clear_edges()
	visual.rotation.y = input.yaw
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer += 1.0 / SEND_RATE
		Net.send_snapshot(Net.now(), make_snapshot())
	if DevArgs.sync_log:
		print("SYNC SELF %d %.4f %.4f %.4f %.4f" % [peer_id, Net.now(), global_position.x, global_position.y, global_position.z])


func _process(delta: float) -> void:
	if is_local:
		rig.set_view(input.yaw, input.pitch)
		return
	if not buffer.has_data():
		return
	var rt := buffer.render_time(Net.now(), delta)
	var s := buffer.sample(rt)
	global_position = s[0]
	velocity = s[1]
	visual.rotation.y = s[2]
	_remote_state = s[4]
	if DevArgs.sync_log:
		print("SYNC SEEN %d %d %.4f %.4f %.4f %.4f" % [Net.my_id(), peer_id, rt, global_position.x, global_position.y, global_position.z])


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or DevArgs.scripted_input:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		input.yaw -= event.relative.x * sens
		var dy: float = event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		input.pitch = clamp(input.pitch - dy, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("toggle_camera"):
		Settings.set_third_person(not Settings.third_person)


## Reads keyboard and mouse into `input`. Mouse look arrives in _unhandled_input.
func read_local_input() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured:
		input.move = Vector2.ZERO
		input.sprint = false
		input.jump_held = false
		return
	input.move = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	input.sprint = Input.is_action_pressed("sprint")
	input.crouch = Input.is_action_pressed("crouch")
	input.jump_held = Input.is_action_pressed("jump")
	if Input.is_action_just_pressed("jump"):
		input.jump_pressed = true
	if Input.is_action_just_pressed("dive"):
		input.dive_pressed = true


## Snapshot layout: position (3), velocity (3), yaw, pitch, movement state.
func make_snapshot() -> PackedFloat32Array:
	var p := global_position
	var v := velocity
	return PackedFloat32Array([p.x, p.y, p.z, v.x, v.y, v.z, input.yaw, input.pitch, float(motor.state)])


func apply_snapshot(remote_time: float, data: PackedFloat32Array) -> void:
	if data.size() < 9:
		return
	buffer.push(remote_time, Net.now(),
		Vector3(data[0], data[1], data[2]), Vector3(data[3], data[4], data[5]),
		data[6], data[7], int(data[8]))


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	input.yaw = yaw
	input.pitch = 0.0


# Moves in a repeating pattern of runs, turns, sprints and jumps, for sync tests.
func _scripted_input(delta: float) -> void:
	_scripted_time += delta
	var t := _scripted_time
	input.move = Vector2(0.0, 1.0)
	input.yaw = sin(t * 0.7) * 2.2 + t * 0.6
	input.sprint = fmod(t, 4.0) < 2.0
	if fmod(t, 1.7) < delta:
		input.jump_pressed = true


# ---------------------------------------------------------------------------
# Placeholder body. Replaced by a real character model in the art phase.

func _build_placeholder_body(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = CAPSULE_RADIUS
	cap.height = CAPSULE_HEIGHT
	body.mesh = cap
	body.material_override = mat
	body.position.y = CAPSULE_HEIGHT * 0.5
	root.add_child(body)
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.08, 0.09, 0.12)
	visor_mat.metallic = 0.6
	visor_mat.roughness = 0.2
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.18, 0.2)
	visor.mesh = box
	visor.material_override = visor_mat
	visor.position = Vector3(0.0, 1.5, -0.33)
	root.add_child(visor)
	return root


func _add_name_tag(text: String) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0015
	tag.font_size = 28
	tag.outline_size = 8
	tag.position.y = CAPSULE_HEIGHT + 0.35
	add_child(tag)


func _set_layer_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = 1 << (layer - 1)
	for c in node.get_children():
		_set_layer_recursive(c, layer)
