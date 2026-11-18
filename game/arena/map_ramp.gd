@tool
class_name MapRamp
extends MapPiece
## A ramp made from a few numbers (see MapPiece). Its top surface starts at its own
## origin and climbs toward its -z, reaching `rise` metres up at z = -run.

## How far up it goes (metres).
@export var rise := 3.0:
	set(v):
		rise = maxf(v, 0.05)
		_changed()

## How far along it goes (metres).
@export var run := 6.0:
	set(v):
		run = maxf(v, 0.1)
		_changed()

@export var width := 3.0:
	set(v):
		width = maxf(v, 0.1)
		_changed()

## A slab's thickness (not used when Filled is on).
@export var thickness := 0.3:
	set(v):
		thickness = maxf(v, 0.02)
		_changed()

## Which colour from the map's palette.
@export var kind := "concrete":
	set(v):
		kind = v
		_changed()

## On: a wedge, solid down to the ground. Off: a tilted slab you can walk under.
@export var filled := false:
	set(v):
		filled = v
		notify_property_list_changed()
		_changed()

## How steep it is. Players walk up to 46 degrees; steeper than that they slide.
@export_custom(PROPERTY_HINT_NONE, "suffix:°", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var slope: float:
	get:
		return rad_to_deg(atan2(rise, run))


func _make() -> Array[Node3D]:
	if filled:
		return [_block("Ramp", kind, Vector3(width, rise, run), Vector3(0, rise * 0.5, -run * 0.5), MapBlock.Shape.WEDGE)]
	var angle := atan2(rise, run)
	var length := sqrt(rise * rise + run * run)
	var slab := _block("Ramp", kind, Vector3(width, thickness, length), Vector3.ZERO)
	slab.basis = Basis(Vector3.RIGHT, angle)
	# Its top face runs from the origin to (0, rise, -run): the middle of that, less
	# half its thickness along the way the top faces.
	slab.position = Vector3(0, rise * 0.5, -run * 0.5) - slab.basis.y * (thickness * 0.5)
	return [slab]


func _validate_property(property: Dictionary) -> void:
	if property.name == "thickness" and filled:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	if slope > 46.0:
		return ["At %.0f degrees this is too steep to walk up (the limit is 46): players slide down it." % slope]
	return []
