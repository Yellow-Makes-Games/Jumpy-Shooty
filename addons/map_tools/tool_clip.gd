@tool
extends RefCounted
## The Clip tool: cut the selected blocks in two.
##
## Point at a selected block: a line shows where it would be cut, snapped to the
## grid. Click to cut. The cut runs across the longest side of the face you point at;
## the "next cut direction" key turns it. Every selected block the cut passes through
## (and that lies square to it) is cut with it. A click anywhere else is an ordinary
## click, so you can pick another block without leaving the tool.

const MapOps := preload("res://addons/map_tools/map_ops.gd")
const MapEdit := preload("res://addons/map_tools/map_edit.gd")

const COLOR := Color(1.0, 0.9, 0.2)

var ctx: RefCounted   # MapContext
var turn := 0         # how many times the cut direction has been turned

var _cuts := []       # [block, axis, at (the block's own units), xf, half, at (metres)]
var _last_view: RefCounted
var _last_pos := Vector2.ZERO


func busy() -> bool:
	return false


func cancel() -> void:
	_cuts = []


## Turn the cut to run the other way across the face.
func next_direction() -> void:
	turn += 1
	if _last_view:
		_find(_last_view, _last_pos)


func input(view: RefCounted, event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mm:
		_find(view, mm.position)
		return false
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed \
			and not mb.shift_pressed and not mb.is_command_or_control_pressed():
		_find(view, mb.position)
		if _cuts.is_empty():
			return false
		_cut()
		return true
	return false


func _find(view: RefCounted, pos: Vector2) -> void:
	_last_view = view
	_last_pos = pos
	_cuts = []
	var blocks: Array = ctx.selected_blocks().filter(func(b: MapBlock) -> bool: return not MapOps.clip_axes(b).is_empty())
	if blocks.is_empty():
		return
	var hit: Dictionary = ctx.pick(view.origin(pos), view.normal(pos), blocks)
	if hit.is_empty():
		return
	var block: MapBlock = hit.block
	var xf: Transform3D = hit.xf
	var half: Vector3 = hit.half
	# Cut across a side of the face pointed at, the longest first.
	var ways: Array = MapOps.clip_axes(block).filter(func(a: int) -> bool: return a != hit.axis)
	if ways.is_empty():
		return
	ways.sort_custom(func(a: int, b: int) -> bool:
		return half[a] > half[b] + 0.001 or (absf(half[a] - half[b]) <= 0.001 and a < b))   # a square face: always the same way first
	var axis: int = ways[turn % ways.size()]
	var at: float = (xf.affine_inverse() * (hit.point as Vector3))[axis]
	var n := xf.basis[axis]
	var world := n.abs().max_axis_index()
	if absf(n[world]) > 0.999:
		# Square to the map: the cut lands on the map's grid.
		var where: float = (hit.point as Vector3)[world]
		at += (MapOps.snap(where, ctx.grid) - where) * signf(n[world])
	else:
		at = MapOps.snap(at + half[axis], ctx.grid) - half[axis]
	var along := Vector3.ZERO
	along[axis] = at
	var through := xf * along   # a point on the cut, in the map
	for b: MapBlock in blocks:
		var box := MapOps.box_of(b)
		var bxf: Transform3D = box[0]
		var bhalf: Vector3 = box[1]
		for j in MapOps.clip_axes(b):
			if absf(bxf.basis[j].dot(n)) < 0.999:
				continue
			var m: float = (bxf.affine_inverse() * through)[j]
			if absf(m) < bhalf[j] - MapOps.SLIVER:
				_cuts.append([b, j, m * (b.size[j] * 0.5) / bhalf[j], bxf, bhalf, m])
			break


func _cut() -> void:
	var edit := MapEdit.new()
	edit.name = "Clip map block"
	var chosen: Array = ctx.selected()
	for c in _cuts:
		var block: MapBlock = c[0]
		var halves := MapOps.clip(block, c[1], c[2])
		if halves.size() != 2:
			continue
		var index := block.get_index()
		edit.removes.append(block)
		edit.adds.append([block.get_parent(), halves[0], index])
		edit.adds.append([block.get_parent(), halves[1], index + 1])
		chosen.erase(block)
		chosen.append_array(halves)
	_cuts = []
	edit.select = chosen
	edit.reselect = true
	if not edit.is_empty():
		ctx.commit.call(edit)


func draw(view: RefCounted, overlay: Control) -> void:
	for c in _cuts:
		var xf: Transform3D = c[3]
		var half: Vector3 = c[4]
		var axis: int = c[1]
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var corners := PackedVector3Array()
		for s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var p := Vector3.ZERO
			p[axis] = c[5]
			p[u] = half[u] * s[0]
			p[v] = half[v] * s[1]
			corners.append(xf * p)
		for i in 4:
			view.draw_line(overlay, corners[i], corners[(i + 1) % 4], COLOR, 3.0)
