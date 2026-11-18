extends Node
## Calling card checks (started by tests/calling_card_test.gd). Nothing here touches
## the real achievements file or saves the settings.

var _fails: Array[String] = []
var _drawn := 0


func run() -> void:
	await get_tree().process_frame
	print("Calling card checks")
	var saved_card := Settings.calling_card
	var saved_icon := Settings.icon
	Settings.calling_card = CallingCard.DEFAULT_CARD
	Settings.icon = CallingCard.DEFAULT_ICON
	Achievements.reset_for_test()

	print("  the designs")
	var ids := {}
	var sound := true
	for c in CallingCard.CARDS:
		sound = sound and not ids.has("card:" + c.id) and str(c.name) != "" and CallingCard.valid_card(c.id) == c.id
		ids["card:" + c.id] = true
	for i in CallingCard.ICONS:
		sound = sound and not ids.has("icon:" + i.id) and str(i.name) != "" and CallingCard.valid_icon(i.id) == i.id
		ids["icon:" + i.id] = true
	_expect(sound and CallingCard.CARDS.size() >= 24 and CallingCard.ICONS.size() >= 24,
		"%d cards and %d icons, each with its own id and a name" % [CallingCard.CARDS.size(), CallingCard.ICONS.size()])
	_expect(CallingCard.valid_card("made_up") == CallingCard.DEFAULT_CARD and CallingCard.valid_icon("") == CallingCard.DEFAULT_ICON
		and CallingCard.card_name("sunset") == "Sunset Drive" and CallingCard.icon_name("skull") == "Skull", "a made-up id is the plain one; a real one has its name")
	var free_cards := CallingCard.CARDS.filter(func(c): return not Achievements.locked("card:" + c.id)).size()
	var free_icons := CallingCard.ICONS.filter(func(i): return not Achievements.locked("icon:" + i.id)).size()
	_expect(free_cards >= 5 and free_icons >= 6 and free_cards < CallingCard.CARDS.size() and free_icons < CallingCard.ICONS.size()
		and not Achievements.locked("card:" + CallingCard.DEFAULT_CARD) and not Achievements.locked("icon:" + CallingCard.DEFAULT_ICON),
		"a new player has %d cards and %d icons to pick from, the plain ones among them; the rest are locked" % [free_cards, free_icons])
	# Every design draws (a pattern or a glyph the drawing code does not know would say so).
	var canvas := Control.new()
	canvas.size = Vector2(400, 100)
	canvas.draw.connect(func():
		for c in CallingCard.CARDS:
			CallingCard.draw(canvas, Rect2(0, 0, 300, 60), c.id, CallingCard.ICONS[_drawn % CallingCard.ICONS.size()].id, 0.5)
			_drawn += 1
		for i in CallingCard.ICONS:
			CallingCard.draw_icon(canvas, Rect2(0, 0, 48, 48), i.id)
			_drawn += 1)
	add_child(canvas)
	for i in 3:
		await get_tree().process_frame
	canvas.queue_free()
	_expect(_drawn == CallingCard.CARDS.size() + CallingCard.ICONS.size(), "every card and icon draws (%d)" % _drawn)

	# No glyph falls through to the plain dot the drawing code uses for one it does not know.
	var source := FileAccess.get_file_as_string("res://game/ui/calling_card.gd")
	var unknown := []
	for i in CallingCard.ICONS:
		if not ('\t\t"%s":' % i.glyph) in source:
			unknown.append(i.glyph)
	for c in CallingCard.CARDS:
		if not ('"%s"' % c.pattern) in source.get_slice("static func _draw_pattern", 1):
			unknown.append(c.pattern)
	_expect(unknown.is_empty(), "every icon's glyph and every card's pattern is one the drawing code knows %s" % [unknown])

	print("  the picker")
	var picker := CallingCardPicker.new()
	picker.saves = false
	add_child(picker)
	_expect(picker.find_child("card_inferno", true, false).locked and not picker.find_child("card_ember", true, false).locked
		and picker.find_child("card_" + CallingCard.DEFAULT_CARD, true, false).chosen, "the locked ones are marked, and yours is framed")
	picker.pick("card", "inferno")
	_expect(Settings.calling_card == CallingCard.DEFAULT_CARD and "locked" in picker.status.text and "Unstoppable" in picker.status.text,
		"a locked card is not taken, and the page says what it needs (%s)" % picker.status.text)
	picker.pick("card", "ember")
	picker.pick("icon", "volt")
	_expect(Settings.calling_card == "ember" and Settings.icon == "volt" and picker.find_child("icon_volt", true, false).chosen
		and not picker.find_child("icon_recruit", true, false).chosen, "a free card and a free icon are yours at a click")
	Achievements.add("streaks_10")
	picker._refresh()
	picker.pick("card", "inferno")
	_expect(Settings.calling_card == "inferno" and not picker.find_child("card_inferno", true, false).locked, "10 kills without dying later, Inferno can be picked")

	print("  the lobby")
	Net.start_offline("Host", "needle", "pistol")
	_expect(Net.player_card(1) == "inferno" and Net.player_icon(1) == "volt", "you take your card and icon into a lobby")
	picker.pick("card", "tide")
	_expect(Net.player_card(1) == "tide", "a pick made in a lobby shows there at once")
	Net.set_my_card("nonsense", "also nonsense")
	_expect(Net.player_card(1) == CallingCard.DEFAULT_CARD and Net.player_icon(1) == CallingCard.DEFAULT_ICON, "a made-up card is the plain one for everyone")
	var bot := Net.add_bot(1)
	_expect(CallingCard.valid_card(Net.player_card(bot)) == Net.player_card(bot) and str(Net.players[bot].get("card", "")) != ""
		and str(Net.players[bot].get("icon", "")) != "", "a bot has a card and an icon of its own")
	_expect(Net.player_card(4242) == CallingCard.DEFAULT_CARD and Net.player_icon(4242) == CallingCard.DEFAULT_ICON, "someone who is not here has the plain ones")
	var view := CallingCardView.of_player(bot)
	_expect(view.card == Net.player_card(bot) and view.icon == Net.player_icon(bot), "a player's card view shows theirs")
	view.free()
	picker.queue_free()

	Net.leave()
	Achievements.reset_for_test()
	Settings.calling_card = saved_card
	Settings.icon = saved_icon
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
