class_name MapMesher
extends RefCounted
## Turns a map's pieces into meshes: one mesh per kind (material), with every piece
## of that kind merged into it, so a map of a few thousand pieces draws in a handful
## of calls. Faces are flat-shaded; a piece's tint goes into the vertex colours.

const BOX_FACES := [   # normal, then the two in-plane axes (u, v) with u x v = normal
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


## kind -> ArrayMesh
static func build(pieces: Array) -> Dictionary:
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


static func _tri(buf: Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	var verts: PackedVector3Array = buf[0]
	var normals: PackedVector3Array = buf[1]
	var colors: PackedColorArray = buf[2]
	for v in [a, c, b]:
		verts.append(v)
		normals.append(n)
		colors.append(color)
