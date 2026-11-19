class_name PortraitFrame
extends Control
## The portrait banner in the lobby and the Character Creator: a dark plate with a
## character on a lit stage (RobotPreview, staged), a small line and its name in the
## top left corner, and brackets round the lot. The name never reaches the character:
## a long one is written smaller, so it ends short of the head. Drag the character to
## turn it round; a couple of seconds after you let go it turns back to face you.
##
## The screens using it add what they need on top (arrows, a colour swatch).

const HEAD_ROOM := 30.0    ## the character's head (or hat) comes no nearer the top than this (canvas pixels)
const FLOOR_ROOM := 18.0   ## ...and the front of the ring under it no nearer the bottom
const BODY_SHARE := 0.8    ## the name keeps clear of this much of the character's width (its shoulders are below the name)...
const HEAD_HALF := 0.27    ## ...and of at least this many metres either side of the middle (a head, a hat's brim)
const BODY_HALF := 0.42    ## ...and no more than this
const TITLE_SIZE := 28     ## the name's size, and the smallest it is written to fit
const TITLE_MIN := 15
const KICKER_SIZE := 11
const KICKER_MIN := 8
const TURN := 0.011        ## radians a character turns for each pixel it is dragged
const BACK_AFTER := 2.0    ## seconds after letting go before it turns back
const BACK_SPEED := 3.5    ## how quickly it turns back (per second, eased)

var preview: RobotPreview
var kicker := "":          ## the small line above the name ("UNIT 1 / 8")
	set(v):
		kicker = v
		_text.queue_redraw()
var title := "":           ## the name
	set(v):
		title = v
		_text.queue_redraw()
var kicker_color := Color(UiKit.CYAN, 0.9):
	set(v):
		kicker_color = v
		_text.queue_redraw()
var bracket_color := Color(1, 1, 1, 0.25):
	set(v):
		bracket_color = v
		_text.queue_redraw()

var _text: Control
var _dragging := false
var _idle := 0.0   # seconds since the character was let go


func _init(stage_size: Vector2, zoom: float = 1.0) -> void:
	custom_minimum_size = stage_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview = RobotPreview.new(stage_size, zoom, true)
	preview.custom_minimum_size = Vector2.ZERO   # it fills the frame, whatever size the page gives that
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preview)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.draw.connect(_draw_text)
	add_child(_text)
	resized.connect(_fit)
	preview.framed.connect(_text.queue_redraw)
	_fit()


## Keep the character's head below the name, however tall the frame is.
func _fit() -> void:
	var h := maxf(size.y, custom_minimum_size.y)
	preview.clear_top = clampf(HEAD_ROOM / maxf(h, 1.0), 0.02, 0.5)
	preview.floor_at = clampf(1.0 - FLOOR_ROOM / maxf(h, 1.0), 0.6, 0.99)
	preview._frame()
	_text.queue_redraw()


## How wide the name may be (canvas pixels) before it would reach the character's head.
func title_room() -> float:
	var per_metre := preview.per_metre()
	var half := clampf(preview.width() * 0.5 * BODY_SHARE, HEAD_HALF, BODY_HALF)
	return maxf(size.x * 0.5 - half * per_metre - 16.0 - 8.0, 60.0)


## The biggest size (no more than `most`, no less than `least`) `s` fits `room` at.
static func _fit_size(s: String, most: int, least: int, room: float, spaced: bool) -> int:
	var font := HudStyle.font_spaced() if spaced else HudStyle.font(true)
	for at in range(most, least, -1):
		if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, at).x <= room:
			return at
	return least


func _draw() -> void:
	HudStyle.framed_plate(self, Rect2(Vector2.ZERO, size).grow(-1.0), 18.0, Color(0.02, 0.03, 0.05, 0.82), Color(UiKit.LINE, 0.22))


func _draw_text() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var room := title_room()
	HudStyle.label(_text, Vector2(16, 20), kicker, _fit_size(kicker, KICKER_SIZE, KICKER_MIN, room, true), kicker_color)
	HudStyle.text(_text, Vector2(16, 44), title, _fit_size(title, TITLE_SIZE, TITLE_MIN, room, false), Color.WHITE)
	HudStyle.brackets(_text, r.grow(-8.0), 12.0, bracket_color, 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		preview.held = _dragging
		_idle = 0.0
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		preview.drag += event.relative.x * TURN
		accept_event()


func _process(delta: float) -> void:
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false   # let go outside the frame
		preview.held = false
	if _dragging or preview.drag == 0.0:
		return
	_idle += delta
	if _idle < BACK_AFTER:
		return
	preview.settle_drag()
	preview.drag = lerpf(preview.drag, 0.0, 1.0 - exp(-delta * BACK_SPEED))
	if absf(preview.drag) < 0.003:
		preview.drag = 0.0
