@tool
class_name MapStairs
extends MapPiece
## A flight of stairs made from a few numbers (see MapPiece). It stands on its own
## origin and climbs toward its -z: the foot of the first step is at z = 0, the top
## step ends at z = -run, `rise` metres up.
##
## Players do not step up kerbs, so with Smooth on (the default) the steps are drawn
## only and an invisible ramp lying on their front edges is what you walk on.

## How far up it goes (metres).
@export var rise := 3.0:
	set(v):
		rise = maxf(v, 0.1)
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

## The tallest a step may be; the steps are made equal, as few as fit under this.
@export var step_height := 0.25:
	set(v):
		step_height = maxf(v, 0.05)
		_changed()

## Which colour from the map's palette.
@export var kind := "concrete":
	set(v):
		kind = v
		_changed()

## On: each step is a block down to the ground. Off: each step is a floating tread.
@export var filled := true:
	set(v):
		filled = v
		_changed()

## On: you walk on an invisible ramp over the steps. Off: the steps themselves are
## solid, and anyone walking has to jump them.
@export var smooth := true:
	set(v):
		smooth = v
		_changed()


## How many steps it has.
func steps() -> int:
	return maxi(1, ceili(rise / step_height - 0.0001))


func _make() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var n := steps()
	var h := rise / n
	var d := run / n
	for i in n:
		var top := (i + 1) * h
		var size := Vector3(width, top if filled else h, d)
		var step := _block("Step%d" % (i + 1), kind, size, Vector3(0, top - size.y * 0.5, -(i + 0.5) * d))
		step.solid = not smooth
		out.append(step)
	if smooth:
		# A wedge is tall at its -z and runs down to nothing at +z. Laid on the steps'
		# front edges it starts one step's depth in front of the first step.
		var ramp := _block("Walk", kind, Vector3(width, rise, run), Vector3(0, rise * 0.5, d - run * 0.5), MapBlock.Shape.WEDGE)
		ramp.drawn = false
		out.append(ramp)
	return out


func _get_configuration_warnings() -> PackedStringArray:
	var angle := rad_to_deg(atan2(rise, run))
	if smooth and angle > 46.0:
		return ["At %.0f degrees this is too steep to walk up (the limit is 46). Give it more Run." % angle]
	return []
