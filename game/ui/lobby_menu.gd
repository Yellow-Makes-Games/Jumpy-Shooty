extends Control
## Multiplayer lobby: shows who is connected and who is hosting, and lets each
## player pick their robot and their gun. The host starts the match; anyone can leave.

var _col: VBoxContainer          # the left column: players, map, rules
var _side: VBoxContainer         # the right column: your character
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _start: Button
var _waiting: Label
var _info: Label
var _copy: Button   # copies the host's internet address
var _rules_label: Label
var _host_rules: HBoxContainer
var _mode_pick: OptionButton
var _amount: SpinBox
var _amount_unit: Label
var _powerups: CheckButton   # Deathmatch: power-ups on the map or not
var _map_label: Label
var _map_pick: OptionButton
var _character: CharacterPicker
var _weapon: WeaponPicker
var _game_label: Label
var _game_row: HBoxContainer   # the host's Shoot-out / Race switch
var _updating := false   # true while we fill the controls from settings (ignore their signals)


func _ready() -> void:
	var page := UiKit.screen(self, 900)
	UiKit.title(page, "Lobby", 36)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	page.add_child(info_row)
	_info = UiKit.label(info_row, "", true, 16)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy = UiKit.button(info_row, "Copy address", func():
		DisplayServer.clipboard_set(_public_address())
		_copy.text = "Copied")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	page.add_child(columns)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_col)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(280, 0)
	columns.add_child(_side)
	UiKit.section(_col, "Players")
	_list_scroll = ScrollContainer.new()   # 16 players don't fit: the list scrolls past 6
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	UiKit.spacer(_col, 4)
	_build_map()
	_build_rules()
	UiKit.spacer(_col, 4)
	_build_character()
	UiKit.spacer(page, 4)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	page.add_child(buttons)
	var leave := UiKit.button(buttons, "Leave lobby", Game.leave_to_menu)
	leave.custom_minimum_size = Vector2(200, 56)
	_waiting = UiKit.label(buttons, "Waiting for the host to start...", true, 17)
	_waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_waiting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_start = UiKit.primary_button(buttons, "Start match", Net.host_start_match)
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Net.players_changed.connect(_refresh)
	Net.internet_changed.connect(_refresh)
	_refresh()
	# Dev/test: the host starts the next match on its own.
	if DevArgs.autostart > 0 and Net.is_host() and Net.players.size() >= DevArgs.autostart:
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.host_start_match())


## The player list grows with the players, up to about six rows, then scrolls.
func _fit_list() -> void:
	if is_instance_valid(_list_scroll):
		_list_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, 300.0)


func _refresh() -> void:
	UiKit.clear(_list)
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		_list.add_child(_player_row(id))
	_fit_list.call_deferred()
	_start.visible = Net.is_host()
	_waiting.visible = not Net.is_host()
	_start.disabled = Net.players.size() < 1
	var where := ""
	_copy.visible = Net.is_host() and Net.internet_state == "open"
	if Net.is_host():
		match Net.internet_state:
			"open":
				where = "Friends anywhere can join at %s." % _public_address()
			"checking":
				where = "Opening your router for internet play..."
			_:
				where = "Your router would not open port %d, so only friends on your network can join (at %s)." % [Net.port, _local_ip()]
	else:
		where = "The host picks the map and rules and starts the match."
	_info.text = "%d of %d players.  %s" % [Net.players.size(), Net.MAX_PLAYERS, where]
	_refresh_rules()
	if Net.players.has(Net.my_id()):   # show what the host has on record for us
		_character.select(Net.player_character(Net.my_id()))
		_character.set_color(Net.player_color(Net.my_id()))
		_weapon.select(Net.player_weapon(Net.my_id()))
		_character.set_weapon(Net.player_weapon(Net.my_id()))


## One player: colour stripe, name, HOST and YOU tags, robot and gun.
func _player_row(id: int) -> PanelContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.05) if id != Net.my_id() else Color(UiKit.ACCENT, 0.12)
	box.set_corner_radius_all(6)
	box.border_width_left = 5
	box.border_color = Net.player_color(id)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var name_label := UiKit.label(row, Net.player_name(id), false, 20)
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if id == Net.host_id():
		_tag(row, "HOST", UiKit.ACCENT)
	if id == Net.my_id():
		_tag(row, "YOU", Color(1, 1, 1, 0.8))
	if Net.is_bot(id):
		_tag(row, "BOT", Color(1, 1, 1, 0.6))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var who := UiKit.label(row, "%s  ·  %s" % [Characters.name_of(Net.player_character(id)), WeaponData.by_id(Net.player_weapon(id)).short_name], true, 16)
	who.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return card


func _tag(parent: Node, text: String, color: Color) -> void:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(1)
	s.border_color = color
	s.set_corner_radius_all(3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	parent.add_child(p)


# Character: everyone picks their own robot. Saved as your choice for next time too.
func _build_character() -> void:
	Net.confirm_my_character()
	_character = CharacterPicker.new(Net.player_character(Net.my_id()), Net.player_color(Net.my_id()), true,
		Net.player_weapon(Net.my_id()))
	_side.add_child(_character)
	# Your gun: in the left column, under the rules (the side column is narrow).
	_weapon = WeaponPicker.new(Net.player_weapon(Net.my_id()))
	_col.add_child(_weapon)
	_weapon.picked.connect(func(id: String):
		Settings.weapon = id
		Settings.save_settings()
		_character.set_weapon(id)
		Net.set_my_weapon(id))
	if DevArgs.switch_weapon and not Match.last_results.is_empty():
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				var ids := WeaponData.IDS
				Net.set_my_weapon(ids[(ids.find(Net.player_weapon(Net.my_id())) + 1) % ids.size()]))
	_character.picked.connect(func(id: String):
		Settings.character = id
		Settings.save_settings()
		Net.set_my_character(id))
	# Dev/test: after a match, come back as the other robot (checks the choice syncs).
	if DevArgs.switch_character and not Match.last_results.is_empty():
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.set_my_character(Characters.next(Net.player_character(Net.my_id()))))


# Map: the host picks; everyone else sees it.
func _build_map() -> void:
	# Mode first: race maps only show up for a race, arena maps only for a shoot-out.
	UiKit.section(_col, "Mode")
	_game_label = UiKit.label(_col, "")
	_game_row = UiKit.segmented(_col, ["Shoot-out (FFA / 1v1)", "Deathmatch", "Race"], Maps.GAMES.find(Net.game_kind()), func(i: int):
		if _updating:
			return
		var g: String = Maps.GAMES[i]
		var s := Net.match_settings.duplicate()
		s["game"] = g
		s["map"] = Game.last_map.get(g, Maps.default_id(g))
		Net.set_match_settings(s))
	UiKit.section(_col, "Map")
	_map_label = UiKit.label(_col, "")
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size = Vector2(0, 44)
	Maps.fill(_map_pick, Net.map_id(), Net.game_kind())
	_col.add_child(_map_pick)
	_map_pick.item_selected.connect(func(_i: int):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["map"] = Maps.picked(_map_pick)
		Game.last_map[Net.game_kind()] = s.map
		Net.set_match_settings(s))


# Win condition: the host picks; everyone else sees it.
func _build_rules() -> void:
	UiKit.section(_col, "Win condition")
	_rules_label = UiKit.label(_col, "")
	_host_rules = HBoxContainer.new()
	_host_rules.add_theme_constant_override("separation", 10)
	_col.add_child(_host_rules)
	_mode_pick = OptionButton.new()
	_mode_pick.add_item("First to", 0)
	_mode_pick.add_item("Time limit", 1)
	_mode_pick.custom_minimum_size = Vector2(170, 44)
	_host_rules.add_child(_mode_pick)
	_amount = SpinBox.new()
	_amount.custom_minimum_size = Vector2(110, 44)
	_host_rules.add_child(_amount)
	_amount_unit = UiKit.label(_host_rules, "kills")
	_amount_unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_amount_unit.autowrap_mode = TextServer.AUTOWRAP_OFF
	_mode_pick.item_selected.connect(func(i: int):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s.mode = "kills" if i == 0 else "time"
		Net.set_match_settings(s))
	_amount.value_changed.connect(func(v: float):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		if Net.game_kind() == "race":
			s.race_minutes = int(v)
		elif s.mode == "kills":
			s.kills = int(v)
		else:
			s.minutes = int(v)
		if s != Net.match_settings:
			Net.set_match_settings(s))
	# Deathmatch only: power-ups (health, uber health, double damage) on the map or not.
	_powerups = CheckButton.new()
	_powerups.text = "Power-ups (health, uber, double damage)"
	_powerups.custom_minimum_size = Vector2(0, 44)
	_col.add_child(_powerups)
	_powerups.toggled.connect(func(on: bool):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["powerups"] = on
		Net.set_match_settings(s))


func _refresh_rules() -> void:
	var s: Dictionary = Net.match_settings
	var race := Net.game_kind() == "race"
	var kills_mode: bool = s.mode == "kills"
	_rules_label.text = ("First to %d kills" % s.kills) if kills_mode else ("Most kills after %d minutes" % s.minutes)
	if race:
		_rules_label.text = "First to the finish  ·  %d minute limit" % int(s.get("race_minutes", 10))
	_game_label.text = Maps.GAME_NAMES.get(Net.game_kind(), "")
	_game_label.visible = not Net.is_host()
	_game_row.visible = Net.is_host()
	_mode_pick.visible = not race
	if _weapon:
		_weapon.visible = not race and not Net.is_deathmatch()   # no guns in a race; a Deathmatch finds them on the map
	_rules_label.visible = not Net.is_host()
	_host_rules.visible = Net.is_host()
	_map_label.text = Maps.label(Net.map_id())
	_map_label.visible = not Net.is_host()
	_map_pick.visible = Net.is_host()
	_updating = true
	for i in _game_row.get_child_count():
		(_game_row.get_child(i) as Button).set_pressed_no_signal(Maps.GAMES[i] == Net.game_kind())
	Maps.fill(_map_pick, Net.map_id(), Net.game_kind())
	_mode_pick.select(0 if kills_mode else 1)
	_powerups.visible = Net.is_deathmatch()
	_powerups.disabled = not Net.is_host()   # everyone else just sees the host's choice
	_powerups.set_pressed_no_signal(Net.powerups_on())
	if race:
		_amount.min_value = 2
		_amount.max_value = 30
		_amount.set_value_no_signal(int(s.get("race_minutes", 10)))
		_amount_unit.text = "minute limit"
	elif kills_mode:
		_amount.min_value = 1
		_amount.max_value = 100
		_amount.set_value_no_signal(s.kills)
		_amount_unit.text = "kills"
	else:
		_amount.min_value = 1
		_amount.max_value = 60
		_amount.set_value_no_signal(s.minutes)
		_amount_unit.text = "minutes"
	_updating = false


## What friends type to join over the internet (the port only if it isn't the usual one).
func _public_address() -> String:
	return Net.public_ip if Net.port == Net.DEFAULT_PORT else "%s:%d" % [Net.public_ip, Net.port]


func _local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
