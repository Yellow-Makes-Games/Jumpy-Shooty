@tool
class_name MapIsland
extends MapMover
## A group of blocks with two places to be, for a map with two layouts (Cirrus: a
## building island that swings round the quad). Put MapBlocks under it like under
## any group. In the game they become one moving body that carries anyone standing
## on it, and everything else inside the group rides along: spawn points, weapon and
## power-up spots, signs, grapple points, MapSpan walkways, breakable glass.
##
## Where it sits in the scene is its first place (blend 0). Its second place
## (blend 1) is that, swung round `pivot` by `swing` degrees, pulled `pull` metres
## toward the pivot and lowered `drop` metres; it turns with the swing, so the side
## that faced the pivot still does. A LayoutEvent moves `blend` between 0 and 1 on
## every copy of the game from the host's clock, so it is in the same place for
## everyone. (Travel, Period, Spin, Phase and Hold, a plain MapMover's settings, do
## nothing here.)

const GROUP := "map_islands"

## The point (in the map's frame) it swings round: the middle of the quad.
@export var pivot := Vector3.ZERO
## Degrees it swings round the pivot on the way to its second place (positive =
## counter-clockwise seen from above).
@export var swing := 36.0
## Metres it moves toward the pivot.
@export var pull := 0.0
## Metres it sinks.
@export var drop := 0.0

## MapRoot moves this node along with the body it builds (see MapRoot.update_movers).
var carries_nodes := true
## 0 = its first place, 1 = its second, in between on the way (a LayoutEvent sets it).
var blend := 0.0

var _base: Transform3D
var _has_base := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		_base_xf()   # (before anything moves it)


## The offset from where it sits in the scene, at its present blend (MapRoot asks).
func offset_at(_t: float) -> Transform3D:
	return offset_for(blend)


func offset_for(k: float) -> Transform3D:
	return _base_xf().affine_inverse() * pose_for(k)


## Where it is, in the map's frame, `k` of the way from its first place to its second.
func pose_for(k: float) -> Transform3D:
	var base := _base_xf()
	var rel := base.origin - pivot
	var flat := Vector2(rel.x, rel.z)
	var r := flat.length()
	var turn := Basis(Vector3.UP, deg_to_rad(swing) * k)
	var out := Vector3.ZERO
	if r > 0.001:
		flat = flat / r * maxf(r - pull * k, 0.0)
		out = turn * Vector3(flat.x, 0.0, flat.y)
	return Transform3D(turn * base.basis, pivot + Vector3(out.x, rel.y - drop * k, out.z))


## Where it sits in the scene, in the map's frame.
func _base_xf() -> Transform3D:
	if _has_base:
		return _base
	var xf := transform
	var node := get_parent()
	while node != null and not node is MapRoot:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	_base = xf
	_has_base = not Engine.is_editor_hint()   # (in the editor it may be dragged about: ask again)
	return xf
