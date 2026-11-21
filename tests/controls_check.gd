extends SceneTree
## Quick check of control rebinding: defaults, conflicts, save/load, reset, and the
## Controls tab capturing a key. godot --headless --path . -s tests/controls_check.gd

func _ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1

var _fails := 0

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e

func _initialize() -> void:
	await process_frame
	var S = root.get_node("/root/Settings")
	S.reset_bindings()
	_ok(InputMap.action_has_event("kick", _key(KEY_F)), "F kicks by default")
	_ok(S.action_text("dive") == "Q", "dive shows Q: " + S.action_text("dive"))
	_ok(S.bindings.glide == ["key:%d" % KEY_ALT] and InputMap.action_has_event("glide", _key(KEY_ALT)), "Alt glides")
	_ok(InputMap.action_has_event("boost", _key(KEY_SHIFT)) and S.bindings.sprint.is_empty() and S.always_sprint, "Shift is rocket boots; sprint is always on, with no key")
	var on_alt := []
	for a in S.ACTIONS:
		if a[0] != "glide" and (a[2] as Array).has("key:%d" % KEY_ALT):
			on_alt.append(a[1])
	_ok(on_alt.is_empty(), "nothing else is on Alt by default %s" % [on_alt])
	# Bindings saved before the glide moved to Alt: brought up to date as they load.
	var old := ConfigFile.new()
	old.set_value("bindings", "glide", ["key:%d" % KEY_SHIFT])
	old.set_value("bindings", "dive", ["key:%d" % KEY_Q, "key:%d" % KEY_ALT])
	old.set_value("bindings", "interact", ["key:%d" % KEY_ALT, "key:%d" % KEY_G])
	S._load_bindings(old)
	_ok(S.bindings.glide == ["key:%d" % KEY_ALT], "an old saved glide key goes back to Alt: %s" % [S.bindings.glide])
	_ok(S.bindings.dive == ["key:%d" % KEY_Q] and S.bindings.interact == ["key:%d" % KEY_G], "...and Alt comes off whatever else had it saved")
	# Bindings saved before Rocket boots took Shift and Interact took E: those come off the rest.
	var v2 := ConfigFile.new()
	S.reset_bindings()
	v2.set_value("bindings", "version", 2)
	v2.set_value("bindings", "kick", ["key:%d" % KEY_E])
	v2.set_value("bindings", "dive", ["key:%d" % KEY_Q, "key:%d" % KEY_SHIFT])
	S._load_bindings(v2)
	_ok(S.bindings.kick.is_empty() and S.bindings.dive == ["key:%d" % KEY_Q] and S.bindings.boost == ["key:%d" % KEY_SHIFT]
		and S.bindings.interact == ["key:%d" % KEY_E], "...and Shift and E come off what had them saved before 3")
	S.reset_bindings()
	var newer := ConfigFile.new()
	S._save_bindings(newer)
	newer.set_value("bindings", "glide", ["mouse:%d" % MOUSE_BUTTON_XBUTTON2])
	S._load_bindings(newer)
	_ok(S.bindings.glide == ["mouse:%d" % MOUSE_BUTTON_XBUTTON2], "a glide key saved since then is kept")
	S.reset_bindings()
	_ok(InputMap.action_has_event("interact", _key(KEY_E)), "E is interact by default (press it at a map terminal)")
	var shared := []
	for a in S.ACTIONS:
		if a[0] != "interact" and (a[2] as Array).has("key:%d" % KEY_E):
			shared.append(a[1])
	_ok(shared.is_empty(), "no other action uses E by default %s" % [shared])
	_ok(S.rebind("sprint", 0, "key:%d" % KEY_ALT).is_empty() and S.bindings.glide.size() == 1, "sprint may share Alt with glide (not a conflict)")
	var taken: Array = S.rebind("boost", 0, "key:%d" % KEY_F)
	_ok(taken == ["Kick"], "F taken from Kick")
	_ok(InputMap.action_has_event("boost", _key(KEY_F)) and not InputMap.action_has_event("kick", _key(KEY_F)), "F boosts, no longer kicks")
	_ok(S.bindings.kick.is_empty(), "Kick unbound")
	S.rebind("grapple", 1, "mouse:%d" % MOUSE_BUTTON_XBUTTON1)
	_ok(S.action_text("grapple") == "Right mouse / Mouse 4", "grapple has a second binding: " + S.action_text("grapple"))
	_ok(S.rebind("jump", 0, "key:%d" % KEY_ESCAPE).is_empty() and S.bindings.jump == ["key:%d" % KEY_SPACE], "Esc can't be taken")
	# Saved and loaded
	S.bindings = {}
	for a in S.ACTIONS:
		S.bindings[a[0]] = a[2].duplicate()
	S.load_settings()
	_ok(S.bindings.boost == ["key:%d" % KEY_F] and S.bindings.kick.is_empty(), "rebinds survive a reload")
	_ok(InputMap.action_has_event("grapple", InputEventMouseButton.new()) == false, "sanity")
	S.reset_bindings()
	S.load_settings()
	_ok(S.bindings.kick == ["key:%d" % KEY_F] and S.bindings.boost == ["key:%d" % KEY_SHIFT], "reset to defaults saved")
	# The Controls tab: click a binding, press a key
	var panel_script: GDScript = load("res://game/ui/settings_panel.gd")
	var panel: Node = panel_script.new()
	root.add_child(panel)
	await process_frame
	var box: VBoxContainer = panel._binds_box
	_ok(box.get_child_count() == S.ACTIONS.size(), "one row per action")
	var kick_i := -1
	for i in S.ACTIONS.size():
		if S.ACTIONS[i][0] == "kick":
			kick_i = i
	var kick_row: Node = box.get_child(kick_i)
	(kick_row.get_child(1) as Button).emit_signal("pressed")
	_ok(panel._listen == ["kick", 0], "listening for Kick")
	Input.parse_input_event(_key(KEY_G))
	await process_frame
	await process_frame
	_ok(S.bindings.kick == ["key:%d" % KEY_G], "Kick rebound to G in the menu")
	(box.get_child(kick_i).get_child(2) as Button).emit_signal("pressed")
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_MIDDLE
	m.pressed = true
	Input.parse_input_event(m)
	await process_frame
	await process_frame
	_ok(S.bindings.kick == ["key:%d" % KEY_G, "mouse:%d" % MOUSE_BUTTON_MIDDLE], "middle mouse added as Kick's second")
	(box.get_child(0).get_child(1) as Button).emit_signal("pressed")
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	await process_frame
	_ok(S.bindings.move_forward == ["key:%d" % KEY_W] and panel._listen.is_empty(), "Esc cancels")
	print(panel_script.cheat_sheet()[0], panel_script.cheat_sheet()[8])
	S.reset_bindings()
	print("FAILS %d" % _fails)
	quit(1 if _fails else 0)
