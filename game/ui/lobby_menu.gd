extends Control
## Multiplayer lobby: shows who is connected and who is hosting, and lets each
## player pick their robot and their gun. The host starts the match; anyone can leave.
## Three columns in a MenuFrame (the match, your robot, your weapon); Leave and Start
## stay on screen at any window size.

var _frame: MenuFrame
var _col: VBoxContainer          # the left column: players, mode, map, rules
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _start: Button
var _waiting: Label
var _info: Label
var _code: Label    # the host's lobby code, big
var _copy: Button   # copies the lobby code
var _rules_label: Label
var _host_rules: HBoxContainer
var _mode_pick: OptionButton
var _amount: SpinBox
var _amount_unit: Label
var _powerups: CheckButton   # Deathmatch: power-ups on the map or not
var _allowed: AllowedWeaponsPicker   # shoot-out: the weapons the host allows (see LobbySettings)
var _allowed_mobility: AllowedMobilityPicker   # every fight: the mobility tools the host allows
var _map_label: Label
var _map_pick: OptionButton
var _character: CharacterPicker
var _weapon: WeaponPicker
var _weapon_box: VBoxContainer   # the right column: your weapon, or a note when the mode has none to pick
var _no_weapon: VBoxContainer
var _no_weapon_note: Label
var _mobility: MobilityPicker
var _game_label: Label
var _game_row: Container   # the host's mode switch
var _updating := false   # true while we fill the controls from settings (ignore their signals)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = MenuFrame.new(1460)
	add_child(_frame)
	_frame.title("Lobby", "Multiplayer")
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	_frame.header.add_child(info_row)
	_info = UiKit.label(info_row, "", true, 16)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_code = UiKit.label(info_row, "", false, 26)
	_code.autowrap_mode = TextServer.AUTOWRAP_OFF
	_code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy = UiKit.button(info_row, "Copy code", func():
		DisplayServer.clipboard_set(Net.lobby_code())
		_copy.text = "Copied")
	_copy.custom_minimum_size = Vector2(0, 38)
	_copy.theme_type_variation = "Chip"
	# Three columns: the match (players, mode, map, rules), your robot, your weapon.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	_frame.body.add_child(columns)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	_col.custom_minimum_size = Vector2(410, 0)
	columns.add_child(_col)
	UiKit.section(_col, "Players")
	_list_scroll = ScrollContainer.new()   # 16 players don't fit: the list scrolls past 4
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	_build_map()
	_build_rules()
	_build_lobby_settings()
	_divider(columns)
	_build_character(columns)
	_frame.back_button("Leave lobby", Game.leave_to_menu)
	_waiting = UiKit.label(_frame.footer, "Waiting for the host to start...", true, 17)
	_waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_waiting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_start = _frame.main_button("Start match", Net.host_start_match)
	Net.players_changed.connect(_refresh)
	Net.internet_changed.connect(_refresh)
	_refresh()
	# Dev/test: the host starts the next match on its own.
	if DevArgs.autostart > 0 and Net.is_host() and Net.players.size() >= DevArgs.autostart:
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.host_start_match())


## A thin upright line between two columns.
func _divider(row: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(UiKit.LINE, 0.12)
	line.custom_minimum_size = Vector2(1, 0)
	row.add_child(line)


## The player list grows with the players, up to about four rows, then scrolls.
func _fit_list() -> void:
	if is_instance_valid(_list_scroll):
		_list_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, 186.0)


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
	var code := Net.lobby_code() if Net.is_host() else ""
	_code.text = code
	_code.visible = code != ""
	_copy.visible = code != ""
	if Net.is_host():
		match Net.internet_state:
			"open":
				where = "Friends anywhere join with the lobby code (or at %s)." % _address(Net.join_ip())
			"checking":
				where = "Opening your router for internet play..."
			_:
				where = "Your router would not open port %d, so only friends on your network can join, with the lobby code (or at %s)." % [Net.port, _address(Net.join_ip())]
	else:
		where = "The host picks the map and rules and starts the match."
	_info.text = "%d of %d players.  %s" % [Net.players.size(), Net.MAX_PLAYERS, where]
	_refresh_rules()
	if Net.players.has(Net.my_id()):   # show what the host has on record for us
		_character.select(Net.player_character(Net.my_id()))
		_character.set_color(Net.player_color(Net.my_id()))
		_weapon.select(Net.player_weapon(Net.my_id()))
		_character.set_weapon(Net.player_weapon(Net.my_id()))
		_mobility.select(Net.player_loadout_mobility(Net.my_id()))


## One player: colour stripe, name, HOST and YOU tags, robot and gun.
func _player_row(id: int) -> PanelContainer:
	var card := PanelContainer.new()
	var box := UiKit.cut_box(Color(1, 1, 1, 0.05) if id != Net.my_id() else Color(UiKit.ACCENT, 0.14), 8, 12, 7)
	box.border_width_left = 4
	box.border_color = Net.player_color(id)
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var name_label := UiKit.label(row, Net.player_name(id), false, 18)
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == Net.host_id():
		UiKit.tag(row, "HOST", UiKit.ACCENT)
	if id == Net.my_id():
		UiKit.tag(row, "YOU", Color(1, 1, 1, 0.85))
	if Net.is_bot(id):
		UiKit.tag(row, "BOT", Color(1, 1, 1, 0.6))
	var who := UiKit.label(row, "%s  ·  %s  ·  %s" % [Characters.name_of(Net.player_character(id)), WeaponData.by_id(Net.player_weapon(id)).short_name,
		Mobility.short_name(Net.player_loadout_mobility(id))], true, 14)
	who.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return card


# Character: everyone picks their own robot. Saved as your choice for next time too.
func _build_character(columns: Node) -> void:
	Net.confirm_my_character()
	_character = CharacterPicker.new(Net.player_character(Net.my_id()), Net.player_color(Net.my_id()),
		Net.player_weapon(Net.my_id()))
	columns.add_child(_character)
	_divider(columns)
	# Your gun, or (in a race, Gun Game or a Deathmatch) a note saying why there is none to pick.
	_weapon_box = VBoxContainer.new()
	_weapon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_box.custom_minimum_size = Vector2(520, 0)
	columns.add_child(_weapon_box)
	_weapon = WeaponPicker.new(Net.player_weapon(Net.my_id()))
	_weapon_box.add_child(_weapon)
	_no_weapon = VBoxContainer.new()
	_no_weapon.add_theme_constant_override("separation", 8)
	_weapon_box.add_child(_no_weapon)
	UiKit.section(_no_weapon, "Weapon")
	_no_weapon_note = UiKit.label(UiKit.inset(_no_weapon), "", true, 17)
	_mobility = MobilityPicker.new(Net.player_loadout_mobility(Net.my_id()))
	_character.add_child(_mobility)   # under the robot: that column has the room
	_mobility.picked.connect(func(id: String):
		Settings.mobility = id
		Settings.save_settings()
		Net.set_my_mobility(id))
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
	_game_row = UiKit.segmented(_col, GunGame.MODE_LABELS, GunGame.MODES.find(GunGame.mode_of(Net.match_settings)), func(i: int):
		if _updating:
			return
		var m: String = GunGame.MODES[i]
		var g := GunGame.game_of_mode(m)
		Net.set_match_settings(GunGame.with_mode(Net.match_settings, m, Game.last_map.get(g, Maps.default_id(g)))), 2)
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


# Lobby settings (see LobbySettings): the host picks; everyone else sees them. New
# settings get their control here.
func _build_lobby_settings() -> void:
	_allowed = AllowedWeaponsPicker.new(Net.match_settings.get("weapons", []), Net.is_host())
	_col.add_child(_allowed)
	_allowed.changed.connect(func(ids: Array):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["weapons"] = ids
		Net.set_match_settings(s))
	_allowed_mobility = AllowedMobilityPicker.new(Net.match_settings.get("mobility", []), Net.is_host())
	_col.add_child(_allowed_mobility)
	_allowed_mobility.changed.connect(func(ids: Array):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["mobility"] = ids
		Net.set_match_settings(s))


func _refresh_rules() -> void:
	var s: Dictionary = Net.match_settings
	var race := Net.game_kind() == "race"
	var gun_game := GunGame.active()
	var killcam := KillcamMode.active()
	var own_rules := gun_game or killcam   # a mode with rules of its own: no kills/time choice
	var kills_mode: bool = s.mode != "time"
	_rules_label.text = ("First to %d kills" % s.kills) if kills_mode else ("Most kills after %d minutes" % s.minutes)
	if race:
		_rules_label.text = "First to the finish  ·  %d minute limit" % int(s.get("race_minutes", 10))
	if gun_game:
		_rules_label.text = "Every kill moves you to the next of %d weapons. First to get a kill with the last one (brass knuckles) wins. Kicked to death: back one weapon." % GunGame.steps()
	if killcam:
		_rules_label.text = "Snipers only. Every kill scores its killcam points: range, headshots, momentum (both of you moving), flicks, trickshots. First to %s points, or the most after %d minutes. The match's #1 killcam earns +%s at the end." \
			% [KillcamMode.format(KillcamMode.target()), int(KillcamMode.TIME_LIMIT / 60.0), KillcamMode.format(KillcamMode.BEST_BONUS)]
	_game_label.text = "Gun Game" if gun_game else ("Killcam" if killcam else Maps.GAME_NAMES.get(Net.game_kind(), ""))
	_game_label.visible = not Net.is_host()
	_game_row.visible = Net.is_host()
	_mode_pick.visible = not race
	var only := LobbySettings.only_weapon()
	if _weapon:
		# No guns in a race; Gun Game hands them out; Killcam is snipers only; a Deathmatch
		# finds them on the map; the host may have set one gun for everyone.
		_weapon.set_allowed(LobbySettings.allowed_weapons())
		_weapon.visible = not race and not own_rules and not Net.is_deathmatch() and only == ""
		_no_weapon.visible = not _weapon.visible
		_mobility.visible = not race   # a race always has the grapple
		_mobility.set_allowed(LobbySettings.allowed_mobility())
		_no_weapon_note.text = "A race has no weapons: it is you, the course and the clock." if race \
			else ("Killcam is snipers only: every kill scores its killcam points." if killcam \
			else ("Gun Game hands out the weapons: every kill moves you to the next one." if gun_game \
			else ("Deathmatch: everyone starts unarmed. Weapons float about the map; walk over one to pick it up." if Net.is_deathmatch() \
			else "One gun for everyone: the %s. The host picked it for this match." % WeaponData.name_of(only))))
	if _allowed:
		_allowed.visible = LobbySettings.weapons_apply()   # a shoot-out: everyone picks their own weapon
		_allowed.set_editable(Net.is_host())
		_allowed.preferred = Net.player_loadout_weapon(Net.my_id())
	_rules_label.visible = not Net.is_host() or own_rules
	_host_rules.visible = Net.is_host() and not own_rules
	_map_label.text = Maps.label(Net.map_id())
	_map_label.visible = not Net.is_host()
	_map_pick.visible = Net.is_host()
	_updating = true
	for i in _game_row.get_child_count():
		(_game_row.get_child(i) as Button).set_pressed_no_signal(GunGame.MODES[i] == GunGame.mode_of(s))
	Maps.fill(_map_pick, Net.map_id(), Net.game_kind())
	_mode_pick.select(0 if kills_mode else 1)
	_powerups.visible = Net.is_deathmatch()
	_powerups.disabled = not Net.is_host()   # everyone else just sees the host's choice
	_powerups.set_pressed_no_signal(Net.powerups_on())
	if _allowed:
		_allowed.set_value(s.get("weapons", []))
	if _allowed_mobility:
		_allowed_mobility.visible = LobbySettings.mobility_apply()   # a race always has the grapple
		_allowed_mobility.set_editable(Net.is_host())
		_allowed_mobility.set_value(s.get("mobility", []))
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


## The address the lobby code stands for, for LAN and development use (the port only
## if it isn't the usual one).
func _address(ip: String) -> String:
	return ip if Net.port == Net.DEFAULT_PORT else "%s:%d" % [ip, Net.port]
