extends SceneTree
## Building a map spread over frames (MapRoot.build with a MapBuildBudget, as behind
## the loading screen) makes the same map as building it in one go.
## Run: godot --headless --path . --script tests/map_build_spread_test.gd
##
## For each map: the same nodes of each kind, the same collision shapes, meshes with
## the same number of vertices, the same breakable cells (and which are protected),
## and the build really did stop for frames along the way.

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _run() -> void:
	await process_frame
	for id in ["construction_site", "office", "sky_island", "rooftop_run"]:   # (sky_island: breakables riding movers)
		var whole := _new_map(id)
		whole.build()
		var spread := _new_map(id)
		var budget := MapBuildBudget.new(self, 300)   # a tiny slice: many stops
		await spread.build(true, budget)
		print(id, ": spread over ", budget.waits + 1, " frames")
		_check(budget.waits > 0, "%s: the spread build stopped for frames" % id)
		var a := _summary(whole)
		var b := _summary(spread)
		for key in a:
			_check(a[key] == b.get(key), "%s: same %s (%s vs %s)" % [id, key, a[key], b.get(key)])
		_check(whole.spawns.size() == spread.spawns.size() and not whole.spawns.is_empty(), "%s: same spawn points" % id)
		whole.queue_free()
		spread.queue_free()
		await process_frame
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)


func _new_map(id: String) -> MapRoot:
	var map: MapRoot = Maps.make(id)
	map.destructible = Maps.game_of(id) != "race"
	root.add_child(map)
	return map


## Counts that two builds of the same map must agree on.
func _summary(map: MapRoot) -> Dictionary:
	var counts := {"nodes": 0, "shapes": 0, "meshes": 0, "vertices": 0, "cells": 0, "protected": 0, "panels": 0}
	var stack: Array = [map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		counts.nodes += 1
		if n is CollisionShape3D:
			counts.shapes += 1
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mesh := (n as MeshInstance3D).mesh
			counts.meshes += 1
			for s in mesh.get_surface_count():
				var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				counts.vertices += verts.size()
		stack.append_array(n.get_children())
	if map.destruction:
		counts.panels = map.destruction.panels.size()
		counts.cells = map.destruction.cells.size()
		for c in map.destruction.cells:
			if c.protected:
				counts.protected += 1
	return counts
