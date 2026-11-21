extends Node
## Sky engine checks (started by tests/sky_engine_test.gd). Nothing here writes settings.

const BASE_LOOKS := ["clear_day", "golden_hour", "hazy_overcast", "night_city", "deep_space",
	"planet_orbit", "psychedelic", "surreal_dream"]

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Sky engine checks")
	_check_presets()
	_check_shaders()
	_check_maps()
	await _check_rig()
	_check_setting()
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
	for id in BASE_LOOKS:
		_expect(load("res://game/maps/sky/presets/%s.tres" % id) is SkyPreset, "the %s look is there" % id)
	var names := SkyPreset.names()
	_expect(names.size() > 80 and not "light_sun" in names, "every sky setting is listed, the lighting is not")
	var uniforms := {}
	for u in (load("res://game/maps/sky/sky_dome.gdshader") as Shader).get_shader_uniform_list():
		uniforms[u.name] = true
	var missing := Array(names).filter(func(n): return not uniforms.has(n))
	_expect(missing.is_empty(), "every sky setting is a uniform of the shader %s" % [missing])
	var a := SkyPreset.new()
	var b := SkyPreset.new()
	a.sky_energy = 0.0
	b.sky_energy = 2.0
	a.floor_mode = 0
	b.floor_mode = 3
	var half := SkyPreset.mix_params(a.params(), b.params(), 0.5)
	_expect(is_equal_approx(half.sky_energy, 1.0) and half.floor_mode == 3, "blending: numbers half way, which layers are on switches half way")
	_expect(SkyPreset.mix_params(a.params(), b.params(), 0.0).floor_mode == 0, "and nothing changes at 0")


func _check_shaders() -> void:
	print("  shaders")
	var still := FileAccess.get_file_as_string("res://game/maps/sky/sky_engine.gdshader")
	var code: Array = Array(still.split("\n")).filter(func(l): return not str(l).strip_edges().begins_with("//"))
	var joined := "\n".join(PackedStringArray(code))
	_expect(not "TIME" in joined and not "POSITION" in joined, "the still sky uses neither TIME nor POSITION")


func _check_maps() -> void:
	print("  maps")
	for m in Maps.LIST:
		var map: MapRoot = (load(m.scene) as PackedScene).instantiate()
		_expect(map.sky != null, "%s has a sky preset" % m.id)
		var env: Environment = (map.get_node("Environment") as WorldEnvironment).environment
		_expect(env.sky == null, "%s keeps no sky of its own in the scene" % m.id)
		map.free()
	for id in ["cirrus", "halcyon"]:
		var map: MapRoot = (load("res://game/maps/%s.tscn" % id) as PackedScene).instantiate()
		var event := map.get_node_or_null("Layout") if id == "cirrus" else map.get_node_or_null("LowGravity")
		_expect(event != null and event.sky is SkyPreset, "%s's event has a second sky to blend to" % id)
		map.free()


func _check_rig() -> void:
	print("  rig")
	var map: MapRoot = (load("res://game/maps/construction_site.tscn") as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	var rig := map.sky_rig()
	_expect(rig != null, "a map with a sky gets a SkyRig")
	if rig == null:
		map.queue_free()
		return
	var env := rig.environment()
	_expect(env.sky != null and env.sky.sky_material is ShaderMaterial, "the Environment's sky is the still sky")
	_expect(env.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL, "captured a little at a time, not every frame")
	_expect(env.background_mode == Environment.BG_COLOR, "with the moving sky, the backdrop covers the background")
	_expect(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "reflections come from the still sky")
	var preset := map.sky
	if preset.light_ambient:
		_expect(env.ambient_light_color.is_equal_approx(preset.light_ambient_color), "the preset sets the ambient light")
	var sun := map.get_node("Sun") as DirectionalLight3D
	sun.basis = Basis.looking_at(-Vector3(0.0, 0.6, 0.8).normalized())
	await get_tree().process_frame
	var dir: Vector3 = rig.current_params().sun_dir
	_expect(dir.is_equal_approx(sun.global_basis.z.normalized()), "the sky's sun follows the Sun")
	var dusk := load("res://game/maps/sky/presets/night_city.tres") as SkyPreset
	rig.blend(dusk, 1.0)
	_expect((rig.current_params().zenith_color as Color).is_equal_approx(dusk.zenith_color), "blending all the way gives the second look")
	rig.blend(dusk, 0.0)
	_expect((rig.current_params().zenith_color as Color).is_equal_approx(preset.zenith_color), "and back")
	rig.set_live("sea_churn", 0.7)
	_expect(is_equal_approx(rig.current_params().sea_churn, 0.7), "a live setting overrides the preset")
	GraphicsQuality.apply_environments(map, GraphicsQuality.preset("low"))
	_expect(not rig.motion and env.background_mode == Environment.BG_SKY, "Low: no backdrop, the still sky is the background")
	GraphicsQuality.apply_environments(map, GraphicsQuality.preset("high"))
	_expect(rig.motion and env.background_mode == Environment.BG_COLOR, "High: the moving sky")
	map.queue_free()


func _check_setting() -> void:
	print("  setting")
	_expect(not GraphicsQuality.preset("low").sky_motion and GraphicsQuality.preset("medium").sky_motion, "Low has a still sky, Medium and High a moving one")
	_expect(GraphicsQuality.clean({"sky_motion": false}).sky_motion == false, "the pick is kept")
	_expect(GraphicsQuality.clean({}).sky_motion == true, "and is on by default")
