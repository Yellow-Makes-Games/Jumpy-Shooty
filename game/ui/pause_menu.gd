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
	_col = UiKit.screen(_root, 480)
	_root.get_child(0).color = Color(0, 0, 0, 0.55)  # see-through background
	visibility_changed.connect(func(): if visible: _show_main())


func _show_main() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "Paused", 36)
	UiKit.button(_col, "Resume", func(): visible = false)
	UiKit.button(_col, "Settings", _show_settings)
	if Net.is_online and Net.is_host():
		UiKit.button(_col, "End match (everyone returns to the lobby)", Net.host_end_match)
	var leave_text := "Leave match"
	if Net.is_online and Net.is_host():
		leave_text = "Close lobby (ends the match for everyone)"
	UiKit.button(_col, leave_text, Game.leave_to_menu)


func _show_settings() -> void:
	UiKit.clear(_col)
	var panel := SettingsPanel.new()
	panel.closed.connect(_show_main)
	_col.add_child(panel)
