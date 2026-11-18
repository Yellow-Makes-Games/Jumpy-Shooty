class_name MapMesher
extends RefCounted
## Turns a map's pieces into meshes: one mesh per kind (material), with every piece
## of that kind merged into it, so a map of a few thousand pieces draws in a handful
## of calls. Faces are flat-shaded; a piece's tint goes into the vertex colours.
##
## `shade` darkens faces by the way they point, baked into the vertex colours:
## (faces looking along x, faces looking along z, faces looking down); tops stay
## at 1. It gives plain boxes some form even in flat light. Vector3.ONE = off.
## `shade_basis` turns the normals before shading: the editor builds each block's
## mesh in the block's own frame, but shades it by the way its faces point in the map.

static var _shade := Vector3.ONE
static var _shade_basis := Basis()

const BOX_FACES := [   # normal, then the two in-plane axes (u, v) with u x v = normal
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


## kind -> ArrayMesh
static func build(pieces: Array, shade: Vector3 = Vector3.ONE, shade_basis: Basis = Basis()) -> Dictionary:
	_shade = shade
	_shade_basis = shade_basis
	var by_kind := {}
	for piece in pieces:
		if piece.get("hidden", false):
			continue
		if not by_kind.has(piece.kind):
			by_kind[piece.kind] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
		var buf: Array = by_kind[piece.kind]
		match piece.shape:
			"cyl": _prism(buf, piece, 0.0)
			"tube": _prism(buf, piece, piece.get("inner", 0.0))
			"cone": _cone(buf, piece)
			_: _box(buf, piece)
	var result := {}
	for kind in by_kind:
		var buf: Array = by_kind[kind]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = buf[0]
		arrays[Mesh.ARRAY_NORMAL] = buf[1]
		arrays[Mesh.ARRAY_COLOR] = buf[2]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result[kind] = mesh
	return result


static func _quad(buf: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	# a, b, c, d go counter-clockwise seen from the front (the side `n` points to).
	var verts: PackedVector3Array = buf[0]
	var normals: PackedVector3Array = buf[1]
	var colors: PackedColorArray = buf[2]
	color = _shaded(color, n)
	for v in [a, c, b, a, d, c]:   # Godot's front faces are clockwise
		verts.append(v)
		normals.append(n)
		colors.append(color)


static func _box(buf: Array, piece: Dictionary) -> void:
	var xf: Transform3D = piece.xf
	var h: Vector3 = piece.size * 0.5
	var color: Color = piece.get("tint", Color.WHITE)
	for face in BOX_FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var c: Vector3 = n * h
		var du: Vector3 = u * h
		var dv: Vector3 = v * h
		_quad(buf, xf * (c - du - dv), xf * (c + du - dv), xf * (c + du + dv), xf * (c - du + dv), xf.basis * n, color)


## A cylinder with flat sides (inner = 0), or a pipe you can see through (inner > 0).
static func _prism(buf: Array, piece: Dictionary, inner: float) -> void:
	var xf: Transform3D = piece.xf
	var color: Color = piece.get("tint", Color.WHITE)
	var sides: int = piece.get("sides", 12)
	var r: float = piece.size.x * 0.5
	var ri: float = inner * 0.5
	var hy: float = piece.size.y * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var am := (a0 + a1) * 0.5
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := Vector3(cos(am), 0, sin(am))
		var up := Vector3(0, hy, 0)
		# outside wall
		_quad(buf, xf * (d1 * r - up), xf * (d0 * r - up), xf * (d0 * r + up), xf * (d1 * r + up), xf.basis * n, color)
		if ri > 0.0:
			_quad(buf, xf * (d0 * ri - up), xf * (d1 * ri - up), xf * (d1 * ri + up), xf * (d0 * ri + up), xf.basis * -n, color)
			_quad(buf, xf * (d0 * ri + up), xf * (d1 * ri + up), xf * (d1 * r + up), xf * (d0 * r + up), xf.basis * Vector3.UP, color)
			_quad(buf, xf * (d1 * ri - up), xf * (d0 * ri - up), xf * (d0 * r - up), xf * (d1 * r - up), xf.basis * Vector3.DOWN, color)
		else:
			_tri(buf, xf * up, xf * (d1 * r + up), xf * (d0 * r + up), xf.basis * Vector3.UP, color)
			_tri(buf, xf * -up, xf * (d0 * r - up), xf * (d1 * r - up), xf.basis * Vector3.DOWN, color)


## A cone with flat sides, coming to a point (top = 0) or cut off flat at the top.
## Its corners: cone_points() (the collision shape is built from the same points).
static func _cone(buf: Array, piece: Dictionary) -> void:
	var xf: Transform3D = piece.xf
	var color: Color = piece.get("tint", Color.WHITE)
	var sides: int = piece.get("sides", 12)
	var r: float = piece.size.x * 0.5
	var rt: float = minf(piece.get("top", 0.0) * 0.5, r)
	var up := Vector3(0, piece.size.y * 0.5, 0)
	for i in sides:
		var d0 := Vector3(cos(TAU * i / sides), 0, sin(TAU * i / sides))
		var d1 := Vector3(cos(TAU * (i + 1) / sides), 0, sin(TAU * (i + 1) / sides))
		var b0 := d0 * r - up
		var b1 := d1 * r - up
		var n := cone_side_normal(d0, d1, r, rt, piece.size.y)
		if rt > 0.0:
			_quad(buf, xf * b1, xf * b0, xf * (d0 * rt + up), xf * (d1 * rt + up), xf.basis * n, color)
			_tri(buf, xf * up, xf * (d1 * rt + up), xf * (d0 * rt + up), xf.basis * Vector3.UP, color)
		else:
			_tri(buf, xf * b1, xf * b0, xf * up, xf.basis * n, color)
		_tri(buf, xf * -up, xf * b0, xf * b1, xf.basis * Vector3.DOWN, color)


## The outward normal of the cone's side between the corners `d0` and `d1` (unit
## directions round its axis), for a foot radius `r`, top radius `rt` and `height`.
static func cone_side_normal(d0: Vector3, d1: Vector3, r: float, rt: float, height: float) -> Vector3:
	var mid := (d0 + d1) * 0.5           # the middle of that side, at radius 1 (flat part)
	var flat := mid.length()
	return (mid / flat * height + Vector3.UP * (r - rt) * flat).normalized()


## A cone's corners in its own frame: the foot's ring, then the top's ring (or the tip).
static func cone_points(piece: Dictionary) -> PackedVector3Array:
	var sides: int = piece.get("sides", 12)
	var r: float = piece.size.x * 0.5
	var rt: float = minf(piece.get("top", 0.0) * 0.5, r)
	var hy: float = piece.size.y * 0.5
	var pts := PackedVector3Array()
	for i in sides:
		pts.append(Vector3(cos(TAU * i / sides) * r, -hy, sin(TAU * i / sides) * r))
	if rt > 0.0:
		for i in sides:
			pts.append(Vector3(cos(TAU * i / sides) * rt, hy, sin(TAU * i / sides) * rt))
	else:
		pts.append(Vector3(0, hy, 0))
	return pts


static func _tri(buf: Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	var verts: PackedVector3Array = buf[0]
	var normals: PackedVector3Array = buf[1]
	var colors: PackedColorArray = buf[2]
	color = _shaded(color, n)
	for v in [a, c, b]:
		verts.append(v)
		normals.append(n)
		colors.append(color)


static func _shaded(color: Color, n: Vector3) -> Color:
	if _shade == Vector3.ONE:
		return color
	n = _shade_basis * n
	var flat := n.x * n.x + n.z * n.z
	var side: float = lerpf(_shade.x, _shade.y, n.z * n.z / flat) if flat > 0.0001 else 1.0
	var k: float = lerpf(side, 1.0, n.y) if n.y >= 0.0 else lerpf(side, _shade.z, -n.y)
	return Color(color.r * k, color.g * k, color.b * k, color.a)
