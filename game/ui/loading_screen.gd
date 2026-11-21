class_name LoadingScreen
extends CanvasLayer
## Covers the screen while a map loads: the map's name, a bar sweeping along, and
## your robot running in the bottom-right corner. The arena builds the map a little
## each frame (see MapBuildBudget), so this keeps moving the whole time. Game puts it
## up and takes it down.

const ROBOT_SIZE := Vector2(300, 340)

var _dots: Label
var _robot: RobotPreview
var _who: Array   # [character, colour, weapon], shown once in the tree
var _time := 0.0


static func make(map_name: String, character: String, color: Color, weapon: String) -> LoadingScreen:
	var s := LoadingScreen.new()
	s.layer = 100   # above the HUD and every menu
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	s._dots = _label("LOADING", 20, UiKit.ACCENT)
	box.add_child(s._dots)
	box.add_child(_label(map_name.to_upper(), 52, UiKit.TEXT))
	var bar := _Sweep.new()
	bar.custom_minimum_size = Vector2(320, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)

	# Your robot, running on the spot over streaks of floor rushing past.
	var corner := Control.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -ROBOT_SIZE.x - 24
	corner.offset_top = -ROBOT_SIZE.y - 12
	corner.offset_right = -24
	corner.offset_bottom = -12
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(corner)
	var streaks := _Streaks.new()
	streaks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.add_child(streaks)
	var robot := RobotPreview.new(ROBOT_SIZE, 1.1)
	robot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	robot.clip = "sprint"
	robot.turn = false
	robot.facing = deg_to_rad(50.0)   # (on top of its usual 200 degrees) running to the right, turned a little toward you
	corner.add_child(robot)
	s._robot = robot
	s._who = [character, color, weapon]
	return s


func _ready() -> void:
	_robot.show_robot(_who[0], _who[1], _who[2])


func _process(delta: float) -> void:
	_time += delta
	_dots.text = "LOADING" + ".".repeat(int(_time * 3.0) % 4)


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A thin track with a bright stretch sweeping along it, over and over.
class _Sweep extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t = fmod(_t + delta * 0.8, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.LINE)
		var w := size.x * 0.3
		var x := lerpf(-w, size.x, ease(_t, -1.8))
		var from := maxf(x, 0.0)
		var to := minf(x + w, size.x)
		if to > from:
			draw_rect(Rect2(from, 0, to - from, size.y), UiKit.ACCENT)


## Lines of floor rushing past under the robot's feet, so it looks like it is going somewhere.
class _Streaks extends Control:
	const LINES := 7
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var floor_y := size.y * 0.93
		draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), UiKit.LINE, 2.0)
		for i in LINES:
			var speed := 420.0 + 90.0 * (i % 3)
			var length := 30.0 + 18.0 * ((i * 5) % 4)
			var y := floor_y - 6.0 - 26.0 * ((i * 3) % LINES)
			var x := size.x - fposmod(_t * speed + i * 137.0, size.x + length)
			var c := UiKit.CYAN
			c.a = 0.12 + 0.05 * (i % 3)
			draw_line(Vector2(x, y), Vector2(x + length, y), c, 2.0)
