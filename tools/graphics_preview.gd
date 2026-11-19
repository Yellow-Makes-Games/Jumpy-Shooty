extends SceneTree
## Renders a map the way a player sees it, with the game's real renderer (Forward+,
## through Vulkan), to compare graphics settings. Used by tools/graphics_preview.sh.
##
##   godot --rendering-driver vulkan --path . --script tools/graphics_preview.gd -- \
##       --map=ID --out=DIR [--tag=before] [--quality=high] [--spawns=0,3] [--size=1280x720]
##
## Each shot stands at a spawn point at eye height, facing the way the spawn faces, with
## a robot a few metres ahead so its edges show how well anti-aliasing works. One more
## shot looks at the whole map from a corner. --quality picks a GraphicsQuality preset
## (low, medium, high, ultra); left out, the project's own settings are used (on a
## branch without GraphicsQuality, that is what the game looked like before).

const EYE := 1.7

var _map: MapRoot
var _camera: Camera3D
var _robot: Node3D
var _shots: Array = []   # [name, Transform3D]
var _shot := -1
var _wait := 0
var _out := "."
var _tag := "shot"
var _prefix := "map"
var _spawns: Array = []


func _initialize() -> void:
	var map_id := ""
	var size := Vector2i(1280, 720)
	var quality := ""
	var spawns := [0, 2]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--quality="):
			quality = arg.substr(10)
		elif arg.begins_with("--spawns="):
			spawns = Array(arg.substr(9).split(",")).map(func(s): return int(s))
		elif arg.begins_with("--size="):
			size = Vector2i(int(arg.substr(7).get_slice("x", 0)), int(arg.substr(7).get_slice("x", 1)))
	_map = Maps.make(map_id) if Maps.has(map_id) else null
	if _map == null:
		push_error("graphics_preview: give --map=ID (one of %s)" % ", ".join(Maps.ids()))
		quit(1)
		return
	_prefix = map_id
	root.size = size
	DisplayServer.window_set_size(size)
	root.add_child(_map)
	_map.build()
	for label in _map.find_children("*", "Label3D", true, false):
		label.visible = false
	if quality != "":
		_use_quality(quality)
	_camera = Camera3D.new()
	_camera.far = 600.0
	_camera.fov = 75.0   # about what the game's 95 degree horizontal field of view gives at 16:9
	root.add_child(_camera)
	_camera.make_current()
	_spawns = spawns
	_robot = RobotModel.new().build(Characters.default_id(), Color(0.95, 0.35, 0.2), false, "pistol")
	root.add_child(_robot)
	var rig = _robot.rig
	var pose = rig.new_pose()
	rig.sample(pose, "idle", 0.0)
	pose.apply(_robot.skeleton)
	_wait = 10


## Puts a preset on the window the way the game does (GraphicsQuality, when this
## branch has it).
func _use_quality(id: String) -> void:
	var script: Script = null
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "GraphicsQuality":
			script = load(c["path"])
	if script == null:
		push_error("graphics_preview: this branch has no GraphicsQuality, so --quality does nothing")
		return
	_prefix += "_" + id
	var picks: Dictionary = script.preset(id)
	script.apply_viewport(root, picks)
	script.apply_global(picks)
	for world in _map.find_children("*", "WorldEnvironment", true, false):
		if (world as WorldEnvironment).environment:
			script.apply_environment((world as WorldEnvironment).environment, picks)


func _process(_delta: float) -> bool:
	if _map == null:
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _shots.is_empty():
		_plan_shots()
	if _shot >= 0:
		var path := "%s/%s_%s_%s.png" % [_out, _prefix, _shots[_shot][0], _tag]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	_shot += 1
	if _shot >= _shots.size():
		return true
	var t: Transform3D = _shots[_shot][1]
	_camera.global_transform = t
	# The robot stands a few metres ahead and a little to the right, facing the camera.
	var ahead := -t.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right := ahead.cross(Vector3.UP)
	_robot.visible = _shots[_shot][0] != "aerial"
	_robot.global_position = t.origin - Vector3.UP * EYE + ahead * 3.4 + right * 0.9
	_robot.look_at(t.origin - Vector3.UP * EYE, Vector3.UP)
	_wait = 8
	return false


## Where each shot stands (once the map is in the tree, so its spawns have places).
func _plan_shots() -> void:
	var points := _map.get_node_or_null("Spawns")
	var markers: Array = points.get_children() if points else []
	for i in _spawns:
		if i < markers.size():
			var t := (markers[i] as Node3D).global_transform
			t.origin += Vector3.UP * EYE
			_shots.append(["spawn%d" % i, t])
	var corner := Transform3D(Basis(), Vector3(-60, 45, 70))
	_shots.append(["aerial", corner.looking_at(Vector3(0, 4, 0))])
