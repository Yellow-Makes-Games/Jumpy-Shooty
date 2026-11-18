extends Node
## The body of tests/movement_variant_test.gd (a separate file: it uses the game's autoloads).

var _ok := true


func run() -> void:
	await get_tree().process_frame
	print("Movement variant checks")
	_ids()
	_tuning()
	_lobby_setting()
	await _practice()
	await _bots("b")
	await _bots("classic")
	Net.leave()
	print("PASS" if _ok else "FAIL")
	get_tree().quit(0 if _ok else 1)


func _ids() -> void:
	_check(MovementTuning.valid_variant("b") == "b", "\"b\" is a variant")
	_check(MovementTuning.valid_variant("nope") == "classic", "an unknown variant is classic")
	_check(MovementTuning.valid_variant(null) == "classic", "no variant is classic")
	_check(MovementTuning.variant_name("b") == "Variant B" and MovementTuning.variant_name("x") == "Classic", "variant names")


func _tuning() -> void:
	var plain := MovementTuning.new()
	var classic := MovementTuning.for_variant("classic")
	var same := true
	for prop in plain.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and plain.get(prop.name) != classic.get(prop.name):
			print("    differs: %s" % prop.name)
			same = false
	_check(same, "classic is the plain MovementTuning numbers")
	_check(classic.variant == "classic", "classic tuning says it is classic")
	_check(MovementTuning.for_variant("b").variant == "b", "Variant B tuning says it is B")
	var a := MovementTuning.for_variant("b")
	var b := MovementTuning.for_variant("b")
	a.run_speed *= 1.5   # (what a weapon's speed bonus does to a player's own copy)
	_check(a != b and b.run_speed == MovementTuning.for_variant("b").run_speed, "each player gets their own copy")


func _lobby_setting() -> void:
	_check(LobbySettings.clean({}).movement == "classic", "a lobby starts with classic movement")
	_check(LobbySettings.clean({"movement": "b"}).movement == "b", "the lobby keeps Variant B")
	_check(LobbySettings.clean({"movement": "zzz"}).movement == "classic", "the lobby turns an unknown variant into classic")
	_check(LobbySettings.clean({"movement": 7}).movement == "classic", "...and one that is not text")


func _practice() -> void:
	Game.last_movement = "b"
	Game.start_practice("testing_grounds")
	await _frames(30)
	var me: Player = Net.arena.local_player if Net.arena else null
	_check(me != null and me.motor != null, "practice starts")
	if me == null:
		return
	_check(LobbySettings.movement() == "b", "practice is set up with Variant B")
	_check(me.motor.tuning.variant == "b", "you move with Variant B")
	var tag := _hud_text("Movement: Variant B")
	_check(tag, "the HUD says Variant B is on")
	Net.leave()
	await _frames(5)


func _bots(variant: String) -> void:
	Game.last_movement = variant
	Game.start_bot(1, 10, "construction_site", 2)
	await _frames(30)
	_check(LobbySettings.movement() == variant, "Vs Bots is set up with %s" % variant)
	var players: Array = Net.arena.players_root.get_children().filter(func(n): return n is Player) if Net.arena else []
	var bots := players.filter(func(p): return p.brain != null)
	_check(players.size() == 3 and bots.size() == 2, "you and two bots (%d players, %d bots)" % [players.size(), bots.size()])
	var all := players.all(func(p): return p.motor != null and p.motor.tuning.variant == variant)
	_check(all, "you and every bot move with %s" % variant)
	if variant == "classic":
		_check(not _hud_text("Movement:"), "the HUD says nothing with classic movement")
	Net.leave()
	await _frames(5)


## Is a visible label with this text on screen (the HUD's variant tag)?
func _hud_text(start: String) -> bool:
	for n in get_tree().root.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.text.begins_with(start):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_ok = false
