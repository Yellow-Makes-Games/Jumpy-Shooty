extends SceneTree
## A MapBlock's Breakable, Break Settings and Material Type.
## Run: godot --headless --path . --script tests/block_settings_test.gd
##
## Breakable: Default follows the palette, Yes breaks a kind the palette leaves out,
## No never breaks; maps saved with the old "unbreakable" still load as No. Break
## Settings: its health replaces the kind's, Whole Block breaks a thick block (any
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
	var yes := _block(map, "Yes", "concrete", Vector3(10, 1.5, 0), Vector3(4, 3, 0.2))
	yes.breakable = MapBlock.Breakable.YES
	var no := _block(map, "No", "drywall", Vector3(20, 1.5, 0), Vector3(4, 3, 0.2))
	no.breakable = MapBlock.Breakable.NO
	var legacy := _block(map, "Legacy", "drywall", Vector3(30, 1.5, 0), Vector3(4, 3, 0.2))
	legacy.set("unbreakable", true)
	var tough := _block(map, "Tough", "drywall", Vector3(40, 1.5, 0), Vector3(4, 3, 0.2))
	tough.break_settings = BlockBreakable.new()
	tough.break_settings.block_health = 500.0
	# A thick crate, whole block, with a steel box resting on top.
	var crate := _block(map, "Crate", "crate", Vector3(-20, 1.0, 0), Vector3(2, 2, 2))
	crate.breakable = MapBlock.Breakable.YES
	crate.break_settings = BlockBreakable.new()
	crate.break_settings.break_mode = BlockBreakable.Mode.WHOLE_BLOCK
	crate.break_settings.block_health = 150.0
	_block(map, "OnCrate", "steel", Vector3(-20, 2.25, 0), Vector3(1, 0.5, 1))
	# A thick block set Yes but per cell: too thick, does not break.
	var thick := _block(map, "Thick", "concrete", Vector3(-30, 1.0, 0), Vector3(2, 2, 2))
	thick.breakable = MapBlock.Breakable.YES
	# A round pillar, whole block.
	var pillar := _block(map, "Pillar", "concrete", Vector3(-40, 1.5, 0), Vector3(1, 3, 1))
	pillar.shape = MapBlock.Shape.CYLINDER
	pillar.breakable = MapBlock.Breakable.YES
	pillar.break_settings = crate.break_settings   # shared settings
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
	_check(panel_of.call(by_palette.position) >= 0, "Default + a breakable kind: breaks")
	_check(panel_of.call(yes.position) >= 0, "Yes + a kind the palette leaves out: breaks")
	_check(panel_of.call(no.position) < 0, "No: never breaks")
	_check(panel_of.call(legacy.position) < 0, "an old map's unbreakable = true loads as No")
	_check(legacy.breakable == MapBlock.Breakable.NO, "  ...and the block says No")
	_check(panel_of.call(thick.position) < 0, "Yes on a thick block, per cell: too thick, stays")
	_check(not MapDestruction.thin_enough(thick.shape, thick.size), "  (and the editor warning agrees)")

	var hp_of := func(at: Vector3) -> float:
		var i: int = panel_of.call(at)
		return d.cells[d.panels[i].first].max_hp if i >= 0 else -1.0
	_check(is_equal_approx(hp_of.call(by_palette.position), 60.0), "no Break Settings: the kind's toughness (60)")
	_check(is_equal_approx(hp_of.call(yes.position), BlockBreakable.DEFAULT_HEALTH), "a kind with no toughness: the default health")
	_check(is_equal_approx(hp_of.call(tough.position), 500.0), "block_health replaces the kind's toughness")

	var ci: int = panel_of.call(crate.position)
	_check(ci >= 0 and d.panels[ci].whole, "Whole Block: a thick crate can break")
	var pi: int = panel_of.call(pillar.position)
	_check(pi >= 0 and d.panels[pi].whole, "Whole Block: a cylinder can break (shared settings)")
	if ci >= 0:
		var panel: Dictionary = d.panels[ci]
		var n: Vector3i = panel.n
		_check(n == Vector3i.ONE, "  ...as one piece")
		var c: int = panel.first
		_check(not d.cells[c].protected, "  ...even with a box resting on it")
		_check(is_equal_approx(d.cells[c].max_hp, 150.0), "  ...with all of block_health (150)")
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

	# Maps saved with the old setting: castle had 37 unbreakable blocks.
	var castle: MapRoot = Maps.make("castle")
	var nos := 0
	for b in castle.find_children("*", "MapBlock", true, false):
		if (b as MapBlock).breakable == MapBlock.Breakable.NO:
			nos += 1
	_check(nos == 37, "castle's 37 never-break blocks load as No (%d)" % nos)
	castle.free()

	map.queue_free()
	await process_frame
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
