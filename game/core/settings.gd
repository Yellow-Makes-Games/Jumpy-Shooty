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
	player_name = cfg.get_value("profile", "player_name", player_name)
	character = Characters.valid(str(cfg.get_value("profile", "character", character)))
	weapon = WeaponData.valid(str(cfg.get_value("profile", "weapon", weapon)))
	last_address = str(cfg.get_value("network", "last_address", last_address))


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
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("profile", "character", character)
	cfg.set_value("profile", "weapon", weapon)
	cfg.set_value("network", "last_address", last_address)
	cfg.save(SAVE_PATH)


func apply() -> void:
	if DisplayServer.get_name() != "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()   # Sound puts the volumes on the audio buses


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
# Controls. Defined in code so they are easy to read and, later, to rebind.

const KEY_BINDINGS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],  # slide when moving fast
	"dive": [KEY_ALT, KEY_Q],
	"kick": [KEY_F],
	"boost": [KEY_E],   # rocket boots
	"toggle_camera": [KEY_V],
	"scoreboard": [KEY_TAB],
	"pause": [KEY_ESCAPE],
	"reload": [KEY_R],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"debug_menu": [KEY_F1, KEY_QUOTELEFT],  # offline only (Practice, Vs Bots)
}

const MOUSE_BINDINGS := {
	"fire": [MOUSE_BUTTON_LEFT],
	"grapple": [MOUSE_BUTTON_RIGHT],
	"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
}


func _setup_input_map() -> void:
	for action in KEY_BINDINGS:
		_ensure_action(action)
		for key in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE_BINDINGS:
		_ensure_action(action)
		for button in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _ensure_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
