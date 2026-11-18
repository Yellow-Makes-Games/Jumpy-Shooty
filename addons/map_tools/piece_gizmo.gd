@tool
extends EditorNode3DGizmoPlugin
## Handles on the map pieces, like the ones on a block's faces. Stairs and ramps
## (MapStairs): Rise at the top, Run at the far end of the foot, Width at the side;
## dragging one changes that number, and the piece makes its blocks again as you go.
## A row (MapRow): one at its last copy, to set how far apart they are.
##
## Lengths snap to the map tools' grid; hold Ctrl to snap to whole metres.

const MapOps := preload("res://addons/map_tools/map_ops.gd")

## The map tools' shared state (plugin.gd sets it): the grid.
var ctx: RefCounted


func _init() -> void:
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "MapPiece"


func _has_gizmo(node: Node3D) -> bool:
	return node is MapStairs or node is MapRow


## A piece's handles: [name, where it is, the way it slides (both in the piece's own
## frame), the property it sets].
static func handles_of(piece: Node3D) -> Array:
	if piece is MapStairs:
		var s := piece as MapStairs
		return [
			["Rise", Vector3(0, s.rise, -s.run), Vector3.UP, "rise"],
			["Run", Vector3(0, 0, -s.run), Vector3.FORWARD, "run"],
			["Width", Vector3(s.width * 0.5, 0, 0), Vector3.RIGHT, "width"],
		]
	if piece is MapRow:
		var r := piece as MapRow
		var first := r.template()
		if first and r.count > 1 and not r.spacing.is_zero_approx():
			return [["Spacing", first.position + r.spacing * (r.count - 1), r.spacing.normalized(), "spacing"]]
	return []


## The value a handle gives its property when it has been slid `along` metres from
## where the property would be zero.
static func value_for(piece: Node3D, handle: Array, along: float, step: float) -> Variant:
	match handle[3]:
		"width":
			return maxf(MapOps.snap(along * 2.0, step), step)
		"spacing":
			var r := piece as MapRow
			return (handle[2] as Vector3) * maxf(MapOps.snap(along / (r.count - 1), step), step)
	return maxf(MapOps.snap(along, step), step)


## Where a handle's property is zero: the point its slide is measured from.
static func zero_of(piece: Node3D, handle: Array) -> Vector3:
	match handle[3]:
		"rise":
			return Vector3(0, 0, -(piece as MapStairs).run)
		"spacing":
			return (piece as MapRow).template().position
	return Vector3.ZERO


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var points := PackedVector3Array()
	var ids := PackedInt32Array()
	var all := handles_of(gizmo.get_node_3d())
	for i in all.size():
		points.append(all[i][1])
		ids.append(i)
	if not points.is_empty():
		gizmo.add_handles(points, get_material("handles", gizmo), ids)


func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	var all := handles_of(gizmo.get_node_3d())
	return all[id][0] if id < all.size() else ""


func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	var all := handles_of(gizmo.get_node_3d())
	return gizmo.get_node_3d().get(all[id][3]) if id < all.size() else null


func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var piece := gizmo.get_node_3d()
	var all := handles_of(piece)
	if id >= all.size():
		return
	var handle: Array = all[id]
	var to_local := piece.global_transform.affine_inverse()
	var from := camera.project_ray_origin(screen_pos)
	var ray := camera.project_ray_normal(screen_pos)
	var zero := zero_of(piece, handle)
	var way: Vector3 = handle[2]
	var closest := Geometry3D.get_closest_points_between_segments(zero - way * 4096.0, zero + way * 4096.0,
		to_local * from, to_local * (from + ray * 4096.0))
	var step: float = 1.0 if Input.is_key_pressed(KEY_CTRL) else (ctx.grid if ctx else 0.1)
	piece.set(handle[3], value_for(piece, handle, (closest[0] - zero).dot(way), step))


func _commit_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var piece := gizmo.get_node_3d()
	var all := handles_of(piece)
	if id >= all.size():
		return
	var property: String = all[id][3]
	if cancel:
		piece.set(property, restore)
		return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Change %s %s" % [piece.name, all[id][0]])
	undo.add_do_property(piece, property, piece.get(property))
	undo.add_undo_property(piece, property, restore)
	undo.commit_action()
