extends SceneTree
## Fewer blocks, the same map: blocks that together make one convex shape become one
## block, so the map draws, collides and loads the same with fewer nodes (and none of
## the faces that met inside them).
##
##   godot --headless --path . --script tools/arena/merge_blocks.gd -- --map=empyrean
##   godot --headless --path . --script tools/arena/merge_blocks.gd -- --map=empyrean --write
##
## Without --write it only says what it would do. --map takes a map id or a scene path.
##
## Two blocks merge only when nothing would show it:
##  - they are siblings (one group, so a click still selects the same objects) with the
##    same kind, Solid, Drawn, Tint and Material Type, none breakable, none with painted
##    faces, children, a hidden eye or a name a NodePath in the scene points at;
##  - the convex shape round both is no bigger than the two of them together (to a
##    third of a millimetre over its surface): no gap or inside corner is filled in;
##  - the result is drawn the way they were: still small decoration (left out from
##    afar, see MapRoot's Drawing) if they were, and not if they were not.
## Two boxes turned the same way that make a box stay a box, and two cylinders that make
## a longer one stay a cylinder; anything else becomes a hull block (at most
## MapMesher.MAX_HULL_CORNERS corners). A block wholly inside another like it goes.
##
## It edits the scene file as text: the merged blocks' transform, shape, size and
## points, and the blocks merged into them taken out. Every other line stays as it was.

const MapOps := preload("res://addons/map_tools/map_ops.gd")
const BLOCK_SCRIPT := "res://game/arena/map_block.gd"
const EPS := 0.0005          # faces this close are flush (metres)
var slack := 0.0003           # (--slack=MM) how much the merged shape may exceed the two, averaged over its surface (metres)
const MAX_GENERIC_POINTS := 32   # corners of the two together, for a merge into a hull (finding faces is slow past it)
## Blocks the map's tests know by name.
const KEEP_PREFIXES := ["Field", "Burn"]
const ONE_LUMP := [MapBlock.Shape.BOX, MapBlock.Shape.CYLINDER, MapBlock.Shape.CONE,
	MapBlock.Shape.WEDGE, MapBlock.Shape.BEVEL, MapBlock.Shape.HULL]
const ROUND_PARAMS := ["sides = ", "inner = ", "top = ", "bevel = ", "arc = "]

var map: Node
var detail_range := 0.0
var detail_size := 1.5
var referenced := {}     # names a NodePath in the scene ends in
var in_text := {}        # path -> true for every node with a section of its own in the file
var changed := {}        # block -> true
var removed := {}        # block -> true
var _geo := {}           # block -> [parent-local AABB, volume] (cleared when it changes)
var listing := false
var out_path := ""          # (--out=res://...) write the merged map here instead of over it
var stats := {"box": 0, "cylinder": 0, "inside": 0, "hull": 0}


func _init() -> void:
	var id := "empyrean"
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			id = a.trim_prefix("--map=")
		elif a.begins_with("--slack="):
			slack = a.trim_prefix("--slack=").to_float() / 1000.0
		elif a == "--list":
			listing = true
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
			write = true
		elif a == "--write":
			write = true
	var path := id
	if not id.begins_with("res://"):
		path = ""
		for m in Maps.LIST:
			if m.id == id:
				path = m.scene
	if path == "":
		print("No map called %s" % id)
		quit(1)
		return
	var text := FileAccess.get_file_as_string(path)
	_read_text(text)
	map = (load(path) as PackedScene).instantiate()
	if map is MapRoot:
		detail_range = (map as MapRoot).detail_range
		detail_size = (map as MapRoot).detail_size
	var started := Time.get_ticks_msec()
	var before := 0
	var groups := {}     # parent -> [blocks that may merge]
	for n in map.find_children("*", "Node3D", true, false):
		if n is MapBlock:
			before += 1
			if _can_merge(n):
				var p: Node = n.get_parent()
				if not groups.has(p):
					groups[p] = []
				groups[p].append(n)
	for p in groups:
		var buckets := {}
		for b: MapBlock in groups[p]:
			var key := _key(b)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(b)
		for key in buckets:
			if buckets[key].size() > 1:
				_merge_all(buckets[key])
	print("%s: %d blocks, %d after merging (%d fewer) in %d s" % [path, before, before - removed.size(), removed.size(),
		(Time.get_ticks_msec() - started) / 1000])
	print("  boxes into boxes %d, cylinders into cylinders %d, blocks inside others %d, into hulls %d" % [
		stats.box, stats.cylinder, stats.inside, stats.hull])
	print("  %d blocks reshaped" % changed.keys().filter(func(b): return not removed.has(b)).size())
	if write:
		var out := _rewrite(text)
		var dest := out_path if out_path != "" else path
		var f := FileAccess.open(dest, FileAccess.WRITE)
		f.store_string(out)
		f.close()
		print("  written to %s" % dest)
	else:
		print("  (nothing written: add --write)")
	map.free()
	quit()


# ---------------------------------------------------------------------------
# What may merge

func _read_text(text: String) -> void:
	var paths := RegEx.create_from_string("NodePath\\(\"([^\"]*)\"\\)")
	for m in paths.search_all(text):
		var parts := m.get_string(1).split("/")
		referenced[parts[parts.size() - 1]] = true
	for line in text.split("\n"):
		var at := _section_path(line)
		if at != "":
			in_text[at] = true


## The node path (from the scene's root) a `[node ...]` line starts the section of, or "".
static func _section_path(line: String) -> String:
	if not line.begins_with("[node "):
		return ""
	var name := _attr(line, "name")
	var parent := _attr(line, "parent")
	if line.contains(" parent=\"") == false:
		return "."
	return name if parent == "." else parent + "/" + name


static func _attr(line: String, attr: String) -> String:
	var start := line.find(" %s=\"" % attr)
	if start < 0:
		return ""
	start += attr.length() + 3
	return line.substr(start, line.find("\"", start) - start)


func _can_merge(b: MapBlock) -> bool:
	if b.get_script() == null or (b.get_script() as Script).resource_path != BLOCK_SCRIPT:
		return false   # (a hazard, or anything else built on blocks)
	if b.shape not in ONE_LUMP or b.breakable or not b.visible or b.get_child_count() > 0 \
			or (b.transform.basis.get_scale() - Vector3.ONE).length() > 0.001:
		return false
	if not b.face_kinds.is_empty() or not b.face_patterns.is_empty():
		return false
	if referenced.has(String(b.name)) or b.owner != map or not in_text.has(String(map.get_path_to(b))):
		return false
	for prefix in KEEP_PREFIXES:
		if String(b.name).begins_with(prefix):
			return false
	var up := b.get_parent()
	while up and up != map:
		if up is MapPiece or up is MapBlock:
			return false   # (a piece remakes its blocks; a block's children ride its frame)
		up = up.get_parent()
	return true


func _key(b: MapBlock) -> String:
	return "%s|%s|%s|%s|%s|%d" % [b.kind, b.solid, b.drawn, b.tint.to_html(), b.material_type, _lot(b, _scaled_size(b))]


## How the map draws it (MapRoot.build): 0 structure, 1 decoration, 2 small decoration.
func _lot(b: MapBlock, size: Vector3) -> int:
	if b.solid:
		return 0
	if detail_range > 0.0 and maxf(size.x, maxf(size.y, size.z)) <= detail_size:
		return 2
	return 1


static func _scaled_size(b: MapBlock) -> Vector3:
	return b.size * b.transform.basis.get_scale().abs()


# ---------------------------------------------------------------------------
# Merging

func _merge_all(list: Array) -> void:
	var live: Array = list.duplicate()
	var again := true
	while again:
		again = false
		var i := 0
		while i < live.size():
			var a: MapBlock = live[i]
			var j := i + 1
			while j < live.size():
				var b: MapBlock = live[j]
				if _aabb(a).grow(EPS * 2.0).intersects(_aabb(b)) and _try(a, b):
					live.remove_at(j)
					again = true
					continue   # (a has changed: try it with the rest again from here)
				j += 1
			i += 1


## Merges `b` into `a` if nothing would show it.
var _into: MapBlock

func _try(a: MapBlock, b: MapBlock) -> bool:
	_into = a
	var rel := a.transform.affine_inverse() * b.transform    # b in a's own frame
	var square := _is_identity(rel.basis)
	if square and a.shape == MapBlock.Shape.BOX and b.shape == MapBlock.Shape.BOX:
		return _boxes(a, b, rel.origin)
	if square and a.shape == MapBlock.Shape.CYLINDER and b.shape == MapBlock.Shape.CYLINDER \
			and a.sides == b.sides and absf(a.size.x - b.size.x) < EPS and a.arc >= 360.0 and b.arc >= 360.0:
		if _cylinders(a, b, rel.origin):
			return true
	return _hulls(a, b, rel)


func _boxes(a: MapBlock, b: MapBlock, o: Vector3) -> bool:
	var ha := a.size * 0.5
	var hb := b.size * 0.5
	var lo_b := o - hb
	var hi_b := o + hb
	var inside_a := true
	var inside_b := true
	var same := 0
	var free_axis := -1
	for axis in 3:
		inside_a = inside_a and lo_b[axis] >= -ha[axis] - EPS and hi_b[axis] <= ha[axis] + EPS
		inside_b = inside_b and -ha[axis] >= lo_b[axis] - EPS and ha[axis] <= hi_b[axis] + EPS
		if absf(lo_b[axis] + ha[axis]) < EPS and absf(hi_b[axis] - ha[axis]) < EPS:
			same += 1
		else:
			free_axis = axis
	if inside_a:
		_take(b)
		stats["inside"] += 1
		return true
	if inside_b:
		_set_box(a, o, b.size)
		_take(b)
		stats["inside"] += 1
		return true
	if same != 2:
		return false
	if lo_b[free_axis] > ha[free_axis] + EPS or hi_b[free_axis] < -ha[free_axis] - EPS:
		return false   # (a gap between them)
	var lo := (-ha).min(lo_b)
	var hi := ha.max(hi_b)
	if not _same_lot(a, hi - lo):
		return false
	_set_box(a, (lo + hi) * 0.5, hi - lo)
	_take(b)
	stats["box"] += 1
	return true


func _cylinders(a: MapBlock, b: MapBlock, o: Vector3) -> bool:
	if absf(o.x) > EPS or absf(o.z) > EPS:
		return false
	var lo := minf(-a.size.y * 0.5, o.y - b.size.y * 0.5)
	var hi := maxf(a.size.y * 0.5, o.y + b.size.y * 0.5)
	if o.y - b.size.y * 0.5 > a.size.y * 0.5 + EPS or o.y + b.size.y * 0.5 < -a.size.y * 0.5 - EPS:
		return false
	var size := Vector3(a.size.x, hi - lo, a.size.z)
	if not _same_lot(a, size):
		return false
	if hi - lo <= a.size.y + EPS:
		stats["inside"] += 1
	else:
		stats["cylinder"] += 1
	_set_box(a, Vector3(0, (lo + hi) * 0.5, 0), size)
	_take(b)
	return true


func _hulls(a: MapBlock, b: MapBlock, rel: Transform3D) -> bool:
	var la := MapOps.editable_lumps(a)
	var lb := MapOps.editable_lumps(b)
	if la.size() != 1 or lb.size() != 1:
		return false
	var pa: PackedVector3Array = la[0]
	var pb := PackedVector3Array()
	for p in lb[0]:
		pb.append(rel * p)
	if pa.size() + pb.size() > MAX_GENERIC_POINTS:
		return false
	var all := pa.duplicate()
	all.append_array(pb)
	var corners := MapMesher.hull_corners(all)
	if corners.size() < 4 or corners.size() > MapMesher.MAX_HULL_CORNERS:
		return false
	# Every corner of the two must be in the shape found: on points a hair out of one
	# plane (rotations kept to four places) the faces can come out wrong and leave some out.
	var outside := MapMesher.hull_planes(corners)
	for p in all:
		if not MapMesher.hull_has(outside, p, 0.001):
			return false
	var whole := _volume(corners)
	var va := _volume_of(a)
	var vb := _volume_of(b)
	var planes: Array[Plane] = MapMesher.hull_planes(pa)
	planes.append_array(MapMesher.hull_planes(pb))
	var shared := MapOps.corners_of(planes)
	var vab: float = _volume(shared)[0] if MapMesher.hull_planes(shared).size() >= 4 else 0.0
	if absf(whole[0] - (va + vb - vab)) > slack * whole[1]:
		return false   # (the shape round them fills in a gap or an inside corner, or was found wrong)
	var a_planes := MapMesher.hull_planes(pa)
	if Array(pb).all(func(p): return MapMesher.hull_has(a_planes, p, EPS)):
		_take(b)       # (b is inside a)
		stats["inside"] += 1
		return true
	var box := MapBlock.points_bounds(corners)
	if not _same_lot(a, box.size * a.transform.basis.get_scale().abs()):
		return false
	var square := corners.size() == 8
	for p in corners:
		for axis in 3:
			square = square and (absf(p[axis] - box.position[axis]) < 0.0002 or absf(p[axis] - box.end[axis]) < 0.0002)
	var middle := box.get_center()
	var at := (a.transform * middle).snappedf(0.0001)
	if square:
		a.shape = MapBlock.Shape.BOX
		a.points = PackedVector3Array()
		a.size = box.size.snappedf(0.0001)
		stats["box"] += 1
	else:
		var centred := PackedVector3Array()
		for p in corners:
			centred.append(p - middle)
		a.shape = MapBlock.Shape.HULL
		a.points = centred
		stats["hull"] += 1
	a.position = at
	_changed(a)
	_take(b)
	return true


## Gives box (or cylinder) `a` the size `size` with its middle at `middle` in its own frame.
func _set_box(a: MapBlock, middle: Vector3, size: Vector3) -> void:
	a.position = (a.transform * middle).snappedf(0.0001)
	a.size = size.snappedf(0.0001)
	_changed(a)


func _take(b: MapBlock) -> void:
	if listing:
		print("    %s: %s <- %s" % [map.get_path_to(b.get_parent()), _into.name, b.name])
	removed[b] = true


func _changed(a: MapBlock) -> void:
	changed[a] = true
	_geo.erase(a)


func _same_lot(a: MapBlock, size: Vector3) -> bool:
	return _lot(a, size) == _lot(a, _scaled_size(a))


static func _is_identity(basis: Basis) -> bool:
	return (basis.x - Vector3.RIGHT).length() < 2e-4 and (basis.y - Vector3.UP).length() < 2e-4 \
		and (basis.z - Vector3.BACK).length() < 2e-4


## The box round a block, in its parent's frame.
func _aabb(b: MapBlock) -> AABB:
	if not _geo.has(b):
		var box := AABB()
		var first := true
		for lump in b.shape_lumps():
			for p: Vector3 in lump:
				var q := b.transform * p
				box = AABB(q, Vector3.ZERO) if first else box.expand(q)
				first = false
		_geo[b] = [box, -1.0]
	return _geo[b][0]


func _volume_of(b: MapBlock) -> float:
	_aabb(b)
	if _geo[b][1] < 0.0:
		if b.shape == MapBlock.Shape.BOX:
			_geo[b][1] = b.size.x * b.size.y * b.size.z
		else:
			_geo[b][1] = _volume(MapOps.editable_lumps(b)[0])[0]
	return _geo[b][1]


## [volume, surface area] of the convex lump with these corners.
static func _volume(pts: PackedVector3Array) -> Array:
	var volume := 0.0
	var area := 0.0
	for face in MapMesher.hull_faces(pts):
		var n: Vector3 = face[0]
		var ring: Array = face[1]
		var twice := Vector3.ZERO
		for i in ring.size():
			twice += (ring[i] as Vector3).cross(ring[(i + 1) % ring.size()])
		var a := twice.length() * 0.5
		area += a
		volume += n.dot(ring[0]) * a / 3.0
	return [volume, area]


# ---------------------------------------------------------------------------
# Writing the scene

func _rewrite(text: String) -> String:
	var by_path := {}
	for b in changed:
		if not removed.has(b):
			by_path[String(map.get_path_to(b))] = b
	var gone := {}
	for b in removed:
		gone[String(map.get_path_to(b))] = true
	var newline := "\r\n" if text.contains("\r\n") else "\n"
	var lines := text.split(newline)
	var out := PackedStringArray()
	var i := 0
	while i < lines.size():
		var at := _section_path(lines[i])
		if at == "" or not (gone.has(at) or by_path.has(at)):
			out.append(lines[i])
			i += 1
			continue
		var end := i + 1
		while end < lines.size() and not lines[end].begins_with("["):
			end += 1
		if by_path.has(at):
			out.append_array(_section(lines.slice(i, end), by_path[at]))
		i = end
	return newline.join(out)


## A block's section with its new transform, shape, size and points.
func _section(old: PackedStringArray, b: MapBlock) -> PackedStringArray:
	var basis_text := "1, 0, 0, 0, 1, 0, 0, 0, 1"
	for line in old:
		if line.begins_with("transform = Transform3D("):
			var nums := line.trim_prefix("transform = Transform3D(").trim_suffix(")").split(", ")
			basis_text = ", ".join(nums.slice(0, 9))
	var plain := b.shape == MapBlock.Shape.BOX or b.shape == MapBlock.Shape.HULL
	var out := PackedStringArray([old[0]])
	out.append("transform = Transform3D(%s, %s, %s, %s)" % [basis_text, _num(b.position.x), _num(b.position.y), _num(b.position.z)])
	var tail := PackedStringArray()
	for k in range(1, old.size()):
		var line := old[k]
		if line.begins_with("transform = ") or line.begins_with("shape = ") or line.begins_with("size = ") or line.begins_with("points = "):
			continue
		if plain and ROUND_PARAMS.any(func(p): return line.begins_with(p)):
			continue
		if line.strip_edges() == "":
			tail.append(line)
			continue
		out.append(line)
		if line.begins_with("script = "):
			if b.shape != MapBlock.Shape.BOX:
				out.append("shape = %d" % b.shape)
			if not b.size.is_equal_approx(Vector3.ONE):
				out.append("size = Vector3(%s, %s, %s)" % [_num(b.size.x), _num(b.size.y), _num(b.size.z)])
	if b.shape == MapBlock.Shape.HULL:
		var nums := PackedStringArray()
		for p in b.points:
			nums.append_array([_num(p.x), _num(p.y), _num(p.z)])
		out.append("points = PackedVector3Array(%s)" % ", ".join(nums))
	out.append_array(tail)
	return out


static func _num(v: float) -> String:
	var s := String.num(snappedf(v, 0.0001), 4)
	return "0" if s == "-0" else s
