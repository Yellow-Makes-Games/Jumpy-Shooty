class_name SwatchPalette
extends PopupPanel
## A small window of colour swatches that opens under the button that was pressed:
## the Character Creator's colours, and your own colour on the robot stage.
##
##   var palette := SwatchPalette.new()
##   add_child(palette)
##   palette.open(button, "Main colour", entries, "red", func(id): ...)
##
## entries: [{ id, name, color }], plus as_built: true for a "leave it as it comes"
## choice (an empty square) and off: "why" for one that can't be picked now. Each
## swatch is a button named pick_<id> ("pick_none" for the id "").

var grid: GridContainer
var _title: Label


func _init(columns: int = 6) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.07, 0.10, 0.98)
	panel.border_color = Color(UiKit.LINE, 0.45)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(12)
	add_theme_stylebox_override("panel", panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = UiKit.label(box, "", true, 13)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_font_override("font", HudStyle.font_spaced(2))
	grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)


## now: the id picked at the moment (drawn lit). on_pick(id) is called with the
## swatch that was pressed, after the window has closed.
func open(from: Control, title: String, entries: Array, now: Variant, on_pick: Callable) -> void:
	UiKit.clear(grid)
	_title.text = title.to_upper()
	for e in entries:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = e.id == now
		b.theme_type_variation = "Chip"
		b.tooltip_text = e.name if not e.has("off") else "%s: %s" % [e.name, e.off]
		b.disabled = e.has("off")
		b.custom_minimum_size = Vector2(44, 34)
		b.icon = swatch(e.color, e.get("as_built", false))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		true_colors(b)
		b.name = "pick_%s" % (e.id if str(e.id) != "" else "none")
		b.set_meta("sfx", "select")
		b.pressed.connect(func():
			hide()
			on_pick.call(e.id))
		grid.add_child(b)
	# Under the button, or above it where there is no room below; never off the right edge.
	var scale := from.get_screen_transform().get_scale()
	var size := Vector2i((grid.get_parent() as Control).get_combined_minimum_size() * scale) + Vector2i(26, 26)
	var at := from.get_screen_position() + Vector2(0, from.size.y * scale.y + 4)
	var window := from.get_window()
	if window:
		var room := Vector2(window.size) if window.is_embedding_subwindows() else Vector2(window.position + window.size)
		if at.y + size.y > room.y:
			at.y = from.get_screen_position().y - size.y - 4
		at.x = minf(at.x, room.x - size.x - 8)
	popup(Rect2i(Vector2i(at), size))


## A small square of colour for a button. as_built: the "leave it as it is" choice,
## an empty square with a stroke through it.
static func swatch(color: Color, as_built: bool = false) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0) if as_built else color)
	for i in 18:
		for e in [0, 17]:
			img.set_pixel(i, e, Color(1, 1, 1, 0.5))
			img.set_pixel(e, i, Color(1, 1, 1, 0.5))
		if as_built:
			img.set_pixel(i, 17 - i, Color(1, 1, 1, 0.5))
	return ImageTexture.create_from_image(img)


## A swatch on a button is drawn in its own colour, lit or not.
static func true_colors(b: Button) -> void:
	for state in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE if state != "icon_disabled_color" else Color(1, 1, 1, 0.25))
