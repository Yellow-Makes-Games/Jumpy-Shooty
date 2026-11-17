extends Node
## Player settings (mouse, camera, audio, graphics) and the control scheme.
## Saved to user://settings.cfg. Every other script reads settings from here.

signal changed

const SAVE_PATH := "user://settings.cfg"

# Controls
var mouse_sensitivity: float = 0.12  # degrees of turn per pixel of mouse movement
var invert_y: bool = false

# Camera
var field_of_view: float = 95.0
var third_person: bool = false

# HUD: which layout to show in each camera view (see HUD_STYLES)
const HUD_STYLES := {"arcs": "Twin arcs (around the crosshair)", "clean": "Clean (corners)"}
var hud_first_person: String = "arcs"
var hud_third_person: String = "clean"

# Audio (0..1)
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9

# Graphics
var fullscreen: bool = false
var vsync: bool = true
## Vector2i.ZERO means native: the screen's own resolution in fullscreen, and whatever
## size the window is in windowed mode.
var resolution: Vector2i = Vector2i.ZERO
## Frame rate cap. 0 = no cap, -1 = match the monitor's refresh rate.
var frame_rate: int = 0

## Resolutions offered in the menu (only those that fit the screen are shown).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(3840, 2160), Vector2i(3440, 1440), Vector2i(2560, 1440), Vector2i(2560, 1080),
	Vector2i(1920, 1080), Vector2i(1680, 1050), Vector2i(1600, 900), Vector2i(1366, 768),
	Vector2i(1280, 720),
]
## Frame rate caps offered in the menu, besides "no cap" and "match monitor".
const FRAME_RATES: Array[int] = [30, 60, 75, 120, 144, 165, 240, 360]

# What apply() last put on the window, so it only resizes when the resolution changes.
var _applied_resolution := Vector2i(-1, -1)
var _applied_fullscreen := false

# Profile
var player_name: String = ""
var character: String = Characters.default_id()   # the robot you play as (see Characters)
var weapon: String = WeaponData.default_id()       # the gun you take into matches (see WeaponData)
var last_address: String = ""   # the host address you last joined (filled in on the Join box next time)


func _ready() -> void:
	_setup_input_map()
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	field_of_view = cfg.get_value("camera", "field_of_view", field_of_view)
	third_person = cfg.get_value("camera", "third_person", third_person)
	hud_first_person = _hud_style(cfg.get_value("hud", "first_person", hud_first_person))
	hud_third_person = _hud_style(cfg.get_value("hud", "third_person", hud_third_person))
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = cfg.get_value("graphics", "fullscreen", fullscreen)
	vsync = cfg.get_value("graphics", "vsync", vsync)
	var res = cfg.get_value("graphics", "resolution", resolution)
	resolution = res if res is Vector2i else Vector2i.ZERO
	frame_rate = int(cfg.get_value("graphics", "frame_rate", frame_rate))
	player_name = cfg.get_value("profile", "player_name", player_name)
	character = Characters.valid(str(cfg.get_value("profile", "character", character)))
	weapon = WeaponData.valid(str(cfg.get_value("profile", "weapon", weapon)))
	last_address = str(cfg.get_value("network", "last_address", last_address))
	_load_bindings(cfg)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("camera", "field_of_view", field_of_view)
	cfg.set_value("camera", "third_person", third_person)
	cfg.set_value("hud", "first_person", hud_first_person)
	cfg.set_value("hud", "third_person", hud_third_person)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "resolution", resolution)
	cfg.set_value("graphics", "frame_rate", frame_rate)
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("profile", "character", character)
	cfg.set_value("profile", "weapon", weapon)
	cfg.set_value("network", "last_address", last_address)
	_save_bindings(cfg)
	cfg.save(SAVE_PATH)


func apply() -> void:
	if DisplayServer.get_name() != "headless":
		# Windowed: only leave fullscreen, so a window you maximized stays maximized.
		var current := DisplayServer.window_get_mode()
		var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fullscreen and not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		_apply_resolution()
		Engine.max_fps = monitor_refresh_rate() if frame_rate < 0 else frame_rate
	changed.emit()   # Sound puts the volumes on the audio buses


## Fullscreen always covers the screen at its own resolution (the game can't change the
## monitor's mode), so there the chosen resolution sets how sharp the 3D picture is drawn
## before it is stretched to fill the screen; menus and the HUD stay sharp. In windowed
## mode it sets the window size (Native maximizes the window).
func _apply_resolution() -> void:
	var screen := screen_size()
	var res := resolution
	if res.x > screen.x or res.y > screen.y:
		res = Vector2i.ZERO   # saved on a bigger monitor: fall back to native
	var root := get_tree().root if is_inside_tree() else null
	if root:
		root.scaling_3d_scale = clampf(float(res.y) / screen.y, 0.25, 1.0) if fullscreen and res != Vector2i.ZERO else 1.0
	if res == _applied_resolution and fullscreen == _applied_fullscreen:
		return
	var first := _applied_resolution == Vector2i(-1, -1)
	_applied_resolution = res
	_applied_fullscreen = fullscreen
	# Copies started side by side by tools/run_local keep the window --window gave them.
	var dev_args := get_node_or_null("/root/DevArgs")
	if fullscreen or (dev_args and dev_args.window_rect.size != Vector2i.ZERO):
		return
	if res == Vector2i.ZERO:
		# Native in a window: fill the screen (but leave the window alone at startup).
		if not first:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_size(res)
	DisplayServer.window_set_position(usable.position + (usable.size - res) / 2)


func screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i(1920, 1080)
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## The monitor's refresh rate in Hz, rounded (60 if the system won't say).
func monitor_refresh_rate() -> int:
	var hz := -1.0
	if DisplayServer.get_name() != "headless":
		hz = DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	return roundi(hz) if hz > 0.0 else 60


## Resolution choices for the menu: stored value -> text. Only those that fit the screen.
func resolution_choices() -> Dictionary:
	var screen := screen_size()
	var choices := {Vector2i.ZERO: "Native (%d x %d)" % [screen.x, screen.y]}
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y and r != screen:
			choices[r] = "%d x %d" % [r.x, r.y]
	return choices


## Frame rate choices for the menu: stored value -> text.
func frame_rate_choices() -> Dictionary:
	var choices := {-1: "Match monitor (%d Hz)" % monitor_refresh_rate()}
	for f in FRAME_RATES:
		choices[f] = "%d fps" % f
	choices[0] = "No cap"
	return choices


## The HUD layout for the current camera view.
func hud_style() -> String:
	return hud_third_person if third_person else hud_first_person


static func _hud_style(value) -> String:
	return str(value) if HUD_STYLES.has(str(value)) else "arcs"


func set_third_person(value: bool) -> void:
	third_person = value
	save_settings()
	changed.emit()


# ---------------------------------------------------------------------------
# Controls. The defaults are defined in code; the Controls tab on the Settings menu
# rebinds them, and anything changed is saved under [bindings] in settings.cfg.
# A binding is "key:<physical keycode>" or "mouse:<button index>".

## Rebindable actions in the order the Controls tab lists them: [action, label, defaults].
## Each action has up to MAX_BINDS bindings.
const ACTIONS := [
	["move_forward", "Move forward", ["key:%d" % KEY_W]],
	["move_back", "Move back", ["key:%d" % KEY_S]],
	["move_left", "Move left", ["key:%d" % KEY_A]],
	["move_right", "Move right", ["key:%d" % KEY_D]],
	["jump", "Jump (again in mid-air to flip)", ["key:%d" % KEY_SPACE]],
	["sprint", "Sprint", ["key:%d" % KEY_SHIFT]],
	["crouch", "Crouch / slide", ["key:%d" % KEY_CTRL, "key:%d" % KEY_C]],
	["dive", "Dive", ["key:%d" % KEY_Q, "key:%d" % KEY_ALT]],
	["kick", "Kick", ["key:%d" % KEY_F]],
	["boost", "Rocket boots", ["key:%d" % KEY_E]],
	["grapple", "Grapple", ["mouse:%d" % MOUSE_BUTTON_RIGHT]],
	["fire", "Shoot / swing", ["mouse:%d" % MOUSE_BUTTON_LEFT]],
	["reload", "Reload (race: last checkpoint)", ["key:%d" % KEY_R]],
	["weapon_1", "Weapon slot 1", ["key:%d" % KEY_1]],
	["weapon_2", "Weapon slot 2", ["key:%d" % KEY_2]],
	["weapon_3", "Weapon group 3 (respawn pick)", ["key:%d" % KEY_3]],
	["weapon_4", "Weapon group 4 (respawn pick)", ["key:%d" % KEY_4]],
	["weapon_5", "Weapon group 5 (respawn pick)", ["key:%d" % KEY_5]],
	["weapon_6", "Weapon group 6 (respawn pick)", ["key:%d" % KEY_6]],
	["weapon_next", "Next weapon", ["mouse:%d" % MOUSE_BUTTON_WHEEL_DOWN]],
	["weapon_prev", "Previous weapon", ["mouse:%d" % MOUSE_BUTTON_WHEEL_UP]],
	["toggle_camera", "First / third person", ["key:%d" % KEY_V]],
	["scoreboard", "Scoreboard (hold)", ["key:%d" % KEY_TAB]],
	["debug_menu", "Debug menu (Practice, Vs Bots)", ["key:%d" % KEY_F1, "key:%d" % KEY_QUOTELEFT]],
]
const MAX_BINDS := 2

## Not rebindable: Esc always opens the menu (and cancels a rebind).
const FIXED_BINDINGS := {"pause": ["key:%d" % KEY_ESCAPE]}

## The current bindings: action -> Array of binding strings.
var bindings := {}


func default_bindings(action: String) -> Array:
	for a in ACTIONS:
		if a[0] == action:
			return (a[2] as Array).duplicate()
	return []


func _setup_input_map() -> void:
	for a in ACTIONS:
		bindings[a[0]] = (a[2] as Array).duplicate()
	for action in FIXED_BINDINGS:
		_ensure_action(action)
		for b in FIXED_BINDINGS[action]:
			InputMap.action_add_event(action, binding_event(b))
	_apply_bindings()


func _apply_bindings() -> void:
	for action in bindings:
		_ensure_action(action)
		for b in bindings[action]:
			var ev := binding_event(b)
			if ev:
				InputMap.action_add_event(action, ev)


func _load_bindings(cfg: ConfigFile) -> void:
	for a in ACTIONS:
		var saved = cfg.get_value("bindings", a[0]) if cfg.has_section_key("bindings", a[0]) else null
		if saved is Array:
			var list := []
			for b in saved:
				if binding_event(str(b)) and not list.has(str(b)) and list.size() < MAX_BINDS:
					list.append(str(b))
			bindings[a[0]] = list
	_apply_bindings()


func _save_bindings(cfg: ConfigFile) -> void:
	for a in ACTIONS:
		if bindings[a[0]] != a[2]:
			cfg.set_value("bindings", a[0], bindings[a[0]])


## Puts `binding` in slot `slot` of `action` (an empty binding clears the slot). If
## another action had it, that action loses it. Returns the labels of the actions it
## was taken from (empty when it was free).
func rebind(action: String, slot: int, binding: String) -> Array:
	var taken := []
	if binding != "":
		if FIXED_BINDINGS.pause.has(binding):
			return taken
		for a in ACTIONS:
			if a[0] != action and bindings[a[0]].has(binding):
				bindings[a[0]].erase(binding)
				taken.append(a[1])
	var list: Array = bindings[action]
	list.erase(binding)
	if slot < list.size():
		if binding == "":
			list.remove_at(slot)
		else:
			list[slot] = binding
	elif binding != "":
		list.append(binding)
	_apply_bindings()
	save_settings()
	return taken


func reset_bindings() -> void:
	for a in ACTIONS:
		bindings[a[0]] = (a[2] as Array).duplicate()
	_apply_bindings()
	save_settings()


## The binding string for a key or mouse button press, or "" if it can't be bound.
static func event_binding(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return "key:%d" % code if code != KEY_NONE else ""
	if ev is InputEventMouseButton and ev.button_index != MOUSE_BUTTON_NONE:
		return "mouse:%d" % ev.button_index
	return ""


static func binding_event(b: String) -> InputEvent:
	var parts := b.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var code := int(parts[1])
	if parts[0] == "key" and code > 0:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		return ev
	if parts[0] == "mouse" and code > 0:
		var ev := InputEventMouseButton.new()
		ev.button_index = code
		return ev
	return null


const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_RIGHT: "Right mouse", MOUSE_BUTTON_MIDDLE: "Middle mouse",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel left", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


## How a binding is shown: the key as printed on your keyboard layout, or the mouse button.
static func binding_text(b: String) -> String:
	var ev := binding_event(b)
	if ev is InputEventMouseButton:
		return MOUSE_NAMES.get(ev.button_index, "Mouse %d" % ev.button_index)
	if ev is InputEventKey:
		var code: int = ev.physical_keycode
		if DisplayServer.get_name() != "headless":
			var local := DisplayServer.keyboard_get_keycode_from_physical(code)
			if local != KEY_NONE:
				code = local
		return OS.get_keycode_string(code)
	return ""


## Everything bound to `action`, as shown in menus ("Q / Alt"); "-" when nothing is.
func action_text(action: String) -> String:
	var names := []
	for b in bindings.get(action, []):
		names.append(binding_text(b))
	return " / ".join(names) if not names.is_empty() else "-"


func _ensure_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
