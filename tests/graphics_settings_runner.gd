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
	_check_gtao()
	await _check_both()
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


## The GTAO pick (see Gtao): the map's SSAO and SSIL off, GTAO on the map's world with the
## map's own tuning, only where the map has AO; and back again.
func _check_gtao() -> void:
	print("  gtao")
	var picks := GraphicsQuality.preset("high")
	picks.ao = "gtao"
	_expect(GraphicsQuality.AO_NAMES.has("gtao"), "GTAO is an Ambient occlusion choice")
	_expect(GraphicsQuality.clean({"ao": "gtao"}).ao == "gtao", "a saved GTAO pick is kept")
	_expect(GraphicsQuality.matching(picks) == "custom", "no preset uses GTAO")
	var view := SubViewport.new()   # a world of its own, so the window's is left alone
	view.own_world_3d = true
	add_child(view)
	var w3d := view.find_world_3d()
	var world := _ao_map(1.6, 1.4)
	view.add_child(world)
	GraphicsQuality.apply_environments(world, picks)
	var env := world.environment
	_expect(not env.ssao_enabled and not env.ssil_enabled, "GTAO: the map's SSAO and SSIL are off")
	_expect(Gtao.is_on(world), "...and GTAO is on for the map")
	var effects := Gtao.effects_of(world)
	_expect(effects.size() == 2 and effects[0].effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_OPAQUE
		and effects[1].effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE,
		"one effect before the opaque pass, one after (it clears the stamp)")
	_expect(_effects(w3d) == Array(effects), "the pair is on the map's world")
	_expect(world.compositor == null, "...not on the WorldEnvironment's own compositor (Godot would put that over the world's)")
	_expect(not effects.is_empty() and is_equal_approx(effects[0].radius, 1.6 * Gtao.RADIUS_SCALE)
		and is_equal_approx(effects[0].power, Gtao.FINAL_VALUE_POWER * 1.4 / 2.0), "the map's SSAO radius and intensity carry over")
	GraphicsQuality.apply_environments(world, picks)
	_expect(Gtao.effects_of(world) == effects and _effects(w3d) == Array(effects), "picking it again adds nothing")
	GraphicsQuality.apply_environments(world, GraphicsQuality.preset("medium"))
	_expect(env.ssao_enabled and not Gtao.is_on(world) and WorldCompositor.compositor_of(w3d) == null and not w3d.has_meta(WorldCompositor.META),
		"back to On: SSAO again, GTAO gone, and the world's compositor with it")
	# It follows the WorldEnvironment in and out of the tree.
	GraphicsQuality.apply_environments(world, picks)
	view.remove_child(world)
	_expect(Gtao.is_on(world) and WorldCompositor.compositor_of(w3d) == null, "a map taken out of the tree takes its GTAO off the world")
	view.add_child(world)
	_expect(_effects(w3d) == _gtao(world), "...and back in, puts it back")
	# Two maps in one world (the next one in before the last has gone): one pair.
	var next := _ao_map(1.0, 2.0)
	view.add_child(next)
	GraphicsQuality.apply_environments(next, picks)
	_expect(_effects(w3d) == _gtao(next), "two maps in one world: the newer one's pair, and only that")
	view.remove_child(next)
	_expect(_effects(w3d) == _gtao(world), "...and the other's again once it goes")
	view.add_child(next)
	view.remove_child(world)
	_expect(_effects(w3d) == _gtao(next), "the older one going leaves the newer one's")
	next.free()
	_expect(WorldCompositor.compositor_of(w3d) == null, "and the last one going leaves none")
	view.add_child(world)
	GraphicsQuality.apply_environments(world, GraphicsQuality.preset("low"))
	# A map with no AO gets none.
	var plain := WorldEnvironment.new()
	plain.environment = Environment.new()
	view.add_child(plain)
	GraphicsQuality.apply_environments(plain, picks)
	_expect(not plain.environment.ssao_enabled and not Gtao.is_on(plain) and WorldCompositor.compositor_of(w3d) == null,
		"settings never add GTAO to a map that has no AO")
	view.queue_free()
	# A real map, through Settings.
	Settings.set_quality("high")
	Settings.ao = "gtao"
	var map := Maps.make("cirrus")
	add_child(map)
	map.build(false)
	var w := map.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
	_expect(Gtao.is_on(w) and not w.environment.ssao_enabled, "cirrus with GTAO: GTAO on, SSAO off")
	_expect(WorldCompositor.effects_of(get_viewport().find_world_3d(), Gtao.KEY) == Gtao.effects_of(w), "...on the game window's world")
	GraphicsQuality.apply_environments(map, GraphicsQuality.preset("medium"))   # leave the shared resource as the map has it
	_expect(not Gtao.is_on(w) and w.environment.ssao_enabled, "cirrus back to On")
	map.queue_free()
	Settings.set_quality("high")


## CMAA2 and GTAO picked together: both in the one compositor each world has
## (WorldCompositor), each coming and going without touching the other, through map
## changes, and the saved killcam video (no CMAA2) left as it should be.
func _check_both() -> void:
	print("  cmaa2 and gtao together")
	var keep := Settings.graphics()
	var picks := GraphicsQuality.preset("high")
	picks.screen_aa = "cmaa2"
	picks.ao = "gtao"
	Settings.set_graphics(picks)   # (what map.build() takes)
	var view := SubViewport.new()
	view.own_world_3d = true
	add_child(view)
	var w3d := view.find_world_3d()
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	var map := Maps.make("castle")
	view.add_child(map)
	map.build(false)
	var we := _env_of(map)
	var cmaa2 := GraphicsQuality.cmaa2_of(view)
	_expect(Gtao.effects_of(we).size() == 2 and cmaa2 != null and _effects(w3d) == _gtao(we) + [cmaa2],
		"both picked: GTAO's pair and CMAA2 in the world's one compositor, GTAO first")
	_expect(we.compositor == null, "the map's WorldEnvironment has no compositor (it would take the world's slot)")

	# Either off leaves the other; on again, the same order whichever came first.
	picks.screen_aa = "smaa"
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	_expect(_effects(w3d) == _gtao(we), "CMAA2 off: GTAO stays")
	picks.screen_aa = "cmaa2"
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	cmaa2 = GraphicsQuality.cmaa2_of(view)
	_expect(_effects(w3d) == _gtao(we) + [cmaa2], "CMAA2 on again: after GTAO, as before")
	GraphicsQuality.apply_environments(map, GraphicsQuality.preset("medium"))
	_expect(_effects(w3d) == [cmaa2], "GTAO off: CMAA2 stays")
	GraphicsQuality.apply_environments(map, picks)
	_expect(_effects(w3d) == _gtao(we) + [cmaa2], "GTAO on again (after CMAA2): still GTAO first")

	# A map change: the old map freed, the next one built in the same world.
	view.remove_child(map)
	map.free()
	_expect(_effects(w3d) == [cmaa2], "the map gone: its GTAO goes with it, CMAA2 stays")
	var next := Maps.make("cirrus")
	view.add_child(next)
	next.build(false)
	_expect(_effects(w3d) == _gtao(_env_of(next)) + [cmaa2], "the next map: its own GTAO and the same CMAA2")
	# ...and with the old one still there for a frame (queue_free), still one pair.
	var third := Maps.make("castle")
	view.add_child(third)
	third.build(false)
	var third_we := _env_of(third)
	next.queue_free()
	_expect(_effects(w3d) == _gtao(third_we) + [cmaa2], "the next map in before the last has gone: one GTAO, the new map's")
	await get_tree().process_frame
	_expect(_effects(w3d) == _gtao(third_we) + [cmaa2], "...and the same once it has gone")

	# A portal-style camera's compositor: the world's less CMAA2, kept in step.
	var side := WorldCompositor.without(w3d, GraphicsQuality.CMAA2_KEY)
	_expect(Array(side.compositor_effects) == _gtao(third_we), "a camera's compositor without CMAA2: just GTAO")
	_expect(WorldCompositor.without(w3d, GraphicsQuality.CMAA2_KEY) == side, "...the same one for every camera that asks")
	GraphicsQuality.apply_environments(third, GraphicsQuality.preset("medium"))
	_expect(side.compositor_effects.is_empty(), "...empty when GTAO goes (still there, so the world's CMAA2 stays off that camera)")
	GraphicsQuality.apply_environments(third, picks)
	_expect(Array(side.compositor_effects) == _gtao(third_we), "...and GTAO again when it comes back")

	# Both off: nothing on the world.
	picks.screen_aa = "smaa"
	GraphicsQuality.apply_viewport(view, picks, -1.0)
	GraphicsQuality.apply_environments(third, GraphicsQuality.preset("medium"))
	_expect(WorldCompositor.compositor_of(w3d) == null, "both off: the world's compositor slot is cleared")
	side = null

	# A WorldEnvironment with a compositor of its own takes the slot (Godot): it is taken back.
	var stray := WorldEnvironment.new()
	stray.compositor = Compositor.new()
	view.add_child(stray)
	_expect(WorldCompositor._reclaim_queued, "a WorldEnvironment with a compositor coming in: the shared one goes back at the end of the frame")
	await get_tree().process_frame
	_expect(not WorldCompositor._reclaim_queued, "...and has")
	stray.free()
	await get_tree().process_frame
	view.queue_free()

	# The saved killcam video: its own world, never given the viewport picks.
	picks.screen_aa = "cmaa2"
	Settings.set_graphics(picks)
	Settings._apply_graphics()
	_expect(GraphicsQuality.cmaa2_of(get_tree().root) != null, "(the game window has CMAA2)")
	var export := KillcamExport.new()
	export.into = OS.get_user_data_dir().path_join("killcam_test_videos")
	add_child(export)
	export.start(_clip("castle"))
	var ew := export._view.find_world_3d()
	var ewe := _env_of(export._view.get_node("Level"))
	_expect(GraphicsQuality.cmaa2_of(export._view) == null, "the saved killcam video has no CMAA2")
	_expect(ewe.compositor == null and _effects(ew) == _gtao(ewe), "...and its world's compositor is its map's GTAO pair and nothing else")
	export.free()   # (before it starts recording)
	Settings.set_graphics(keep)
	Settings._apply_graphics()


## A map's WorldEnvironment with SSAO tuned so.
func _ao_map(radius: float, intensity: float) -> WorldEnvironment:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ssao_enabled = true
	world.environment.ssao_radius = radius
	world.environment.ssao_intensity = intensity
	return world


func _env_of(map: Node) -> WorldEnvironment:
	return map.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment


## A map's GTAO pair, as a plain Array (to compare with _effects()).
func _gtao(world: WorldEnvironment) -> Array:
	return Array(Gtao.effects_of(world))


## What the world's compositor runs, in order (empty when it has none).
func _effects(world: World3D) -> Array:
	var c := WorldCompositor.compositor_of(world)
	return Array(c.compositor_effects) if c else []


## A short killcam clip on `map` (two players standing).
func _clip(map: String) -> KillClip:
	var clip := KillClip.new()
	clip.map = map
	clip.killer = 1
	clip.victim = 2
	clip.kill_time = 0.5
	clip.end = 1.0
	clip.info = {"seq": 1, "score": 100, "tags": 0, "streak": 0, "distance": 10.0, "weapon": "pistol", "killer": 1, "victim": 2}
	var tracks := {}
	for id in [1, 2]:
		var t := KillClip.Track.new()
		t.name = "P%d" % id
		for i in 31:
			t.push(i / 30.0, [Vector3(0, 0, -10 * (id - 1)), Vector3.ZERO, 0.0, 0.0, 0, 0, false, Vector3.ZERO, true, true, 1.6, "pistol"])
		tracks[id] = t
	clip.tracks = tracks
	return clip


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
