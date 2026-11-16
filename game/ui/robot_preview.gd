class_name RobotPreview
extends SubViewportContainer
## A robot standing in its idle pose, turning slowly, in a player's colour.
## Its own small 3D world, so nothing behind the menu shows through.

var character := ""
var color := Color.WHITE
var turn := true   ## sway left and right; false keeps it facing you

var _stage: Node3D
var _camera: Camera3D
var _robot: RobotModel
var _pose: RobotPose
var _time := 0.0


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
	_camera.fov = 28.0 / zoom
	_camera.position = Vector3(0, 1.0, 4.6)
	view.add_child(_camera)
	_stage = Node3D.new()
	view.add_child(_stage)


func show_robot(id: String, player_color: Color) -> void:
	id = Characters.valid(id)
	if id == character and player_color == color and _robot:
		return
	character = id
	color = player_color
	_drop_robot()
	_robot = RobotModel.new().setup(Characters.body(character), color)
	_stage.add_child(_robot)
	_pose = _robot.rig.new_pose()
	_robot.rig.sample(_pose, "idle", 0.0)
	_pose.apply(_robot.skeleton)


func _process(delta: float) -> void:
	if _robot == null or not is_visible_in_tree():
		return
	_time += delta
	_robot.rig.sample(_pose, "idle", fmod(_time, _robot.rig.length("idle")))
	_pose.apply(_robot.skeleton)
	var sway := sin(_time * 0.6) * deg_to_rad(24.0) if turn else 0.0
	_stage.rotation.y = deg_to_rad(200.0) + sway   # 180 = facing you


func _exit_tree() -> void:
	_drop_robot()


func _drop_robot() -> void:
	if _robot == null or not is_instance_valid(_robot):
		return
	# Let go of the per-player materials first; headless Godot (used by the tests)
	# prints an error when a robot inside the preview's own 3D world is freed with them.
	for i in _robot.mesh.mesh.get_surface_count():
		_robot.mesh.set_surface_override_material(i, null)
	_robot.queue_free()
	_robot = null
