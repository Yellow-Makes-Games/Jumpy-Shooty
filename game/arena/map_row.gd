@tool
class_name MapRow
extends MapPiece
## Repeats its first child along a line (see MapPiece): fence posts, railings,
## merlons, pillars. The first child (a block, or a group of them) is the one you
## edit; the copies follow it. After moving or changing it, the copies are made again
## on the next edit, or press Rebuild in the inspector.

## How many there are, counting the first.
@export_range(1, 200) var count := 4:
	set(v):
		count = maxi(v, 1)
		_changed()

## From each one to the next (metres, in the row's own frame).
@export var spacing := Vector3(0, 0, -2):
	set(v):
		spacing = v
		_changed()

var _copied := 0   # the first child's signature when the copies were made


func _make() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var first := template()
	if first == null:
		return out
	for i in range(1, count):
		var c := MapPiece.copy(first) as Node3D
		c.transform = Transform3D(Basis.IDENTITY, spacing * i) * first.transform
		out.append(c)
	return out


func _made() -> void:
	_copied = MapPiece.signature(template())


## Makes the copies again if the first child has changed since they were made (the
## map tools plugin asks after every edit).
func refresh_if_changed() -> void:
	if MapPiece.signature(template()) != _copied:
		rebuild()
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if template() == null:
		return ["Add a MapBlock (or a group of them) as its first child: that is what gets repeated."]
	return []
