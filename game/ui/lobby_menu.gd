extends Control
## Multiplayer lobby: shows who is connected and who is hosting.
## The host starts the match; anyone can leave.

var _col: VBoxContainer
var _list: VBoxContainer
var _start: Button
var _info: Label


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
	_start = UiKit.button(_col, "Start match", Net.host_start_match)
	UiKit.button(_col, "Leave lobby", Game.leave_to_menu)
	Net.players_changed.connect(_refresh)
	_refresh()


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


func _local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
