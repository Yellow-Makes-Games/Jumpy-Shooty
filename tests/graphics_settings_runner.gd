extends Node
## Graphics quality checks (started by tests/graphics_settings_test.gd). Nothing here
## writes settings.cfg.

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Graphics settings checks")
	var keep := Settings.graphics()
	var keep_quality := Settings.quality

	_check_presets()
	_check_clean()
	_check_viewport()
	_check_cmaa2()
	_check_environment()
	_check_map()
	await _check_settings_tab()

	Settings.set_graphics(keep)
	Settings.quality = keep_quality
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _check_presets() -> void:
	print("  presets")
	for id in GraphicsQuality.PRESETS:
		_expect(GraphicsQuality.matching(GraphicsQuality.preset(id)) == id, "%s matches itself" % id)
		Settings.set_quality(id)
		_expect(Settings.quality == id and Settings.graphics() == GraphicsQuality.preset(id), "Settings takes the %s preset" % id)
	var high := GraphicsQuality.preset("high")
	_expect(high.msaa == 4 and high.screen_aa == "smaa" and high.ao == "high", "High is 4x MSAA, SMAA and AO with bounce")
	_expect(GraphicsQuality.preset("medium").msaa == 2 and GraphicsQuality.preset("low").screen_aa == "fxaa", "Medium is 2x MSAA, Low is FXAA")
	high.msaa = 8
	_expect(GraphicsQuality.matching(high) == "custom", "changing one setting makes it Custom")
	Settings.set_quality("high")
	Settings.shadows = "ultra"
	Settings.set_quality("custom")
	_expect(Settings.quality == "custom" and Settings.shadows == "ultra", "picking Custom keeps the advanced settings")
	_expect(GraphicsQuality.first_launch() == "high", "a computer with no graphics card to ask about starts on High")


func _check_clean() -> void:
	print("  bad saved values")
	var c := GraphicsQuality.clean({"msaa": 3, "screen_aa": "taa", "render_scale": 0.1, "fsr_sharpness": 9.0,
		"shadows": "huge", "ao": 7, "glow": false})
	_expect(c.msaa == 4 and c.screen_aa == "smaa" and c.shadows == "high" and c.ao == "high", "unknown choices fall back to High's")
	_expect(is_equal_approx(c.render_scale, 0.5) and is_equal_approx(c.fsr_sharpness, 2.0), "numbers are kept in range")
	_expect(c.glow == false, "a good value is kept")
	_expect(GraphicsQuality.clean({}) == GraphicsQuality.preset("high"), "nothing saved is High")


func _check_viewport() -> void:
	print("  viewport")
	var view := SubViewport.new()
	add_child(view)
	GraphicsQuality.apply_viewport(view, GraphicsQuality.preset("low"), -1.0)
	_expect(view.msaa_3d == Viewport.MSAA_DISABLED and view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Low: no MSAA, FXAA")
	_expect(view.use_debanding, "debanding is always on")
	_expect(is_equal_approx(view.scaling_3d_scale, 1.0) and view.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "a negative scale leaves scaling alone (the killcam)")
	var picks := GraphicsQuality.preset("high")
	picks.render_scale = 0.75
	GraphicsQuality.apply_viewport(view, picks, 0.8)
	_expect(view.msaa_3d == Viewport.MSAA_4X and view.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA, "High: 4x MSAA and SMAA")
	_expect(is_equal_approx(view.scaling_3d_scale, 0.6) and view.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "render scale and the fullscreen resolution multiply, and FSR 1 stretches")
	picks.render_scale = 1.0
	GraphicsQuality.apply_viewport(view, picks, 1.0)
	_expect(view.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "full size: nothing to stretch")
	_expect(view.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2, "never FSR 2 (it trails)")
	view.queue_free()


## CMAA2 (Cmaa2Effect): a Screen-space AA choice of its own, run as a compositor effect
## on the viewport's world. (Headless, the effect is never drawn: this is the plumbing.)
func _check_cmaa2() -> void:
	print("  cmaa2")
	_expect(GraphicsQuality.SCREEN_AA_NAMES.has("cmaa2"), "CMAA2 is in the Screen-space AA drop-down")
	_expect(GraphicsQuality.clean({"screen_aa": "cmaa2"}).screen_aa == "cmaa2", "a saved CMAA2 is kept")
	for id in GraphicsQuality.PRESETS:
		_expect(GraphicsQuality.preset(id).screen_aa != "cmaa2", "%s does not use CMAA2" % id)
	var picks := GraphicsQuality.preset("high")
	picks.screen_aa = "cmaa2"
	_expect(GraphicsQuality.matching(picks) == "custom", "picking CMAA2 makes it Custom")

	var view := SubViewport.new()
	view.own_world_3d = true
	add_child(view)
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	var fx := GraphicsQuality.cmaa2_of(view)
	_expect(view.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "CMAA2: Godot's own screen-space AA is off")
	_expect(view.msaa_3d == Viewport.MSAA_4X, "and MSAA is left as picked")
	_expect(fx != null and fx.enabled, "and the viewport's world has the CMAA2 effect")
	_expect(fx != null and fx.effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and fx.access_resolved_color,
		"after transparent things, before tonemapping, on the resolved colour (MSAA)")
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	_expect(GraphicsQuality.cmaa2_of(view) == fx, "applying again keeps the same effect (no second one)")

	var other := SubViewport.new()
	other.own_world_3d = true
	add_child(other)
	GraphicsQuality.apply_viewport(other, picks, -1.0)
	_expect(GraphicsQuality.cmaa2_of(other) != null and GraphicsQuality.cmaa2_of(other) != fx, "each world has its own (its buffers fit its size)")
	var plain := SubViewport.new()   # like the saved killcam video's: its own world, never given the picks
	plain.own_world_3d = true
	add_child(plain)
	_expect(GraphicsQuality.cmaa2_of(plain) == null, "a world nobody picked CMAA2 for has none")

	var gone: WeakRef = weakref(fx)
	fx = null
	picks.screen_aa = "smaa"
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	_expect(view.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA and GraphicsQuality.cmaa2_of(view) == null, "back to SMAA: the effect is off")
	_expect(gone.get_ref() == null, "and freed (with its GPU buffers)")
	_expect(GraphicsQuality.cmaa2_of(other) != null, "other worlds keep theirs")
	picks.screen_aa = "cmaa2"
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	_expect(GraphicsQuality.cmaa2_of(view) != null, "and on again")

	# The game window, through Settings (as Apply does).
	var keep: String = Settings.screen_aa
	Settings.screen_aa = "cmaa2"
	Settings._apply_graphics()
	_expect(get_tree().root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED and GraphicsQuality.cmaa2_of(get_tree().root) != null,
		"the game window takes CMAA2 from Settings")
	Settings.screen_aa = keep
	Settings._apply_graphics()
	_expect((GraphicsQuality.cmaa2_of(get_tree().root) == null) == (keep != "cmaa2"), "and lets it go")
	for v in [view, other, plain]:
		v.queue_free()


func _check_environment() -> void:
	print("  environment")
	var env := Environment.new()
	env.ssao_enabled = true
	env.glow_enabled = true
	GraphicsQuality.apply_environment(env, GraphicsQuality.preset("low"))
	_expect(not env.ssao_enabled and not env.ssil_enabled and env.glow_enabled, "Low: no AO, glow stays")
	GraphicsQuality.apply_environment(env, GraphicsQuality.preset("medium"))
	_expect(env.ssao_enabled and not env.ssil_enabled, "Medium: AO, no bounce")
	var picks := GraphicsQuality.preset("high")
	picks.glow = false
	GraphicsQuality.apply_environment(env, picks)
	_expect(env.ssao_enabled and env.ssil_enabled and not env.glow_enabled, "High: AO and bounce; glow off when picked off")
	var copy := env.duplicate() as Environment   # what a map event does
	GraphicsQuality.apply_environment(copy, GraphicsQuality.preset("high"))
	_expect(copy.glow_enabled, "a copy still knows the map had glow")
	var plain := Environment.new()
	GraphicsQuality.apply_environment(plain, GraphicsQuality.preset("high"))
	_expect(not plain.ssao_enabled and not plain.ssil_enabled and not plain.glow_enabled, "settings never add to a map that has none")


func _check_map() -> void:
	print("  maps")
	for id in ["cirrus", "empyrean"]:
		Settings.set_quality("low")
		var map := Maps.make(id)
		add_child(map)
		map.build(false)
		var env: Environment = (map.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
		_expect(not env.ssao_enabled, "%s on Low: no AO" % id)
		GraphicsQuality.apply_environments(map, GraphicsQuality.preset("high"))
		_expect(env.ssao_enabled and env.ssil_enabled, "%s has AO tuned for it on High" % id)
		GraphicsQuality.apply_environment(env, GraphicsQuality.preset("medium"))   # leave the shared resource as the map has it
		env.ssao_enabled = true
		env.ssil_enabled = false
		map.queue_free()
	Settings.set_quality("high")


func _check_settings_tab() -> void:
	print("  settings tab")
	SettingsPanel.open_on_tab(4)
	var panel := SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	_expect(is_instance_valid(panel._quality_btn), "the Graphics tab has a Quality drop-down")
	_expect(is_instance_valid(panel._advanced) and panel._advanced.get_child_count() > 0, "and Advanced settings under it")
	panel._pick_quality("low")
	_expect(panel._pending.msaa == 0 and panel._pending.quality == "low", "picking Low sets the advanced settings to Low's")
	_expect(Settings.quality == "high", "nothing changes before Apply")
	panel._pick_advanced("msaa", 8)
	_expect(panel._pending.quality == "custom", "changing an advanced setting makes it Custom")
	_expect(GraphicsQuality.QUALITY_NAMES.keys()[panel._quality_btn.selected] == "custom", "and the drop-down shows Custom")
	_expect(not panel._apply_btn.disabled, "Apply is ready")
	panel._pick_quality("high")
	_expect(panel._apply_btn.disabled, "back to what is in use: nothing to apply")
	panel.queue_free()
	SettingsPanel.open_on_tab(0)
