extends Node
## The checks for tests/death_buttons_test.gd.

var _fails: Array = []


func run() -> void:
	var killcam := Settings.killcam
	Settings.killcam = false   # (straight to the death screen)
	DevArgs.manual_respawn = true   # (a headless run would otherwise come back by itself)
	Game.start_bot(1, 10, "testing_grounds", 1)
	await _frames(40)
	var arena = Net.arena
	_expect(arena != null and arena.local_player != null, "a Vs Bots match starts")
	if arena == null:
		_finish(killcam)
		return
	var hud = arena.hud
	var buttons: HBoxContainer = hud.get("_death_buttons")
	var respawn := buttons.get_node("Respawn") as Button
	var loadout := buttons.get_node("Loadout") as Button
	_expect(not buttons.visible, "no buttons while you are alive")
	var bot: int = Net.bot_ids()[0]
	Match._host_kill(Net.my_id(), bot)   # (the host's own kill: the death goes out as in a match)
	await _frames(3)
	_expect(buttons.visible and respawn.visible and loadout.visible, "dead: Respawn and Loadout show")
	_expect(respawn.disabled and respawn.text.begins_with("Respawn  "), "Respawn counts down while you must wait (%s)" % respawn.text)
	# Loadout: the pause menu, on its loadout page; the buttons step aside meanwhile.
	loadout.pressed.emit()
	await _frames(2)
	var pause: PauseMenu = arena.pause_menu
	_expect(pause.visible and _has_text(pause, "Changes apply when you respawn"), "Loadout opens the loadout page")
	_expect(not buttons.visible, "the buttons step aside while it is open")
	pause.visible = false
	await _frames(2)
	_expect(buttons.visible, "and come back when it closes")
	# The wait, then Respawn.
	var waited := 0
	while respawn.disabled and waited < 600:
		await _frames(1)
		waited += 1
	_expect(not respawn.disabled and respawn.text == "Respawn", "once you may, Respawn can be pressed")
	respawn.pressed.emit()
	for i in 60:
		await _frames(1)
		if Match.is_alive(Net.my_id()):
			break
	_expect(Match.is_alive(Net.my_id()), "pressing it brings you back")
	await _frames(2)
	_expect(not buttons.visible, "and the buttons go")

	# Practice: you come back on your own, so only Loadout.
	Game.start_practice("testing_grounds")
	await _frames(40)
	arena = Net.arena
	hud = arena.hud
	buttons = hud.get("_death_buttons")
	Match._host_kill(Net.my_id(), Net.my_id(), "fell")
	await _frames(3)
	_expect(buttons.visible and not (buttons.get_node("Respawn") as Button).visible and (buttons.get_node("Loadout") as Button).visible,
		"Practice: only Loadout (you come back on your own)")
	_finish(killcam)


func _finish(killcam: bool) -> void:
	Settings.killcam = killcam
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _has_text(n: Node, text: String) -> bool:
	if (n is Label and text in (n as Label).text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
