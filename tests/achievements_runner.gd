extends Node
## Achievement checks (started by tests/achievements_test.gd). Nothing here touches
## the real achievements file or saves the settings.

const TEST_FILE := "user://achievements_test.cfg"

var _fails: Array[String] = []
var _announced: Array = []


func run() -> void:
	await get_tree().process_frame
	print("Achievement checks")
	var saved_characters: Array = Settings.custom_characters.duplicate()
	var saved_pick := Settings.character
	Settings.custom_characters = []
	Settings.character = Characters.default_id()
	Achievements.reset_for_test()
	Achievements.unlocked.connect(func(id: String): _announced.append(id))

	print("  the list")
	var seen := {}
	var bad := []
	for a in Achievements.LIST:
		for key in a.rewards:
			var kind: String = key.get_slice(":", 0)
			var id: String = key.get_slice(":", 1)
			var real := false
			match kind:
				"part": real = Characters.has_part(id) and not id in ["human", "goblin", "frog", Characters.default_id()]
				"paint": real = CustomCharacter.paint_color(id).a > 0.0
				_: real = kind in CustomCharacter.SLOTS and CustomCharacter.accessory_name(kind, id) != "None"
			if not real or seen.has(key):
				bad.append(key)
			seen[key] = true
	_expect(bad.is_empty(), "every reward is a real item, given once, and never the dude, the goblin or the frog %s" % [bad])
	_expect(Achievements.item_counts() == [0, seen.size()] and Achievements.done_count() == 0, "a new player has none of the %d locked items" % seen.size())
	_expect(Achievements.locked("hat:crown") and not Achievements.locked("hat:top_hat") and not Achievements.locked("part:frog"),
		"the crown is locked; the top hat and the frog are free")
	_expect("0 / 500" in Achievements.requirement("hat:crown") and "Warlord" in Achievements.requirement("hat:crown"),
		"a locked item says what it needs (%s)" % Achievements.requirement("hat:crown"))
	_expect(Achievements.item_name("hat:crown") == "Crown" and Achievements.item_name("part:ninja") == "Ninja" and Achievements.item_name("paint:gold") == "Gold paint",
		"items go by their creator names")

	print("  kills")
	Net.start_offline("Host", "needle", "pistol")
	var bot := Net.add_bot(1)
	Match.kill_scored.emit(_kill(bot, 1, KillScore.T_HEADSHOT))
	_expect(Achievements.stat("kills") == 0, "a bot's kill is not yours")
	Match.kill_scored.emit(_kill(1, bot, KillScore.T_HEADSHOT | KillScore.T_MID_AIR | KillScore.T_ROPE))
	_expect(Achievements.stat("kills") == 1 and Achievements.stat("headshots") == 1 and Achievements.stat("air_kills") == 1
		and Achievements.stat("rope_kills") == 1 and Achievements.stat("long_shots") == 0, "your kill counts, with what was special about it")
	_expect(_announced == ["first_blood"] and Achievements.done("first_blood") and not Achievements.locked("hat:party"),
		"the first kill completes First Blood and unlocks the party hat")
	Match.kill_scored.emit(_kill(1, bot, KillScore.T_LONG | KillScore.T_AIR_SHOT, 1))
	Match.kill_scored.emit(_kill(1, bot, KillScore.T_FLYING_KICK, 2))
	_expect(Achievements.stat("doubles") == 1 and Achievements.stat("triples") == 1 and Achievements.stat("trickshots") == 1,
		"a second kill in a run is a double, a third a triple; a long shot on a target in the air is a trickshot (%d)" % Achievements.stat("trickshots"))
	_expect(Achievements.stat("kicks") == 1 and Achievements.stat("flying_kicks") == 1, "a flying kick is a kick too")
	Match.player_died.emit(1, bot)
	Match.player_died.emit(bot, 1)
	_expect(Achievements.stat("deaths") == 1, "your deaths count, not the bot's")
	_announced.clear()
	Achievements.add("headshots", 8)
	_expect(_announced.is_empty() and Achievements.locked("face:monocle"), "9 headshots: Sharp Eye is not done yet")
	Achievements.add("headshots")
	Achievements.add("headshots")
	_expect(_announced == ["headshots_10"] and not Achievements.locked("face:monocle"), "the 10th completes it, once")

	print("  matches")
	Match.match_over.emit([{"id": 1, "kills": 3, "deaths": 1}])
	_expect(Achievements.stat("matches") == 0, "a match alone is no match")
	Match.match_over.emit([{"id": 1, "kills": 3, "deaths": 1}, {"id": bot, "kills": 1, "deaths": 3}])
	_expect(Achievements.stat("matches") == 1 and Achievements.stat("wins") == 1, "top of the table: a match and a win")
	Match.match_over.emit([{"id": bot, "kills": 3, "deaths": 1}, {"id": 1, "kills": 1, "deaths": 3}])
	_expect(Achievements.stat("matches") == 2 and Achievements.stat("wins") == 1, "second place: a match, no win")
	Match.match_over.emit([{"id": bot, "kills": 9, "deaths": 1, "team": 0, "team_won": true}, {"id": 1, "kills": 0, "deaths": 3, "team": 0, "team_won": true}])
	_expect(Achievements.stat("wins") == 2, "on the winning team: a win, wherever you are in the table")

	print("  races")
	Net.match_settings["map"] = "rooftop_run"
	Race.progress = {1: {"cp": 3, "finish": 41.5, "resets": 0, "time": 41.5}, bot: {"cp": 2, "finish": -1.0, "resets": 1, "time": 0.0}}
	Race.gate_passed.emit(1, 2, 20.0, false)
	_expect(Achievements.stat("races") == 0, "a gate is not the finish")
	Race.gate_passed.emit(bot, 3, 30.0, true)
	_expect(Achievements.stat("races") == 0, "a bot's finish is not yours")
	Race.gate_passed.emit(1, 3, 41.5, true)
	_expect(Achievements.stat("races") == 1 and Achievements.stat("clean_races") == 1 and Achievements.stat("race_wins") == 1 and Achievements.stat("courses") == 1,
		"first over the line with no resets: a race, a clean run, a win and a course")
	Race.progress[1]["resets"] = 2
	Race.progress[bot]["finish"] = 30.0
	Race.gate_passed.emit(1, 3, 41.5, true)
	_expect(Achievements.stat("races") == 2 and Achievements.stat("clean_races") == 1 and Achievements.stat("race_wins") == 1 and Achievements.stat("courses") == 1,
		"second, after resets, on the same course: only the race counts")
	Race.progress = {}

	print("  the Character Creator")
	var creator: Node = load("res://game/ui/character_creator.gd").new("")
	add_child(creator)
	creator.set_part("whole", "ninja")
	creator.set_part("hat", "top_hat")
	_expect(not creator.can_save() and "Ninja" in creator.locked_note() and "Wall Crawler" in creator.status.text,
		"a locked body can be tried on, and the creator says what it needs (%s)" % creator.status.text)
	_expect(creator.save() == "" and Settings.custom_characters.is_empty(), "but it can't be saved")
	creator.open_list("whole")
	var names := []
	for i in creator._list.item_count:
		names.append(creator._list.get_item_text(i))
	creator._list.hide()
	_expect("Ninja  (locked)" in names and "Frog" in names, "the list marks the locked ones")
	creator.open_palette("p")
	_expect((creator._palette_grid.find_child("pick_gold", false, false) as Button).disabled
		and not (creator._palette_grid.find_child("pick_red", false, false) as Button).disabled, "a locked paint is greyed out in the palette")
	creator._palette.hide()
	Achievements.add("wall_kills", 10)
	creator.set_part("hat", "cap")
	_expect(creator.can_save() and creator.locked_note() == "", "10 wall-run kills later the ninja can be saved")
	var clean := true
	for i in 40:
		creator.randomize_parts()
		clean = clean and creator.can_save()
	_expect(clean, "Randomize only uses what you have")
	creator.queue_free()

	print("  yours to keep")
	Settings.custom_characters = ["custom:n=King|l=needle|t=needle|h=needle|hat=crown|back=cape.gold"]
	_expect(Achievements.locked("hat:crown") and Achievements.locked("paint:gold"), "before: the crown and gold paint are locked")
	Achievements.keep_saved()
	_expect(not Achievements.locked("hat:crown") and not Achievements.locked("paint:gold") and Achievements.locked("hat:halo"),
		"what a saved character wears is unlocked, and nothing else")
	Achievements.unlock_all = true
	_expect(not Achievements.locked("hat:halo") and Achievements.locked_in(CustomCharacter.parse("custom:n=x|l=zombie|t=imp|h=yeti|hat=halo")).is_empty(),
		"--unlock-all: nothing is locked")
	Achievements.unlock_all = false

	print("  the file")
	var kills := Achievements.stat("kills")
	Achievements._file = TEST_FILE
	Achievements.save()
	Settings.custom_characters = []
	Achievements._load()
	_expect(Achievements.stat("kills") == kills and Achievements.stat("wall_kills") == 10 and not Achievements.locked("hat:crown")
		and not Achievements.locked("part:ninja") and Achievements._courses.has("rooftop_run"), "counts, kept items and courses come back from the file")
	_announced.clear()
	Achievements.add("deaths")
	_expect(_announced.is_empty(), "and nothing already done is announced again")
	# Another copy of the game on this PC counted 5 kills and saved while this one was open.
	var other := ConfigFile.new()
	other.load(TEST_FILE)
	other.set_value("stats", "kills", kills + 5)
	other.save(TEST_FILE)
	Achievements.add("kills", 2)
	Achievements.save()
	other.load(TEST_FILE)
	_expect(Achievements.stat("kills") == kills + 7 and int(other.get_value("stats", "kills", 0)) == kills + 7,
		"two copies of the game add to the same file instead of writing over each other (%d)" % Achievements.stat("kills"))
	Achievements.save()
	_expect(Achievements.stat("kills") == kills + 7, "and saving twice counts nothing twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))

	Achievements.reset_for_test()
	Settings.custom_characters.assign(saved_characters)
	Settings.character = saved_pick
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _kill(killer: int, victim: int, tags: int, streak: int = 0) -> Dictionary:
	return {"seq": 1, "score": 100, "tags": tags, "streak": streak, "distance": 10.0, "weapon": "pistol",
		"speed": 5.0, "target_speed": 5.0, "flick": 0.0, "killer": killer, "victim": victim}


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
