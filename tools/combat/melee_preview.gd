extends SceneTree
## Renders a melee weapon on its own, to check its looks without opening the game:
## the broad face, a three-quarter view and edge-on side by side, then the hilt close up.
## Used by tools/combat/melee_preview.sh.
##
##   godot --path . --script tools/combat/melee_preview.gd -- --weapon=sword --out=DIR [--color=r,g,b]

var _weapon := "sword"
var _out := "."
var _color := Color(0.95, 0.35, 0.25)
var _shot := -1
var _wait := 0
var _camera: Camera3D
var _shots := []   # [file, camera position, look at, ortho height]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			_weapon = arg.substr(9)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 28, 0)
	sun.light_energy = 1.15
	root.add_child(sun)
	_camera = Camera3D.new()
	root.add_child(_camera)
	_camera.make_current()
	var yaws := [90.0, 50.0, 0.0]   # the blade's flat (or the hammer's side), three-quarter, face on
	var box := AABB()
	for i in 3:
		var w := MeleeModel.build(_weapon, RobotModel.trim_color(_color))
		if i == 0:
			for c in w.get_children():
				if c is MeshInstance3D:
					box = c.get_aabb() if box.size == Vector3.ZERO else box.merge(c.get_aabb())
		w.position = Vector3((i - 1) * maxf(maxf(box.size.x, box.size.z) * 1.5, box.size.y * 0.3), 0, 0)
		w.rotation_degrees.y = yaws[i]
		root.add_child(w)
	var mid := box.get_center().y
	var far := maxf(box.size.y, 0.3)
	_shots = [
		["%s/%s_views.png" % [_out, _weapon], Vector3(0, mid, 6), Vector3(0, mid, 0), far * 1.15],
		["%s/%s_close.png" % [_out, _weapon], Vector3(0.3, mid + far * 0.2, 0.9).normalized() * far * 0.9 + Vector3(0, box.end.y - far * 0.3, 0),
			Vector3(0, box.end.y - minf(far * 0.3, 0.25), 0), 0.0],
	]


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _shot >= 0:
		root.get_texture().get_image().save_png(_shots[_shot][0])
		print("saved ", _shots[_shot][0])
	_shot += 1
	if _shot >= _shots.size():
		return true
	var s: Array = _shots[_shot]
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if s[3] > 0.0 else Camera3D.PROJECTION_PERSPECTIVE
	if s[3] > 0.0:
		_camera.size = s[3]
	else:
		_camera.fov = 40.0
	_camera.look_at_from_position(s[1], s[2])
	_wait = 4
	return false
