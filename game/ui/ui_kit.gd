class_name UiKit
## Small helpers so every menu shares one look. Placeholder styling for now;
## the art pass will replace the colours and fonts once the visual direction is chosen.

const BG := Color(0.06, 0.07, 0.09)
const PANEL := Color(0.11, 0.12, 0.15, 0.94)
const ACCENT := Color(0.98, 0.55, 0.18)
const TEXT := Color(0.93, 0.94, 0.96)
const TEXT_DIM := Color(0.62, 0.65, 0.70)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	var normal := _box(Color(0.17, 0.18, 0.22))
	var hover := _box(Color(0.24, 0.25, 0.30))
	var pressed := _box(ACCENT.darkened(0.2))
	var disabled := _box(Color(0.12, 0.12, 0.14))
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": hover}[s]
		t.set_stylebox(s, "Button", box)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 12, 24))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.08, 0.09, 0.11)))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.08, 0.09, 0.11)))
	return t


static func _box(color: Color, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin * 1.5
	b.content_margin_right = margin * 1.5
	b.content_margin_top = margin * 0.75
	b.content_margin_bottom = margin * 0.75
	return b


## A full-screen background with a centred column. Returns the column.
static func screen(root: Control, width: float = 460.0) -> VBoxContainer:
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	return col


static func title(parent: Node, text: String, size: int = 44) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	parent.add_child(l)
	return l


static func label(parent: Node, text: String, dim: bool = false, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


static func line_edit(parent: Node, placeholder: String, value: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size = Vector2(0, 44)
	parent.add_child(e)
	return e


static func spacer(parent: Node, height: float = 8.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
