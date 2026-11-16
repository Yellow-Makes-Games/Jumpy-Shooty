@tool
class_name MapMover
extends Node3D
## A group of blocks that moves: a platform sliding back and forth, a press going
## up and down, a sweeper bar turning (race maps). Put MapBlocks (and MapHazards)
## under it like under any group. In the game they become one moving body that
## carries anyone standing on it.
##
## Every copy of the game moves it by the time since the match started, so it is
## in the same place for everyone.

## How far it slides at the far end of its trip (in its own frame). Zero = no sliding.
@export var travel := Vector3.ZERO
## Seconds for one trip there and back (or one full turn when it spins).
@export var period := 4.0
## Turns around its own y axis, in degrees per second (negative = the other way).
@export var spin := 0.0
## 0..1: where in its cycle it starts, so neighbours can be out of step.
@export_range(0.0, 1.0) var phase := 0.0
## 0..0.45: the share of each trip it waits at either end (a press resting down, a
## platform waiting at the edge). With zero it eases smoothly there and back.
@export_range(0.0, 0.45) var hold := 0.0


## The offset of the moving part from where it sits in the editor, at time `t`.
func offset_at(t: float) -> Transform3D:
	var basis := Basis.IDENTITY
	if spin != 0.0:
		basis = Basis(Vector3.UP, deg_to_rad(spin * t + phase * 360.0))
	var along := 0.0
	if travel != Vector3.ZERO and period > 0.0:
		var c := fposmod(t / period + phase, 1.0)
		# 0 -> 1 -> 0 over the cycle, waiting `hold` at each end.
		var h := hold
		var move := 0.5 - h
		if c < h * 0.5:
			along = 0.0
		elif c < h * 0.5 + move:
			along = (c - h * 0.5) / move
		elif c < h * 1.5 + move:
			along = 1.0
		elif c < 1.0 - h * 0.5:
			along = 1.0 - (c - (h * 1.5 + move)) / move
		else:
			along = 0.0
		along = 0.5 - 0.5 * cos(along * PI)
	return Transform3D(basis, travel * along)
