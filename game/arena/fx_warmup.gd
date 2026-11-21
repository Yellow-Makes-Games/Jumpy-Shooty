class_name FxWarmup
extends Node3D
## Draws, once and far too small to see, everything a first hit would otherwise be the
## first to draw: an explosion (each part of BlastFx) and its light and, on a map with
## fine destruction, rubble and its dust and the pieces of a building coming down.
##
## A graphics card builds what it needs for each new sort of surface the first time one
## is drawn, and that can hold the whole game up for a moment. Better as the match
## starts, when nobody is aiming at anything, than at the first rocket.

const FRAMES := 8        ## how many frames it is drawn for
const AHEAD := 2.5       ## metres in front of the camera
const SMALL := 0.002     ## how big it is drawn (1 = life size)

var _map: MapRoot
var _left := FRAMES
var _waited := 0.0


## Starts one for `map` under `arena`.
static func start(arena: Node3D, map: MapRoot) -> void:
	if DisplayServer.get_name() == "headless" or map == null:
		return
	var warm := FxWarmup.new()
	warm.name = "FxWarmup"
	warm._map = map
	arena.add_child(warm)


func _ready() -> void:
	scale = Vector3.ONE * SMALL
	visible = false   # (until there is a camera to put it in front of)
	if _map.debris:
		_map.debris.warm(self)
	for c in _map.collapses:
		c.warm(self)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_waited += delta
		if _waited > 30.0:
			queue_free()
		return
	var view := camera.global_transform
	global_transform = Transform3D(view.basis.orthonormalized().scaled(Vector3.ONE * SMALL), view * Vector3(0, 0, -AHEAD))
	visible = true
	if _left == FRAMES:
		BlastFx.warm(self)
	_left -= 1
	if _left <= 0:
		queue_free()
