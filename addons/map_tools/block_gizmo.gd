@tool
extends EditorNode3DGizmoPlugin
## Map blocks in the 3D editor: click one to select it, then drag the orange
## handle on a face to move that face (the opposite face stays put). A cylinder
## has a handle for its diameter and one at each end.
##
## Sizes snap to 0.1 m; hold Ctrl to snap to whole metres.

const NAMES := ["Right (+x)", "Left (-x)", "Top (+y)", "Bottom (-y)", "Back (+z)", "Front (-z)"]


func _init() -> void:
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "MapBlock"


func _has_gizmo(node: Node3D) -> bool:
	return node is MapBlock


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var block := gizmo.get_node_3d() as MapBlock
	var triangles := block.preview_triangles()
	if triangles:
		gizmo.add_collision_triangles(triangles)
	var h := block.size * 0.5
	var handles := PackedVector3Array()
	var ids := PackedInt32Array()
	for id in 6:
		if block.is_round() and id in [1, 4, 5]:
			continue   # round: one handle for the diameter
		var axis := id / 2
		var p := Vector3.ZERO
		p[axis] = h[axis] * (1.0 if id % 2 == 0 else -1.0)
		handles.append(p)
		ids.append(id)
	gizmo.add_handles(handles, get_material("handles", gizmo), ids)


func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	var block := gizmo.get_node_3d() as MapBlock
	return "Diameter" if block.is_round() and id == 0 else NAMES[id]


func _get_handle_value(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool) -> Variant:
	var block := gizmo.get_node_3d() as MapBlock
	return [block.size, block.position]


func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var block := gizmo.get_node_3d() as MapBlock
	var to_local := block.global_transform.affine_inverse()
	var from := camera.project_ray_origin(screen_pos)
	var ray := camera.project_ray_normal(screen_pos)
	var a := to_local * from
	var b := to_local * (from + ray * 4096.0)
	var axis := id / 2
	var dir := 1.0 if id % 2 == 0 else -1.0
	var line := Vector3.ZERO
	line[axis] = 4096.0
	var closest := Geometry3D.get_closest_points_between_segments(-line, line, a, b)
	var reach: float = closest[0][axis] * dir   # how far out the dragged face is, from the centre
	block.move_face(id, reach, 1.0 if Input.is_key_pressed(KEY_CTRL) else 0.1)


func _commit_handle(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var block := gizmo.get_node_3d() as MapBlock
	if cancel:
		block.size = restore[0]
		block.position = restore[1]
		return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Resize map block")
	undo.add_do_property(block, "size", block.size)
	undo.add_do_property(block, "position", block.position)
	undo.add_undo_property(block, "size", restore[0])
	undo.add_undo_property(block, "position", restore[1])
	undo.commit_action()
