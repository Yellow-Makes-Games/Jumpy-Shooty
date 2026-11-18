@tool
extends EditorInspectorPlugin
## Two buttons at the top of a MapPiece's inspector (stairs, a ramp, a row, a ring):
## Rebuild makes its blocks again; Bake turns it into a plain group of blocks.

## (MapPiece): bake it (the plugin does it as one undo step).
var bake := Callable()


func _can_handle(object: Object) -> bool:
	return object is MapPiece


func _parse_begin(object: Object) -> void:
	var piece := object as MapPiece
	var row := HBoxContainer.new()
	var rebuild := Button.new()
	rebuild.text = "Rebuild"
	rebuild.tooltip_text = "Make its blocks again from its numbers (and, for a row or a ring, from its first child)."
	rebuild.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebuild.pressed.connect(func() -> void:
		if is_instance_valid(piece):
			piece.rebuild())
	row.add_child(rebuild)
	var bake_button := Button.new()
	bake_button.text = "Bake"
	bake_button.tooltip_text = "Turn it into a plain group of blocks you can edit by hand. Its numbers are gone after that (undo brings them back)."
	bake_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bake_button.pressed.connect(func() -> void:
		if is_instance_valid(piece) and bake.is_valid():
			bake.call(piece))
	row.add_child(bake_button)
	add_custom_control(row)
