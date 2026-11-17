class_name MeleeKit
extends RefCounted
## Shapes for building the melee weapons (see MeleeModel): flat-shaded and faceted
## like the robots, made of triangles gathered per material kind, so a finished weapon
## is one mesh per kind however many pieces it has.
##
## Everything is in weapon space: the right hand's grip at the origin, the blade or
## shaft up +Y. Add shapes, then take parts().

## For plate(): lays the outline in the weapon's side view, x toward the edge (-Z) and
## y up, with the thickness across the weapon (X).
const SIDE := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO)
## For bar(): lays it along -Z (its "up" pointing forward out of the fist).
const Z_AXIS := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)

var _verts := {}     # kind -> PackedVector3Array
var _normals := {}   # kind -> PackedVector3Array


## One flat triangle. `out`: roughly which way its face looks (it is turned to suit).
func tri(kind: String, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return   # no area (a ring closed to a point)
	if n.dot(out) < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	n = n.normalized()
	if not _verts.has(kind):
		_verts[kind] = PackedVector3Array()
		_normals[kind] = PackedVector3Array()
	var v: PackedVector3Array = _verts[kind]
	var nn: PackedVector3Array = _normals[kind]
	v.append_array([a, c, b])   # Godot's front faces are clockwise
	nn.append_array([n, n, n])
	_verts[kind] = v
	_normals[kind] = nn


func quad(kind: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	tri(kind, a, b, c, out)
	tri(kind, a, c, d, out)


## A skin stretched over a row of rings (each the same number of points, each bulging
## outward all round), closed at both ends. A ring may be a single spot repeated (a point).
func loft(kind: String, rings: Array, cap_start: bool = true, cap_end: bool = true) -> void:
	for i in rings.size() - 1:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		var mid := (_middle(a) + _middle(b)) * 0.5
		for j in a.size():
			var k := (j + 1) % a.size()
			var face := (a[j] + a[k] + b[k] + b[j]) * 0.25
			quad(kind, a[j], a[k], b[k], b[j], face - mid)
	if cap_start:
		_cap(kind, rings[0], _middle(rings[0]) - _middle(rings[1]))
	if cap_end:
		_cap(kind, rings[-1], _middle(rings[-1]) - _middle(rings[-2]))


## A flat plate: the outline (any simple shape, drawn in X and Y) given thickness
## from z0 to z1. `xf` then moves it anywhere (to lay a plate in another plane).
func plate(kind: String, outline: PackedVector2Array, z0: float, z1: float, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var pts := outline
	var area := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		area += p.x * q.y - q.x * p.y
	if area < 0.0:
		pts = pts.duplicate()
		pts.reverse()
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		var out := xf.basis * Vector3(q.y - p.y, p.x - q.x, 0.0)
		quad(kind, xf * Vector3(p.x, p.y, z0), xf * Vector3(q.x, q.y, z0), xf * Vector3(q.x, q.y, z1), xf * Vector3(p.x, p.y, z1), out)
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var a := pts[idx[i]]
		var b := pts[idx[i + 1]]
		var c := pts[idx[i + 2]]
		for z in [z0, z1]:
			var out := xf.basis * Vector3(0, 0, signf(z - (z0 + z1) * 0.5))
			tri(kind, xf * Vector3(a.x, a.y, z), xf * Vector3(b.x, b.y, z), xf * Vector3(c.x, c.y, z), out)


## The same outline mirrored left to right as well (x and -x): for pairs of wings and panels.
func plate_pair(kind: String, outline: PackedVector2Array, z0: float, z1: float) -> void:
	plate(kind, outline, z0, z1)
	var other := PackedVector2Array()
	for p in outline:
		other.append(Vector2(-p.x, p.y))
	plate(kind, other, z0, z1)


func box(kind: String, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	plate(kind, PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]),
		-h.z, h.z, Transform3D(Basis.IDENTITY, center))


## A faceted bar up the Y axis through the given [y, radius] steps (`sides` flats;
## `squash` narrows it in x or z). `xf` then moves it anywhere (Z_AXIS lays it along -Z).
func bar(kind: String, steps: Array, sides: int = 8, squash: Vector2 = Vector2.ONE, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var rings := []
	for s in steps:
		var r := ring(float(s[0]), float(s[1]), sides, squash)
		for i in r.size():
			r[i] = xf * r[i]
		rings.append(r)
	loft(kind, rings)


## A flat ring of points round the Y axis at height y.
static func ring(y: float, radius: float, sides: int = 8, squash: Vector2 = Vector2.ONE) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in sides:
		var a := TAU * (float(i) + 0.5) / float(sides)
		out.append(Vector3(cos(a) * radius * squash.x, y, sin(a) * radius * squash.y))
	return out


## A rectangle with its corners cut off, as an outline for plate(): half sizes, the cut, its middle.
static func cut_rect(hx: float, hy: float, cut: float, mid: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([mid + Vector2(-hx + cut, -hy), mid + Vector2(hx - cut, -hy), mid + Vector2(hx, -hy + cut),
		mid + Vector2(hx, hy - cut), mid + Vector2(hx - cut, hy), mid + Vector2(-hx + cut, hy),
		mid + Vector2(-hx, hy - cut), mid + Vector2(-hx, -hy + cut)])


## The finished pieces: [mesh, transform, material kind], one per kind used.
func parts() -> Array:
	var out := []
	for kind in _verts:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts[kind]
		arrays[Mesh.ARRAY_NORMAL] = _normals[kind]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.append([mesh, Transform3D.IDENTITY, kind])
	return out


## How many triangles so far (to keep an eye on the budget).
func triangles() -> int:
	var n := 0
	for kind in _verts:
		n += (_verts[kind] as PackedVector3Array).size() / 3
	return n


func _cap(kind: String, r: PackedVector3Array, out: Vector3) -> void:
	var m := _middle(r)
	for j in r.size():
		tri(kind, m, r[j], r[(j + 1) % r.size()], out)


static func _middle(r: PackedVector3Array) -> Vector3:
	var m := Vector3.ZERO
	for p in r:
		m += p
	return m / float(r.size())
