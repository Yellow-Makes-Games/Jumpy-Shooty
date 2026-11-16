extends Control
## Multiplayer lobby: shows who is connected and who is hosting.
## The host starts the match; anyone can leave.

var _col: VBoxContainer
var _list: VBoxContainer
var _start: Button
var _info: Label
var _rules_label: Label
var _host_rules: HBoxContainer
var _mode_pick: OptionButton
var _amount: SpinBox
var _amount_unit: Label
var _map_label: Label
var _map_pick: OptionButton
var _updating := false   # true while we fill the controls from settings (ignore their signals)


func _ready() -> void:
	_col = UiKit.screen(self, 520)
	UiKit.title(_col, "Lobby", 40)
	_info = UiKit.label(_col, "", true, 16)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.spacer(_col, 4)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_col.add_child(_list)
	UiKit.spacer(_col, 8)
	_build_map()
	_build_rules()
	UiKit.spacer(_col, 4)
	_start = UiKit.button(_col, "Start match", Net.host_start_match)
	UiKit.button(_col, "Leave lobby", Game.leave_to_menu)
	Net.players_changed.connect(_refresh)
	_refresh()
	# Dev/test: the host starts the next match on its own.
	if DevArgs.autostart > 0 and Net.is_host() and Net.players.size() >= DevArgs.autostart:
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_inside_tree() and not Net.in_match:
				Net.host_start_match())


func _refresh() -> void:
	UiKit.clear(_list)
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var row := HBoxContainer.new()
		_list.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Net.player_color(id)
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_text: String = Net.player_name(id)
		if id == Net.host_id():
			name_text += "   (host)"
		if id == Net.my_id():
			name_text += "   (you)"
		var l := UiKit.label(row, "  " + name_text)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.visible = Net.is_host()
	_start.disabled = Net.players.size() < 1
	var where := ""
	if Net.is_host():
		where = "Friends on your network can join at %s (port %d)." % [_local_ip(), Net.port]
	else:
		where = "Waiting for the host to start the match."
	_info.text = "%d / %d players. %s" % [Net.players.size(), Net.MAX_PLAYERS, where]
	_refresh_rules()


# Map: the host picks; everyone else sees it.
func _build_map() -> void:
	UiKit.label(_col, "Map", true, 16)
	_map_label = UiKit.label(_col, "")
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size = Vector2(0, 44)
	Maps.fill(_map_pick, Net.map_id())
	_col.add_child(_map_pick)
	_map_pick.item_selected.connect(func(i: int):
		if _updating:
			return
		var s := Net.match_settings.duplicate()
		s["map"] = Maps.LIST[i].id
		Net.set_match_settings(s))


# Win condition: the host picks; everyone else sees it.
func _build_rules() -> void:
	UiKit.label(_col, "Win condition", true, 16)
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
		if s.mode == "kills":
			s.kills = int(v)
		else:
			s.minutes = int(v)
		if s != Net.match_settings:
			Net.set_match_settings(s))


func _refresh_rules() -> void:
	var s: Dictionary = Net.match_settings
	var kills_mode: bool = s.mode == "kills"
	_rules_label.text = ("First to %d kills" % s.kills) if kills_mode else ("Most kills after %d minutes" % s.minutes)
	_rules_label.visible = not Net.is_host()
	_host_rules.visible = Net.is_host()
	_map_label.text = Maps.label(Net.map_id())
	_map_label.visible = not Net.is_host()
	_map_pick.visible = Net.is_host()
	_updating = true
	_map_pick.select(Maps.ids().find(Net.map_id()))
	_mode_pick.select(0 if kills_mode else 1)
	if kills_mode:
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


func _local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
