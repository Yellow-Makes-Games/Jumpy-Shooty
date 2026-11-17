@tool
class_name MapCheckpoint
extends Marker3D
## A race checkpoint gate (race maps). Racers must pass the gates in order of their
## Number; passing one makes it the place they come back to when they fall or touch
## a hazard. The gate with Finish ticked is the finish line (give it the highest
## number). Stand it on the floor across the course and turn it (around y) so the
## arrow points the way racers run: they come back facing that way.
## In the game it is drawn as an arch with a light curtain.

## The order racers pass the gates in: 1, 2, 3...
@export var number := 1:
	set(v):
		number = v
		_refresh()
## The finish line.
@export var finish := false:
	set(v):
		finish = v
		_refresh()
## The gate's opening: width (across the course) and height. Racers count as through
## once their body crosses this rectangle.
@export var opening := Vector2(8, 5):
	set(v):
		opening = v.max(Vector2(1, 1))
		_refresh()

var _preview: Node3D


## Is `point` (in the map's frame, with this gate at `xf`) inside the gate's box?
## The box is the opening, `depth` metres thick along the way racers run.
static func contains(xf: Transform3D, size: Vector2, point: Vector3, depth: float = 1.6) -> bool:
	var local := xf.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and local.y >= -0.5 and local.y <= size.y and absf(local.z) <= depth * 0.5


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_refresh()


func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
	_preview = RaceGate.make(opening, finish, number, true)
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
