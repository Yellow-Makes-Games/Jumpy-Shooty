class_name Player
extends CharacterBody3D
## A player in the arena. The same scene is used for:
##  - the local player: reads input, runs movement, fires, sends snapshots;
##  - remote players: shown from snapshots, smoothed by SnapshotBuffer.
## Bots will be local players whose input comes from the AI.

const SEND_RATE := 30.0  ## snapshots per second
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8
const VIEWMODEL_LAYER := 3   ## render layer for the first-person gun

var peer_id := 1
var is_local := false
var alive := true

var input := PlayerInput.new()
var motor: MovementController
var rig: CameraRig
var visual: Node3D
var buffer := SnapshotBuffer.new()   ## remote: received states; local: own recent states (for the host's rewind)
var weapon: WeaponState
## Time (on this player's clock) at which we are currently drawing them. Sent with shots.
var last_render_time := -1.0

var _send_timer := 0.0
var _scripted_time := 0.0
var _remote_state := 0
var _teleport_count := 0          # local: bumped on every respawn; remote: last seen value
var _awaiting_respawn := false    # remote: hidden until the first post-respawn snapshot
var _body_gun: Node3D
var _view_gun: Node3D
var _fell_reported := false
var _fire_buffer := 0.0           # a click slightly too early still fires when the gun is ready
var _rope: MeshInstance3D         # the grapple line, drawn from the gun to the anchor
var _hook: MeshInstance3D         # the hook at the anchor
var _rope_events: Array = []      # remote: [time, attached, anchor] waiting to be shown
var _rope_on := false             # remote: is the rope shown
var _rope_anchor := Vector3.ZERO  # remote: where it is hooked


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
	_body_gun = _build_placeholder_gun()
	_body_gun.position = Vector3(0.32, 1.25, -0.35)
	visual.add_child(_body_gun)

	if is_local:
		motor = MovementController.new()
		weapon = WeaponState.new(WeaponData.pistol())
		rig = CameraRig.new()
		add_child(rig)
		rig.setup(self)
		_set_layer_recursive(visual, CameraRig.BODY_LAYER)
		_view_gun = _build_placeholder_gun()
		_view_gun.position = Vector3(0.2, -0.17, -0.62)
		_view_gun.scale = Vector3(0.7, 0.7, 0.7)
		rig.camera.add_child(_view_gun)
		_set_layer_recursive(_view_gun, VIEWMODEL_LAYER)
	else:
		_add_name_tag(Net.player_name(id))
	_build_rope()


# ---------------------------------------------------------------------------
# Per-frame

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if DevArgs.scripted_input:
		_scripted_input(delta)
	else:
		read_local_input()
	if alive:
		_set_crosshair_ray()
		var was_on := motor.grapple.attached
		motor.step(self, input, delta)
		if DevArgs.sync_log and motor.grapple.attached != was_on:
			print("ROPE SELF %d %s" % [peer_id, "on" if motor.grapple.attached else "off"])
		visual.rotation.y = input.yaw
		_update_weapon(delta)
	else:
		velocity = Vector3.ZERO
	input.clear_edges()
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer += 1.0 / SEND_RATE
		var now := Net.now()
		Net.send_snapshot(now, make_snapshot())
		buffer.push(now, now, global_position, velocity, input.yaw, input.pitch, motor.state)
	if DevArgs.sync_log:
		print("SYNC SELF %d %.4f %.4f %.4f %.4f" % [peer_id, Net.now(), global_position.x, global_position.y, global_position.z])


func _process(delta: float) -> void:
	if is_local:
		rig.set_view(input.yaw, input.pitch)
		var g := motor.grapple
		_draw_rope(g.attached and alive, g.anchor)
		return
	if not buffer.has_data():
		return
	var rt := buffer.render_time(Net.now(), delta)
	last_render_time = rt
	var s := buffer.sample(rt)
	global_position = s[0]
	velocity = s[1]
	visual.rotation.y = s[2]
	_remote_state = s[4]
	while not _rope_events.is_empty() and _rope_events[0][0] <= rt:
		var ev: Array = _rope_events.pop_front()
		_rope_on = ev[1]
		_rope_anchor = ev[2]
		if DevArgs.sync_log:
			print("ROPE SEEN %d %d %s" % [Net.my_id(), peer_id, "on" if _rope_on else "off"])
	_draw_rope(_rope_on and alive and not _awaiting_respawn, _rope_anchor)
	if DevArgs.sync_log and alive and not _awaiting_respawn:
		print("SYNC SEEN %d %d %.4f %.4f %.4f %.4f %.4f" % [Net.my_id(), peer_id, rt, global_position.x, global_position.y, global_position.z, delta])


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
	elif event.is_action_pressed("reload") and weapon:
		weapon.start_reload()


## Reads keyboard and mouse into `input`. Mouse look arrives in _unhandled_input.
func read_local_input() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured:
		input.move = Vector2.ZERO
		input.sprint = false
		input.jump_held = false
		input.fire = false
		input.grapple = false
		return
	input.move = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	input.sprint = Input.is_action_pressed("sprint")
	input.crouch = Input.is_action_pressed("crouch")
	input.jump_held = Input.is_action_pressed("jump")
	input.fire = Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("fire"):
		input.fire_pressed = true
	if Input.is_action_just_pressed("jump"):
		input.jump_pressed = true
	if Input.is_action_just_pressed("dive"):
		input.dive_pressed = true
	input.grapple = Input.is_action_pressed("grapple")
	if Input.is_action_just_pressed("grapple"):
		input.grapple_pressed = true


## In third person, the grapple aims along the crosshair from the camera.
func _set_crosshair_ray() -> void:
	if rig and rig.is_third_person():
		var cam := rig.camera.global_transform
		input.aim_origin = cam.origin
		input.aim_dir = -cam.basis.z
	else:
		input.aim_origin = Vector3.ZERO
		input.aim_dir = Vector3.ZERO


# ---------------------------------------------------------------------------
# Shooting

func _update_weapon(delta: float) -> void:
	weapon.update(delta)
	if input.fire_pressed:
		_fire_buffer = 0.1
	else:
		_fire_buffer = max(_fire_buffer - delta, 0.0)
	var wants: bool = input.fire if weapon.data.automatic else _fire_buffer > 0.0
	if not wants or not Match.running:
		return
	if not weapon.fire():
		return
	_fire_buffer = 0.0
	var eye := eye_position()
	var dir := _aim_direction(eye)
	var spread := deg_to_rad(weapon.data.spread_degrees)
	var side := dir.cross(Vector3.UP)
	if side.length_squared() > 0.0001:
		dir = dir.rotated(side.normalized(), randf_range(-spread, spread))
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread)).normalized()
	# Show the shot straight away; the host decides whether it hit.
	var end := eye + dir * weapon.data.max_range
	var ray := PhysicsRayQueryParameters3D.create(eye, end, 1 | (1 << 1), [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit:
		end = hit.position
	ShotFx.spawn(get_parent(), muzzle_position(), end, hit and hit.collider is Player)
	var view_times := {}
	for p in get_parent().get_children():
		if p != self and p is Player and p.last_render_time >= 0.0:
			view_times[p.peer_id] = p.last_render_time
	Match.request_shot(eye, dir, view_times, weapon.data.id)


func eye_position() -> Vector3:
	return global_position + Vector3(0, CameraRig.EYE_HEIGHT, 0)


func aim_forward() -> Vector3:
	return Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD


## In third person the camera sits behind the shoulder, so we find what the crosshair
## points at from the camera, then shoot at that point from the eyes.
func _aim_direction(eye: Vector3) -> Vector3:
	var forward := aim_forward()
	if rig == null or not rig.is_third_person():
		return forward
	var cam := rig.camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * weapon.data.max_range
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 1), [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var target: Vector3 = hit.position if hit else to
	var dir := (target - eye).normalized()
	return dir if dir.dot(forward) > 0.2 else forward


func muzzle_position() -> Vector3:
	if is_local and _view_gun and not rig.is_third_person():
		return _view_gun.get_node("Muzzle").global_position
	return _body_gun.get_node("Muzzle").global_position


# ---------------------------------------------------------------------------
# Life and death

func set_dead() -> void:
	alive = false
	if motor:
		motor.grapple.reset()
	_rope_on = false
	visual.visible = false
	collision_layer = 0
	if _view_gun:
		_view_gun.visible = false


## Local player: come back at a spawn point.
func respawn_at(pos: Vector3, yaw: float) -> void:
	teleport(pos, yaw)
	_teleport_count += 1
	_fell_reported = false
	alive = true
	visual.visible = true
	collision_layer = 1 << 1
	if _view_gun:
		_view_gun.visible = true
	if weapon:
		weapon.reset()
	_send_timer = 0.0  # tell everyone at once


## Remote player: alive again, but stay hidden until their new position arrives.
func expect_respawn() -> void:
	alive = true
	_awaiting_respawn = true


func report_fell_once() -> void:
	if not _fell_reported and alive:
		_fell_reported = true
		Match.request_fell()


# ---------------------------------------------------------------------------
# Network state

## Snapshot layout: position (3), velocity (3), yaw, pitch, movement state,
## respawn count, grapple attached (0/1), grapple anchor (3).
func make_snapshot() -> PackedFloat32Array:
	var p := global_position
	var v := velocity
	var g := motor.grapple
	var a := g.anchor
	return PackedFloat32Array([p.x, p.y, p.z, v.x, v.y, v.z, input.yaw, input.pitch,
		float(motor.state), float(_teleport_count), 1.0 if g.attached else 0.0, a.x, a.y, a.z])


func apply_snapshot(remote_time: float, data: PackedFloat32Array) -> void:
	if data.size() < 10:
		return
	var count := int(data[9])
	if count != _teleport_count:
		_teleport_count = count
		buffer.clear_history()  # never blend across a respawn
		if _awaiting_respawn:
			_awaiting_respawn = false
			if alive:
				visual.visible = true
				collision_layer = 1 << 1
	buffer.push(remote_time, Net.now(),
		Vector3(data[0], data[1], data[2]), Vector3(data[3], data[4], data[5]),
		data[6], data[7], int(data[8]))
	if data.size() >= 14:
		var on := data[10] > 0.5
		var anchor := Vector3(data[11], data[12], data[13])
		var last_on: bool = _rope_events[-1][1] if not _rope_events.is_empty() else _rope_on
		var last_anchor: Vector3 = _rope_events[-1][2] if not _rope_events.is_empty() else _rope_anchor
		if on != last_on or (on and anchor.distance_squared_to(last_anchor) > 0.01):
			_rope_events.append([remote_time, on, anchor])


func latest_position() -> Vector3:
	return buffer.snaps[-1].pos if buffer.has_data() else global_position


func latest_time() -> float:
	return buffer.snaps[-1].t if buffer.has_data() else Net.now()


## Where this player's feet were at time t (on this player's clock).
func position_at(t: float) -> Vector3:
	return buffer.sample(t)[0] if buffer.has_data() else global_position


func teleport(pos: Vector3, yaw: float) -> void:
	if motor:
		motor.grapple.reset()
	global_position = pos
	velocity = Vector3.ZERO
	input.yaw = yaw
	input.pitch = 0.0


# ---------------------------------------------------------------------------
# Scripted input for automated tests

func _scripted_input(delta: float) -> void:
	_scripted_time += delta
	var t := _scripted_time
	input.move = Vector2(0.0, 1.0)
	input.yaw = sin(t * 0.7) * 2.2 + t * 0.6
	input.sprint = fmod(t, 4.0) < 2.0
	if fmod(t, 1.7) < delta:
		input.jump_pressed = true
	input.fire = false
	# Every 5 s, swing from the central tower for a moment (tests the grapple online).
	var swing_phase := fmod(t + float(peer_id % 7), 5.0)
	input.grapple = swing_phase < 1.3
	if swing_phase < delta:
		var to_tower := Vector3(0, 5.5, 0) - eye_position()
		input.yaw = atan2(-to_tower.x, -to_tower.z)
		input.pitch = atan2(to_tower.y, Vector2(to_tower.x, to_tower.z).length())
		input.grapple_pressed = true
	if DevArgs.scripted_fire:
		var target := _nearest_visible_opponent()
		if target:
			var aim_height := 1.65 if fmod(t, 4.0) < 2.0 else 1.0  # alternate head and body
			var to: Vector3 = target.global_position + Vector3(0, aim_height, 0) - eye_position()
			input.yaw = atan2(-to.x, -to.z)
			input.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			input.move = Vector2(1.0 if fmod(t, 3.0) < 1.5 else -1.0, 0.3)  # strafe while shooting
			input.fire = true
			if fmod(t, 0.2) < delta:
				input.fire_pressed = true  # click about 5 times a second


func _nearest_visible_opponent() -> Player:
	var best: Player = null
	var best_d := INF
	var space := get_world_3d().direct_space_state
	for p in get_parent().get_children():
		if p == self or not p is Player or not p.alive or not p.visual.visible:
			continue
		var target: Vector3 = p.global_position + Vector3(0, 1.0, 0)
		var ray := PhysicsRayQueryParameters3D.create(eye_position(), target, 1)
		if space.intersect_ray(ray):
			continue  # behind a wall
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------------------
# Placeholder body and gun. Replaced by real models in the art phase.

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


func _build_placeholder_gun() -> Node3D:
	var gun := Node3D.new()
	gun.name = "Gun"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.16, 0.18)
	mat.metallic = 0.5
	mat.roughness = 0.4
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.12, 0.5)
	body.mesh = box
	body.material_override = mat
	gun.add_child(body)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -0.28)
	gun.add_child(muzzle)
	return gun


func _build_rope() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.metallic = 0.6
	mat.roughness = 0.4
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = mat
	_rope.mesh = cyl
	_rope.top_level = true
	_rope.visible = false
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	_hook = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	var hook_mat := StandardMaterial3D.new()
	hook_mat.albedo_color = Color(0.95, 0.7, 0.15)
	box.material = hook_mat
	_hook.mesh = box
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)


## Stretches the rope from the gun to the anchor.
func _draw_rope(on: bool, anchor: Vector3) -> void:
	_rope.visible = on
	_hook.visible = on
	if not on:
		return
	var from := muzzle_position()
	var span := anchor - from
	var dist := span.length()
	if dist < 0.05:
		_rope.visible = false
		return
	var y := span / dist
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	_rope.global_transform = Transform3D(Basis(x, y * dist, z), from + span * 0.5)
	_hook.global_position = anchor


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
	visual.add_child(tag)


func _set_layer_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = 1 << (layer - 1)
	for c in node.get_children():
		_set_layer_recursive(c, layer)
