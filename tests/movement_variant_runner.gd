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
	await _bots("classic")   # (an old pick from before Classic was retired)
	await _movement_b()
	_menus()
	Net.leave()
	print("PASS" if _ok else "FAIL")
	get_tree().quit(0 if _ok else 1)


func _ids() -> void:
	_check(MovementTuning.valid_variant("b") == "b", "\"b\" is a variant")
	_check(MovementTuning.VARIANTS == ["b", "sprint"] and MovementTuning.DEFAULT_VARIANT == "b", "Movement A (\"b\") and B (\"sprint\"), A the default")
	_check(MovementTuning.valid_variant("classic") == "b", "an old Classic pick is Variant B")
	_check(MovementTuning.valid_variant("nope") == "b", "an unknown variant is Variant B")
	_check(MovementTuning.valid_variant(null) == "b", "no variant is Variant B")
	_check(MovementTuning.variant_name("b") == "A" and MovementTuning.variant_name("sprint") == "B", "variant names")


func _tuning() -> void:
	_check(MovementTuning.for_variant("classic").variant == "b" and MovementTuning.for_variant("classic").ctrl_moves,
		"asking for Classic gets Variant B")
	_check(MovementTuning.for_variant("b").variant == "b", "Variant B tuning says it is B")
	_check(MovementTuning.for_variant("b").glides_on, "Variant B glides (on Alt)")
	var a := MovementTuning.for_variant("b")
	var b := MovementTuning.for_variant("b")
	a.run_speed *= 1.5   # (what a weapon's speed bonus does to a player's own copy)
	_check(a != b and b.run_speed == MovementTuning.for_variant("b").run_speed, "each player gets their own copy")


func _lobby_setting() -> void:
	_check(LobbySettings.clean({}).movement == "b", "a lobby starts with Variant B")
	_check(LobbySettings.clean({"movement": "b"}).movement == "b", "the lobby keeps Variant B")
	_check(LobbySettings.clean({"movement": "classic"}).movement == "b", "an older host's Classic is Variant B")
	_check(LobbySettings.clean({"movement": "zzz"}).movement == "b", "the lobby turns an unknown variant into Variant B")
	_check(LobbySettings.clean({"movement": 7}).movement == "b", "...and one that is not text")


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
	_check(not _hud_text("Movement:"), "the HUD shows no movement tag (there is nothing else to be on)")
	Net.leave()
	await _frames(5)


func _bots(variant: String) -> void:
	Game.last_movement = variant
	Game.start_bot(1, 10, "construction_site", 2)
	await _frames(30)
	_check(LobbySettings.movement() == "b", "Vs Bots is set up with Variant B (picked: %s)" % variant)
	var players: Array = Net.arena.players_root.get_children().filter(func(n): return n is Player) if Net.arena else []
	var bots := players.filter(func(p): return p.brain != null)
	_check(players.size() == 3 and bots.size() == 2, "you and two bots (%d players, %d bots)" % [players.size(), bots.size()])
	var all := players.all(func(p): return p.motor != null and p.motor.tuning.variant == "b")
	_check(all, "you and every bot move with Variant B")
	Net.leave()
	await _frames(5)


## Movement B: always sprinting, rocket boots on Shift and Interact on E, and back after.
func _movement_b() -> void:
	var t := MovementTuning.for_variant("sprint")
	_check(t.variant == "sprint" and t.always_sprint and t.shift_boost and t.ctrl_moves, "Movement B is A plus always sprinting and the Shift boost")
	_check(not MovementTuning.for_variant("b").always_sprint, "Movement A does not always sprint")
	_check(LobbySettings.clean({"movement": "sprint"}).movement == "sprint", "the lobby keeps Movement B")
	Settings.reset_bindings()
	Game.last_movement = "sprint"
	Game.start_practice("testing_grounds")
	await _frames(30)
	var me: Player = Net.arena.local_player if Net.arena else null
	_check(me != null and me.motor.tuning.variant == "sprint", "practice on Movement B")
	_check(_hud_text("Movement: B"), "the HUD says Movement: B")
	_check(Settings.bindings.boost == ["key:%d" % KEY_SHIFT] and Settings.bindings.interact == ["key:%d" % KEY_E]
		and Settings.bindings.sprint.is_empty(), "Shift boosts, E interacts, no Sprint key (%s)" % [[Settings.bindings.boost, Settings.bindings.interact]])
	for v in ["sprint", "b"]:
		var hs := await _run_speed(v)
		var want := t.sprint_speed if v == "sprint" else t.run_speed
		_check(absf(hs - want) < 0.5, "running without Sprint held: %s reaches %.1f m/s (%.1f)" % [MovementTuning.variant_name(v), want, hs])
	var cfg := ConfigFile.new()
	Settings._save_bindings(cfg)
	_check(not cfg.has_section_key("bindings", "boost") and not cfg.has_section_key("bindings", "sprint"), "Movement B's keys are not saved as your own")
	Net.leave()
	Game.goto_main_menu()
	await _frames(5)
	_check(Settings.bindings.boost == ["key:%d" % KEY_E] and Settings.bindings.sprint == ["key:%d" % KEY_SHIFT]
		and Settings.bindings.interact == ["key:%d" % KEY_G], "back to the usual keys after")
	Game.last_movement = "b"


## How fast holding forward (no Sprint) gets you on flat ground in 2 s, with this variant.
func _run_speed(variant: String) -> float:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -2000.5, 0)
	add_child(floor_body)
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	body.position = Vector3(0, -2000, 0)
	add_child(body)
	var motor := MovementController.new(MovementTuning.for_variant(variant))
	var input := PlayerInput.new()
	for i in 150:
		input.move = Vector2(0, 1) if i > 20 else Vector2.ZERO
		await get_tree().physics_frame
		motor.step(body, input, 1.0 / Engine.physics_ticks_per_second)
	var hs := Vector2(body.velocity.x, body.velocity.z).length()
	body.queue_free()
	floor_body.queue_free()
	return hs


## The host's movement switch in the lobby.
func _menus() -> void:
	var lobby: String = (load("res://game/ui/lobby_menu.gd") as GDScript).source_code
	_check(lobby.contains("_movement_ab"), "the lobby has the Movement A / B switch")


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
