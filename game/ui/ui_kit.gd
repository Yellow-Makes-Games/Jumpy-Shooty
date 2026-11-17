class_name UiKit
## The look every menu shares, and small helpers to build menus in code.
## Matches the HUD: Chakra Petch, dark see-through panels with two corners cut off,
## thin cool-blue lines, an orange accent and a cyan one for small details.
## Buttons light up with an orange edge and a soft glow on hover; the main action on
## a page is a solid orange "primary" button.
##
## Pages are built in a MenuFrame (title on top, buttons pinned at the bottom, a
## middle that scrolls), so nothing can be pushed off the screen.

const BG := Color(0.03, 0.04, 0.065)
const PANEL := Color(0.04, 0.055, 0.085, 0.94)
const FIELD := Color(0.09, 0.115, 0.16, 0.92)
const FIELD_HOVER := Color(0.13, 0.17, 0.235, 0.96)
const LINE := Color(0.55, 0.8, 1.0, 0.16)          ## thin lines round panels and buttons
const ACCENT := Color(1.0, 0.55, 0.2)
const ACCENT_DARK := Color(0.08, 0.06, 0.04)
const CYAN := Color(0.4, 0.9, 1.0)
const TEXT := Color(0.93, 0.95, 0.98)
const TEXT_DIM := Color(0.62, 0.67, 0.74)
const CUT := 10                                    ## how much is cut off a button's corners

static var _theme: Theme


static func make_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = HudStyle.font(false)
	t.default_font_size = 20

	# Buttons (OptionButton, CheckBox and the rest fall back to these).
	var normal := cut_box(FIELD)
	_edge(normal, LINE)
	var hover := cut_box(FIELD_HOVER)
	_edge(hover, ACCENT)
	hover.border_width_left = 3
	_glow(hover, ACCENT, 0.22, 6)
	var pressed := cut_box(ACCENT)
	_glow(pressed, ACCENT, 0.3, 8)
	var disabled := cut_box(Color(0.08, 0.09, 0.12, 0.7))
	_edge(disabled, Color(1, 1, 1, 0.05))
	var focus := cut_box(Color(0, 0, 0, 0))
	focus.draw_center = false
	_edge(focus, Color(CYAN, 0.8))
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
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_pressed_color", "Button", ACCENT_DARK)
	t.set_color("icon_hover_pressed_color", "Button", ACCENT_DARK)

	# The solid orange button for the main action on a page.
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	var prim := cut_box(ACCENT, 14)
	_glow(prim, ACCENT, 0.28, 10)
	var prim_hover := cut_box(ACCENT.lightened(0.18), 14)
	_glow(prim_hover, ACCENT, 0.5, 16)
	var prim_pressed := cut_box(ACCENT.darkened(0.15), 14)
	t.set_stylebox("normal", "PrimaryButton", prim)
	t.set_stylebox("hover", "PrimaryButton", prim_hover)
	t.set_stylebox("pressed", "PrimaryButton", prim_pressed)
	t.set_stylebox("focus", "PrimaryButton", focus)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "PrimaryButton", ACCENT_DARK)

	# Small buttons in a grid: robot names, weapon cards, key bindings.
	t.add_type("Chip")
	t.set_type_variation("Chip", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var chip: StyleBoxFlat = t.get_stylebox(state, "Button").duplicate()
		chip.corner_radius_top_left = 7
		chip.corner_radius_bottom_right = 7
		chip.content_margin_left = 8
		chip.content_margin_right = 8
		chip.content_margin_top = 4
		chip.content_margin_bottom = 4
		t.set_stylebox(state, "Chip", chip)
	t.set_font_size("font_size", "Chip", 15)

	# Toggle switches (settings).
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_font("font", "CheckButton", HudStyle.font(false))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_color("icon_pressed_color", "CheckButton", Color.WHITE)
	t.set_color("icon_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_icon("checked", "CheckButton", _switch_texture(true))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false))

	# Drop-down lists.
	var popup := cut_box(Color(0.05, 0.065, 0.1, 0.98), 10, 6, 6)
	_edge(popup, Color(CYAN, 0.35))
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", cut_box(ACCENT, 6, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT_DARK)
	t.set_font("font", "PopupMenu", HudStyle.font(false))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_constant("v_separation", "PopupMenu", 10)

	# Text boxes (and SpinBox).
	var field := cut_box(Color(0.025, 0.035, 0.055, 0.95))
	_edge(field, Color(1, 1, 1, 0.14))
	var field_focus: StyleBoxFlat = field.duplicate()
	_edge(field_focus, ACCENT)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXT_DIM, 0.6))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))

	# Sliders: a thin track that fills orange, a square handle.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _handle_texture(10, 20, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _handle_texture(12, 22, Color.WHITE))

	# Scroll bars: a thin rail, an orange grip.
	for bar in ["VScrollBar", "HScrollBar"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(1, 1, 1, 0.05)
		rail.set_content_margin_all(3)
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color(ACCENT, 0.55)
		var grip_on: StyleBoxFlat = grip.duplicate()
		grip_on.bg_color = ACCENT
		t.set_stylebox("scroll", bar, rail)
		t.set_stylebox("scroll_focus", bar, rail)
		t.set_stylebox("grabber", bar, grip)
		t.set_stylebox("grabber_highlight", bar, grip_on)
		t.set_stylebox("grabber_pressed", bar, grip_on)

	# Tooltips.
	var tip := cut_box(Color(0.03, 0.04, 0.06, 0.97), 6, 6, 6)
	_edge(tip, Color(CYAN, 0.4))
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	_theme = t
	return t


## The box behind a page: dark, two big cut corners, a thin line round it and a
## shadow that lifts it off the backdrop.
static func panel_box(margin: int = 28) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = PANEL
	b.corner_detail = 1
	b.corner_radius_top_left = 26
	b.corner_radius_bottom_right = 26
	b.set_content_margin_all(margin)
	b.content_margin_top = margin - 4
	_edge(b, Color(LINE, 0.3))
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 28
	return b


## A flat box with its top-left and bottom-right corners cut off.
## margin_h / margin_v: space between its edge and what is inside it.
static func cut_box(color: Color, cut: int = CUT, margin_h: int = 18, margin_v: int = 9) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.corner_detail = 1
	b.corner_radius_top_left = cut
	b.corner_radius_bottom_right = cut
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v
	b.content_margin_bottom = margin_v
	return b


## A darker inset box for a group of controls inside a page.
static func inset_box(margin: int = 16) -> StyleBoxFlat:
	var b := cut_box(Color(1, 1, 1, 0.03), 14, margin, margin)
	_edge(b, Color(1, 1, 1, 0.07))
	return b


static func _edge(b: StyleBoxFlat, color: Color, width: int = 1) -> void:
	b.set_border_width_all(width)
	b.border_color = color


static func _glow(b: StyleBoxFlat, color: Color, alpha: float, size: int) -> void:
	b.shadow_color = Color(color, alpha)
	b.shadow_size = size


## A small upright bar (slider handle).
static func _handle_texture(w: int, h: int, color: Color) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			img.set_pixel(x, y, Color(0.05, 0.06, 0.08) if edge else color)
	return ImageTexture.create_from_image(img)


## An on/off switch: a slanted track with a block that sits left (off) or right (on).
static func _switch_texture(on: bool) -> Texture2D:
	var w := 50
	var h := 24
	var lean := 7.0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color(ACCENT, 0.95) if on else Color(1, 1, 1, 0.16)
	var knob := Color(0.07, 0.06, 0.05) if on else Color(1, 1, 1, 0.85)
	for y in h:
		var shift := lean * (1.0 - (y + 0.5) / h)     # the top leans right
		for x in w:
			var px := x + 0.5 - shift
			var a := clampf(minf(px + 0.5, (w - lean) - px + 0.5), 0.0, 1.0)
			var col := Color(track, track.a * a)
			var k0 := (w - lean) - 20.0 if on else 3.0
			if y >= 3 and y < h - 3:
				var k := clampf(minf(px - k0 + 0.5, k0 + 17.0 - px + 0.5), 0.0, 1.0)
				col = col.blend(Color(knob, knob.a * k))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A page heading: bold capitals with an orange bar and a thin line under them, and
## (if given) a small cyan line of capitals above.
static func title(parent: Node, text: String, size: int = 44, centred: bool = false, kicker: String = "") -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	if kicker != "":
		var k := Label.new()
		k.text = kicker.to_upper()
		k.add_theme_font_override("font", HudStyle.font_spaced(3))
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", Color(CYAN, 0.85))
		if centred:
			k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(k)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centred else Control.SIZE_SHRINK_BEGIN
	box.add_child(bar)
	for part in [[56, 4, ACCENT], [14, 4, Color(ACCENT, 0.55)], [6, 4, Color(ACCENT, 0.3)]]:
		var r := ColorRect.new()
		r.color = part[2]
		r.custom_minimum_size = Vector2(part[0], part[1])
		bar.add_child(r)
	return l


## A small capitalised heading for a group of controls: an orange tick, the text,
## then a rule to the edge.
static func section(parent: Node, text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var tick := ColorRect.new()
	tick.color = ACCENT
	tick.custom_minimum_size = Vector2(3, 12)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", HudStyle.font_spaced(2))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", ACCENT)
	row.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(LINE, 0.14)
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


## Toggle buttons where exactly one is pressed. Calls on_pick(index). One row, or a
## grid `columns` wide (for long labels in a narrow column). The buttons are the
## returned container's children, in order.
static func segmented(parent: Node, options: Array, current: int, on_pick: Callable, columns: int = 0) -> Container:
	var row: Container
	if columns > 0:
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		row = grid
	else:
		row = HBoxContainer.new()
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
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 18)
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
	var box := cut_box(Color(1, 1, 1, 0.08), 6, 8, 3)
	_edge(box, Color(CYAN, 0.3))
	cap.add_theme_stylebox_override("panel", box)
	cap.custom_minimum_size = Vector2(104, 0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var k := Label.new()
	k.text = key
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_override("font", HudStyle.font(true))
	k.add_theme_font_size_override("font_size", 14)
	cap.add_child(k)
	var a := label(row, action, true, 15)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


## A small outlined tag (HOST, YOU, BOT; a weapon's class).
static func tag(parent: Node, text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := cut_box(Color(color, 0.1), 4, 7, 1)
	_edge(s, Color(color, 0.8))
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font_spaced(1))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	parent.add_child(p)
	return p


## A darker inset box in a page. Returns the column inside it.
static func inset(parent: Node, separation: int = 12) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", inset_box())
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	p.add_child(v)
	return v


static func spacer(parent: Node, height: float = 8.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
