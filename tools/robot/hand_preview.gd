extends SceneTree
## Renders close-ups of a robot's hands, to check their shape, their poses and how they
## hold a weapon without opening the game. Used by tools/robot/hand_sheet.py.
##
##   godot --path . --script tools/robot/hand_preview.gd -- --job=JOB.json
##
## JOB.json: {"shots": [{"out": "a.png", "size": [480, 480], "character": "vanguard",
##   "weapon": "none" | a weapon id,
##   "hand": "open" (a pose in rig.HANDS: both hands held that way, arms out in front;
##            left out: the robot stands holding its weapon as it does in the game),
##   "bone": "hand_r" (what to look at), "aim": [x,y,z] (moved by this, in the robot's own space),
##   "from": [x,y,z] (the camera, from that point), "ortho": 0.3 (metres of height in the picture),
##   "dist": 3.0 (metres from the camera to what it looks at: closer, to get in front of the body)}]}

var _job := {}
var _shot := -1
var _wait := 0
var _camera: Camera3D
var _holder: Node3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(arg.substr(6)))
			if parsed is Dictionary:
				_job = parsed
	if not _job.has("shots"):
		push_error("hand_preview: no job file, or it has no shots")
		quit(1)
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.02
	root.add_child(_camera)
	_camera.make_current()
	var sun := DirectionalLight3D.new()   # rides on the camera: the hand is lit from over the viewer's shoulder
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.0
	_camera.add_child(sun)
	_holder = Node3D.new()
	root.add_child(_holder)


func _process(_delta: float) -> bool:
	if not _job.has("shots"):
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _shot >= 0:
		root.get_texture().get_image().save_png(_job.shots[_shot].out)
		print("saved ", _job.shots[_shot].out)
	_shot += 1
	if _shot >= _job.shots.size():
		return true
	_set_up(_job.shots[_shot])
	_wait = 3
	return false


func _set_up(shot: Dictionary) -> void:
	for c in _holder.get_children():
		c.queue_free()
	var size: Array = shot.get("size", [480, 480])
	root.size = Vector2i(size[0], size[1])
	DisplayServer.window_set_size(Vector2i(size[0], size[1]))
	var robot := RobotModel.new().build(shot.get("character", "vanguard"), Color(0.95, 0.35, 0.25), false, shot.get("weapon", "none"))
	_holder.add_child(robot)
	if shot.has("hand"):
		var pose := robot.rig.new_pose()
		# The arms held out in front, bent at the elbow, so the hands are clear of the body.
		for side in ["l", "r"]:
			pose.rot[robot.rig.bones["upper_arm_" + side]] = Quaternion(Vector3.RIGHT, deg_to_rad(35.0))
			pose.rot[robot.rig.bones["forearm_" + side]] = Quaternion(Vector3.RIGHT, deg_to_rad(75.0))
		Hands.set_hand(pose, robot.rig, shot.hand, 1.0, false)
		Hands.set_hand(pose, robot.rig, shot.hand, 1.0, true)
		pose.apply(robot.skeleton)
	else:
		var animator := RobotAnimator.new(robot)
		var inp := RobotAnimInput.new()
		inp.state = MovementController.State.GROUND
		for i in 40:
			animator.update(1.0 / 60.0, inp, robot.global_transform)
	var bone: String = shot.get("bone", "hand_r")
	var at: Vector3 = robot.marker(bone) + _v(shot.get("aim", [0, 0, 0]))
	_camera.size = shot.get("ortho", 0.3)
	_camera.look_at_from_position(at + _v(shot.get("from", [1, 0, -1])).normalized() * float(shot.get("dist", 3.0)), at)


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
