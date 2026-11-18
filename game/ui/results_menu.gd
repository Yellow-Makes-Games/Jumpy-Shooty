extends Control
## Match results: first the match's best kills, fullscreen from the killers' eyes
## (KillcamScreen); then the winner's robot, the rankings and the best kills to watch
## again or save as a video to share (KillcamExport), and a rematch or back to the lobby.
## Built in a MenuFrame: with 16 players the rankings scroll and the buttons stay put.

const KILLCAM_LIST_W := 420.0

var _show: KillcamScreen   # the best kills playing fullscreen over the page, or null
var _next: Button
var _saves: Array = []     # the Save buttons, one per best kill
var _saving := false       # a video is being made (one at a time)
var _status: Label         # "Saved ... in Videos/Jumpy Shooty"
var _open: Button          # ...and a button to show it in its folder
var _saved_path := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var results: Array = Match.last_results
	var race: bool = not results.is_empty() and results[0].get("race", false)
	var highlights: Array = Match.highlights if not race else []
	var frame := MenuFrame.new(1000 if highlights.is_empty() else 1240)
	add_child(frame)
	var col := frame.body
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
		var killcam: bool = not results.is_empty() and results[0].get("killcam", false)
		var teams := str(results[0].get("teams", "")) if not results.is_empty() else ""
		if teams != "":
			# A team mode: your team won, lost or drew; the score in rounds or captures.
			var scores: Array = results[0].get("scores", [0, 0])
			var winner := -1 if int(scores[0]) == int(scores[1]) else (0 if int(scores[0]) > int(scores[1]) else 1)
			var mine := results.filter(func(r): return r.id == Net.my_id())
			var my_team: int = int(mine[0].get("team", -1)) if not mine.is_empty() else -1
			won = winner >= 0 and my_team == winner
			if winner < 0:
				title = "Draw"
			elif my_team < 0:
				title = "%s wins" % Teams.team_name(winner)
			else:
				title = "Victory" if won else "Defeat"
			sub += "  ·  %s  ·  Red %d - %d Blue" % [Teams.MODE_NAMES.get(teams, ""), int(scores[0]), int(scores[1])]
			if winner >= 0:
				sub += "  ·  %s team wins" % Teams.team_name(winner)
		elif killcam:
			won = results[0].id == Net.my_id() and int(results[0].points) > 0
			title = "Victory" if won else "%s wins" % results[0].name
			sub += "  ·  Killcam  ·  %s scored %s points" % ["You" if won else results[0].name, KillcamMode.format(int(results[0].points))]
		elif not results.is_empty():
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
	if not highlights.is_empty():
		_add_killcams(row, highlights)
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
	_next = next
	if not highlights.is_empty():
		watch.call_deferred([])   # the best kills first, fullscreen; then the page
	if DevArgs.auto_return and Game.mode == Game.Mode.ONLINE:
		get_tree().create_timer(2.0).timeout.connect(Game.goto_lobby)
	elif DevArgs.auto_return and Game.mode == Game.Mode.BOT:
		get_tree().create_timer(2.0).timeout.connect(Game.rematch_bot)


## The best kills: a button for each that plays it again fullscreen, and one for all three.
func _add_killcams(row: HBoxContainer, highlights: Array) -> void:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.custom_minimum_size = Vector2(KILLCAM_LIST_W, 0)
	row.add_child(side)
	UiKit.section(side, "Best kills")
	for i in highlights.size():
		var h: Dictionary = highlights[i]
		var tags := KillScore.words(h)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text = "#%d   %s  >  %s" % [i + 1, Net.player_name(int(h.killer)), Net.player_name(int(h.victim))]
		b.tooltip_text = "  ·  ".join(tags) if not tags.is_empty() else "A clean kill"
		b.pressed.connect(func(): watch([i]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		side.add_child(pair)
		pair.add_child(b)
		var save := UiKit.button(pair, "Save", func(): save_video(i))
		save.tooltip_text = "Save this killcam as a video to share (in Videos/Jumpy Shooty)"
		save.custom_minimum_size.x = 96
		_saves.append(save)
		var line := UiKit.label(side, "  ·  ".join(tags.slice(0, 3)) if not tags.is_empty() else "A clean kill", true, 13)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = true
		if i == 0 and not Match.last_results.is_empty() and Match.last_results[0].get("killcam", false):
			line.text = "+%s points for the best killcam  ·  %s" % [KillcamMode.format(KillcamMode.BEST_BONUS), line.text]
			line.add_theme_color_override("font_color", ResultsTable.GOLD)
	UiKit.button(side, "Watch all three" if highlights.size() == 3 else "Watch them all", func(): watch([]))
	var saved := HBoxContainer.new()
	saved.add_theme_constant_override("separation", 6)
	side.add_child(saved)
	_status = UiKit.label(saved, "", true, 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open = UiKit.button(saved, "Show file", func(): OS.shell_show_in_file_manager(_saved_path))
	_open.visible = false
	if DevArgs.save_killcam > 0 and DevArgs.save_killcam <= highlights.size():
		save_video.call_deferred(DevArgs.save_killcam - 1)


## Save best kill `i` (an index into Match.highlights) as a video file to share.
func save_video(i: int) -> void:
	if _saving or i < 0 or i >= Match.highlights.size():
		return
	var clip := Killcam.clip_for(Match.highlights[i])
	if clip == null:
		_status.text = "No replay of that kill on this copy (it was before you joined)"
		return
	_saving = true
	_open.visible = false
	for b in _saves:
		(b as Button).disabled = true
	var button: Button = _saves[i]
	var export := KillcamExport.new()
	if DevArgs.save_killcam > 0:
		export.into = ProjectSettings.globalize_path("user://killcams")   # tests: not into your Videos
	get_tree().root.add_child(export)   # (finishes even if you leave this page meanwhile)
	_status.text = "Saving the video..."
	export.progress.connect(func(f: float): button.text = "%d%%" % roundi(f * 100.0))
	export.finished.connect(func(path: String, error: String):
		_saving = false
		for b in _saves:
			(b as Button).disabled = false
			(b as Button).text = "Save"
		if error != "":
			_status.text = "Could not save the video: %s" % error
			return
		_saved_path = path
		_status.text = "Video saved in %s" % path.get_base_dir().get_file()
		_status.tooltip_text = path
		_open.visible = true
		Sound.play("ui_click"))
	export.start(clip, "BEST KILL #%d" % (i + 1))


## Play best kills fullscreen over the page (`which`: indexes into Match.highlights;
## empty for all of them, counting down to the best).
func watch(which: Array) -> void:
	if _show and is_instance_valid(_show):
		_show.queue_free()
	_show = KillcamScreen.new()
	add_child(_show)
	_show.done.connect(func():
		_show.queue_free()
		_show = null
		if _next and is_instance_valid(_next):
			_next.grab_focus())
	_show.play(Match.highlights, which)
