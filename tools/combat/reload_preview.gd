extends SceneTree
## Films a robot reloading a gun, frame by frame, to check a reload without opening the
## game: seen from the front, the side and behind at once, with the spent cell it throws.
## Used by tools/combat/reload_preview.sh.
##
##   godot --fixed-fps 60 --path . --script tools/combat/reload_preview.gd -- --weapon=pistol --out=DIR
##       [--speed=0.5] (half speed) [--cut=0.5] (the reload is cut short this many seconds in)
##       [--close] (the hands and the gun, close up)
##       [--color=r,g,b] [--character=ID]
##
## Writes DIR/f_0001.png and so on.

const YAWS := [25.0, -70.0, 180.0]

var _weapon := "pistol"
var _out := "."
var _speed := 0.5
var _cut := -1.0
var _close := false
var _color := Color(0.95, 0.35, 0.25)
var _character := "vanguard"
var _robots: Array = []      # [RobotModel, RobotAnimator]
var _inp := RobotAnimInput.new()
var _t := -0.35              # game seconds: the reload starts at 0
var _frame := 0
var _warm := 6
var _length := 1.3


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			_weapon = arg.substr(9)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--speed="):
			_speed = float(arg.substr(8))
		elif arg.begins_with("--cut="):
			_cut = float(arg.substr(6))
		elif arg == "--close":
			_close = true
		elif arg.begins_with("--character="):
			_character = arg.substr(12)
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
	Engine.time_scale = _speed   # (the spent cell keeps its own time)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.39, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -150, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_body := StaticBody3D.new()   # something for the spent cell to bounce on
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(200, 1, 200)
	shape.shape = slab
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.37)
	mat.roughness = 0.9
	plane.material = mat
	floor_mesh.mesh = plane
	floor_body.add_child(floor_mesh)
	root.add_child(floor_body)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2 if _close else 2.25
	var eye := 1.3 if _close else 1.0
	camera.look_at_from_position(Vector3(0, eye, -12), Vector3(0, eye, 0))
	camera.make_current()
	for i in YAWS.size():
		var robot := RobotModel.new().setup(Characters.body(_character), _color, false, _weapon)
		root.add_child(robot)
		robot.position = Vector3((1 - i) * (1.05 if _close else 1.9), 0, 0)
		robot.rotation_degrees.y = YAWS[i]
		var animator := RobotAnimator.new(robot)
		animator.fx_parent = root
		_robots.append([robot, animator])
	_inp.state = MovementController.State.GROUND
	_length = WeaponData.by_id(_weapon).reload_time
	if WeaponData.by_id(_weapon).reload_per_round:
		_length *= 2.0   # two shells, then whatever ends the reload
	DirAccess.make_dir_recursive_absolute(_out)


func _process(delta: float) -> bool:
	if _warm > 0:   # let the first frames settle (shadows, the idle pose)
		_warm -= 1
		_advance(1.0 / 60.0, false)
		return false
	_frame += 1
	root.get_texture().get_image().save_png("%s/f_%04d.png" % [_out, _frame])
	if _t > _length + 0.9:
		print("saved %d frames in %s" % [_frame, _out])
		return true
	_advance(delta, true)
	return false


func _advance(dt: float, run: bool) -> void:
	if run:
		_t += dt
	var reloading := _t >= 0.0 and _t < (_cut if _cut > 0.0 else _length)
	_inp.flags = RobotAnimInput.make_flags(false, false, reloading, 0, 0)
	for r in _robots:
		var robot: RobotModel = r[0]
		_inp.yaw = robot.rotation.y
		(r[1] as RobotAnimator).update(dt, _inp, robot.global_transform)
