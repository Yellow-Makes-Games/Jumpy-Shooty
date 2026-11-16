class_name SettingsPanel
extends VBoxContainer
## Settings controls, used from the main menu and the in-game pause menu.

signal closed


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	UiKit.title(self, "Settings", 34)
	_section("Controls")
	_slider("Mouse sensitivity", 0.02, 0.5, 0.01, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v)
	_check("Invert mouse Y", Settings.invert_y, func(v): Settings.invert_y = v)
	_section("Camera")
	_slider("Field of view", 70.0, 120.0, 1.0, Settings.field_of_view, func(v): Settings.field_of_view = v)
	_check("Third-person camera (V to switch in game)", Settings.third_person, func(v): Settings.third_person = v)
	_section("HUD")
	_option("HUD in first person", Settings.HUD_STYLES, Settings.hud_first_person, func(v): Settings.hud_first_person = v)
	_option("HUD in third person", Settings.HUD_STYLES, Settings.hud_third_person, func(v): Settings.hud_third_person = v)
	_section("Audio")
	_slider("Master volume", 0.0, 1.0, 0.05, Settings.master_volume, func(v): Settings.master_volume = v)
	_slider("Music volume", 0.0, 1.0, 0.05, Settings.music_volume, func(v): Settings.music_volume = v)
	_slider("Effects volume", 0.0, 1.0, 0.05, Settings.sfx_volume, func(v): Settings.sfx_volume = v)
	_section("Graphics")
	_check("Fullscreen", Settings.fullscreen, func(v): Settings.fullscreen = v)
	_check("V-Sync", Settings.vsync, func(v): Settings.vsync = v)
	UiKit.spacer(self)
	UiKit.button(self, "Back", _on_back)


func _on_back() -> void:
	Settings.save_settings()
	closed.emit()


func _section(text: String) -> void:
	UiKit.spacer(self, 4)
	UiKit.label(self, text, true, 16)


func _slider(text: String, lo: float, hi: float, step: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var l := UiKit.label(row, text)
	l.custom_minimum_size = Vector2(230, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := UiKit.label(row, _fmt(value, step))
	v.custom_minimum_size = Vector2(60, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x):
		setter.call(x)
		v.text = _fmt(x, step)
		Settings.apply())


func _check(text: String, value: bool, setter: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(func(x):
		setter.call(x)
		Settings.apply())
	add_child(c)


## A drop-down. `choices` maps each stored value to the text shown for it.
func _option(text: String, choices: Dictionary, value: String, setter: Callable) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var l := UiKit.label(row, text)
	l.custom_minimum_size = Vector2(230, 0)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys := choices.keys()
	for k in keys:
		o.add_item(choices[k])
	o.selected = maxi(keys.find(value), 0)
	o.item_selected.connect(func(i):
		setter.call(keys[i])
		Settings.apply())
	row.add_child(o)


func _fmt(x: float, step: float) -> String:
	return str(int(x)) if step >= 1.0 else "%.2f" % x
