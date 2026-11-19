extends SceneTree
## Finds what flickers on a map: faces of two drawn blocks of different kinds that lie in
## the same plane, face the same way and overlap. There the graphics card cannot tell
## which is in front, and the two colours fight for the same pixels as you move.
##
##   godot --headless --path . --script tools/arena/find_shared_planes.gd -- --map=empyrean
##
## It lists each pair of block names with how many times and over how much area they
## clash, worst first, and where one of them is. Faces that rest on something (the
## underside of a crate on a floor) are listed too, though nobody sees those.
## Empyrean Tower's generator settles its own (tools/arena/empyrean_planes.py), and
## tests/empyrean_test.gd checks that none are left.
const GAP := 0.0015
func _over(A: Array, B: Array) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var p: Vector3 = B[1] + B[2] * B[4] * su + B[3] * B[5] * sv - A[1]
			var q := Vector2(p.dot(A[2]), p.dot(A[3]))
			lo = lo.min(q)
			hi = hi.max(q)
	var w := minf(hi.x, A[4]) - maxf(lo.x, -A[4])
	var h := minf(hi.y, A[5]) - maxf(lo.y, -A[5])
	return Vector2(w, h) if w > 0.03 and h > 0.03 and w * h > 0.01 else Vector2.ZERO


func _init() -> void:
	var id := "empyrean"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			id = a.trim_prefix("--map=")
	var map: MapRoot = Maps.make(id)
	root.add_child(map)
	await process_frame
	await process_frame
	var faces := {}     # normal key -> [[d, centre, u, v, hu, hv, name, kind, path]]
	var count := 0
	for n in map.find_children("*", "Node3D", true, false):
		if not (n is MapBlock) or not n.drawn:
			continue
		var b := n as MapBlock
		var xf := b.global_transform
		var half := b.size * 0.5
		var round := b.shape in [MapBlock.Shape.CYLINDER, MapBlock.Shape.TUBE, MapBlock.Shape.CONE, MapBlock.Shape.DOME]
		for axis in 3:
			if round and axis != 1:
				continue
			for sign: float in [-1.0, 1.0]:
				if b.shape == MapBlock.Shape.DOME or (b.shape == MapBlock.Shape.CONE and sign > 0.0 and b.top <= 0.01):
					continue
				var nrm := (xf.basis[axis] * sign).normalized()
				var c := xf.origin + xf.basis[axis] * half[axis] * sign
				var u := xf.basis[(axis + 1) % 3].normalized()
				var v := xf.basis[(axis + 2) % 3].normalized()
				var hu: float = half[(axis + 1) % 3] * (0.7 if round else 1.0)
				var hv: float = half[(axis + 2) % 3] * (0.7 if round else 1.0)
				var key := Vector3i(roundi(nrm.x * 300), roundi(nrm.y * 300), roundi(nrm.z * 300))
				if not faces.has(key):
					faces[key] = []
				faces[key].append([nrm.dot(c), c, u, v, hu, hv, String(b.name).rstrip("0123456789"), String(b.kind), b])
				count += 1
	var found := {}
	for key in faces:
		var list: Array = faces[key]
		list.sort_custom(func(a, b): return a[0] < b[0])
		for i in list.size():
			var A: Array = list[i]
			var j := i + 1
			while j < list.size() and list[j][0] - A[0] < GAP:
				var B: Array = list[j]
				j += 1
				if A[7] == B[7] or A[8] == B[8]:
					continue
				var wh := _over(A, B)
				var w := wh.x
				var h := wh.y
				if _over(B, A).x <= 0.0:
					continue
				if w > 0.03 and h > 0.03 and w * h > 0.01:
					var names := [A[6] + "(" + A[7] + ")", B[6] + "(" + B[7] + ")"]
					names.sort()
					var k := " + ".join(names)
					var e: Array = found.get(k, [0, 0.0, null])
					e[0] += 1
					e[1] += w * h
					if e[2] == null:
						e[2] = A[1]
					found[k] = e
	var keys := found.keys()
	keys.sort_custom(func(a, b): return found[a][1] > found[b][1])
	print("%s: %d faces; %d kinds of overlap" % [id, count, keys.size()])
	for k in keys.slice(0, 70):
		print("%5d x  %8.1f m2  %s   e.g. at %s" % [found[k][0], found[k][1], k, (found[k][2] as Vector3).snappedf(0.1)])
	quit()
