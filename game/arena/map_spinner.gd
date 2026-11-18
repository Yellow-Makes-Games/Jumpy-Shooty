@tool
class_name MapSpinner
extends Node3D
## Scenery that turns: a group of MapBlocks spinning round the group's own y axis,
## for things nobody can touch (Halcyon's centrifuge ring outside the hull). Tip the
## node over to spin round another axis.
##
## Decoration only: its blocks are drawn but never solid, whatever their Solid box
## says, so it cannot carry or block players or shots. For platforms people ride,
## use a MapMover (race maps).
##
## Every copy of the game turns it by its own clock, so it is not in exactly the
## same place for everyone; a map event can slow it down or speed it up
## (speed_scale), which every copy does at the same moment.

## Degrees per second (negative = the other way).
@export var speed := 6.0
## 0..1: where in its turn it starts.
@export_range(0.0, 1.0) var phase := 0.0

## What turns it. Itself: at Speed, by its own clock. Countdown and Swing: a
## LayoutEvent does. Countdown is the hand of a clock, once round (clockwise, seen
## from the side its y axis points to) for every turn of the event's timer and at its
## starting place when the bell goes; Swing rocks to and fro when the bell goes.
enum Driven { ITSELF, COUNTDOWN, SWING }
@export var driven := Driven.ITSELF

## Multiplies the speed (a GravityEvent eases this down and back up).
var speed_scale := 1.0
## How far it has turned, in radians.
var angle := 0.0

var _pivot: Node3D


## Called by MapRoot.build(): draws the blocks under this node as meshes that turn.
func build(map: MapRoot, with_meshes: bool) -> void:
	angle = phase * TAU
	if _pivot:
		_pivot.queue_free()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	if not with_meshes:
		return
	var pieces := []
	_collect(self, Transform3D.IDENTITY, pieces)
	var meshes := MapMesher.build(pieces, map.face_shade, transform.basis.orthonormalized())
	for kind in meshes:
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[kind]
		mesh.material_override = map.material_for(kind)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# It may be huge and mostly off screen: never cull it by its (unturned) bounds.
		mesh.extra_cull_margin = 16384.0
		_pivot.add_child(mesh)


func _collect(node: Node, xf: Transform3D, pieces: Array) -> void:
	for child in node.get_children():
		if not child is Node3D or child == _pivot or not (child as Node3D).visible:
			continue
		var at := xf * (child as Node3D).transform
		if child is MapBlock:
			var piece := (child as MapBlock).to_piece(at)
			piece.solid = false
			pieces.append(piece)
		_collect(child, at, pieces)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pivot == null:
		return
	if driven == Driven.ITSELF:
		angle = fposmod(angle + deg_to_rad(speed * speed_scale) * delta, TAU)
	_pivot.rotation.y = angle
