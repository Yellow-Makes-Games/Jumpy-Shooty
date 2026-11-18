@tool
extends RefCounted
## One 3D editor view as the map tools see it: rays from the mouse and where a point
## in the map is on screen. (The editor shrinks the 3D image when Half Resolution is
## on, but not the mouse positions: `shrink` puts that right.)

var camera: Camera3D
var shrink := 1.0


func _init(cam: Camera3D, shrink_by: float = 1.0) -> void:
	camera = cam
	shrink = shrink_by


## Where the ray under the mouse starts.
func origin(pos: Vector2) -> Vector3:
	return camera.project_ray_origin(pos / shrink)


## Which way the ray under the mouse goes.
func normal(pos: Vector2) -> Vector3:
	return camera.project_ray_normal(pos / shrink)


func screen(point: Vector3) -> Vector2:
	return camera.unproject_position(point) * shrink


func behind(point: Vector3) -> bool:
	return camera.is_position_behind(point)


## A top, front or side view looks straight along one of the map's axes: which one
## (0 x, 1 y, 2 z). -1 for a perspective view, or one turned some other way.
func ortho_axis() -> int:
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return -1
	var forward := -camera.global_basis.z
	var axis := forward.abs().max_axis_index()
	return axis if absf(forward[axis]) > 0.999 else -1


## Where the ray under the mouse crosses the plane `axis` = `at`, or null if it runs
## along the plane or the plane is behind the camera.
func on_plane(pos: Vector2, axis: int, at: float) -> Variant:
	var o := origin(pos)
	var d := normal(pos)
	if absf(d[axis]) < 1e-6:
		return null
	var t := (at - o[axis]) / d[axis]
	if t < 0.0 and camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return null
	var p := o + d * t
	p[axis] = at
	return p


## How far along the line through `from` going `along` (a unit vector) the point
## nearest the ray under the mouse is.
func along_line(pos: Vector2, from: Vector3, along: Vector3) -> float:
	var o := origin(pos)
	var d := normal(pos)
	var closest := Geometry3D.get_closest_points_between_segments(from - along * 4096.0, from + along * 4096.0, o - d * 4096.0, o + d * 4096.0)
	return (closest[0] - from).dot(along)


## Draws the edges of a box (`xf` its frame, `half` its half size) on an overlay.
func draw_box(overlay: Control, xf: Transform3D, half: Vector3, color: Color, width := 2.0) -> void:
	var c := PackedVector3Array()
	for i in 8:
		c.append(xf * Vector3(half.x if i & 1 else -half.x, half.y if i & 2 else -half.y, half.z if i & 4 else -half.z))
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		draw_line(overlay, c[pair[0]], c[pair[1]], color, width)


func draw_line(overlay: Control, a: Vector3, b: Vector3, color: Color, width := 2.0) -> void:
	if behind(a) or behind(b):
		return
	overlay.draw_line(screen(a), screen(b), color, width, true)
