class_name MenuFrame
extends Control
## The frame every menu page is built in: one centred panel with a header (the
## title), a body, and a footer (the page's buttons).
##
## It can never be taller or wider than the window. The header and footer always
## stay on screen; the body takes the height it needs and, when the window has less
## than that, scrolls. So a long page (23 weapons, 16 players, every key binding)
## never pushes Back or Start off the bottom, at any window size or shape.

const MARGIN := Vector2(40, 28)   ## the least space kept clear round the panel
const MIN_BODY := 120.0           ## the body never shrinks below this (then the panel is as small as it gets)

var header: VBoxContainer
var body: VBoxContainer
var footer: HBoxContainer
var panel: PanelContainer
var width := 900.0                ## the panel's width, when the window has room for it

var _scroll: ScrollContainer
var _body_margin: MarginContainer
var _rule: ColorRect
var _decor: Control
var _time := 0.0


## see_through: a dark veil instead of the animated backdrop (menus over the game).
## backdrop: false leaves the background to the caller (the main menu has its own).
func _init(panel_width: float = 900.0, see_through: bool = false, backdrop: bool = true) -> void:
	width = panel_width
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if see_through:
		var veil := ColorRect.new()
		veil.color = Color(0.015, 0.025, 0.045, 0.66)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(veil)
	elif backdrop:
		add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_body_margin = MarginContainer.new()
	_body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body_margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_body_margin.add_child(body)
	_rule = ColorRect.new()
	_rule.color = Color(UiKit.LINE, 0.12)
	_rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(_rule)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)
	_decor = Control.new()
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_draw_decor)
	add_child(_decor)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## Empty the page (header, body and footer) before building another one in it.
func clear(new_width: float = -1.0) -> void:
	UiKit.clear(header)
	UiKit.clear(body)
	UiKit.clear(footer)
	if new_width > 0.0:
		width = new_width
	_scroll.scroll_vertical = 0
	_scroll.custom_minimum_size.y = 0
	panel.reset_size()
	_fit.call_deferred()


## The page's heading, in the header.
func title(text: String, kicker: String = "", size: int = 38) -> Label:
	return UiKit.title(header, text, size, false, kicker)


## Back on the left of the footer.
func back_button(text: String, on_press: Callable) -> Button:
	var b := UiKit.button(footer, text, on_press)
	b.custom_minimum_size = Vector2(180, 56)
	return b


## The page's main action, filling the rest of the footer.
func main_button(text: String, on_press: Callable) -> Button:
	var b := UiKit.primary_button(footer, text, on_press)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## True when the body is taller than the window allows and is scrolling.
func scrolling() -> bool:
	return _body_margin.get_combined_minimum_size().y > _scroll.size.y + 1.0


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		_fit()
		_decor.queue_redraw()


## Size the panel for the window: as wide as asked and as tall as the page needs,
## but never more than the window has.
func _fit() -> void:
	if panel == null:
		return
	var room := size - MARGIN * 2.0
	var w := floorf(minf(width, room.x))
	if not is_equal_approx(panel.custom_minimum_size.x, w):
		panel.custom_minimum_size.x = w
	var has_footer := footer.get_child_count() > 0
	footer.visible = has_footer
	_rule.visible = has_footer
	var want := _body_margin.get_combined_minimum_size().y
	var others := panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var h := floorf(clampf(want, 0.0, maxf(room.y - others, MIN_BODY)))
	if not is_equal_approx(_scroll.custom_minimum_size.y, h):
		_scroll.custom_minimum_size.y = h
	# Keep the scroll bar off the controls when there is one.
	var pad := 14 if want > h + 1.0 else 0
	if _body_margin.get_theme_constant("margin_right") != pad:
		_body_margin.add_theme_constant_override("margin_right", pad)


## Corner brackets just outside the panel and a few small marks along its edges.
func _draw_decor() -> void:
	var r := Rect2(panel.global_position - global_position, panel.size).grow(7.0)
	var pulse := 0.55 + 0.2 * sin(_time * 1.6)
	var line := Color(UiKit.CYAN, 0.5 * pulse + 0.2)
	# Brackets on the two square corners (the other two are cut).
	var arm := 22.0
	_decor.draw_polyline(PackedVector2Array([Vector2(r.end.x - arm, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.position.y + arm)]), line, 2.0, true)
	_decor.draw_polyline(PackedVector2Array([Vector2(r.position.x + arm, r.end.y), Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.end.y - arm)]), line, 2.0, true)
	# An orange slash across each cut corner.
	var cut := 26.0 + 7.0
	_decor.draw_line(Vector2(r.position.x, r.position.y + cut - 8.0), Vector2(r.position.x + cut - 8.0, r.position.y), UiKit.ACCENT, 3.0, true)
	_decor.draw_line(Vector2(r.end.x, r.end.y - cut + 8.0), Vector2(r.end.x - cut + 8.0, r.end.y), Color(UiKit.ACCENT, 0.7), 3.0, true)
	# Small marks: a row of ticks top right, a dashed run bottom left.
	for i in 5:
		var x := r.end.x - 60.0 - i * 9.0
		_decor.draw_line(Vector2(x, r.position.y), Vector2(x - 5.0, r.position.y), Color(UiKit.CYAN, 0.35 - i * 0.05), 2.0)
	for i in 4:
		var x := r.position.x + 44.0 + i * 16.0
		_decor.draw_line(Vector2(x, r.end.y), Vector2(x + 9.0, r.end.y), Color(UiKit.ACCENT, 0.5 - i * 0.1), 2.0)
