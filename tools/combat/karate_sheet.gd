extends SceneTree
## A picture sheet of Karate's gear and aura (KarateGear): a row per body, at rest,
## half wound up and fully wound up, so the fit and the aura can be checked on every
## kind of body without opening the game. Used by tools/combat/karate_sheet.sh.
##
##   godot --path . --script tools/combat/karate_sheet.gd -- --out=FILE.png
##       [--bodies=vanguard,needle,...] (robot ids, or custom:... ids) [--close] (fists and shins, close up)
##       [--color=r,g,b] [--yaw=DEG] [--frames=N] (frames to settle and let the sparks fill in)

const STAGES := [0.0, 0.5, 1.0]   ## how far wound up, per column

var _out := "karate_sheet.png"
var _bodies := ["vanguard", "needle", "bulwark", "custom:l=rex|t=rex|h=rex", "custom:l=frog|t=yeti|h=duck"]
var _close := false
var _color := Color(0.95, 0.35, 0.25)
var _yaw := 25.0
var _frames := 120
var _robots: Array = []   # [RobotModel, RobotAnimator, stage]
var _inp := RobotAnimInput.new()
var _frame := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--bodies="):
			_bodies = Array(arg.substr(9).split(","))
		elif arg == "--close":
			_close = true
		elif arg.begins_with("--yaw="):
			_yaw = float(arg.substr(6))
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -150, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var gap_x := 1.3 if _close else 1.6
	var gap_y := 1.15 if _close else 2.25
	for row in _bodies.size():
		for col in STAGES.size():
			var robot := RobotModel.new().build(_bodies[row], _color, false, "karate")
			root.add_child(robot)
			robot.position = Vector3((1 - col) * gap_x, -row * gap_y - (0.35 if _close else 0.0), 0)
			robot.rotation_degrees.y = _yaw
			_robots.append([robot, RobotAnimator.new(robot), STAGES[col]])
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var rows := _bodies.size()
	# From the front and a little above; the rows stacked down the picture.
	camera.size = gap_y * rows
	var mid := Vector3(0, (0.95 if not _close else 0.55) - (rows - 1) * gap_y * 0.5, 0)
	camera.look_at_from_position(mid + Vector3(0, 2.0, -14.0), mid)
	camera.make_current()
	_inp.state = MovementController.State.GROUND


func _process(delta: float) -> bool:
	_frame += 1
	for r in _robots:
		var robot: RobotModel = r[0]
		var animator: RobotAnimator = r[1]
		var stage: float = r[2]
		_inp.yaw = robot.rotation.y
		if stage > 0.0 and _frame > 10:
			animator.wind(stage, 0)
		animator.update(1.0 / 60.0, _inp, robot.global_transform)
	if _frame >= _frames:
		root.get_texture().get_image().save_png(_out)
		print("saved " + _out)
		return true
	return false
