extends Control
## Main menu: Play, Multiplayer, Settings, Exit.
## Built in code; each "page" replaces the contents of one centred panel.

var _col: VBoxContainer
var _name_edit: LineEdit
var _address_edit: LineEdit
var _status: Label


func _ready() -> void:
	_col = UiKit.screen(self)
	match DevArgs.menu:
		"play": _show_play()
		"bot": _show_bot()
		"multiplayer": _show_multiplayer()
		"settings": _show_settings()
		_: _show_main()


func _show_main() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "JUMPY SHOOTY", 52)
	UiKit.label(_col, "Milestone 1 in progress: placeholder visuals", true, 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Game.pending_notice != "":
		var n := UiKit.label(_col, Game.pending_notice)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", UiKit.ACCENT)
		Game.pending_notice = ""
	UiKit.spacer(_col, 12)
	UiKit.button(_col, "Play", _show_play).grab_focus()
	UiKit.button(_col, "Multiplayer", _show_multiplayer)
	UiKit.button(_col, "Settings", _show_settings)
	UiKit.button(_col, "Exit", Game.quit_game)


func _show_play() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "Play", 36)
	UiKit.button(_col, "1v1 Bot", _show_bot).grab_focus()
	UiKit.button(_col, "Practice (free roam)", Game.start_practice)
	UiKit.button(_col, "Multiplayer FFA", _show_multiplayer)
	UiKit.spacer(_col)
	UiKit.button(_col, "Back", _show_main)


const BOT_BLURBS := [
	"Slow to react, wobbly aim, mostly just runs and shoots.",
	"Reacts in about a third of a second, slides while chasing you.",
	"Quick and accurate, strafes hard, grapples, dives and flips.",
	"Near-instant reactions, leads its shots, goes for your head.",
]


func _show_bot() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "1v1 Bot", 36)
	UiKit.label(_col, "Difficulty", true, 16)
	var pick := OptionButton.new()
	for i in BotDifficulty.NAMES.size():
		pick.add_item(BotDifficulty.NAMES[i], i)
	pick.custom_minimum_size = Vector2(0, 44)
	pick.select(Game.last_bot.difficulty)
	_col.add_child(pick)
	var blurb := UiKit.label(_col, BOT_BLURBS[Game.last_bot.difficulty], true, 15)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(0, 44)
	pick.item_selected.connect(func(i: int): blurb.text = BOT_BLURBS[i])
	UiKit.spacer(_col, 4)
	UiKit.label(_col, "Kills to win", true, 16)
	var kills := SpinBox.new()
	kills.min_value = 1
	kills.max_value = 50
	kills.value = Game.last_bot.kills
	kills.custom_minimum_size = Vector2(0, 44)
	_col.add_child(kills)
	UiKit.label(_col, "Map: %s" % TestingGrounds.MAP_NAME, true, 15)
	UiKit.spacer(_col, 4)
	UiKit.button(_col, "Start", func(): Game.start_bot(pick.selected, int(kills.value))).grab_focus()
	UiKit.spacer(_col)
	UiKit.button(_col, "Back", _show_play)


func _show_multiplayer() -> void:
	UiKit.clear(_col)
	UiKit.title(_col, "Multiplayer", 36)
	UiKit.label(_col, "Your name", true, 16)
	_name_edit = UiKit.line_edit(_col, "Player", Game.local_name() if Game.local_name() != "Player" else "")
	UiKit.spacer(_col, 4)
	UiKit.button(_col, "Create lobby", _on_create)
	UiKit.spacer(_col, 4)
	UiKit.label(_col, "Join by address (direct IP; Steam invites come next)", true, 16)
	_address_edit = UiKit.line_edit(_col, "127.0.0.1", "")
	UiKit.button(_col, "Join lobby", _on_join)
	_status = UiKit.label(_col, "", true, 16)
	UiKit.spacer(_col)
	UiKit.button(_col, "Back", _show_main)


func _show_settings() -> void:
	UiKit.clear(_col)
	var panel := SettingsPanel.new()
	panel.closed.connect(_show_main)
	_col.add_child(panel)


func _save_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "" and n != Settings.player_name:
		Settings.player_name = n
		Settings.save_settings()


func _on_create() -> void:
	_save_name()
	var err := Game.host_online()
	if err != OK:
		_status.text = "Could not create the lobby (%s). Is another copy already hosting on this PC?" % error_string(err)


func _on_join() -> void:
	_save_name()
	var err := Game.join_online(_address_edit.text.strip_edges())
	if err != OK:
		_status.text = "Could not start joining (%s)." % error_string(err)
	else:
		_status.text = "Connecting..."
