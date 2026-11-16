class_name SettingsPanel
extends VBoxContainer
## Settings, used from the main menu and the in-game pause menu.
## Four tabs (Controls, Camera & HUD, Audio, Graphics); every change applies at once
## and is saved when you leave.

signal closed

const TABS := ["Controls", "Camera & HUD", "Audio", "Graphics"]
const KEYS := [
	["W A S D", "Move"], ["Shift", "Sprint"], ["Space", "Jump; again in mid-air to flip"],
	["Ctrl / C", "Crouch; slide when moving fast"], ["Q / Alt", "Dive"], ["Right mouse", "Grapple"],
	["Left mouse", "Shoot"], ["R", "Reload"], ["V", "First / third person"], ["Tab", "Scoreboard"],
]

static var _last_tab := 0

var _page: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size = Vector2(620, 0)
	UiKit.title(self, "Settings", 34)
	UiKit.segmented(self, TABS, _last_tab, _show_tab)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_page.custom_minimum_size = Vector2(0, 400)
	add_child(_page)
	_show_tab(_last_tab)
	UiKit.button(self, "Back", _on_back)


func _show_tab(i: int) -> void:
	_last_tab = i
	UiKit.clear(_page)
	match i:
		0:
			UiKit.section(_page, "Mouse")
			_slider("Sensitivity", 0.02, 0.5, 0.01, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v)
			_switch("Invert mouse Y", Settings.invert_y, func(v): Settings.invert_y = v)
			UiKit.section(_page, "Keys")
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 24)
			grid.add_theme_constant_override("v_separation", 6)
			_page.add_child(grid)
			for k in KEYS:
				UiKit.key_row(grid, k[0], k[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		1:
			UiKit.section(_page, "Camera")
			_slider("Field of view", 70.0, 120.0, 1.0, Settings.field_of_view, func(v): Settings.field_of_view = v)
			_switch("Third-person camera (V switches in game)", Settings.third_person, func(v): Settings.third_person = v)
			UiKit.section(_page, "HUD")
			_option("In first person", Settings.HUD_STYLES, Settings.hud_first_person, func(v): Settings.hud_first_person = v)
			_option("In third person", Settings.HUD_STYLES, Settings.hud_third_person, func(v): Settings.hud_third_person = v)
			UiKit.label(_page, "Twin arcs keeps health, ammo and move cooldowns round the crosshair. Clean puts them in the bottom corners.", true, 15)
		2:
			UiKit.section(_page, "Volume")
			_slider("Master", 0.0, 1.0, 0.05, Settings.master_volume, func(v): Settings.master_volume = v, true)
			_slider("Music", 0.0, 1.0, 0.05, Settings.music_volume, func(v): Settings.music_volume = v, true)
			_slider("Effects", 0.0, 1.0, 0.05, Settings.sfx_volume, func(v): Settings.sfx_volume = v, true)
		3:
			UiKit.section(_page, "Display")
			_switch("Fullscreen", Settings.fullscreen, func(v): Settings.fullscreen = v)
			_switch("V-Sync", Settings.vsync, func(v): Settings.vsync = v)


func _on_back() -> void:
	Settings.save_settings()
	closed.emit()


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_page.add_child(row)
	var l := UiKit.label(row, text, false, 18)
	l.custom_minimum_size = Vector2(200, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _slider(text: String, lo: float, hi: float, step: float, value: float, setter: Callable, percent: bool = false) -> void:
	var row := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := UiKit.label(row, _fmt(value, step, percent), false, 18)
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_override("font", HudStyle.font(true))
	s.value_changed.connect(func(x):
		setter.call(x)
		v.text = _fmt(x, step, percent)
		Settings.apply())


func _switch(text: String, value: bool, setter: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(x):
		setter.call(x)
		Settings.apply())
	_page.add_child(c)


## A drop-down. `choices` maps each stored value to the text shown for it.
func _option(text: String, choices: Dictionary, value: String, setter: Callable) -> void:
	var row := _row(text)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(0, 44)
	o.add_theme_font_size_override("font_size", 18)
	var keys := choices.keys()
	for k in keys:
		o.add_item(choices[k])
	o.selected = maxi(keys.find(value), 0)
	o.item_selected.connect(func(i):
		setter.call(keys[i])
		Settings.apply())
	row.add_child(o)


func _fmt(x: float, step: float, percent: bool) -> String:
	if percent:
		return "%d%%" % roundi(x * 100.0)
	return str(int(x)) if step >= 1.0 else "%.2f" % x
