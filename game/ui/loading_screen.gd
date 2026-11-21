class_name LoadingScreen
extends CanvasLayer
## Covers the screen while a map loads. Building a map (its meshes, its breakable
## walls) holds up the game for a moment; this goes up first, so that moment shows
## "Loading <map>" instead of a frozen menu. Game puts it up and takes it down.


static func make(map_name: String) -> LoadingScreen:
	var s := LoadingScreen.new()
	s.layer = 100   # above the HUD and every menu
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	box.add_child(_label("LOADING", 20, UiKit.ACCENT))
	box.add_child(_label(map_name.to_upper(), 52, UiKit.TEXT))
	return s


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
