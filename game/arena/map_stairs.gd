@tool
class_name MapStairs
extends MapPiece
## A flight of stairs, or a ramp, made from a few numbers (see MapPiece): Style picks
## which. It stands on its own origin and climbs toward its -z: its foot is at z = 0,
## its top `rise` metres up at z = -run. In the editor, drag its handles to set Rise
## (at the top), Run (at the far end of its foot) and Width (at its side).
##
## Players do not step up kerbs, so with Smooth on (the default) the steps are drawn
## only and an invisible ramp lying on their front edges is what you walk on. Steps are
## one Stairs block (MapBlock.Shape.STAIRS), however many there are; a ramp is one wedge
## or one slab.

enum Style { STEPS, RAMP }

## Steps, or a plain ramp.
@export var style := Style.STEPS:
	set(v):
		style = v
		notify_property_list_changed()
		_changed()

## How far up it goes (metres).
@export var rise := 3.0:
	set(v):
		rise = maxf(v, 0.05)
		_changed()

## How far along it goes (metres).
@export var run := 4.5:
	set(v):
		run = maxf(v, 0.1)
		_changed()

@export var width := 2.0:
	set(v):
		width = maxf(v, 0.1)
		_changed()

## Which colour from the map's palette.
@export var kind := "concrete":
	set(v):
		kind = v
		_changed()

## What holds it up. Solid: down to the ground (a ramp: a wedge). Slab: the steps sit on
## a sloping slab Thickness thick, with room to walk under its high end (a ramp: a tilted
## slab). Treads: each step a floating tread Thickness thick (a ramp: the same slab).
@export var step_style := MapBlock.StepStyle.SOLID:
	set(v):
		step_style = v
		notify_property_list_changed()
		_changed()

## Steps: the tallest a step may be; the steps are made equal, as few as fit under this.
@export var step_height := 0.25:
	set(v):
		step_height = maxf(v, 0.05)
		_changed()

## Steps: on, you walk on an invisible ramp over the steps. Off, the steps themselves
## are solid, and anyone walking has to jump them.
@export var smooth := true:
	set(v):
		smooth = v
		_changed()

## With a Slab or Treads: how thick the slab or each tread is (a ramp's slab: square to
## its slope; a step's: upright).
@export var thickness := 0.3:
	set(v):
		thickness = maxf(v, 0.02)
		_changed()

## How steep it is. Players walk up to 46 degrees; steeper than that they slide.
@export_custom(PROPERTY_HINT_NONE, "suffix:°", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var slope: float:
	get:
		return rad_to_deg(atan2(rise, run))


## How many steps it has (as Steps).
func steps() -> int:
	return maxi(1, ceili(rise / step_height - 0.0001))


func _make() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if style == Style.RAMP:
		out.append(_ramp())
		return out
	# One block: the way on (a step's depth in front of the first step, at floor level),
	# then the steps; its walked ramp lies on their front edges (see MapMesher.climb_walk).
	var n := steps()
	var d := run / n
	var held := 0.0 if step_style == MapBlock.StepStyle.SOLID else thickness
	var flight := _block("Stairs", kind, Vector3(width, rise + held, run + d), Vector3(0, (rise - held) * 0.5, (d - run) * 0.5), MapBlock.Shape.STAIRS)
	flight.steps = n
	flight.step_style = step_style
	flight.thickness = thickness
	flight.smooth = smooth
	out.append(flight)
	return out


func _ramp() -> MapBlock:
	if step_style == MapBlock.StepStyle.SOLID:
		return _block("Ramp", kind, Vector3(width, rise, run), Vector3(0, rise * 0.5, -run * 0.5), MapBlock.Shape.WEDGE)
	var angle := atan2(rise, run)
	var slab := _block("Ramp", kind, Vector3(width, thickness, sqrt(rise * rise + run * run)), Vector3.ZERO)
	slab.basis = Basis(Vector3.RIGHT, angle)
	# Its top face runs from the origin to (0, rise, -run): the middle of that, less
	# half its thickness along the way the top faces.
	slab.position = Vector3(0, rise * 0.5, -run * 0.5) - slab.basis.y * (thickness * 0.5)
	return slab


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"step_height", "smooth":
			if style != Style.STEPS:
				property.usage &= ~PROPERTY_USAGE_EDITOR
		"thickness":
			if step_style == MapBlock.StepStyle.SOLID:
				property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	if slope > 46.0 and (style == Style.RAMP or smooth):
		return ["At %.0f degrees this is too steep to walk up (the limit is 46): players slide down it. Give it more Run." % slope]
	return []
