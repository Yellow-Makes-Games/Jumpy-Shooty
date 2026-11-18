extends SceneTree
## A MapBlock's Breakable, Break Settings and Material Type.
## Run: godot --headless --path . --script tests/block_settings_test.gd
##
## Breakable: ticked breaks, unticked never does (whatever the palette lists); maps
## saved with the old Default / Yes / No, or "unbreakable", still load. Break
## Settings: one of the ready-made choices; Break Health replaces its health; Whole Block breaks a thick block (any
## shape) in one go and leaves what rests on it. Material Type: blank comes from
## the palette or the kind's name, set wins; footsteps find what is underfoot.

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _block(map: MapRoot, name: String, kind: String, at: Vector3, size: Vector3) -> MapBlock:
	var b := MapBlock.new()
	b.name = name
	b.kind = kind
	b.size = size
	b.position = at
	map.add_child(b)
	return b


func _run() -> void:
	await process_frame
	var map := MapRoot.new()
	var palette := MapPalette.new()
	palette.colors = {"concrete": Color.GRAY, "drywall": Color.WHITE, "crate": Color.BROWN, "steel": Color.DIM_GRAY, "pad": Color.BLACK}
	palette.breakable = {"drywall": 60.0}
	palette.material = {"pad": "rubber"}
	map.palette = palette
	map.destructible = true
	_block(map, "Ground", "concrete", Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	var spawn := MapSpawn.new()
	spawn.position = Vector3(80, 0, 80)
	map.add_child(spawn)
	# Walls 4 x 3 x 0.2, well apart.
	var by_palette := _block(map, "ByPalette", "drywall", Vector3(0, 1.5, 0), Vector3(4, 3, 0.2))
	by_palette.breakable = true
	var unticked := _block(map, "Unticked", "drywall", Vector3(0, 1.5, 20), Vector3(4, 3, 0.2))
	var old_yes := _block(map, "OldYes", "concrete", Vector3(10, 1.5, 20), Vector3(4, 3, 0.2))
	old_yes.set("breakable", 1)   # as an old map file sets it: Yes
	var old_no := _block(map, "OldNo", "drywall", Vector3(20, 1.5, 20), Vector3(4, 3, 0.2))
	old_no.set("breakable", 2)    # No
	var fragile := _block(map, "Fragile", "concrete", Vector3(30, 1.5, 20), Vector3(4, 3, 0.2))
	fragile.breakable = true
	fragile.break_settings = "Per Cell, Fragile"
	var yes := _block(map, "Yes", "concrete", Vector3(10, 1.5, 0), Vector3(4, 3, 0.2))
	yes.breakable = true
	var no := _block(map, "No", "drywall", Vector3(20, 1.5, 0), Vector3(4, 3, 0.2))
	var legacy := _block(map, "Legacy", "drywall", Vector3(30, 1.5, 0), Vector3(4, 3, 0.2))
	legacy.set("unbreakable", true)
	var tough := _block(map, "Tough", "drywall", Vector3(40, 1.5, 0), Vector3(4, 3, 0.2))
	tough.breakable = true
	tough.break_health = 500.0
	# A thick crate, whole block, with a steel box resting on top.
	var crate := _block(map, "Crate", "crate", Vector3(-20, 1.0, 0), Vector3(2, 2, 2))
	crate.breakable = true
	crate.break_settings = "Whole Block"
	crate.break_health = 150.0
	_block(map, "OnCrate", "steel", Vector3(-20, 2.25, 0), Vector3(1, 0.5, 1))
	# A thick block set Yes but per cell: too thick, does not break.
	var thick := _block(map, "Thick", "concrete", Vector3(-30, 1.0, 0), Vector3(2, 2, 2))
	thick.breakable = true
	# A round pillar, whole block.
	var pillar := _block(map, "Pillar", "concrete", Vector3(-40, 1.5, 0), Vector3(1, 3, 1))
	pillar.shape = MapBlock.Shape.CYLINDER
	pillar.breakable = true
	pillar.break_settings = "Whole Block, Tough"
	# Floors to stand on for footsteps.
	_block(map, "Pad", "pad", Vector3(60, 0.05, 0), Vector3(4, 0.1, 4))
	var steel_floor := _block(map, "SteelFloor", "concrete", Vector3(60, 0.05, 10), Vector3(4, 0.1, 4))
	steel_floor.material_type = "metal"
	root.add_child(map)
	map.build(false)
	var d := map.destruction
	_check(d != null, "the map has breakables")
	if d == null:
		quit(1)
		return

	var panel_of := func(at: Vector3) -> int:
		for i in d.panels.size():
			if ((d.panels[i].xf as Transform3D).origin - at).length() < 0.01:
				return i
		return -1
	_check(panel_of.call(by_palette.position) >= 0, "ticked: breaks")
	_check(panel_of.call(unticked.position) < 0, "not ticked: never breaks, though the palette lists its kind")
	_check(panel_of.call(old_yes.position) >= 0 and old_yes.breakable == true, "an old map.s Yes (1) loads as ticked")
	_check(panel_of.call(old_no.position) < 0 and old_no.breakable == false, "an old map.s No (2) loads as not ticked")
	_check(panel_of.call(yes.position) >= 0, "ticked + a kind the palette leaves out: breaks")
	_check(panel_of.call(no.position) < 0, "left alone: never breaks")
	_check(panel_of.call(legacy.position) < 0, "an old map.s unbreakable = true loads as not ticked")
	_check(legacy.breakable == false, "  ...and the block says so")
	_check(panel_of.call(thick.position) < 0, "ticked on a thick block, per cell: too thick, stays")
	_check(not MapDestruction.thin_enough(thick.shape, thick.size), "  (and the editor warning agrees)")

	var hp_of := func(at: Vector3) -> float:
		var i: int = panel_of.call(at)
		return d.cells[d.panels[i].first].max_hp if i >= 0 else -1.0
	_check(is_equal_approx(hp_of.call(by_palette.position), 60.0), "Per Cell: the kind.s toughness (60)")
	_check(is_equal_approx(hp_of.call(yes.position), BlockBreakable.DEFAULT_HEALTH), "a kind with no toughness: the default health")
	_check(is_equal_approx(hp_of.call(tough.position), 500.0), "Break Health replaces the kind.s toughness")
	_check(is_equal_approx(hp_of.call(fragile.position), 25.0), "Per Cell, Fragile: 25")
	_check(is_equal_approx(hp_of.call(pillar.position), 300.0), "Whole Block, Tough: 300")
	var listed := false
	for p in tough.get_property_list():
		if p.name == "breakable":
			listed = p.type == TYPE_BOOL
	_check(listed, "Breakable is a tick box in the inspector")
	var shown := {}
	for p in tough.get_property_list():
		shown[p.name] = p
	_check(shown.break_settings.hint == PROPERTY_HINT_ENUM and shown.break_settings.hint_string == ",".join(BlockBreakable.names()), "Break Settings is a dropdown of the ready-made choices only")
	var hidden := {}
	for p in unticked.get_property_list():
		hidden[p.name] = p
	_check(not (hidden.break_settings.usage & PROPERTY_USAGE_EDITOR) and not (hidden.break_health.usage & PROPERTY_USAGE_EDITOR), "and is hidden, with Break Health, until Breakable is ticked")

	var ci: int = panel_of.call(crate.position)
	_check(ci >= 0 and d.panels[ci].whole, "Whole Block: a thick crate can break")
	var pi: int = panel_of.call(pillar.position)
	_check(pi >= 0 and d.panels[pi].whole, "Whole Block: a cylinder can break")
	if ci >= 0:
		var panel: Dictionary = d.panels[ci]
		var n: Vector3i = panel.n
		_check(n == Vector3i.ONE, "  ...as one piece")
		var c: int = panel.first
		_check(not d.cells[c].protected, "  ...even with a box resting on it")
		_check(is_equal_approx(d.cells[c].max_hp, 150.0), "  ...with all of its Break Health (150)")
		await physics_frame
		var space := map.get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(Vector3(-20, 1, 5), Vector3(-20, 1, -5), 1)
		var hit := space.intersect_ray(ray)
		_check(hit and hit.collider.has_meta("panel") and d.cell_at(hit.collider, hit.position, hit.normal) == c, "a shot at it hits it")
		d.damage(c, 100.0)
		var change := d.flush()
		d.apply(change[0], change[1])
		_check(not d.is_broken(c) and d.cells[c].stage > 0, "100 damage cracks it")
		d.damage(c, 60.0)
		change = d.flush()
		d.apply(change[0], change[1])
		_check(d.is_broken(c), "the rest breaks it")
		await physics_frame
		await physics_frame
		hit = space.intersect_ray(ray)
		_check(hit.is_empty(), "a shot now goes through where it was")
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-20, 4, 0), Vector3(-20, 0.1, 0), 1))
		_check(top and absf(top.position.y - 2.5) < 0.05, "the box on top stays where it was")

	# Materials
	_check(d.material_of(d.panels[panel_of.call(by_palette.position)].first) == "concrete", "drywall: guessed concrete")
	if ci >= 0:
		_check(d.material_of(d.panels[ci].first) == "wood", "crate: guessed wood")
	_check(BlockMaterials.for_kind("steel", palette) == "metal", "steel: guessed metal")
	_check(BlockMaterials.for_kind("pad", palette) == "rubber", "the palette's Material list wins over the guess")
	_check(map.material_at(Vector3(60, 0.1, 0)) == "rubber", "standing on the pad: rubber")
	_check(map.material_at(Vector3(60, 0.1, 10)) == "metal", "a block's own Material Type wins")
	_check(map.material_at(Vector3(70, 0.0, 30)) == "concrete", "on the open ground: the ground's material")
	_check(MapRoot.current == map, "footsteps can find the map being played")
	for m in BlockMaterials.TABLE:
		var info: Dictionary = BlockMaterials.TABLE[m]
		for key in ["step", "step_pitch", "step_db", "break", "break_pitch", "debris", "dust", "shards"]:
			if not info.has(key):
				_check(false, "%s has %s" % [m, key])

	# A scene file saved when Breakable was Default / Yes / No (a number) still loads.
	var old_path := "user://old_breakable_map.tscn"
	var old_file := FileAccess.open(old_path, FileAccess.WRITE)
	old_file.store_string("\n".join([
		"[gd_scene format=3]", "",
		"[ext_resource type=\"Script\" path=\"res://game/arena/map_root.gd\" id=\"1\"]",
		"[ext_resource type=\"Script\" path=\"res://game/arena/map_block.gd\" id=\"2\"]", "",
		"[node name=\"Old\" type=\"Node3D\"]", "script = ExtResource(\"1\")", "",
		"[node name=\"WasYes\" type=\"Node3D\" parent=\".\"]", "script = ExtResource(\"2\")", "breakable = 1", "",
		"[node name=\"WasNo\" type=\"Node3D\" parent=\".\"]", "script = ExtResource(\"2\")", "breakable = 2", "",
		"[node name=\"WasDefault\" type=\"Node3D\" parent=\".\"]", "script = ExtResource(\"2\")", ""]))
	old_file.close()
	var old_map := (ResourceLoader.load(old_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	_check(old_map.get_node("WasYes").breakable == true and old_map.get_node("WasNo").breakable == false and old_map.get_node("WasDefault").breakable == false,
		"an old scene file: Yes loads ticked, No and Default not")
	old_map.free()
	DirAccess.remove_absolute(old_path)

	# The maps were brought up to date by tools/arena/migrate_breakable.gd: the Castle's
	# two wooden hoardings are the only things there that break.
	var castle: MapRoot = Maps.make("castle")
	var ticked := 0
	for b in castle.find_children("*", "MapBlock", true, false):
		if (b as MapBlock).breakable:
			ticked += 1
	_check(ticked == 2, "the castle's 2 breakable blocks are ticked, the rest not (%d)" % ticked)
	castle.free()

	map.queue_free()
	await process_frame
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
