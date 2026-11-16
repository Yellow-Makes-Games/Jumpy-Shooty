class_name UiKit
## The look every menu shares, and small helpers to build menus in code.
## Matches the HUD: Chakra Petch, dark see-through panels, orange accent.
## Buttons light up with an orange edge on hover; the main action on a page is a
## solid orange "primary" button.

const BG := Color(0.05, 0.06, 0.08)
const PANEL := Color(0.07, 0.08, 0.105, 0.92)
const FIELD := Color(0.12, 0.13, 0.17)
const FIELD_HOVER := Color(0.17, 0.18, 0.23)
const ACCENT := Color(1.0, 0.55, 0.2)
const ACCENT_DARK := Color(0.08, 0.06, 0.04)
const TEXT := Color(0.93, 0.94, 0.96)
const TEXT_DIM := Color(0.62, 0.65, 0.70)

static var _theme: Theme


static func make_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = HudStyle.font(false)
	t.default_font_size = 20

	# Buttons (OptionButton, CheckBox and the rest fall back to these).
	var normal := _box(FIELD)
	var hover := _box(FIELD_HOVER)
	hover.border_width_left = 4
	hover.border_color = ACCENT
	var pressed := _box(ACCENT)
	var disabled := _box(Color(0.1, 0.1, 0.12, 0.8))
	var focus := _box(Color(0, 0, 0, 0))
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = Color(ACCENT, 0.8)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", HudStyle.font(true))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT_DARK)
	t.set_color("font_hover_pressed_color", "Button", ACCENT_DARK)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.6))

	# The solid orange button for the main action on a page.
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	var prim := _box(ACCENT)
	var prim_hover := _box(ACCENT.lightened(0.15))
	t.set_stylebox("normal", "PrimaryButton", prim)
	t.set_stylebox("hover", "PrimaryButton", prim_hover)
	t.set_stylebox("pressed", "PrimaryButton", _box(ACCENT.darkened(0.15)))
	t.set_stylebox("focus", "PrimaryButton", focus)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "PrimaryButton", ACCENT_DARK)

	# Toggle switches (settings).
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_font("font", "CheckButton", HudStyle.font(false))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_icon("checked", "CheckButton", _switch_texture(true))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false))

	# Drop-down lists.
	var popup := _box(Color(0.09, 0.1, 0.13, 0.98), 6, 6)
	popup.set_border_width_all(1)
	popup.border_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _box(ACCENT, 4, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT_DARK)
	t.set_font("font", "PopupMenu", HudStyle.font(false))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_constant("v_separation", "PopupMenu", 10)

	# Text boxes (and SpinBox).
	var field := _box(Color(0.05, 0.06, 0.08))
	field.set_border_width_all(1)
	field.border_color = Color(1, 1, 1, 0.12)
	var field_focus := field.duplicate()
	field_focus.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXT_DIM, 0.6))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))

	# Sliders: a thin track that fills orange, a round handle.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate()
	fill.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_texture(9, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(10, Color.WHITE))

	t.set_color("font_color", "Label", TEXT)
	var panel := _box(PANEL, 12, 26)
	panel.border_width_top = 3
	panel.border_color = ACCENT
	t.set_stylebox("panel", "PanelContainer", panel)
	_theme = t
	return t


static func _box(color: Color, radius: int = 6, margin: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin * 1.5
	b.content_margin_right = margin * 1.5
	b.content_margin_top = margin * 0.75
	b.content_margin_bottom = margin * 0.75
	return b


static func _dot_texture(r: int, color: Color) -> Texture2D:
	var s := r * 2 + 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			img.set_pixel(x, y, Color(color, clampf(r - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## A pill-shaped on/off switch.
static func _switch_texture(on: bool) -> Texture2D:
	var w := 46
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var track := ACCENT if on else Color(1, 1, 1, 0.18)
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var col := Color(track, track.a * clampf(r - d + 0.5, 0.0, 1.0))
			var k := clampf(r - 4.0 - p.distance_to(Vector2(knob_x, r)) + 0.5, 0.0, 1.0)
			col = col.blend(Color(1, 1, 1, k))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A full-screen backdrop with a centred panel. Returns the panel's column.
## see_through: a dark veil instead of the backdrop (menus over the game).
static func screen(root: Control, width: float = 460.0, see_through: bool = false) -> VBoxContainer:
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if see_through:
		var veil := ColorRect.new()
		veil.color = Color(0.02, 0.03, 0.05, 0.6)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(veil)
	else:
		root.add_child(MenuBackdrop.new())
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


## A page heading: bold capitals with a short orange bar under them.
static func title(parent: Node, text: String, size: int = 44, centred: bool = false) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(56, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centred else Control.SIZE_SHRINK_BEGIN
	box.add_child(bar)
	return l


## A small capitalised heading for a group of controls, with a rule after it.
static func section(parent: Node, text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", ACCENT)
	row.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
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
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## The solid orange button for the main action on a page.
static func primary_button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := button(parent, text.to_upper(), on_press)
	b.theme_type_variation = "PrimaryButton"
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	return b


## Toggle buttons in a row where exactly one is pressed. Calls on_pick(index).
static func segmented(parent: Node, options: Array, current: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): on_pick.call(i))
		row.add_child(b)
	return row


static func line_edit(parent: Node, placeholder: String, value: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size = Vector2(0, 46)
	parent.add_child(e)
	return e


## A key cap with an action beside it (controls lists).
static func key_row(parent: Node, key: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var cap := PanelContainer.new()
	var box := _box(Color(1, 1, 1, 0.1), 4, 4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", box)
	cap.custom_minimum_size = Vector2(96, 0)
	row.add_child(cap)
	var k := Label.new()
	k.text = key
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_override("font", HudStyle.font(true))
	k.add_theme_font_size_override("font_size", 14)
	cap.add_child(k)
	var a := label(row, action, true, 15)
	a.autowrap_mode = TextServer.AUTOWRAP_OFF
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


static func spacer(parent: Node, height: float = 8.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
