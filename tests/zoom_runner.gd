extends Node
## The checks for tests/zoom_test.gd.

var _fails: Array = []


func run() -> void:
	await get_tree().process_frame
	var saved_fov := Settings.field_of_view
	var saved_toggle := Settings.zoom_toggle
	_expect(Settings.default_bindings("zoom") == ["mouse:%d" % MOUSE_BUTTON_MIDDLE], "zoom is on middle mouse by default")
	_expect(InputMap.has_action("zoom"), "and it is an input action (rebindable on the Controls page)")

	# The camera: from your field of view, down by the lobby's zoom (A: 30), eased.
	Settings.field_of_view = 95.0
	var body := CharacterBody3D.new()
	add_child(body)
	var rig := CameraRig.new()
	body.add_child(rig)
	rig.setup(body)
	rig._process(0.016)
	_expect(is_equal_approx(rig.camera.fov, 95.0), "not zoomed: your field of view (%.1f)" % rig.camera.fov)
	rig.zoom = true
	rig._process(CameraRig.ZOOM_TIME * 0.5)
	var halfway := rig.camera.fov
	_expect(halfway < 95.0 and halfway > 95.0 - 30.0, "it eases in (%.1f halfway)" % halfway)
	rig._process(CameraRig.ZOOM_TIME)
	_expect(is_equal_approx(rig.camera.fov, 95.0 - 30.0), "zoomed (A, the default): 30 degrees less (%.1f)" % rig.camera.fov)
	var scale := rig.aim_scale()
	var want := tan(deg_to_rad(95.0 - 30.0) * 0.5) / tan(deg_to_rad(95.0) * 0.5)
	_expect(is_equal_approx(scale, want) and scale < 1.0, "the mouse turns slower by as much as the view narrows (%.2f)" % scale)
	Settings.field_of_view = 110.0
	Settings.changed.emit()
	_expect(is_equal_approx(rig.camera.fov, 110.0 - 30.0), "from whatever field of view you play at (%.1f)" % rig.camera.fov)
	# The lobby's Zoom B: further, for everyone.
	var saved_settings := Net.match_settings.duplicate()
	Net.match_settings["zoom"] = "b"
	Settings.changed.emit()
	_expect(is_equal_approx(rig.camera.fov, 110.0 - 45.0) and LobbySettings.zoom_degrees() == 45.0, "Zoom B: 45 degrees less (%.1f)" % rig.camera.fov)
	Settings.field_of_view = 70.0   # (the lowest the settings go)
	_expect(is_equal_approx(CameraRig.zoom_fov(), 70.0 - 45.0), "the lowest field of view zooms just as far (%.1f)" % CameraRig.zoom_fov())
	Net.match_settings["zoom"] = "nonsense"
	_expect(LobbySettings.zoom() == "a" and LobbySettings.clean({"zoom": "x"}).zoom == "a", "anything else is A")
	Net.match_settings = saved_settings
	Settings.field_of_view = 95.0
	rig.zoom = false
	rig._process(CameraRig.ZOOM_TIME * 2.0)
	_expect(is_equal_approx(rig.camera.fov, 95.0) and is_equal_approx(rig.aim_scale(), 1.0), "zoomed out: back to normal")

	# The button: toggle or hold; it drops when you die.
	var p := Player.new()
	p.alive = true
	Settings.zoom_toggle = true
	p.zoom_input(true)
	p.zoom_input(false)
	_expect(p.zoomed, "toggle: a press zooms in, and letting go keeps it")
	p.zoom_input(true)
	p.zoom_input(false)
	_expect(not p.zoomed, "toggle: the next press zooms out")
	Settings.zoom_toggle = false
	p.zoom_input(true)
	_expect(p.zoomed, "hold: zoomed while held")
	p.zoom_input(false)
	_expect(not p.zoomed, "hold: letting go zooms out")
	Settings.zoom_toggle = true
	p.zoom_input(true)
	p.alive = false
	p.update_zoom()
	_expect(not p.zoomed, "dying drops the zoom")
	p.zoom_input(true)
	_expect(not p.zoomed, "and it can't come back on while you are down")
	p.free()

	# The setting is saved.
	Settings.zoom_toggle = false
	Settings.field_of_view = saved_fov
	Settings.save_settings()
	var cfg := ConfigFile.new()
	cfg.load(Settings.SAVE_PATH)
	_expect(cfg.get_value("controls", "zoom_toggle", true) == false, "hold or toggle is saved")
	Settings.zoom_toggle = saved_toggle
	Settings.save_settings()

	body.queue_free()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
