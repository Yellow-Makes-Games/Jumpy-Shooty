extends SceneTree
## Breakable walls and floors (MapDestruction), on the real maps.
## Run: godot --headless --path . --script tests/destruction_test.gd
##
## Arena maps have breakable walls and floors and race maps none; every spawn point
## stands on floor that cannot break; a broken cell lets a shot (a ray) through where
## it was blocked, its neighbours stay; an intact panel's collision is one box (so it
## walks exactly like before); a cell under a desk or a column never breaks; enough
## damage cracks a cell, then breaks it; the hit is found from where a shot landed.

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _make(id: String) -> MapRoot:
	var map: MapRoot = Maps.make(id)
	map.destructible = Maps.game_of(id) != "race"
	root.add_child(map)
	var started := Time.get_ticks_msec()
	map.build()
	print("%s: built in %d ms" % [id, Time.get_ticks_msec() - started])
	return map


func _run() -> void:
	await process_frame
	for id in ["construction_site", "office", "rail_yard", "lost_temple", "neon_arcade"]:
		var map := _make(id)
		var d := map.destruction
		_check(d != null and d.panels.size() > 10, "%s has breakable panels (%d)" % [id, d.panels.size() if d else 0])
		if d == null:
			map.queue_free()
			continue
		var open := d.breakable_count()
		print("  %d cells, %d can break" % [d.cells.size(), open])
		_check(open > 50 and open < d.cells.size(), "%s: many cells can break, some are held" % id)
		var intact_one_box := true
		for p in d.panels:
			if (p.body as StaticBody3D).get_child_count() != 1:
				intact_one_box = false
		_check(intact_one_box, "%s: every intact panel collides as one box" % id)
		# Spawn points: the floor under each stays.
		var space := map.get_world_3d().direct_space_state
		await physics_frame
		var spawn_ok := true
		for s in map.spawns:
			var at: Vector3 = s[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 1, 0), at - Vector3(0, 2, 0), 1))
			if hit and hit.collider.has_meta("panel"):
				var c := d.cell_at(hit.collider, hit.position, hit.normal)
				if not d.cells[c].protected:
					spawn_ok = false
		_check(spawn_ok, "%s: no spawn point stands on floor that can break" % id)
		# Break one cell of a floor and one of a wall, through the same path as a shot.
		for want_floor in [true, false]:
			var c := _open_cell(d, want_floor)
			_check(c >= 0, "%s: found a breakable %s cell" % [id, "floor" if want_floor else "wall"])
			if c < 0:
				continue
			var box := d.cell_box(c)
			var panel: Dictionary = d.panels[d.cells[c].panel]
			var normal: Vector3 = (panel.xf as Transform3D).basis[panel.thin].normalized()
			var centre := box.get_center()
			var from := centre + normal * 1.5
			var to := centre - normal * 1.5
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			_check(not hit.is_empty() and d.cell_at(hit.collider, hit.position, hit.normal) == c, "  a shot at it lands on that cell")
			var hp: float = d.cells[c].max_hp
			var armour: float = panel.armour
			if armour > 0.0:
				d.damage(c, armour * 0.9)
				_check(d.flush().is_empty(), "  a hit too weak for it (under %d) does nothing" % int(armour))
			# (Where a hit must be heavy to count, one such hit is already most of a cell.)
			d.damage(c, maxf(hp * 0.5, armour))
			var change := d.flush()
			_check(not change.is_empty() and change[1][0] in [1, 2], "  half its strength cracks it")
			d.apply(change[0], change[1])
			d.damage(c, maxf(hp, armour))
			change = d.flush()
			_check(not change.is_empty() and change[1][0] == MapDestruction.BROKEN, "  the rest breaks it")
			d.apply(change[0], change[1])
			await physics_frame
			await physics_frame
			hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			var through: bool = hit.is_empty() or not hit.collider.has_meta("panel") or int(hit.collider.get_meta("panel")) != d.cells[c].panel
			_check(through, "  a shot now goes through the hole")
			_check((panel.body as StaticBody3D).get_child_count() >= 1 or panel.n.x * panel.n.y * panel.n.z == 1, "  the rest of the panel still stands")
			d.damage(c, 999.0)
			_check(d.flush().is_empty(), "  a broken cell takes no more damage")
		if d.fine:
			await _fine_checks(map, d, space)
		# A protected cell ignores damage.
		var held := -1
		for c in d.cells.size():
			if d.cells[c].protected:
				held = c
				break
		d.damage(held, 99999.0)
		_check(d.flush().is_empty(), "%s: a held cell never breaks" % id)
		# Late joiners: the snapshot lists what is broken.
		var snap := d.snapshot()
		_check((snap[0] as PackedInt32Array).size() >= 2, "%s: the snapshot for late joiners lists the broken cells" % id)
		map.queue_free()
		await process_frame
	for id in ["rooftop_run", "foundry", "sky_ruins", "summit_plunge"]:
		var map := _make(id)
		_check(map.destruction == null, "%s (race): nothing breaks" % id)
		map.queue_free()
	await process_frame
	# Melee weapons break walls faster than their damage alone.
	_check(WeaponData.by_id("hammer").structure_damage > 1.0, "the hammer hits walls extra hard")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)


## A map that breaks fine: small cells, holes the size of what made them, ragged edges.
func _fine_checks(map: MapRoot, d: MapDestruction, space: PhysicsDirectSpaceState3D) -> void:
	var biggest := 0.0
	for p in d.panels:
		if p.fine:
			biggest = maxf(biggest, maxf(p.cell[p.u], p.cell[p.v]))
	_check(biggest > 0.0 and biggest <= 0.75, "  fine: no cell is more than 0.75 m across (%.2f)" % biggest)
	# A blast in the middle of a block wall: a round hole about its size, cracked round the edge.
	var wall := -1
	for i in d.panels.size():
		var p: Dictionary = d.panels[i]
		if p.fine and p.kind == "block" and p.thin != 1 and p.nu * p.nv > 200 and wall < 0:
			wall = i
	_check(wall >= 0, "  fine: found a block wall")
	if wall < 0:
		return
	var panel: Dictionary = d.panels[wall]
	# (at a cell that can break, well inside the wall)
	var middle := -1
	for iv in range(3, panel.nv - 3):
		for iu in range(5, panel.nu - 5):
			var c: int = panel.first + iu * panel.su + iv * panel.sv
			if middle < 0 and not d.cells[c].protected:
				middle = c
	_check(middle >= 0, "  fine: it has a cell that can break well inside it")
	if middle < 0:
		return
	var at := d.cell_center(middle)
	var before := d.broken_count()
	d.damage_area(at, 1.6, 260.0)   # (a rocket)
	var change := d.flush()
	_check(not change.is_empty(), "  fine: a blast changes cells")
	if change.is_empty():
		return
	d.apply(change[0], change[1])
	var broke := d.broken_count() - before
	var cracked := (change[0] as PackedInt32Array).size() - broke
	print("    a rocket on blockwork: %d cells broken, %d cracked" % [broke, cracked])
	_check(broke >= 8 and broke <= 60, "  fine: it breaks a hole of 8 to 60 cells (%d)" % broke)
	_check(cracked >= 4, "  fine: and cracks the cells round it (%d)" % cracked)
	var far := true
	for c in (change[0] as PackedInt32Array):
		if d.cell_center(c).distance_to(at) > 1.6 + 0.6:
			far = false
	_check(far, "  fine: nothing further than the blast reaches changes")
	await physics_frame
	await physics_frame
	var normal: Vector3 = (panel.xf as Transform3D).basis[panel.thin].normalized()
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + normal * 1.5, at - normal * 1.5, 1))
	_check(hit.is_empty() or not hit.collider.has_meta("panel") or int(hit.collider.get_meta("panel")) != wall, "  fine: a shot goes through the middle of the hole")
	var away: Vector3 = (panel.xf as Transform3D).basis[panel.u].normalized() * 2.6
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + away + normal * 1.5, at + away - normal * 1.5, 1))
	_check(not hit.is_empty() and hit.collider.has_meta("panel"), "  fine: the wall beside the hole still stops one")
	# The edge of the hole is drawn ragged, and the same every time.
	await process_frame
	await process_frame
	var corners := _drawn_corners(panel)
	_check(corners.size() > 100, "  fine: the wall round the hole is drawn (%d corners)" % corners.size())
	var off_grid := 0
	var inv: Transform3D = (panel.xf as Transform3D).affine_inverse()
	for v: Vector3 in corners:
		var local := inv * v
		var along: float = (local[panel.u] + panel.size[panel.u] * 0.5) / panel.cell[panel.u]
		if absf(along - roundf(along)) > 0.02:
			off_grid += 1
	_check(off_grid > 0, "  fine: the hole's edge is ragged (%d corners off the grid)" % off_grid)
	d._rebuild_meshes(wall)
	_check(_drawn_corners(panel) == corners, "  fine: drawn again, it is the same edge")
	await _through_checks(map, d, space, panel, at + (panel.xf as Transform3D).basis[panel.u].normalized() * 5.0, normal)


## Rounds through a wall, and the marks they leave: `at` is a point in the middle of an
## unbroken stretch of block wall `panel`, `normal` the way it faces.
func _through_checks(map: MapRoot, d: MapDestruction, space: PhysicsDirectSpaceState3D, panel: Dictionary, at: Vector3, normal: Vector3) -> void:
	var from := at + normal * 3.0
	var path := func(weapon: WeaponData) -> Array:
		var to := from - normal * weapon.max_range
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		var legs := [{"a": from, "b": to if hit.is_empty() else hit.position, "dir": -normal, "hit": hit}]
		d.pierce(space, legs, weapon)
		return legs
	var rifle: Array = path.call(WeaponData.by_id("rifle"))
	_check(rifle.size() == 1 and int(rifle[0].cell) >= 0 and d.panels[d.cells[rifle[0].cell].panel] == panel,
		"  through: a rifle round stops in a block wall")
	var sniper: Array = path.call(WeaponData.by_id("sniper"))
	_check(sniper.size() == 2 and sniper[1].has("through"), "  through: a sniper round goes through it")
	if sniper.size() == 2:
		_check(is_equal_approx(sniper[0].keep, 1.0) and is_equal_approx(sniper[1].keep, MapDestruction.FINE_STYLES.masonry.keep),
			"  through: with %d%% of its damage left on the far side" % roundi(sniper[1].keep * 100.0))
		_check((sniper[1].a as Vector3).distance_to(at - normal * 0.17) < 0.1, "  through: it comes out of the far face")
		_check(int(sniper[0].cell) == int(rifle[0].cell), "  through: and the wall still takes the hit")
	var pistol := WeaponData.by_id("pistol")
	var sheet := -1
	for i in d.panels.size():
		if d.panels[i].fine and d.panels[i].kind == "sheeting" and sheet < 0:
			sheet = i
	if sheet >= 0:
		var sp: Dictionary = d.panels[sheet]
		var sn: Vector3 = (sp.xf as Transform3D).basis[sp.thin].normalized()
		var s_from: Vector3 = (sp.xf as Transform3D).origin + sn * 1.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(s_from, s_from - sn * 3.0, 1))
		var legs := [{"a": s_from, "b": hit.get("position", s_from - sn * 3.0), "dir": -sn, "hit": hit}]
		d.pierce(space, legs, pistol)
		_check(legs.size() >= 2 and legs[1].has("through"), "  through: a pistol round goes through sheeting")
	# The marks.
	var marks := map.marks
	_check(marks != null, "  marks: a map with fine destruction has them")
	if marks == null:
		return
	var had: int = marks.counts()[0]
	marks.shot(from, rifle[0].b, WeaponData.by_id("rifle"))
	_check(marks.counts()[0] == had + 1, "  marks: a round that stops in a wall leaves one")
	had = marks.counts()[0]
	marks.shot(from, sniper[sniper.size() - 1].b, WeaponData.by_id("sniper"))
	_check(marks.counts()[0] >= had + 2, "  marks: one that goes through leaves a hole on each face (%d more)" % (marks.counts()[0] - had))
	had = marks.counts()[0]
	for n in BulletMarks.MAX_MARKS + 50:
		marks.shot(from + Vector3(0, (n % 20) * 0.02, 0), rifle[0].b + Vector3(0, (n % 20) * 0.02, 0), WeaponData.by_id("rifle"))
	_check(marks.counts()[0] == BulletMarks.MAX_MARKS, "  marks: there are never more than %d" % BulletMarks.MAX_MARKS)
	# A cracked cell is drawn cracked; a broken one takes its marks with it.
	var c := int(rifle[0].cell)
	var cracks: int = marks.counts()[1]
	d.damage(c, d.cells[c].max_hp * 0.5)
	var change := d.flush()
	if not change.is_empty():
		d.apply(change[0], change[1])
	_check(marks.counts()[1] == cracks + 1, "  marks: a cracked cell gets its cracks")
	d.damage(c, 100000.0)
	change = d.flush()
	if not change.is_empty():
		d.apply(change[0], change[1])
	_check(marks.counts()[1] == cracks, "  marks: broken, they go")
	var left := 0
	for slot in BulletMarks.MAX_MARKS:
		if marks._mark_cell[slot] == c:
			left += 1
	_check(left == 0 and not marks._by_cell.has(c), "  marks: and so does every mark on it")
	await physics_frame


func _drawn_corners(panel: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in (panel.meshes as Node3D).get_children():
		out.append_array((m as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return out


## A cell that can break, on a floor (thin along y) or a wall, away from the panel edges if it can.
func _open_cell(d: MapDestruction, floor_panel: bool) -> int:
	var fallback := -1
	for c in d.cells.size():
		var cell: Dictionary = d.cells[c]
		var panel: Dictionary = d.panels[cell.panel]
		if cell.protected or cell.stage != 0 or (panel.thin == 1) != floor_panel or panel.kind.contains("glass"):
			continue
		var n: Vector3i = panel.n
		if n.x * n.y * n.z >= 4:
			return c
		fallback = c
	return fallback
