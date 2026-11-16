@tool
extends EditorNode3DGizmoPlugin
## Shows a map's limits in the 3D editor: the bounds (leave them and you are out)
## as a red rectangle at ground level, and the test swing point as a small cross.


func _init() -> void:
	create_material("bounds", Color(1.0, 0.25, 0.2))
	create_material("swing", Color(0.3, 0.8, 1.0))


func _get_gizmo_name() -> String:
	return "MapRoot"


func _has_gizmo(node: Node3D) -> bool:
	return node is MapRoot


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var map := gizmo.get_node_3d() as MapRoot
	var r := map.bounds
	if r.has_area():
		var c := [Vector3(r.position.x, 0.05, r.position.y), Vector3(r.end.x, 0.05, r.position.y),
			Vector3(r.end.x, 0.05, r.end.y), Vector3(r.position.x, 0.05, r.end.y)]
		var lines := PackedVector3Array()
		for i in 4:
			lines.append(c[i])
			lines.append(c[(i + 1) % 4])
		gizmo.add_lines(lines, get_material("bounds", gizmo))
	var s := map.swing_point
	var cross := PackedVector3Array()
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		cross.append(s - axis * 0.75)
		cross.append(s + axis * 0.75)
	gizmo.add_lines(cross, get_material("swing", gizmo))
