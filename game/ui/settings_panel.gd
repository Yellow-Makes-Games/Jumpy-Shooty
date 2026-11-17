class_name SettingsPanel
extends VBoxContainer
## Settings, used from the main menu and the in-game pause menu.
## Four tabs (Controls, Camera & HUD, Audio, Graphics); every change applies at once
## and is saved when you leave, except the display settings on the Graphics tab: those
## wait for Apply, and a new resolution or screen mode puts itself back after a few
## seconds unless you press Keep (in case the new one is unusable).

signal closed

const TABS := ["Controls", "Camera & HUD", "Audio", "Graphics"]
const KEYS := [
	["W A S D", "Move"], ["Shift", "Sprint"], ["Space", "Jump; again in mid-air to flip"],
	["Ctrl / C", "Crouch; slide when moving fast"], ["Q / Alt", "Dive (keep holding to land in a belly slide)"], ["Right mouse", "Grapple"],
	["Left mouse", "Shoot; melee: hold to wind up, let go to swing"], ["R", "Reload"], ["V", "First / third person"], ["Tab", "Scoreboard"],
	["F1", "Debug menu (Practice and Vs Bots)"],
]

const DISPLAY_KEYS := ["fullscreen", "vsync", "resolution", "frame_rate"]
const CONFIRM_SECONDS := 15

static var _last_tab := 0

var _page: VBoxContainer
var _pending := {}       # display settings picked on the Graphics tab, not applied yet
var _revert_to := {}     # what Revert (or running out of time) puts back
var _countdown := 0
var _timer: Timer
var _apply_btn: Button
var _confirm_row: HBoxContainer
var _confirm_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size = Vector2(620, 0)
	UiKit.title(self, "Settings", 34)
	UiKit.segmented(self, TABS, _last_tab, _show_tab)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_page.custom_minimum_size = Vector2(0, 400)
	add_child(_page)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_show_tab(_last_tab)
	UiKit.button(self, "Back", _on_back)


func _show_tab(i: int) -> void:
	_last_tab = i
	_on_keep()   # leaving the tab while asked to keep new display settings keeps them
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
			_build_display()


func _on_back() -> void:
	_on_keep()
	Settings.save_settings()
	closed.emit()


# ---------------------------------------------------------------------------
# Graphics tab: display settings wait for Apply.

func _build_display() -> void:
	_pending = _current_display()
	UiKit.section(_page, "Display")
	_switch("Fullscreen", _pending.fullscreen, func(v): _pick("fullscreen", v), false)
	_switch("V-Sync", _pending.vsync, func(v): _pick("vsync", v), false)
	_option("Resolution", Settings.resolution_choices(), _pending.resolution, func(v): _pick("resolution", v), false)
	_option("Frame rate", Settings.frame_rate_choices(), _pending.frame_rate, func(v): _pick("frame_rate", v), false)
	UiKit.label(_page, "Windowed, Resolution sets the window size. In fullscreen it sets how sharp the 3D world is drawn (you'll see it in a match, not in menus). Frame rate caps how fast the game draws; your monitor's refresh rate is set in your computer's display settings.", true, 15)
	if Engine.is_embedded_in_editor():
		var note := UiKit.label(_page, "You're running the game inside the Godot editor, which keeps it in its own panel, so window size and fullscreen won't change here. They work in the exported game, or after turning off \"Embed Game on Next Play\" in the editor's Game tab.", false, 15)
		note.add_theme_color_override("font_color", UiKit.ACCENT)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_page.add_child(bar)
	_apply_btn = UiKit.primary_button(bar, "Apply", _on_apply)
	_apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_row = HBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 12)
	_page.add_child(_confirm_row)
	_confirm_label = UiKit.label(_confirm_row, "", false, 18)
	_confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.button(_confirm_row, "Keep", _on_keep).custom_minimum_size.x = 120
	UiKit.button(_confirm_row, "Revert", _on_revert).custom_minimum_size.x = 120
	_confirm_row.visible = false
	_update_apply()


func _current_display() -> Dictionary:
	var d := {}
	for k in DISPLAY_KEYS:
		d[k] = Settings.get(k)
	return d


func _set_display(d: Dictionary) -> void:
	for k in DISPLAY_KEYS:
		Settings.set(k, d[k])
	Settings.apply()
	Settings.save_settings()


func _pick(key: String, value) -> void:
	_pending[key] = value
	_update_apply()


func _has_changes() -> bool:
	var now := _current_display()
	for k in DISPLAY_KEYS:
		if now[k] != _pending[k]:
			return true
	return false


func _update_apply() -> void:
	if is_instance_valid(_apply_btn):
		_apply_btn.disabled = not _has_changes() or not _timer.is_stopped()


func _on_apply() -> void:
	var before := _current_display()
	_set_display(_pending)
	if before.fullscreen != _pending.fullscreen or before.resolution != _pending.resolution:
		_revert_to = before   # a new screen mode or size: ask before keeping it
		_countdown = CONFIRM_SECONDS
		_confirm_row.visible = true
		_confirm_label.text = _confirm_text()
		_timer.start()
	_update_apply()


func _tick() -> void:
	_countdown -= 1
	if _countdown <= 0:
		_on_revert()
	elif is_instance_valid(_confirm_label):
		_confirm_label.text = _confirm_text()


func _confirm_text() -> String:
	return "Keep these settings? Reverting in %d s" % _countdown


func _on_keep() -> void:
	if not is_instance_valid(_timer) or _timer.is_stopped():
		return
	_timer.stop()
	_revert_to = {}
	if is_instance_valid(_confirm_row):
		_confirm_row.visible = false
	_update_apply()


func _on_revert() -> void:
	_timer.stop()
	if not _revert_to.is_empty():
		_set_display(_revert_to)
	_revert_to = {}
	UiKit.clear(_page)
	_build_display()


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


## `live`: apply the change at once (otherwise the caller decides when).
func _switch(text: String, value: bool, setter: Callable, live: bool = true) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(x):
		setter.call(x)
		if live:
			Settings.apply())
	_page.add_child(c)


## A drop-down. `choices` maps each stored value to the text shown for it.
func _option(text: String, choices: Dictionary, value: Variant, setter: Callable, live: bool = true) -> void:
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
		if live:
			Settings.apply())
	row.add_child(o)


func _fmt(x: float, step: float, percent: bool) -> String:
	if percent:
		return "%d%%" % roundi(x * 100.0)
	return str(int(x)) if step >= 1.0 else "%.2f" % x
