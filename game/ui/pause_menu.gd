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
	UiKit.button(_col, "Loadout", _show_loadout)
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


## Change your robot and (in a shoot-out) your weapon mid-match. In a fight the change
## waits for your next respawn; a race has no deaths, so there it happens at once. A
## Deathmatch only offers the robot: weapons there come off the map.
func _show_loadout() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "Loadout", 36)
	var me := Net.my_id()
	var race := Race.active
	var deathmatch := Net.is_deathmatch() or GunGame.active()   # weapons come off the map, or from the ladder
	var note := "Your robot changes straight away." if race else "Changes apply the next time you respawn."
	if deathmatch:
		note += "  Weapons are found on the map." if Net.is_deathmatch() else "  Gun Game hands out the weapons."
	var dead := not race and not Match.is_alive(me)
	if dead:
		note = "Changes apply when you respawn."
	UiKit.label(_col, note, true, 15)
	var picked := {"character": Net.pending_character(), "weapon": Net.pending_weapon()}
	var gun: String = "none" if race or deathmatch else picked.weapon
	var robots := CharacterPicker.new(picked.character, Net.player_color(me), false, gun)
	_col.add_child(robots)
	robots.picked.connect(func(id: String): picked.character = id)
	if not race and not deathmatch:
		var weapons := WeaponPicker.new(picked.weapon)
		_col.add_child(weapons)
		weapons.picked.connect(func(id: String):
			picked.weapon = id
			robots.set_weapon(id))
	UiKit.spacer(_col, 4)
	UiKit.primary_button(_col, "Apply", func():
		Settings.character = picked.character
		Settings.weapon = picked.weapon
		Settings.save_settings()
		Net.set_loadout(picked.character, picked.weapon)
		_show_main())
	UiKit.button(_col, "Back", _show_main)


func _show_settings() -> void:
	UiKit.clear(_col)
	var panel := SettingsPanel.new()
	panel.closed.connect(_show_main)
	_col.add_child(panel)
