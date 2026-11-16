@tool
extends EditorPlugin
## Adds the map gizmos to the 3D editor (block_gizmo.gd and map_gizmo.gd).

var _blocks: EditorNode3DGizmoPlugin
var _maps: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_blocks = preload("res://addons/map_tools/block_gizmo.gd").new()
	_maps = preload("res://addons/map_tools/map_gizmo.gd").new()
	add_node_3d_gizmo_plugin(_blocks)
	add_node_3d_gizmo_plugin(_maps)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_blocks)
	remove_node_3d_gizmo_plugin(_maps)
