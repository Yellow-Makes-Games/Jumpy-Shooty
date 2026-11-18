@tool
extends RefCounted
## The Move tool: drag blocks about with snapping.
##
## Press on a block and drag: it (or the whole selection, if it is part of one)
## slides over the ground, or across the view in a top, front or side view. Hold
## Shift to move it straight up and down instead. Its faces snap against, or flush
## with, the faces of blocks beside it that lie square to it; otherwise it snaps to
## the grid. Esc or a right click puts it back. A press on empty space is left to the
## editor, so box select still works.

const MapOps := preload("res://addons/map_tools/map_ops.gd")
const MapEdit := preload("res://addons/map_tools/map_edit.gd")

const CLICK := 4.0

var ctx: RefCounted   # MapContext

var _armed := false
var _dragging := false
var _press := Vector2.ZERO
var _start := Vector3.ZERO           # the point on the block that was grabbed
var _nodes: Array[Node3D] = []
var _homes: Array[Vector3] = []      # where each was
var _frame := Basis.IDENTITY         # the frame it snaps in
var _square := true                  # that frame is the map's own
var _box := AABB()                   # what is being moved, in that frame
var _others: Array[AABB] = []        # what it can snap to
var _snapped := Vector3i.ZERO        # which axes are held by a neighbour's face (for the overlay)


func busy() -> bool:
	return _armed


func cancel() -> void:
	if _armed:
		for i in _nodes.size():
			if is_instance_valid(_nodes[i]):
				_nodes[i].position = _homes[i]
	_armed = false
	_dragging = false


func input(view: RefCounted, event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var key := event as InputEventKey
	if _armed and ((key and key.pressed and key.keycode == KEY_ESCAPE) or (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT)):
		cancel()
		return true
	if not _armed:
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed and not mb.is_command_or_control_pressed():
			return _grab(view, mb.position)
		return false
	if mm:
		if not _dragging and mm.position.distance_to(_press) < CLICK:
			return true
		_dragging = true
		_slide(view, mm.position, mm.shift_pressed)
		return true
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_drop()
		return true
	return false


func _grab(view: RefCounted, pos: Vector2) -> bool:
	var hit: Dictionary = ctx.pick(view.origin(pos), view.normal(pos))
	if hit.is_empty():
		return false
	var node: Node = ctx.selectable(hit.block)
	if node == null:
		return false
	var chosen: Array = ctx.selected()
	var held := false
	for n: Node in chosen:
		held = held or n == node or n.is_ancestor_of(node)
	if not held:
		ctx.select.call([node])
	_nodes = ctx.selected_tops()
	if _nodes.is_empty():
		return false
	_homes = []
	for n in _nodes:
		_homes.append(n.position)
	_start = hit.point
	_press = pos
	var xf: Transform3D = hit.xf
	_square = MapOps.aligned_box(Transform3D.IDENTITY, xf, hit.half) != null
	_frame = Basis.IDENTITY if _square else xf.basis
	var frame := Transform3D(_frame, Vector3.ZERO)
	var moving: Array[MapBlock] = []
	for n in _nodes:
		moving.append_array(MapOps.blocks_in(n))
	var mine := MapOps.boxes_in_frame(frame, moving)
	_box = AABB(frame.affine_inverse() * _start, Vector3.ZERO)
	for i in mine.size():
		_box = mine[i] if i == 0 else _box.merge(mine[i])
	var rest := []
	for e in ctx.blocks():
		if e.block not in moving:
			rest.append(e.block)
	_others = MapOps.boxes_in_frame(frame, rest)
	_armed = true
	_dragging = false
	return true


func _slide(view: RefCounted, pos: Vector2, upright: bool) -> void:
	var delta := Vector3.ZERO
	var flat: int = view.ortho_axis()
	if upright and flat < 0:
		delta.y = view.along_line(pos, _start, Vector3.UP)
	else:
		var axis := flat if flat >= 0 else 1
		var p: Variant = view.on_plane(pos, axis, _start[axis])
		if p == null:
			return
		delta = (p as Vector3) - _start
		delta[axis] = 0.0
	var local := _frame.inverse() * delta
	var result := MapOps.snap_move(AABB(_box.position + local, _box.size), _others, ctx.grid * 0.5)
	var nudge: Vector3 = result[0]
	_snapped = Vector3i.ZERO
	var final := Vector3.ZERO
	for a in 3:
		if absf(local[a]) < 0.0001:
			continue   # not being moved along this axis
		if result[1][a]:
			final[a] = local[a] + nudge[a]
			_snapped[a] = 1
		elif _square:
			final[a] = MapOps.snap(_box.position[a] + local[a], ctx.grid) - _box.position[a]
		else:
			final[a] = MapOps.snap(local[a], ctx.grid)
	var world := _frame * final
	for i in _nodes.size():
		_nodes[i].position = _homes[i] + MapOps.parent_global(_nodes[i]).basis.inverse() * world


func _drop() -> void:
	var edit := MapEdit.new()
	edit.name = "Move map blocks"
	if _dragging:
		for i in _nodes.size():
			if not _nodes[i].position.is_equal_approx(_homes[i]):
				edit.sets.append([_nodes[i], "position", _nodes[i].position, _homes[i]])
	_armed = false
	_dragging = false
	if not edit.is_empty():
		ctx.commit.call(edit)


func draw(view: RefCounted, overlay: Control) -> void:
	if not _dragging or _nodes.is_empty():
		return
	var moved := _nodes[0].position - _homes[0]
	var world: Vector3 = MapOps.parent_global(_nodes[0]).basis * moved
	var local := _frame.inverse() * world
	var color := Color(0.4, 1.0, 0.5) if _snapped != Vector3i.ZERO else Color(1.0, 0.75, 0.2)
	view.draw_box(overlay, Transform3D(_frame, _frame * (_box.get_center() + local)), _box.size * 0.5, color, 1.5)
