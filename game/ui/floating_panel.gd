class_name FloatingPanel
extends Control
## A small window that floats over a menu page, in the page's own look (the dark
## panel with cut corners, a thin blue edge and the orange corner slashes), for a
## choice that would clutter the page if it were always out: the lobby opens one for
## the game mode, your robot, your mobility tool and your weapon from a button that
## shows what is picked.
##
## Put the picker in `content` once; open() shows it next to the button that opened
## it (to its left if there is room, else under it), dims the page behind, and
## close() hides it again. A click outside or Esc closes it too. The page keeps its
## picker the whole time, so it can keep it up to date while it is closed.
##
## Add it as the last child of the page's MenuFrame so it is drawn on top and gets the
## menu theme.

signal closed

const GAP := 14.0          ## space between the panel and the button that opened it
const EDGE := 16.0         ## space kept clear round the screen's edge

var content: VBoxContainer
var panel: PanelContainer

var _dim: ColorRect
var _decor: Control
var _anchor: Control
var _side := "left"

## When set, a panel beside its button starts level with the top of this (the page's
## columns) rather than with the button, as tall choices sit best from the top.
var top_of: Control


## side: "left" (beside the button, to its left), "right" (to its right), "below"
## (under it), "above" (over it: a button in the page's footer) or "center" (in the
## middle of the screen).
func _init(side: String = "left", min_width: float = 0.0) -> void:
	_side = side
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.015, 0.03, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)
	panel = PanelContainer.new()
	var box := UiKit.panel_box(22)
	box.border_color = Color(UiKit.CYAN, 0.45)
	box.shadow_size = 18
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(min_width, 0)
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_decor = Control.new()
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_draw_decor)
	add_child(_decor)
	panel.resized.connect(_place)


## Show the panel beside `anchor` (the button that opened it).
func open(anchor: Control) -> void:
	_anchor = anchor
	visible = true
	panel.reset_size()
	_place.call_deferred()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func is_open() -> bool:
	return visible


## Wrapping content (rows of chips, wrapped lines) only knows its height once it has
## been laid out at its width: fit the panel again whenever what it needs changes.
func _process(_delta: float) -> void:
	if visible and panel.get_combined_minimum_size() != panel.size:
		_place()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Beside the button: to its left, its top level with the button's, if that fits;
## otherwise under it. Always inside the screen.
func _place() -> void:
	if not visible or not is_instance_valid(_anchor):
		return
	var view := get_global_rect()
	var a := _anchor.get_global_rect()
	var s := panel.get_combined_minimum_size()
	panel.size = s
	var top := top_of.get_global_rect().position.y if is_instance_valid(top_of) else a.position.y
	var at := Vector2(a.position.x - GAP - s.x, top)
	if _side == "right":
		at = Vector2(a.end.x + GAP, a.position.y)
	elif _side == "below" or at.x < view.position.x + EDGE:
		at = Vector2(a.position.x + (a.size.x - s.x) * 0.5, a.end.y + GAP)
	if _side == "above":
		at = Vector2(a.position.x, a.position.y - GAP - s.y)
	elif _side == "center":
		at = view.position + (view.size - s) * 0.5
	at.x = clampf(at.x, view.position.x + EDGE, maxf(view.end.x - s.x - EDGE, view.position.x + EDGE))
	at.y = clampf(at.y, view.position.y + EDGE, maxf(view.end.y - s.y - EDGE, view.position.y + EDGE))
	panel.global_position = at
	_decor.queue_redraw()


## Orange slashes across the two cut corners and short blue brackets on the others,
## as the page's own frame has.
func _draw_decor() -> void:
	if not visible:
		return
	var r := Rect2(panel.global_position - global_position, panel.size).grow(5.0)
	var line := Color(UiKit.CYAN, 0.6)
	var arm := 16.0
	_decor.draw_polyline(PackedVector2Array([Vector2(r.end.x - arm, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.position.y + arm)]), line, 2.0, true)
	_decor.draw_polyline(PackedVector2Array([Vector2(r.position.x + arm, r.end.y), Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.end.y - arm)]), line, 2.0, true)
	var cut := 26.0 + 5.0
	_decor.draw_line(Vector2(r.position.x, r.position.y + cut - 8.0), Vector2(r.position.x + cut - 8.0, r.position.y), UiKit.ACCENT, 3.0, true)
	_decor.draw_line(Vector2(r.end.x, r.end.y - cut + 8.0), Vector2(r.end.x - cut + 8.0, r.end.y), Color(UiKit.ACCENT, 0.7), 3.0, true)
