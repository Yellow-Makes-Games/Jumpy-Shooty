extends SceneTree
## Renders the portrait banner (the character on its stage in the lobby and the
## Character Creator) with the game's real renderer, to look at it without opening the
## game. Used by tools/portrait_preview.sh.
##
##   godot --rendering-driver vulkan --path . --script tools/portrait_preview.gd -- \
##       --out=DIR [--tag=after] [--size=2560x1440] [--quality=high] [--character=needle]
##       [--color=13] [--weapon=pistol] [--shape=lobby|creator] [--hold=front|low|side|flourish]
##       [--at=2.0,4.0] [--frames=N --fps=30] [--switch=SEC:ID] [--drag=SEC:RADIANS]
##       [--do=SEC:ACTION[:VALUE]]...
##
## --at: when to take each picture (seconds). --frames: instead, N pictures in a row at
## --fps (frame_0000.png...), for a clip. --switch: put another character on the stage
## at SEC (it builds in). --drag: turn the character by hand at SEC.
## --do (as many as you like, for a clip; they also stop the holds changing by themselves):
## hold:front|low|side (go to a hold), flourish, switch:ID, weapon:ID,
## drag:RADIANS (turn it by hand, over a second) and release (let go).
##
## (The game's own scripts are loaded by path once the game is up: a tool script is
## compiled before the autoloads they use exist.)

var _frame: Control   # a PortraitFrame
var _times: Array = [2.0]
var _out := "."
var _tag := "shot"
var _clock := 0.0
var _shot := 0
var _frames := 0
var _fps := 30.0
var _switch := []     # [seconds, id]
var _drag := []       # [seconds, radians]
var _color := Color.WHITE
var _weapon := "pistol"
var _hold := ""
var _warm := 6
var _events := []     # [seconds, action, value]
var _drag_from := 0.0
var _drag_to := 0.0
var _drag_t := -1.0


func _initialize() -> void:
	var size := Vector2i(2560, 1440)
	var quality := ""
	var character := "needle"
	var color := 13
	var shape := "lobby"
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--out="): _out = v
		elif arg.begins_with("--tag="): _tag = v
		elif arg.begins_with("--size="): size = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
		elif arg.begins_with("--quality="): quality = v
		elif arg.begins_with("--character="): character = arg.substr(12)
		elif arg.begins_with("--color="): color = int(v)
		elif arg.begins_with("--weapon="): _weapon = v
		elif arg.begins_with("--shape="): shape = v
		elif arg.begins_with("--hold="): _hold = v
		elif arg.begins_with("--at="): _times = Array(v.split(",")).map(func(s): return float(s))
		elif arg.begins_with("--frames="): _frames = int(v)
		elif arg.begins_with("--fps="): _fps = float(v)
		elif arg.begins_with("--switch="): _switch = [float(v.get_slice(":", 0)), arg.substr(arg.find(":") + 1)]
		elif arg.begins_with("--drag="): _drag = [float(v.get_slice(":", 0)), float(v.get_slice(":", 1))]
		elif arg.begins_with("--do="): _events.append([float(v.get_slice(":", 0)), v.get_slice(":", 1), v.substr(v.find(":", v.find(":") + 1) + 1)])
	root.size = size
	DisplayServer.window_set_size(size)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var settings: Node = root.get_node("Settings")
	var graphics: Script = load("res://game/core/graphics_quality.gd")
	if quality != "":
		settings.call("set_quality", quality)
		graphics.apply_viewport(root, graphics.preset(quality))
		graphics.apply_global(graphics.preset(quality))
		_tag += "_" + quality
	var back := ColorRect.new()
	back.color = Color(0.035, 0.05, 0.075)   # about what the lobby's panel is behind the banner
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var stage := Vector2(360, 292) if shape == "lobby" else Vector2(360, 440)
	var characters: Script = load("res://game/player/robot/characters.gd")
	_frame = load("res://game/ui/portrait_frame.gd").new(stage, 1.0 if shape == "lobby" else 0.95)
	_frame.position = Vector2(40, 40)
	_frame.size = stage
	_frame.kicker = "UNIT 1 / 8" if shape == "lobby" else "CUSTOM UNIT"
	_frame.title = characters.name_of(characters.valid(character)).to_upper()
	root.add_child(_frame)
	var colors: Array = root.get_node("Net").PLAYER_COLORS
	_color = colors[color % colors.size()]
	_frame.preview.show_robot(character, _color, _weapon)
	var poser = _frame.preview._poser
	match _hold:
		"front": poser.snap(0)
		"low": poser.snap(1)
		"side": poser.snap(2)
		"flourish": poser.flourish_now()


func _process(delta: float) -> bool:
	if _warm > 0:
		_warm -= 1
		return false
	_clock += delta
	if not _switch.is_empty() and _clock >= _switch[0]:
		var characters: Script = load("res://game/player/robot/characters.gd")
		_frame.title = characters.name_of(characters.valid(_switch[1])).to_upper()
		_frame.preview.show_robot(_switch[1], _color, _weapon, true)
		_switch = []
	if not _drag.is_empty() and _clock >= _drag[0]:
		_frame.preview.drag = _drag[1]
		_frame.preview.held = true
		_drag = []
	_run_events(delta)
	if _frames > 0:
		_save("%s/frame_%04d.png" % [_out, _shot])
		_shot += 1
		return _shot >= _frames
	if _shot < _times.size() and _clock >= _times[_shot]:
		_save("%s/%s_%d.png" % [_out, _tag, _shot])
		_shot += 1
	return _shot >= _times.size()


func _run_events(delta: float) -> void:
	var preview = _frame.preview
	if not _events.is_empty():
		preview._poser._left = 999.0   # the holds change when told to
	for e in _events.duplicate():
		if _clock < e[0]:
			continue
		_events.erase(e)
		var poser = preview._poser
		match e[1]:
			"hold":
				poser.hold = ["front", "low", "side"].find(e[2])
			"flourish":
				poser.hold = poser._home()
				poser._next = poser._home()
			"switch":
				var characters: Script = load("res://game/player/robot/characters.gd")
				_frame.title = characters.name_of(characters.valid(e[2])).to_upper()
				preview.show_robot(e[2], _color, _weapon, true)
			"weapon":
				_weapon = e[2]
				preview.show_robot(preview.character, _color, _weapon)
			"drag":
				_drag_from = preview.drag
				_drag_to = float(e[2])
				_drag_t = 0.0
				preview.held = true
			"release":
				preview.held = false
				_frame._idle = 0.0
		_events.append([INF, "", ""])   # (keeps the holds from changing by themselves to the end)
	if _drag_t >= 0.0:
		_drag_t = minf(_drag_t + delta, 1.0)
		preview.drag = lerpf(_drag_from, _drag_to, smoothstep(0.0, 1.0, _drag_t))
		if _drag_t >= 1.0:
			_drag_t = -1.0


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	var k := float(root.size.x) / 1600.0
	var r := Rect2i(Vector2i((_frame.position - Vector2(12, 12)) * k), Vector2i((_frame.size + Vector2(24, 24)) * k))
	image.get_region(r).save_png(path)
	print("saved ", path, "  (3D drawn at ", _frame.preview.view.size, ", ", snappedf(_frame.preview.pixel_factor(), 0.01), " pixels a unit)")
