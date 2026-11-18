@tool
extends RefCounted
## The Place tool: put down a prefab or a new piece (stairs, a ramp...) with a click.
##
## An outline follows the mouse over the blocks and the ground, snapped to the grid.
## Each click places one; Esc goes back to selecting.

const MapOps := preload("res://addons/map_tools/map_ops.gd")
const MapEdit := preload("res://addons/map_tools/map_edit.gd")

const COLOR := Color(0.4, 0.8, 1.0)

var ctx: RefCounted        # MapContext
## () -> Node3D: makes the thing to place, not yet in the scene.
var factory := Callable()
## What it is, for Edit > Undo.
var what := "prefab"
## Called when the tool is done with (the plugin goes back to Select).
var done := Callable()

var _at: Variant = null    # where the next one would go
var _outline := AABB()     # its size, round its own origin


func busy() -> bool:
	return false


func cancel() -> void:
	_at = null


## Start placing things made by `make`.
func start(make: Callable, label: String) -> void:
	factory = make
	what = label
	_at = null
	var sample: Node3D = make.call()
	_outline = AABB()
	if sample:
		_outline = MapOps.bounds_of([sample])
		sample.free()


func input(view: RefCounted, event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var key := event as InputEventKey
	if key and key.pressed and key.keycode == KEY_ESCAPE:
		_at = null
		if done.is_valid():
			done.call()
		return true
	if mm:
		_at = _point(view, mm.position)
		return false
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed and not mb.is_command_or_control_pressed():
		_at = _point(view, mb.position)
		if _at != null:
			_put()
		return true
	return false


## Where the mouse points: on the face of a block, else on the ground.
func _point(view: RefCounted, pos: Vector2) -> Variant:
	var hit: Dictionary = ctx.pick(view.origin(pos), view.normal(pos))
	var p: Variant = hit.point if not hit.is_empty() else view.on_plane(pos, 1, 0.0)
	if p == null:
		return null
	var s := MapOps.snap_v(p, ctx.grid)
	if hit.is_empty() or (hit.normal as Vector3).y > 0.7:
		s.y = (p as Vector3).y   # standing on a floor: at the floor's own height
	return s


func _put() -> void:
	var node: Node3D = factory.call()
	var parent: Node = ctx.new_parent()
	if node == null or parent == null:
		return
	var to_parent := Transform3D.IDENTITY
	if parent is Node3D:
		to_parent = MapOps.global_of(parent).affine_inverse()
	node.transform = to_parent * Transform3D(node.basis, _at)
	var edit := MapEdit.new()
	edit.name = "Place %s" % what
	edit.adds = [[parent, node, -1]]
	edit.select = [node]
	edit.reselect = true
	ctx.commit.call(edit)


func draw(view: RefCounted, overlay: Control) -> void:
	if _at == null:
		return
	var size := _outline.size.max(Vector3.ONE * 0.2)
	view.draw_box(overlay, Transform3D(Basis.IDENTITY, (_at as Vector3) + _outline.get_center()), size * 0.5, COLOR)
