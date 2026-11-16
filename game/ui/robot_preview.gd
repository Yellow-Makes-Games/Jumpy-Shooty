class_name RobotPreview
extends SubViewportContainer
## Robots standing in their idle pose, in a player's colour: one (show_robot,
## turning slowly) or a lineup side by side (show_lineup, for the main menu).
## Its own small 3D world, so nothing behind the menu shows through.

var character := ""
var color := Color.WHITE
var weapon := "pistol"   ## the gun in its hands
var turn := true   ## sway left and right; false keeps it facing you

var _stage: Node3D
var _camera: Camera3D
var _robots: Array = []   # {robot: RobotModel, pose: RobotPose, phase: float}
var _time := 0.0
var _base_fov := 28.0
var _lineup := false


func _init(preview_size: Vector2 = Vector2(150, 190), zoom: float = 1.0) -> void:
	stretch = true
	custom_minimum_size = preview_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.90)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX   # the same film look as the arenas
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	view.add_child(sun)
	var rim := DirectionalLight3D.new()   # a cool light from behind, to lift the outline off dark menus
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.6, 0.75, 1.0)
	view.add_child(rim)
	_camera = Camera3D.new()
	_base_fov = 28.0 / zoom
	_camera.fov = _base_fov
	_camera.position = Vector3(0, 1.0, 4.6)
	view.add_child(_camera)
	_stage = Node3D.new()
	view.add_child(_stage)


func show_robot(id: String, player_color: Color, gun: String = "") -> void:
	id = Characters.valid(id)
	gun = weapon if gun == "" else WeaponData.valid(gun)
	if id == character and player_color == color and gun == weapon and not _robots.is_empty() and not _lineup:
		return
	character = id
	color = player_color
	weapon = gun
	_lineup = false
	_drop_robots()
	_add(id, player_color, Vector3.ZERO, 0.0, gun)
	_camera.position = Vector3(0, 1.0, 4.6)


## Several robots side by side, the first on the right (as you look at them) and
## each next one to its left. They all idle, out of step, angled a little inward.
func show_lineup(ids: Array, colors: Array, spacing: float = 1.15) -> void:
	_lineup = true
	_drop_robots()
	var n := ids.size()
	for i in n:
		var x := (n - 1) * spacing * 0.5 - i * spacing
		_add(ids[i], colors[i % colors.size()], Vector3(x, 0, 0), i * 0.37)
	# Pull the camera back until the whole row fits the frame.
	var aspect := maxf(custom_minimum_size.x / maxf(custom_minimum_size.y, 1.0), 0.1)
	var half_h := tan(deg_to_rad(_base_fov * 0.5))
	var half_w := (n - 1) * spacing * 0.5 + 0.6
	var dist := maxf(4.6, half_w / (half_h * aspect))
	_camera.position = Vector3(0, 1.0, dist)


func _add(id: String, player_color: Color, at: Vector3, phase: float, gun: String = "pistol") -> void:
	var robot := RobotModel.new().setup(Characters.body(id), player_color, false, gun)
	robot.position = at
	_stage.add_child(robot)
	var pose := robot.rig.new_pose()
	var entry := {"robot": robot, "pose": pose, "phase": phase, "hold": null}
	# A long gun: hold it the way the game does (its aim pose on the arms, chest turned).
	if robot.rig.has_clip("aim_" + gun):
		var hold := robot.rig.new_pose()
		robot.rig.sample(hold, "aim_" + gun, 0.0)
		entry.hold = hold
	_robots.append(entry)
	_pose(entry, phase)


func _pose(r: Dictionary, t: float) -> void:
	var robot: RobotModel = r.robot
	var pose: RobotPose = r.pose
	robot.rig.sample(pose, "idle", fmod(t, robot.rig.length("idle")))
	if r.hold:
		var hold: RobotPose = r.hold
		var rig := robot.rig
		var arms := PackedInt32Array()
		for n in ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag"]:
			arms.append(rig.bones[n])
		pose.blend_bones(hold, 1.0, arms)
		var chest: int = rig.bones["chest"]
		pose.rot[chest] = pose.rot[chest] * hold.rot[chest]
		pose.rot[rig.bones["head"]] = hold.rot[chest].inverse() * pose.rot[rig.bones["head"]]
	pose.apply(robot.skeleton)


func _process(delta: float) -> void:
	if _robots.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	for r in _robots:
		var robot: RobotModel = r.robot
		_pose(r, _time + r.phase)
		if _lineup:   # each turned a little toward the middle of the row
			robot.rotation.y = PI + 0.15 - clampf(robot.position.x * 0.4, -0.5, 0.5)
	if not _lineup:
		var sway := sin(_time * 0.6) * deg_to_rad(24.0) if turn else 0.0
		_stage.rotation.y = deg_to_rad(200.0) + sway   # 180 = facing you


func _exit_tree() -> void:
	_drop_robots()


func _drop_robots() -> void:
	for r in _robots:
		var robot: RobotModel = r.robot
		if not is_instance_valid(robot):
			continue
		# Let go of the per-player materials first; headless Godot (used by the tests)
		# prints an error when a robot inside the preview's own 3D world is freed with them.
		for i in robot.mesh.mesh.get_surface_count():
			robot.mesh.set_surface_override_material(i, null)
		robot.queue_free()
	_robots.clear()
	_stage.rotation.y = 0.0
