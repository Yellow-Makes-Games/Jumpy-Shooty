@tool
extends RefCounted
## The Draw tool: drag out a new block on the grid.
##
## In the 3D view: press on a block's face (or the ground, y = 0) and drag the
## block's footprint across it; let go, move the mouse to pull the block out of the
## face, and click to set it. In a top, front or side view: drag a rectangle, and the
## block is as deep as the selection or the last block drawn (see MapContext.depth).
## Esc or a right click gives up.

const MapOps := preload("res://addons/map_tools/map_ops.gd")
const MapEdit := preload("res://addons/map_tools/map_edit.gd")

const COLOR := Color(1.0, 0.75, 0.2)
const CLICK := 4.0   # a press that moves less than this (pixels) is a click, not a drag

enum Phase { IDLE, FOOT, HEIGHT }

var ctx: RefCounted   # MapContext
var phase := Phase.IDLE

var _axis := 1          # the axis the face drawn on looks along
var _side := 1.0        # and which way
var _at := 0.0          # where that face is along it
var _a := Vector3.ZERO  # the footprint's corners, on the face
var _b := Vector3.ZERO
var _height := 0.0
var _flat := false      # a top, front or side view: no pulling out
var _depth := Vector2.ZERO
var _press := Vector2.ZERO


func busy() -> bool:
	return phase != Phase.IDLE


func cancel() -> void:
	phase = Phase.IDLE


## Returns true if it used the event.
func input(view: RefCounted, event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var key := event as InputEventKey
	if busy() and ((key and key.pressed and key.keycode == KEY_ESCAPE) or (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT)):
		cancel()
		return true
	match phase:
		Phase.IDLE:
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed and not mb.is_command_or_control_pressed():
				return _begin(view, mb.position)
		Phase.FOOT:
			if mm:
				_b = _on_face(view, mm.position)
				return true
			if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_b = _on_face(view, mb.position)
				if mb.position.distance_to(_press) < CLICK:
					cancel()
				elif _flat:
					_finish()
				else:
					_height = ctx.grid
					phase = Phase.HEIGHT
				return true
		Phase.HEIGHT:
			if mm:
				_height = _pull(view, mm.position)
				return true
			if mb and mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_finish()
				return true
	return false


func _begin(view: RefCounted, pos: Vector2) -> bool:
	var start: Variant = null
	var axis: int = view.ortho_axis()
	_flat = axis >= 0
	if _flat:
		_axis = axis
		_side = 1.0
		_depth = ctx.depth(axis)
		_at = _depth.x
		start = view.on_plane(pos, _axis, _at)
	else:
		var hit: Dictionary = ctx.pick(view.origin(pos), view.normal(pos))
		if hit.is_empty():
			_axis = 1
			_side = 1.0
			_at = 0.0
			start = view.on_plane(pos, 1, 0.0)
		else:
			var n: Vector3 = hit.normal
			_axis = n.abs().max_axis_index()
			_side = signf(n[_axis])
			_at = (hit.point as Vector3)[_axis]
			start = hit.point
	if start == null:
		return false
	_a = _snapped(start)
	_b = _a
	_press = pos
	phase = Phase.FOOT
	return true


func _snapped(p: Vector3) -> Vector3:
	var s := MapOps.snap_v(p, ctx.grid)
	s[_axis] = _at
	return s


func _on_face(view: RefCounted, pos: Vector2) -> Vector3:
	var p: Variant = view.on_plane(pos, _axis, _at)
	return _b if p == null else _snapped(p)


func _pull(view: RefCounted, pos: Vector2) -> float:
	var along := Vector3.ZERO
	along[_axis] = _side
	var h: float = view.along_line(pos, (_a + _b) * 0.5, along)
	return maxf(MapOps.snap(h, ctx.grid), ctx.grid)


## The block being drawn: [its middle, its size], in the map.
func box() -> Array:
	var lo := _a.min(_b)
	var hi := _a.max(_b)
	for axis in 3:
		if axis != _axis and hi[axis] - lo[axis] < ctx.grid - 0.0001:
			hi[axis] = lo[axis] + ctx.grid
	if _flat:
		lo[_axis] = _depth.x
		hi[_axis] = _depth.y
	else:
		var h := _height if phase == Phase.HEIGHT else 0.0
		if _side > 0.0:
			hi[_axis] = _at + h
		else:
			lo[_axis] = _at - h
	return [(lo + hi) * 0.5, hi - lo]


func _finish() -> void:
	var made := box()
	phase = Phase.IDLE
	var size: Vector3 = made[1]
	if minf(size.x, minf(size.y, size.z)) < MapOps.SLIVER:
		return
	var parent: Node = ctx.new_parent()
	if parent == null:
		return
	var block := MapBlock.new()
	block.name = "Block"
	block.kind = ctx.kind
	block.size = size
	var to_parent := Transform3D.IDENTITY
	if parent is Node3D:
		to_parent = MapOps.global_of(parent).affine_inverse()
	block.transform = to_parent * Transform3D(Basis.IDENTITY, made[0])
	var edit := MapEdit.new()
	edit.name = "Draw map block"
	edit.adds = [[parent, block, -1]]
	edit.select = [block]
	edit.reselect = true
	ctx.last_box = AABB((made[0] as Vector3) - size * 0.5, size)
	ctx.has_last = true
	ctx.commit.call(edit)


func draw(view: RefCounted, overlay: Control) -> void:
	if not busy():
		return
	var made := box()
	var size: Vector3 = made[1]
	view.draw_box(overlay, Transform3D(Basis.IDENTITY, made[0]), size * 0.5, COLOR)
	var middle: Vector3 = made[0]
	if not view.behind(middle):
		var text := "%s × %s × %s m" % [_m(size.x), _m(size.y), _m(size.z)]
		overlay.draw_string(overlay.get_theme_default_font(), view.screen(middle) + Vector2(12, -12), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, overlay.get_theme_default_font_size(), COLOR)


func _m(v: float) -> String:
	return String.num(v, 2)
