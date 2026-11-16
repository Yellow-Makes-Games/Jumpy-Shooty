extends Control
## Match results: the winner's robot, the rankings, then a rematch or back to the lobby.

func _ready() -> void:
	var col := UiKit.screen(self, 860)
	var results: Array = Match.last_results
	var won: bool = not results.is_empty() and results[0].id == Net.my_id() and results[0].kills > 0
	var title := "Match over"
	if won:
		title = "Victory"
	elif not results.is_empty():
		title = "%s wins" % results[0].name
	UiKit.title(col, title, 48)
	var sub := Maps.name_of(Net.map_id())
	if not results.is_empty():
		sub += "  ·  %s scored %d" % ["You" if won else results[0].name, results[0].kills]
	UiKit.label(col, sub, true, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	if not results.is_empty():
		var winner := RobotPreview.new(Vector2(240, 300), 1.0)
		row.add_child(winner)
		winner.show_robot(Net.player_character(results[0].id), Net.player_color(results[0].id))
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(table)
	ResultsTable.build(table, results)
	UiKit.spacer(col, 4)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	UiKit.button(buttons, "Main menu", Game.leave_to_menu).custom_minimum_size = Vector2(200, 56)
	var next: Button = null
	if Game.mode == Game.Mode.BOT:
		next = UiKit.primary_button(buttons, "Rematch", Game.rematch_bot)
	elif Game.mode == Game.Mode.ONLINE and Net.is_online:
		next = UiKit.primary_button(buttons, "Return to lobby", Game.goto_lobby)
	if next:
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.grab_focus()
	if DevArgs.auto_return and Game.mode == Game.Mode.ONLINE:
		get_tree().create_timer(2.0).timeout.connect(Game.goto_lobby)
	elif DevArgs.auto_return and Game.mode == Game.Mode.BOT:
		get_tree().create_timer(2.0).timeout.connect(Game.rematch_bot)
