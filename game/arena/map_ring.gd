@tool
class_name MapRing
extends MapPiece
## Repeats its first child round a circle (see MapPiece): a tower's crenellations, a
## ring of pillars. The ring turns about its own origin and y axis; put the first
## child (a block, or a group of them) where one of them should stand, as far from the
## origin as the circle is wide. After moving or changing it, the copies are made
## again on the next edit, or press Rebuild in the inspector.

## How many there are, counting the first.
@export_range(1, 200) var count := 8:
	set(v):
		count = maxi(v, 1)
		_changed()

## How much of the circle they are spread over, in degrees. 360 = all the way round,
## evenly. Less = an arc starting at the first child, with one at each end.
@export_range(1.0, 360.0) var arc := 360.0:
	set(v):
		arc = v
		_changed()

var _copied := 0   # the first child's signature when the copies were made


## The angle (radians) from each one to the next.
func step_angle() -> float:
	if arc >= 360.0 or count < 2:
		return TAU / count
	return deg_to_rad(arc) / (count - 1)


func _make() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var first := template()
	if first == null:
		return out
	for i in range(1, count):
		var c := MapPiece.copy(first) as Node3D
		c.transform = Transform3D(Basis(Vector3.UP, step_angle() * i), Vector3.ZERO) * first.transform
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
