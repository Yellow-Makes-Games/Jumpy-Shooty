extends Control
## Match results: the winner's robot, the rankings, then a rematch or back to the lobby.
## Built in a MenuFrame: with 16 players the rankings scroll and the buttons stay put.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := MenuFrame.new(1000)
	add_child(frame)
	var col := frame.body
	var results: Array = Match.last_results
	var race: bool = not results.is_empty() and results[0].get("race", false)
	var won: bool = not results.is_empty() and results[0].id == Net.my_id() and results[0].kills > 0
	var title := "Match over"
	var sub := Maps.name_of(Net.map_id())
	if race:
		# A race: the winner is whoever finished first (if anyone did).
		var first_done: bool = results[0].finished
		won = first_done and results[0].id == Net.my_id()
		if results.size() == 1:
			title = "Finished!" if first_done else "Out of time"
		elif won:
			title = "You win the race"
		elif first_done:
			title = "%s wins" % results[0].name
		else:
			title = "Nobody finished"
		sub += "  ·  Race"
		if first_done:
			sub += "  ·  %s in %s" % ["You" if won else results[0].name, Race.format_time(results[0].time)]
		var mine := results.filter(func(r): return r.id == Net.my_id())
		if results.size() > 1 and not mine.is_empty() and mine[0].finished and not won:
			sub += "  ·  You: %s, %s" % [Race.ordinal(results.find(mine[0]) + 1), Race.format_time(mine[0].time)]
	else:
		if won:
			title = "Victory"
		elif not results.is_empty():
			title = "%s wins" % results[0].name
		if not results.is_empty():
			sub += "  ·  %s scored %d" % ["You" if won else results[0].name, results[0].kills]
	frame.title(title, "Results", 48)
	UiKit.label(frame.header, sub, true, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	if not results.is_empty():
		var winner := RobotPreview.new(Vector2(240, 300), 1.0)
		winner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(winner)
		winner.show_robot(Net.player_character(results[0].id), Net.player_color(results[0].id))
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(table)
	ResultsTable.build(table, results)
	var buttons := frame.footer
	frame.back_button("Main menu", Game.leave_to_menu)
	var next: Button = null
	if Game.mode == Game.Mode.BOT:
		next = UiKit.primary_button(buttons, "Race again" if race else "Rematch", Game.rematch_bot)
	elif Game.mode == Game.Mode.PRACTICE:
		next = UiKit.primary_button(buttons, "Run it again", func(): Game.start_practice(Net.map_id()))
	elif Game.mode == Game.Mode.ONLINE and Net.is_online:
		next = UiKit.primary_button(buttons, "Return to lobby", Game.goto_lobby)
	if next:
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.grab_focus()
	if DevArgs.auto_return and Game.mode == Game.Mode.ONLINE:
		get_tree().create_timer(2.0).timeout.connect(Game.goto_lobby)
	elif DevArgs.auto_return and Game.mode == Game.Mode.BOT:
		get_tree().create_timer(2.0).timeout.connect(Game.rematch_bot)
