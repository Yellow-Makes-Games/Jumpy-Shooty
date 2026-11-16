extends Control
## Match results: rankings with kills and deaths, then back to the lobby.

func _ready() -> void:
	var col := UiKit.screen(self, 560)
	var results: Array = Match.last_results
	var title := "Match over"
	if not results.is_empty():
		title = "You win!" if results[0].id == Net.my_id() and results[0].kills > 0 else "%s wins" % results[0].name
	UiKit.title(col, title, 44)
	UiKit.spacer(col, 6)
	ResultsTable.build(col, results)
	UiKit.spacer(col, 12)
	if Game.mode == Game.Mode.BOT:
		UiKit.button(col, "Rematch", Game.rematch_bot).grab_focus()
	elif Game.mode == Game.Mode.ONLINE and Net.is_online:
		UiKit.button(col, "Return to lobby", Game.goto_lobby).grab_focus()
	UiKit.button(col, "Main menu", Game.leave_to_menu)
	if DevArgs.auto_return and Game.mode == Game.Mode.ONLINE:
		get_tree().create_timer(2.0).timeout.connect(Game.goto_lobby)
	elif DevArgs.auto_return and Game.mode == Game.Mode.BOT:
		get_tree().create_timer(2.0).timeout.connect(Game.rematch_bot)
