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
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = cfg.get_value("graphics", "fullscreen", fullscreen)
	vsync = cfg.get_value("graphics", "vsync", vsync)
	player_name = cfg.get_value("profile", "player_name", player_name)
	character = Characters.valid(str(cfg.get_value("profile", "character", character)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("camera", "field_of_view", field_of_view)
	cfg.set_value("camera", "third_person", third_person)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("profile", "character", character)
	cfg.save(SAVE_PATH)


func apply() -> void:
	if DisplayServer.get_name() != "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(max(master_volume, 0.0001)))
	changed.emit()


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
	"toggle_camera": [KEY_V],
	"scoreboard": [KEY_TAB],
	"pause": [KEY_ESCAPE],
	"reload": [KEY_R],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
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
