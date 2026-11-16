class_name PauseMenu
extends CanvasLayer
## Esc menu during a match. The game keeps running underneath (it is multiplayer).

var _root: Control
var _col: VBoxContainer


func _ready() -> void:
	layer = 20
	visible = false
	_root = Control.new()
	add_child(_root)
	_col = UiKit.screen(_root, 480, true)
	visibility_changed.connect(func(): if visible: _show_main())


func _show_main() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "Paused", 36)
	UiKit.label(_col, "%s  ·  the match keeps going" % Maps.name_of(Net.map_id()), true, 15)
	UiKit.spacer(_col, 4)
	UiKit.primary_button(_col, "Resume", func(): visible = false).grab_focus()
	UiKit.button(_col, "Settings", _show_settings)
	if Net.is_online and Net.is_host():
		UiKit.button(_col, "End match now (show results)", Match.host_end_match)
	var leave_text := "Leave match"
	if Net.is_online and Net.is_host():
		leave_text = "Close lobby (ends the match for everyone)"
	UiKit.button(_col, leave_text, Game.leave_to_menu)
	UiKit.spacer(_col, 4)
	UiKit.section(_col, "Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	_col.add_child(grid)
	for k in SettingsPanel.KEYS:
		UiKit.key_row(grid, k[0], k[1].get_slice(";", 0))


func _show_settings() -> void:
	UiKit.clear(_col)
	var panel := SettingsPanel.new()
	panel.closed.connect(_show_main)
	_col.add_child(panel)
