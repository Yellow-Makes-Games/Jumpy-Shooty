extends SceneTree
## Films a robot swinging a melee weapon, frame by frame, to check the swings without
## opening the game: a tap from each side, then a full wind-up, seen from the front,
## the side and behind at once, with the blade's trail. Used by tools/combat/swing_preview.sh.
##
##   godot --path . --script tools/combat/swing_preview.gd -- --weapon=sword --out=DIR
##       [--step=0.004167] (game seconds a frame: 1/240 is quarter speed at 60 frames a second)
##       [--blows=a,b,heavy] [--close] (the hands, close up) [--color=r,g,b] [--character=ID]
##
## Writes DIR/f_0001.png and so on, and DIR/marks.txt (which frame each blow was let go on).

const YAWS := [25.0, -70.0, 180.0]

var _weapon := "sword"
var _out := "."
var _step := 1.0 / 240.0
var _blows := ["a", "b", "heavy"]
var _close := false
var _color := Color(0.95, 0.35, 0.25)
var _character := "vanguard"
var _robots: Array = []      # [RobotModel, RobotAnimator, SwingTrail]
var _inp := RobotAnimInput.new()
var _plan: Array = []        # [seconds, what, side]: "idle", "wind", "swing"
var _at := 0                 # which part of the plan
var _t := 0.0                # seconds into it
var _frame := 0
var _warm := 6
var _marks := PackedStringArray()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			_weapon = arg.substr(9)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--step="):
			_step = float(arg.substr(7))
		elif arg.begins_with("--blows="):
			_blows = Array(arg.substr(8).split(","))
		elif arg == "--close":
			_close = true
		elif arg.begins_with("--character="):
			_character = arg.substr(12)
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
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
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.37)
	mat.roughness = 0.9
	plane.material = mat
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.5 if _close else 3.0
	camera.look_at_from_position(Vector3(0, 1.3 if _close else 1.25, -12), Vector3(0, 1.3 if _close else 1.25, 0))
	camera.make_current()
	var gap := 1.6 if _close else 3.0
	for i in YAWS.size():
		var robot := RobotModel.new().setup(Characters.body(_character), _color, false, _weapon)
		root.add_child(robot)
		robot.position = Vector3((1 - i) * gap, 0, 0)
		robot.rotation_degrees.y = YAWS[i]
		var trail := SwingTrail.new().setup(RobotModel.trim_color(_color))
		root.add_child(trail)
		_robots.append([robot, RobotAnimator.new(robot), trail])
	_inp.state = MovementController.State.GROUND
	var data := WeaponData.by_id(_weapon)
	var rest := MeleeSwing.new(_weapon).length() + 0.25
	_plan.append([0.3, "idle", 0])
	for blow in _blows:
		var side := 1 if blow == "b" else 0
		_plan.append([data.charge_time + 0.25 if blow == "heavy" else data.windup, "wind", side])
		_plan.append([rest, "swing", side])
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _warm > 0:   # let the first frames settle (shadows, the idle pose)
		_warm -= 1
		_advance(1.0 / 60.0, false)
		return false
	_frame += 1
	root.get_texture().get_image().save_png("%s/f_%04d.png" % [_out, _frame])
	if _at >= _plan.size():
		var f := FileAccess.open(_out + "/marks.txt", FileAccess.WRITE)
		f.store_string("\n".join(_marks) + "\n")
		print("saved %d frames in %s" % [_frame, _out])
		return true
	_advance(_step, true)
	return false


func _advance(dt: float, run: bool) -> void:
	var data := WeaponData.by_id(_weapon)
	var part: Array = _plan[mini(_at, _plan.size() - 1)]
	var let_go := false
	if run:
		if part[1] == "swing" and _t == 0.0:
			let_go = true
			_marks.append("%s %d %d" % [_blows[(_at - 1) / 2], _frame + 1, int(round(MeleeSwing.impact_time(_weapon) / _step))])
		_t += dt
	for r in _robots:
		var robot: RobotModel = r[0]
		var animator: RobotAnimator = r[1]
		var trail: SwingTrail = r[2]
		_inp.yaw = robot.global_rotation.y
		if run and part[1] == "wind":
			animator.wind(data.charge_of(_t), part[2])
		elif let_go:
			var power := data.charge_of(_plan[_at - 1][0])
			animator.swing(power, part[2])
			trail.power = power
		animator.update(dt, _inp, robot.global_transform)
		if animator.cutting() and robot.melee:
			var e := MeleeModel.edge(robot.melee)
			trail.add(e[0], e[1])
		trail.tick(dt)
	if run and _t >= part[0]:
		_t = 0.0
		_at += 1
