extends SceneTree
## Renders pictures of a map without opening the game: an aerial view from each
## corner and a top-down plan. Used by tools/map_preview.sh.
##
##   godot --path . --script tools/map_preview.gd -- --map=ID --out=DIR
##       [--shots=sw;ne;top] [--size=1600x900] [--span=92] [--no-signs] [--layout=1]
##
## ID is a map id from game/arena/maps.gd (construction_site) or a map scene's path
## (res://game/maps/my_map.tscn).
##
## Shots (separated by ";"): a corner or side to look from (sw, se, nw, ne, s, n, e,
## w), "top" (a plan), "cutY" (a plan with everything above height Y sliced off, to
## see one floor), or a camera "x,y,z:lx,ly,lz[:fov]" (position : look-at). --span is how
## many metres a plan shows from top to bottom (92; a 140 m map needs about 150).
## --layout is for a map with two layouts (a LayoutEvent: Cirrus): 0 its first, 1 its
## second, anything between a moment part-way through the move from the first to the
## second (0.5 = half time). The pictures' names end in _layoutN.

var _map: MapRoot
var _camera: Camera3D
var _shots: Array = []
var _shot := -1
var _wait := 0
var _out := "."
var _prefix := "map"
var _span := 92.0
var _layout := 0.0

const CORNERS := {
	"sw": Vector3(-74, 70, 84), "se": Vector3(74, 70, 84),
	"nw": Vector3(-74, 70, -84), "ne": Vector3(74, 70, -84),
	"s": Vector3(0, 60, 88), "n": Vector3(0, 60, -88), "e": Vector3(88, 60, 0), "w": Vector3(-88, 60, 0),
}


func _initialize() -> void:
	var map_path := ""
	var shots := "sw;ne;top"
	var size := Vector2i(1600, 900)
	var show_signs := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_path = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--shots="):
			shots = arg.substr(8)
		elif arg.begins_with("--size="):
			size = Vector2i(int(arg.substr(7).get_slice("x", 0)), int(arg.substr(7).get_slice("x", 1)))
		elif arg.begins_with("--span="):
			_span = float(arg.substr(7))
		elif arg == "--no-signs":
			show_signs = false
		elif arg.begins_with("--layout="):
			_layout = float(arg.substr(9))
	if map_path.begins_with("res://"):
		var scene := load(map_path) as PackedScene
		_map = scene.instantiate() as MapRoot if scene else null
	elif Maps.has(map_path):
		_map = Maps.make(map_path)
	if _map == null:
		push_error("map_preview: give --map=ID (one of %s) or --map=res://...tscn (a map scene)" % ", ".join(Maps.ids()))
		quit(1)
		return
	_prefix = map_path.get_file().get_basename()
	root.size = size
	DisplayServer.window_set_size(size)
	root.add_child(_map)
	_map.build()
	if _layout > 0.0:
		_pose_layout()
	if not show_signs:
		for label in _map.find_children("*", "Label3D", true, false):
			label.visible = false
	_camera = Camera3D.new()
	_camera.far = 600.0
	root.add_child(_camera)
	_camera.make_current()
	for s in shots.split(";"):
		_shots.append(s)


func _process(_delta: float) -> bool:
	if _map == null:
		return true
	if _layout > 0.0:
		_hold_layout()
	if _wait > 0:
		_wait -= 1
		return false
	if _shot >= 0:
		var path := "%s/%s_%s.png" % [_out, _prefix, _name(_shot)]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	_shot += 1
	if _shot >= _shots.size():
		return true
	_aim(_shots[_shot])
	_wait = 4
	return false


## Puts a two-layout map in its second layout, or part-way through the move there.
func _pose_layout() -> void:
	_prefix += "_layout%s" % str(_layout).replace(".", "")
	_wait = 12   # (a few frames for the parts to get there)


## Every frame: holds the layout event at the moment asked for (its own clock would run on).
func _hold_layout() -> void:
	for node in _map.find_children("*", "", true, false):
		var event := node as LayoutEvent
		if event == null:
			continue
		event.set_physics_process(false)
		event.state = 1
		event.running = _layout < 1.0
		event.elapsed = _layout * event.move_time if _layout < 1.0 else 0.0
		event._place()


func _name(i: int) -> String:
	return _shots[i] if CORNERS.has(_shots[i]) or _shots[i] == "top" or _shots[i].begins_with("cut") else "cam%d" % i


func _aim(shot: String) -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 33.0
	if shot == "top" or shot.begins_with("cut"):
		# "cutY" is a plan with everything above height Y sliced off (to see one floor).
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = _span
		_camera.near = 0.05
		_camera.position = Vector3(0, 200.0 if shot == "top" else float(shot.substr(3)), 0)
		_camera.rotation_degrees = Vector3(-90, 0, 0)
	elif CORNERS.has(shot):
		_camera.position = CORNERS[shot]
		_camera.look_at(Vector3(0, 8, 0))
	else:
		var parts := shot.split(":")
		_camera.position = _v(parts[0])
		_camera.look_at(_v(parts[1]))
		if parts.size() > 2:
			_camera.fov = float(parts[2])


func _v(text: String) -> Vector3:
	var c := text.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))
