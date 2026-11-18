extends Control
## Multiplayer lobby: shows who is connected and who is hosting, and lets each
## player pick their robot and their gun. Everyone else readies up (Ready); the host
## starts the match once they all have, can kick a player, and sets the lobby size.
## Anyone can leave.
## Three columns in a MenuFrame (the match, your robot, your weapon); Leave and Start
## stay on screen at any window size.

var _frame: MenuFrame
var _col: VBoxContainer          # the left column: players, mode, map, rules
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _watching: Label     # who is spectating
var _spectate: Button    # watch instead of play, or play again
var _start: Button
var _ready_button: Button   # everyone but the host: ready up (press again to take it back)
var _size_box: HBoxContainer   # the host's lobby size
var _size: SpinBox
var _waiting: Label
var _info: Label
var _code: Label    # the host's lobby code, big
var _copy: Button   # copies the lobby code
var _rules_label: Label
var _host_rules: HBoxContainer
var _mode_pick: OptionButton
var _amount: SpinBox
var _killcam_rules: HBoxContainer   # Killcam mode: first to [points] or [minutes] (host only)
var _killcam_points: SpinBox
var _killcam_minutes: SpinBox
var _amount_unit: Label
var _powerups: CheckButton   # Deathmatch: power-ups on the map or not
var _allowed: AllowedWeaponsPicker   # shoot-out: the weapons the host allows (see LobbySettings)
var _allowed_mobility: AllowedMobilityPicker   # every fight: the mobility tools the host allows
var _rules_head: Control   # the "Loadout rules" heading over the lobby settings
var _map_label: Label
var _map_pick: OptionButton
var _map_pool: MapPoolPicker   # a random map: the maps it may pick from (the host ticks them)
var _song_box: HBoxContainer   # the lobby song: the host's pick, or what it is for everyone else
var _song_pick: OptionButton
var _song_label: Label
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
	# The host: how many players the lobby takes (see LobbySettings.max_players).
	_size_box = HBoxContainer.new()
	_size_box.add_theme_constant_override("separation", 8)
	info_row.add_child(_size_box)
	var size_label := UiKit.label(_size_box, "Lobby size", true, 15)
	size_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size = SpinBox.new()
	_size.min_value = LobbySettings.MIN_PLAYERS
	_size.max_value = Net.MAX_PLAYERS
	_size.custom_minimum_size = Vector2(96, 38)
	_size_box.add_child(_size)
	_size.value_changed.connect(func(v: float):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["max_players"] = int(v)
		if s != Net.match_settings:
			Net.set_match_settings(s))
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
	var watch_row := HBoxContainer.new()
	watch_row.add_theme_constant_override("separation", 10)
	_col.add_child(watch_row)
	_watching = UiKit.label(watch_row, "", true, 14)
	_watching.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watching.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spectate = UiKit.button(watch_row, "Spectate", func(): Net.set_spectating(not Net.spectating()))
	_spectate.custom_minimum_size = Vector2(0, 38)
	_spectate.theme_type_variation = "Chip"
	_build_map()
	_build_rules()
	_build_lobby_settings()
	_divider(columns)
	_build_character(columns)
	_frame.back_button("Leave lobby", Game.leave_to_menu)
	_build_song()
	_waiting = UiKit.label(_frame.footer, "Waiting for the host to start...", true, 17)
	_waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_waiting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ready_button = _frame.main_button("Ready", func(): Net.set_my_ready(not Net.is_ready(Net.my_id())))
	_start = _frame.main_button("Start match", func(): Net.host_start_match())
	Net.players_changed.connect(_refresh)
	Net.internet_changed.connect(_refresh)
	_refresh()
	_dev_lobby_steps()
	# Dev/test: the host starts the next match on its own.
	if DevArgs.autostart > 0 and Net.is_host() and Net.players.size() >= DevArgs.autostart:
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.host_start_match(true))


## A thin upright line between two columns.
func _divider(row: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(UiKit.LINE, 0.12)
	line.custom_minimum_size = Vector2(1, 0)
	row.add_child(line)


## The player list grows with the players, up to three rows, then scrolls (so the lobby
## fits the screen whoever is in it).
func _fit_list() -> void:
	if is_instance_valid(_list_scroll):
		_list_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, 124.0)


func _refresh() -> void:
	UiKit.clear(_list)
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		_list.add_child(_player_row(id))
	_fit_list.call_deferred()
	var watchers := Net.spectator_ids().map(func(id): return Net.spectator_name(id) + (" (you)" if id == Net.my_id() else ""))
	_watching.text = "Spectating: %s" % ", ".join(watchers) if not watchers.is_empty() else "Nobody is spectating."
	if not Net.spectating():
		Net.moved_by_host = false   # playing again
	_spectate.text = ("Play" if Net.player_slot_free() else "Play (lobby full)") if Net.spectating() else "Spectate"
	_spectate.disabled = Net.spectating() and not Net.player_slot_free()
	_start.visible = Net.is_host()
	_ready_button.visible = not Net.is_host()
	_waiting.visible = not Net.is_host()
	var waiting_for := Net.not_ready().size()
	_start.disabled = Net.players.size() < 1 or waiting_for > 0
	_start.text = "START MATCH" if waiting_for == 0 else ("WAITING FOR %d TO READY UP" % waiting_for)
	var me_ready := Net.is_ready(Net.my_id())
	_ready_button.text = "READY  ·  PRESS TO UNDO" if me_ready else "READY UP"
	_waiting.text = "Waiting for the host to start..." if me_ready else "Ready up when you have picked your loadout."
	_size_box.visible = Net.is_host() and Net.is_online
	_updating = true
	_size.min_value = maxi(LobbySettings.MIN_PLAYERS, Net.players.size())   # never below who is already here
	_size.set_value_no_signal(LobbySettings.max_players())
	_updating = false
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
	_info.text = "%d of %d players.  %s" % [Net.players.size(), LobbySettings.max_players(), where]
	if Net.spectating():
		_info.text = "You are spectating: you will watch the match with a free camera.  " + _info.text
		if Net.moved_by_host:
			_info.text = "The host moved you to the spectators. Press Play to join back in when there is room.  " + _info.text
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
	elif id != Net.host_id():   # the host is ready when it presses Start
		var ready := Net.is_ready(id)
		UiKit.tag(row, "READY" if ready else "NOT READY", Color(0.45, 0.95, 0.5) if ready else Color(1, 1, 1, 0.45))
	var who := UiKit.label(row, "%s  ·  %s  ·  %s" % [Characters.name_of(Net.player_character(id)), WeaponData.by_id(Net.player_weapon(id)).short_name,
		Mobility.short_name(Net.player_loadout_mobility(id))], true, 14)
	who.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size = Vector2(60, 0)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Net.is_host() and Net.is_online and id != Net.my_id() and not Net.is_bot(id):
		var kick := UiKit.button(row, "Kick", func(): Net.host_kick(id))
		kick.theme_type_variation = "Chip"
		kick.custom_minimum_size = Vector2(0, 28)
		kick.add_theme_font_size_override("font_size", 13)
		kick.tooltip_text = "Remove %s from the lobby" % Net.player_name(id)
		var watch := UiKit.button(row, "Spectate", func(): Net.host_move_to_spectators(id))
		watch.theme_type_variation = "Chip"
		watch.custom_minimum_size = Vector2(0, 28)
		watch.add_theme_font_size_override("font_size", 13)
		watch.tooltip_text = "Move %s to the spectators (they can come back when there is room)" % Net.player_name(id)
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
		Net.set_match_settings(GunGame.with_mode(Net.match_settings, m, Game.last_map.get(g, Maps.default_id(g)))), 3)   # 3 across: three rows for the seven modes
	for b in _game_row.get_children():
		(b as Button).add_theme_font_size_override("font_size", 16)   # "Deathmatch" in a third of the column
		var short: String = {"Search & Destroy": "S&D", "Capture the Flag": "CTF"}.get((b as Button).text, "")
		if short != "":   # the team modes, by their usual short names (the full name in the tooltip and the rules)
			(b as Button).tooltip_text = (b as Button).text
			(b as Button).text = short
	UiKit.section(_col, "Map")
	_map_label = UiKit.label(_col, "")
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size = Vector2(0, 44)
	Maps.fill(_map_pick, _map_choice(), Net.game_kind(), true)
	_col.add_child(_map_pick)
	_map_pick.item_selected.connect(func(_i: int):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		var picked := Maps.picked(_map_pick)
		s["random_map"] = picked == Maps.RANDOM   # the map is picked from the pool as the match starts
		if picked != Maps.RANDOM:
			s["map"] = picked
			Game.last_map[Net.game_kind()] = picked
		Net.set_match_settings(s))
	# Random map: the maps it may pick from (only this game's; one always stays ticked).
	_map_pool = MapPoolPicker.new(Net.match_settings.get("map_pool", []), Net.game_kind(), Net.is_host())
	_col.add_child(_map_pool)
	_map_pool.changed.connect(func(ids: Array):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["map_pool"] = ids
		Net.set_match_settings(s))


## What the map drop-down shows: the map, or Random.
func _map_choice() -> String:
	return Maps.RANDOM if bool(Net.match_settings.get("random_map", false)) else Net.map_id()


# The lobby song (see Music): the host picks it, any time; everyone hears it, in step.
# In the footer, beside Leave, so the columns keep their room.
func _build_song() -> void:
	_song_box = HBoxContainer.new()
	_song_box.add_theme_constant_override("separation", 8)
	_frame.footer.add_child(_song_box)
	var head := UiKit.label(_song_box, "Lobby song", true, 15)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_song_pick = OptionButton.new()
	_song_pick.custom_minimum_size = Vector2(230, 0)
	_song_pick.add_item(Music.title_of(""))
	_song_pick.set_item_metadata(0, "")
	for song in Music.song_names():
		_song_pick.add_item(Music.title_of(song))
		_song_pick.set_item_metadata(_song_pick.item_count - 1, song)
	_song_box.add_child(_song_pick)
	_song_pick.item_selected.connect(func(i: int):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["song"] = str(_song_pick.get_item_metadata(i))
		if s != Net.match_settings:
			Net.set_match_settings(s))
	_song_label = UiKit.label(_song_box, "", false, 15)
	_song_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_song_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


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
		elif s.mode != "time":   # ("kills", or a mode played to a kill target: Golden Gun)
			s.kills = int(v)
		else:
			s.minutes = int(v)
		if s != Net.match_settings:
			Net.set_match_settings(s))
	# Killcam mode: the points to win and the time limit (see KillcamMode).
	_killcam_rules = HBoxContainer.new()
	_killcam_rules.add_theme_constant_override("separation", 10)
	_col.add_child(_killcam_rules)
	var first := UiKit.label(_killcam_rules, "First to")
	first.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	first.autowrap_mode = TextServer.AUTOWRAP_OFF
	_killcam_points = SpinBox.new()
	_killcam_points.min_value = KillcamMode.POINTS_MIN
	_killcam_points.max_value = KillcamMode.POINTS_MAX
	_killcam_points.step = KillcamMode.POINTS_STEP
	_killcam_points.custom_minimum_size = Vector2(130, 44)
	_killcam_rules.add_child(_killcam_points)
	var or_label := UiKit.label(_killcam_rules, "points, or")
	or_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	or_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_killcam_minutes = SpinBox.new()
	_killcam_minutes.min_value = KillcamMode.MINUTES_MIN
	_killcam_minutes.max_value = KillcamMode.MINUTES_MAX
	_killcam_minutes.custom_minimum_size = Vector2(90, 44)
	_killcam_rules.add_child(_killcam_minutes)
	var mins := UiKit.label(_killcam_rules, "minutes")
	mins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mins.autowrap_mode = TextServer.AUTOWRAP_OFF
	var set_killcam := func(key: String, v: float):
		if _updating:
			return
		var ks := Net.match_settings.duplicate()
		ks[key] = int(v)
		ks = LobbySettings.clean(ks)
		if ks != Net.match_settings:
			Net.set_match_settings(ks)
	_killcam_points.value_changed.connect(func(v: float): set_killcam.call("killcam_points", v))
	_killcam_minutes.value_changed.connect(func(v: float): set_killcam.call("killcam_minutes", v))
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
	_rules_head = UiKit.section(_col, "Loadout rules").get_parent()
	_allowed = AllowedWeaponsPicker.new(Net.match_settings.get("weapons", []), Net.is_host(), false)
	_col.add_child(_allowed)
	_allowed.changed.connect(func(ids: Array):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["weapons"] = ids
		Net.set_match_settings(s))
	_allowed_mobility = AllowedMobilityPicker.new(Net.match_settings.get("mobility", []), Net.is_host(), false)
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
	var team_mode := Teams.mode()   # "snd", "ctf" or ""
	var own_rules := gun_game or killcam or team_mode != ""   # a mode with rules of its own: no kills/time choice
	var golden := GoldenGun.active()   # (first to a kill target the host sets, never a time limit)
	var kills_mode: bool = s.mode != "time"
	_rules_label.text = ("First to %d kills" % s.kills) if kills_mode else ("Most kills after %d minutes" % s.minutes)
	if race:
		_rules_label.text = "First to the finish  ·  %d minute limit" % int(s.get("race_minutes", 10))
	if gun_game:
		_rules_label.text = "Every kill moves you to the next of %d weapons. First to get a kill with the last one (brass knuckles) wins. Kicked to death: back one weapon." % GunGame.steps()
	if killcam:
		_rules_label.text = "Snipers only. Every kill scores its killcam points: range, headshots, momentum (both of you moving), flicks, trickshots. First to %s points, or the most after %d minutes. The match's #1 killcam earns +%s at the end." \
			% [KillcamMode.format(KillcamMode.target()), KillcamMode.minutes(), KillcamMode.format(KillcamMode.BEST_BONUS)]
		if Net.is_host():   # (the host's boxes below show the points and minutes)
			_rules_label.text = "Snipers only. Every kill scores its killcam points. The match's #1 killcam earns +%s at the end." \
				% KillcamMode.format(KillcamMode.BEST_BONUS)
	if golden:
		_rules_label.text = "One player has the Golden Gun: one round, and whoever it hits dies. Kill them to take it. Everyone else has their own weapon. First to %d kills." % s.kills
	if team_mode == "snd":
		_rules_label.text = "Two teams, Red and Blue, no respawns in a round. The attackers carry a bomb: hold %s on site A or B to plant it. Defenders: hold %s on it to defuse. Blow a site, defuse, or knock the other team out to win the round. Sides swap after %d rounds; first to %d rounds wins." \
			% [Settings.action_text("interact"), Settings.action_text("interact"), Teams.HALF, Teams.ROUNDS_TO_WIN]
	elif team_mode == "ctf":
		_rules_label.text = "Two teams, Red and Blue. Walk over the other team's flag to take it and bring it to your own flag (it must be home) to score. Walk over your own dropped flag to send it home. First to %d captures, or the most after %d minutes." \
			% [Teams.CAPTURES_TO_WIN, int(Teams.CTF_TIME / 60.0)]
	_game_label.text = "Gun Game" if gun_game else ("Killcam" if killcam else ("Golden Gun" if golden else (Teams.MODE_NAMES[team_mode] if team_mode != "" else Maps.GAME_NAMES.get(Net.game_kind(), ""))))
	_game_label.visible = not Net.is_host()
	_game_row.visible = Net.is_host()
	_mode_pick.visible = not race and not golden
	var only := LobbySettings.only_weapon()
	if _weapon:
		# No guns in a race; Gun Game hands them out; Killcam is snipers only; a Deathmatch
		# finds them on the map; the host may have set one gun for everyone.
		_weapon.set_allowed(LobbySettings.allowed_weapons())
		_weapon.visible = not race and not gun_game and not killcam and not Net.is_deathmatch() and only == ""
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
	_rules_label.visible = not Net.is_host() or own_rules or golden
	_host_rules.visible = Net.is_host() and not own_rules
	_killcam_rules.visible = Net.is_host() and killcam
	var random := bool(s.get("random_map", false))
	_map_label.text = Maps.label(Net.map_id())
	if random:   # everyone else sees the pool below; after a match, what it picked last
		_map_label.text = "Random map" + ("  ·  last: %s" % Maps.name_of(Net.map_id()) if not Match.last_results.is_empty() else "")
	_map_label.visible = not Net.is_host()
	_map_pick.visible = Net.is_host()
	_map_pool.visible = random
	_map_pool.set_editable(Net.is_host())
	_map_pool.set_value(s.get("map_pool", []), Net.game_kind())
	var song := str(s.get("song", ""))
	_song_pick.visible = Net.is_host()
	_song_label.visible = not Net.is_host()
	_song_label.text = Music.title_of(song)
	_updating = true
	for i in _game_row.get_child_count():
		(_game_row.get_child(i) as Button).set_pressed_no_signal(GunGame.MODES[i] == GunGame.mode_of(s))
	Maps.fill(_map_pick, _map_choice(), Net.game_kind(), true)
	for i in _song_pick.item_count:
		if str(_song_pick.get_item_metadata(i)) == song:
			_song_pick.select(i)
	_mode_pick.select(0 if kills_mode else 1)
	_killcam_points.set_value_no_signal(KillcamMode.clean_points(s.get("killcam_points")))
	_killcam_minutes.set_value_no_signal(KillcamMode.clean_minutes(s.get("killcam_minutes")))
	_powerups.visible = Net.is_deathmatch()
	_powerups.disabled = not Net.is_host()   # everyone else just sees the host's choice
	_powerups.set_pressed_no_signal(Net.powerups_on())
	if _allowed:
		_allowed.set_value(s.get("weapons", []))
	if _allowed_mobility:
		_allowed_mobility.visible = LobbySettings.mobility_apply()   # a race always has the grapple
		_rules_head.visible = _allowed_mobility.visible   # a race has no loadout rules
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


## Dev/test: ready up, kick a player and start once everyone is ready, on their own
## (--ready-at, --kick-at, --start-when-ready), the first time the lobby opens.
func _dev_lobby_steps() -> void:
	if not Match.last_results.is_empty():
		return
	if DevArgs.song_at >= 0.0 and Net.is_host():
		get_tree().create_timer(DevArgs.song_at).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				var s := Net.match_settings.duplicate()
				s["song"] = DevArgs.song_later
				Net.set_match_settings(s))
	if DevArgs.ready_at >= 0.0 and not Net.is_host():
		get_tree().create_timer(DevArgs.ready_at).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.set_my_ready(true))
	if DevArgs.kick_at >= 0.0 and Net.is_host():
		get_tree().create_timer(DevArgs.kick_at).timeout.connect(func():
			for id in Net.players:
				if is_inside_tree() and Net.player_name(id) == DevArgs.kick_name:
					Net.host_kick(id)
					return)
	if DevArgs.move_at >= 0.0 and Net.is_host():
		get_tree().create_timer(DevArgs.move_at).timeout.connect(func():
			for id in Net.players:
				if is_inside_tree() and Net.player_name(id) == DevArgs.move_name:
					Net.host_move_to_spectators(id)
					return)
	for t in DevArgs.play_at:
		get_tree().create_timer(float(t)).timeout.connect(func():
			if is_inside_tree() and Net.spectating():
				print("PLAY_PRESSED")
				Net.set_spectating(false))
	if DevArgs.start_when_ready and Net.is_host():
		Net.players_changed.connect(func():
			if is_inside_tree() and not Net.in_match and Net.players.size() >= 2 and Net.all_ready():
				Net.host_start_match())
