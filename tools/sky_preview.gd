extends SceneTree
## Renders a map's sky the way a player sees it, with the game's real renderer (Forward+
## on Vulkan, in software where there is no GPU). Used by tools/sky_preview.sh.
##
##   godot --rendering-driver vulkan --path . --script tools/sky_preview.gd -- \
##       --map=ID --out=DIR [--sky=res://...tres] [--views=sun;away;up] [--tag=after]
##       [--size=1280x720] [--clip=SECONDS] [--fps=12] [--still]
##
## --map is a map id (game/arena/maps.gd), or "stage": an open floor with a robot on it,
## to look at a sky preset on its own (give --sky). --sky puts a SkyPreset on the map in
## place of its own. Views stand at the map's first spawn, at eye height:
##   sun    toward the sun, a little above the horizon
##   away   the other way
##   up     looking well up into the sky
##   aerial from high over one side of the map, looking across it to the far horizon
##   skyward from the same place, looking out away from the map
##   yaw,pitch  any heading (degrees from north toward east, degrees up)
## --clip renders that many seconds of one view (the first) as numbered frames, for a
## video (run with --fixed-fps so time in the sky runs at the frame rate).
## --still shows the still sky (the Low graphics preset).

const EYE := 1.6

var _map: Node3D
var _camera: Camera3D
var _out := "."
var _prefix := ""
var _tag := "after"
var _views: Array = []
var _shot := -1
var _wait := 0
var _clip := 0.0
var _fps := 12
var _frame := 0
var _frames := 0


func _initialize() -> void:
	var map_id := ""
	var sky := ""
	var views := "sun;away;up"
	var size := Vector2i(1280, 720)
	var still := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--sky="):
			sky = arg.substr(6)
		elif arg.begins_with("--views="):
			views = arg.substr(8)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--size="):
			size = Vector2i(int(arg.substr(7).get_slice("x", 0)), int(arg.substr(7).get_slice("x", 1)))
		elif arg.begins_with("--clip="):
			_clip = float(arg.substr(7))
		elif arg.begins_with("--fps="):
			_fps = int(arg.substr(6))
		elif arg == "--still":
			still = true
	root.size = size
	DisplayServer.window_set_size(size)
	if map_id == "stage":
		_map = _stage()
		_prefix = "stage"
	else:
		_map = Maps.make(map_id) if Maps.has(map_id) else null
		_prefix = map_id
	if _map == null:
		push_error("sky_preview: give --map=ID (one of %s) or --map=stage" % ", ".join(Maps.ids()))
		quit(1)
		return
	if sky != "":
		_prefix += "_" + sky.get_file().get_basename()
		if "sky" in _map:
			_map.sky = load(sky)
	root.add_child(_map)
	if _map.has_method("build"):
		_map.build()
	for label in _map.find_children("*", "Label3D", true, false):
		label.visible = false
	if still:
		_prefix += "_still"
		for rig in get_nodes_in_group("sky_rig"):
			rig.motion = false
	_camera = Camera3D.new()
	_camera.far = 900.0
	_camera.fov = 80.0
	root.add_child(_camera)
	_camera.make_current()
	_views = Array(views.split(";"))
	_wait = 12


## An open floor, a sun and a robot: a sky preset on its own.
func _stage() -> Node3D:
	var script := load("res://game/arena/map_root.gd")
	var stage: Node3D = script.new()
	stage.name = "Stage"
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.glow_enabled = true
	env.ssao_enabled = true
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.basis = Basis.looking_at(-Vector3(0.45, 0.42, -0.79).normalized())
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.56, 0.58)
	mat.roughness = 0.8
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	for i in 4:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2, 1.5 + i, 2)
		box.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.85, 0.5, 0.25), Color(0.3, 0.55, 0.8), Color(0.75, 0.75, 0.72), Color(0.45, 0.7, 0.4)][i]
		m.roughness = 0.55
		box.material_override = m
		box.position = Vector3(-7 + i * 4.5, bm.size.y * 0.5, -9 - (i % 2) * 3)
		stage.add_child(box)
	var robot = RobotModel.new().build(Characters.default_id(), Color(0.95, 0.35, 0.2), false, "pistol")
	stage.add_child(robot)
	robot.position = Vector3(0.9, 0, -3.4)
	robot.rotation.y = PI
	return stage


func _process(_delta: float) -> bool:
	if _map == null:
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _clip > 0.0:
		return _clip_step()
	if _shot >= 0:
		var path := "%s/%s_%s_%s.png" % [_out, _prefix, _views[_shot], _tag]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	_shot += 1
	if _shot >= _views.size():
		return true
	_camera.global_transform = _view(str(_views[_shot]))
	_wait = 10
	return false


func _clip_step() -> bool:
	if _frames == 0:
		_frames = int(_clip * _fps)
		_camera.global_transform = _view(str(_views[0]))
		_wait = 4
		return false
	var path := "%s/%s_clip_%04d.png" % [_out, _prefix, _frame]
	root.get_texture().get_image().save_png(path)
	_frame += 1
	if _frame >= _frames:
		print("saved %d frames" % _frames)
		return true
	return false


## Where a view stands and looks.
func _view(name: String) -> Transform3D:
	var at := Vector3(0, EYE, 0)
	var spawns := _map.get_node_or_null("Spawns")
	if spawns and spawns.get_child_count() > 0:
		at = (spawns.get_child(0) as Node3D).global_position + Vector3.UP * EYE
	elif _map.name == "Stage":
		at = Vector3(0, EYE, 2.0)
	var sun := _map.get_node_or_null("Sun") as DirectionalLight3D
	var to_sun := sun.global_basis.z if sun else Vector3(0, 0.5, -1)
	var flat := Vector3(to_sun.x, 0, to_sun.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	if name == "aerial" or name == "skyward":
		var middle := Vector3.ZERO
		var reach := 60.0
		if "bounds" in _map and (_map.bounds as Rect2).has_area():
			var b: Rect2 = _map.bounds
			middle = Vector3(b.get_center().x, 0, b.get_center().y)
			reach = clampf(maxf(b.size.x, b.size.y) * 0.45, 30.0, 120.0)
		if "swing_point" in _map:
			middle.y = _map.swing_point.y
		var from := middle - flat * reach + Vector3.UP * (reach * 0.35 + 8.0)
		if name == "aerial":
			return Transform3D(Basis.looking_at((middle - from).normalized()), from)
		var out := (-flat * cos(deg_to_rad(6.0)) + Vector3.UP * sin(deg_to_rad(6.0))).normalized()
		return Transform3D(Basis.looking_at(out), from)
	var look := flat
	var pitch := 8.0
	match name:
		"sun":
			look = flat
		"away":
			look = -flat
		"up":
			look = flat.rotated(Vector3.UP, 2.2)
			pitch = 38.0
		_:
			var yaw := deg_to_rad(float(name.get_slice(",", 0)))
			pitch = float(name.get_slice(",", 1))
			look = Vector3(sin(yaw), 0, -cos(yaw))
	var dir := (look * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))).normalized()
	return Transform3D(Basis.looking_at(dir), at)
