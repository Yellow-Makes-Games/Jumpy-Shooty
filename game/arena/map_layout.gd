class_name MapLayout
extends RefCounted
## A map built from code. Each map is a script that extends this one and lists its
## pieces (boxes, ramps, cylinders), spawn points and signs in build().
##
## A piece: { "xf": Transform3D (centre), "size": Vector3, "kind": String (which
## material), "solid": bool (false = drawn only), "shape": "box", "cyl" or "tube" }.
## A cylinder's size is (diameter, height, diameter), standing along its own y axis.
## Optional keys: "hidden" (solid but not drawn), "tint" (Color multiplied into the
## kind's colour), "sides" (cylinders and tubes), "inner" (a tube's inside diameter).

var pieces: Array = []
var spawns: Array = []   ## Array of [Vector3 position, float yaw]
var signs: Array = []    ## Array of {"pos", "text", "yaw", "size"}; yaw NAN = always faces the camera
var lights: Array = []   ## Lamps, lit only if the look says "lamps": {"pos", "range", "energy", "color", "toward" (a spot's target, or null), "angle"}


## The name players see.
func map_name() -> String:
	return "Map"


## Fill in pieces, spawns and signs. Returns self.
func build() -> MapLayout:
	return self


## kind -> Color. Every kind used by a piece needs an entry.
func kind_colors() -> Dictionary:
	return {}


## Greybox maps draw a 1 m / 4 m grid on every surface; finished maps do not.
func grid_texture() -> bool:
	return false


## Darkens faces by the way they point (see MapMesher). Vector3.ONE = off.
func face_shade() -> Vector3:
	return Vector3.ONE


## Falling below this height counts as falling out of the map.
func kill_height() -> float:
	return -25.0


## Leaving this box (x and z only) also counts as falling out. Zero size = no limit.
func bounds() -> Rect2:
	return Rect2()


## A high point near the middle that scripted test players swing from.
func swing_point() -> Vector3:
	return Vector3(0, 5.5, 0)


## Sky, sun, fog and lamps. See MapScenery.DEFAULT_LOOK for the keys.
func look() -> Dictionary:
	return {}


# ---------------------------------------------------------------------------
# Pieces

func _box(center: Vector3, size: Vector3, kind: String, solid: bool = true) -> Dictionary:
	return _add(Transform3D(Basis(), center), size, kind, solid, "box")


## A box given by its corners instead of its centre: from (x0, y0, z0) to (x1, y1, z1).
func _span(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, kind: String, solid: bool = true) -> Dictionary:
	return _box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
		Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)), kind, solid)


## An upright cylinder standing on `base`.
func _cyl(base: Vector3, radius: float, height: float, kind: String, solid: bool = true) -> Dictionary:
	return _add(Transform3D(Basis(), base + Vector3(0, height * 0.5, 0)),
		Vector3(radius * 2.0, height, radius * 2.0), kind, solid, "cyl")


## Paint on the floor: drawn but not solid, so it never trips you.
func _decal(center: Vector3, size: Vector3, kind: String) -> Dictionary:
	return _box(center, size, kind, false)


func _sign(pos: Vector3, text: String, yaw: float, size: int = 72, help: String = "") -> void:
	signs.append({"pos": pos, "text": text, "yaw": yaw, "size": size})
	if help != "":
		signs.append({"pos": pos - Vector3(0, 1.1, 0), "text": help, "yaw": yaw, "size": 40})


## A slab from `low` up to `high` (both are centres of the walking surface).
func _ramp(low: Vector3, high: Vector3, width: float, kind: String = "ramp") -> Dictionary:
	return _slab(low, high, width, 0.5, kind)


## A walkway between two points (both are centres of the walking surface).
func _beam(a: Vector3, b: Vector3, width: float, kind: String = "bridge") -> Dictionary:
	return _slab(a, b, width, 0.6, kind)


## A flat bar from `a` to `b`; the points are on the centre line of its top face.
func _slab(a: Vector3, b: Vector3, width: float, thickness: float, kind: String, solid: bool = true) -> Dictionary:
	var dir := b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * (thickness * 0.5)
	return _add(Transform3D(basis, center), Vector3(width, thickness, dir.length()), kind, solid, "box")


## A bar from `a` to `b` through its centre line (any direction, even straight up).
func _strut(a: Vector3, b: Vector3, width: float, height: float, kind: String, solid: bool = true) -> Dictionary:
	var dir := b - a
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir.normalized(), up)
	return _add(Transform3D(basis, (a + b) * 0.5), Vector3(width, height, dir.length()), kind, solid, "box")


## A staircase of blocks you vault up, each `rise` higher. Starts at `start`
## (ground level) and runs along x by `run` metres in total.
func _steps(start: Vector3, run: float, count: int, top: float) -> void:
	var depth := run / count
	for i in count:
		var h := top * (i + 1) / count
		_box(Vector3(start.x + depth * (i + 0.5), h * 0.5, start.z), Vector3(abs(depth), h, 4), "block")


func _add(xf: Transform3D, size: Vector3, kind: String, solid: bool, shape: String) -> Dictionary:
	var piece := {"xf": xf, "size": size, "kind": kind, "solid": solid, "shape": shape}
	pieces.append(piece)
	return piece


## A lamp. With `toward` it is a floodlight aimed there; without, it shines all round.
func _light(pos: Vector3, reach: float, energy: float, color: Color, toward: Variant = null, angle: float = 40.0) -> void:
	lights.append({"pos": pos, "range": reach, "energy": energy, "color": color, "toward": toward, "angle": angle})


func _spawn(pos: Vector3, look_at: Vector3) -> void:
	var to := look_at - pos
	spawns.append([pos + Vector3(0, 0.2, 0), atan2(-to.x, -to.z)])


# ---------------------------------------------------------------------------
# Putting it in the world

## Adds the level under `parent`: one "Collision" body holding every solid piece,
## and, if `materials` (kind -> Material) is given, one mesh per kind plus the signs.
func instantiate(parent: Node3D, materials: Dictionary = {}) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	parent.add_child(body)
	for piece in pieces:
		if not piece.solid:
			continue
		var shape := CollisionShape3D.new()
		shape.shape = _collision_shape(piece)
		shape.transform = piece.xf
		body.add_child(shape)
	if materials.is_empty():
		return
	var meshes := MapMesher.build(pieces, face_shade())
	for kind in meshes:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh_%s" % kind
		mesh.mesh = meshes[kind]
		mesh.material_override = materials[kind]
		parent.add_child(mesh)
	for s in signs:
		var label := Label3D.new()
		label.text = s.text
		label.font_size = s.size
		label.pixel_size = 0.01
		label.outline_size = 12 if not is_nan(s.yaw) else s.size / 4
		label.modulate = s.get("color", Color(1, 1, 1))
		label.outline_modulate = s.get("outline", Color(0.05, 0.05, 0.08))
		label.position = s.pos
		if is_nan(s.yaw):
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
		else:
			label.rotation.y = s.yaw
			label.double_sided = false
		parent.add_child(label)


func _collision_shape(piece: Dictionary) -> Shape3D:
	if piece.shape == "cyl":
		var c := CylinderShape3D.new()
		c.radius = piece.size.x * 0.5
		c.height = piece.size.y
		return c
	var box := BoxShape3D.new()
	box.size = piece.size
	return box
