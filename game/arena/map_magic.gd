@tool
class_name MapMagic
extends Node3D
## Living magic: a box of air with something drifting in it (Empyrean Tower). Scenery
## only: it has no collision, cannot be shot, hooked or stood on, and nothing about it
## travels over the network. Every copy of the game animates it by its own clock.
##
## Put the node at the middle of the box and set Size. Kind picks what is in it:
## motes (drifting specks of light), sparks (rising), pages (loose sheets tumbling down),
## books (a flock of them flying round the box), droplets and bubbles (rising), fish,
## jellyfish and moths (small see-through spirits), candles (hanging in the air),
## stars (a constellation: points joined by lines) and arcs (caged lightning, the box's
## whole height).
##
## It is one MultiMesh and one shader (map_magic_glow / map_magic_solid.gdshader): all
## the movement is worked out on the graphics card, so a box costs nothing while nobody
## is near. If the map has a MapMagicField, boxes with Reacts ticked answer to players
## within 4 m (13 ft) who are in plain sight of the box: motes scatter, books and
## spirits flee, candles gutter. The field also makes them livelier during the map's event.

enum Kind { MOTES, SPARKS, PAGES, BOOKS, DROPLETS, BUBBLES, FISH, JELLIES, MOTHS, CANDLES, STARS, ARCS }

const GLOW := preload("res://game/arena/map_magic_glow.gdshader")
const SOLID := preload("res://game/arena/map_magic_solid.gdshader")
const SLOTS := 4          ## how many players one box can answer to at once
const RISE := 5.0         ## how fast it answers (1/seconds)...
const FALL := 1.6         ## ...and settles again
const SOLID_KINDS := [Kind.PAGES, Kind.BOOKS, Kind.CANDLES]

## What drifts in the box.
@export var kind := Kind.MOTES:
	set(v):
		kind = v
		_rebuild()
## The box (metres), centred on the node.
@export var size := Vector3(6, 4, 6):
	set(v):
		size = v
		_rebuild()
## How many pieces.
@export_range(1, 400) var count := 40:
	set(v):
		count = v
		_rebuild()
## A piece's size (metres).
@export var piece := 0.12:
	set(v):
		piece = v
		_rebuild()
## Its colour, and a second one some pieces take instead.
@export var color := Color(0.5, 0.9, 1.0):
	set(v):
		color = v
		_rebuild()
@export var color_b := Color(1.0, 0.8, 0.45):
	set(v):
		color_b = v
		_rebuild()
## How bright.
@export var power := 1.4:
	set(v):
		power = v
		_rebuild()
## It is not drawn from farther than this (metres from the middle of the box; 0: always).
@export var draw_range := 90.0:
	set(v):
		draw_range = v
		_rebuild()
## Does it answer to players near it (see MapMagicField)?
@export var reacts := true
## A different number lays the pieces out differently.
@export var variation := 1:
	set(v):
		variation = v
		_rebuild()

var _mat: ShaderMaterial
var _who: Array[int] = []           # the players it is answering to...
var _where: Array[Vector3] = []     # ...where each is (world)...
var _level: Array[float] = []       # ...how much it has answered so far (0..1)...
var _want: Array[float] = []        # ...and where that is heading
var _swirl := 0.0
var _surge := 0.0


func _ready() -> void:
	_rebuild()


## The box in the world.
func box() -> AABB:
	return global_transform * AABB(-size * 0.5, size)


## The point of the box nearest to `point` (both in the world).
func nearest(point: Vector3) -> Vector3:
	var half := size * 0.5
	return global_transform * (global_transform.affine_inverse() * point).clamp(-half, half)


## Called by the field: the players stirring this box right now (id -> where, in the
## world). Anyone it was answering to who is not in the list is let go.
func seen(actors: Dictionary) -> void:
	for i in _who.size():
		_want[i] = 1.0 if actors.has(_who[i]) else 0.0
		if actors.has(_who[i]):
			_where[i] = actors[_who[i]]
	for id in actors:
		if _who.has(id) or _who.size() >= SLOTS:
			continue
		_who.append(id)
		_where.append(actors[id])
		_level.append(0.0)
		_want.append(1.0)


## How stirred it is: 0 (at rest) to 1.
func stir() -> float:
	var most := 0.0
	for v in _level:
		most = maxf(most, v)
	return most


## Is it answering to anyone, or still settling?
func stirred() -> bool:
	return not _who.is_empty()


## Called by the field every frame while stirred() or the event is running.
func ease(delta: float, surge: float) -> void:
	for i in range(_who.size() - 1, -1, -1):
		_level[i] = move_toward(_level[i], _want[i], delta * (RISE if _want[i] > _level[i] else FALL))
		if _want[i] <= 0.0 and _level[i] <= 0.0:
			_who.remove_at(i)
			_where.remove_at(i)
			_level.remove_at(i)
			_want.remove_at(i)
	_surge = surge
	_swirl = wrapf(_swirl + delta * 0.5 * surge, 0.0, TAU * 8.0)
	_push()


func _push() -> void:
	if _mat == null:
		return
	var inv := global_transform.affine_inverse()
	var list := PackedVector4Array()
	for i in SLOTS:
		if i < _who.size():
			var p := inv * _where[i]
			list.append(Vector4(p.x, p.y, p.z, _level[i]))
		else:
			list.append(Vector4.ZERO)
	_mat.set_shader_parameter("actor", list)
	_mat.set_shader_parameter("surge", _surge)
	_mat.set_shader_parameter("swirl", _swirl)


# ---------------------------------------------------------------------------
# What you see

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.has_meta("magic"):
			remove_child(c)
			c.queue_free()
	_mat = null
	if DisplayServer.get_name() == "headless" and not Engine.is_editor_hint():
		return      # (a server or a test: the answering above still works, there is just nothing drawn)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([variation, kind])
	_mat = ShaderMaterial.new()
	_mat.shader = SOLID if kind in SOLID_KINDS else GLOW
	_mat.set_shader_parameter("mode", int(kind))
	_mat.set_shader_parameter("extent", size)
	_mat.set_shader_parameter("tint_a", color)
	_mat.set_shader_parameter("tint_b", color_b)
	_mat.set_shader_parameter("power", power)
	_mat.set_shader_parameter("piece", piece)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _piece_mesh()
	var places: Array[Vector3] = []
	var n := count
	if kind == Kind.STARS:
		places = _constellation(rng)
		n = places.size()
	mm.instance_count = n
	for i in n:
		var at := places[i] if i < places.size() else Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(at.x, at.y, at.z, rng.randf()))
		mm.set_instance_color(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	mm.custom_aabb = AABB(-size * 0.5, size).grow(4.0)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_range > 0.0:
		inst.visibility_range_end = draw_range + size.length() * 0.5
		inst.visibility_range_end_margin = draw_range * 0.1
	inst.set_meta("magic", true)
	add_child(inst, false, Node.INTERNAL_MODE_FRONT)
	if kind == Kind.STARS:
		_draw_lines(places)
	_push()


## A constellation: a handful of stars wandering across the box, each joined to the last.
func _constellation(rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var at := Vector3(-0.4, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2))
	for i in clampi(count, 3, 12):
		out.append(at)
		at += Vector3(rng.randf_range(0.08, 0.22), rng.randf_range(-0.28, 0.28), rng.randf_range(-0.25, 0.25))
		at = at.clamp(Vector3(-0.5, -0.5, -0.5), Vector3(0.5, 0.5, 0.5))
	return out


func _draw_lines(places: Array[Vector3]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := piece * 0.12
	for i in range(1, places.size()):
		var a := places[i - 1] * size
		var b := places[i] * size
		var along := (b - a).normalized()
		a += along * piece * 0.7
		b -= along * piece * 0.7
		var s1 := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized() * w
		var s2 := along.cross(s1).normalized() * w
		for s: Vector3 in [s1, s2]:      # two flat strips crossed: a line from any side
			for v: Vector3 in [a - s, a + s, b + s, a - s, b + s, b - s]:
				st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b) * 0.5
	var lines := MeshInstance3D.new()
	lines.mesh = st.commit()
	lines.material_override = mat
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lines.set_meta("magic", true)
	add_child(lines, false, Node.INTERNAL_MODE_FRONT)


func _piece_mesh() -> Mesh:
	match kind:
		Kind.PAGES:
			return _flat([[Vector3(-0.5, 0, -0.7), Vector3(0.5, 0, -0.7), Vector3(0.5, 0, 0.7), Vector3(-0.5, 0, 0.7)]])
		Kind.BOOKS:
			# two covers hinged along the spine (z); the shader beats them like wings
			return _flat([[Vector3(0, 0, -0.65), Vector3(1, 0, -0.65), Vector3(1, 0, 0.65), Vector3(0, 0, 0.65)],
				[Vector3(-1, 0, -0.65), Vector3(0, 0, -0.65), Vector3(0, 0, 0.65), Vector3(-1, 0, 0.65)]])
		Kind.MOTHS:
			return _flat([[Vector3(0, 0, -0.5), Vector3(1, 0, -0.8), Vector3(1.1, 0, 0.3), Vector3(0, 0, 0.5)],
				[Vector3(-1.1, 0, 0.3), Vector3(-1, 0, -0.8), Vector3(0, 0, -0.5), Vector3(0, 0, 0.5)]], true)
		Kind.FISH:
			return _fish()
		Kind.JELLIES:
			return _jelly()
		Kind.CANDLES:
			return _candle()
		Kind.ARCS:
			return _arc()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return quad


## Flat four-cornered pieces. `along`: write how far along the body each corner is into UV.x.
func _flat(quads: Array, along: bool = false) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: Array in quads:
		for i: int in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = q[i]
			st.set_uv(Vector2(clampf(v.z + 0.5, 0.0, 1.0) if along else 0.0, 0.0))
			st.add_vertex(v)
	return st.commit()


## A small fish seen from the side and from above: two crossed outlines, nose at +z.
## UV.x: 0 at the tail, 1 at the nose.
func _fish() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [[-1.0, 0.0, 0.42], [-0.72, 0.0, 0.1], [-0.2, 0.0, 0.3], [0.45, 0.0, 0.36], [1.0, 0.0, 0.0]]   # z, -, half height
	for axis in 2:
		for i in range(1, outline.size()):
			var a: Array = outline[i - 1]
			var b: Array = outline[i]
			var pts := [Vector3(0, a[2], a[0]), Vector3(0, -a[2], a[0]), Vector3(0, -b[2], b[0]), Vector3(0, b[2], b[0])]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = pts[k]
				if axis == 1:
					v = Vector3(v.y * 0.5, 0.0, v.z)
				st.set_uv(Vector2((v.z + 1.0) * 0.5, 0.0))
				st.add_vertex(v)
	return st.commit()


## A jellyfish: a bell and four trailing ribbons. UV.y: 1 on the bell; UV.x: 0 at a
## ribbon's tip, 1 at the top.
func _jelly() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var rim0 := Vector3(cos(a0), 0.0, sin(a0))
		var rim1 := Vector3(cos(a1), 0.0, sin(a1))
		var mid0 := Vector3(cos(a0) * 0.75, 0.45, sin(a0) * 0.75)
		var mid1 := Vector3(cos(a1) * 0.75, 0.45, sin(a1) * 0.75)
		var top := Vector3(0, 0.7, 0)
		for tri: Array in [[rim0, rim1, mid1, 0.55], [rim0, mid1, mid0, 0.55], [mid0, mid1, top, 1.0]]:
			for k in 3:
				var v: Vector3 = tri[k]
				st.set_uv(Vector2(0.55 + 0.45 * v.y / 0.7, 1.0))
				st.add_vertex(v)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var out := Vector3(cos(a), 0.0, sin(a)) * 0.45
		var w := Vector3(-sin(a), 0.0, cos(a)) * 0.09
		var steps := 4
		for s in steps:
			var y0 := -1.9 * s / steps
			var y1 := -1.9 * (s + 1) / steps
			var pts := [out - w + Vector3(0, y0, 0), out + w + Vector3(0, y0, 0), out + w + Vector3(0, y1, 0), out - w + Vector3(0, y1, 0)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = pts[k]
				st.set_uv(Vector2(0.5 * (1.0 + v.y / 1.9), 0.0))
				st.add_vertex(v)
	return st.commit()


## A candle 0.3 tall with a flame on top (in units of Piece). UV.x: 1 on the flame.
func _candle() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.07
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.07
		var up := Vector3(0, 0.3, 0)
		for v: Vector3 in [p0, p1, p1 + up, p0, p1 + up, p0 + up, p0 + up, p1 + up, up]:
			st.set_uv(Vector2(0.0, 0.0))
			st.add_vertex(v)
		var f0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.05 + Vector3(0, 0.36, 0)
		var f1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.05 + Vector3(0, 0.36, 0)
		for v: Vector3 in [Vector3(0, 0.3, 0), f1, f0, f0, f1, Vector3(0, 0.58, 0)]:
			st.set_uv(Vector2(1.0, 0.0))
			st.add_vertex(v)
	return st.commit()


## A bolt: two crossed strips one unit tall in eight lengths. UV.y: 0 at the foot, 1 at the top.
func _arc() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 2:
		var s := Vector3(0.5, 0, 0) if axis == 0 else Vector3(0, 0, 0.5)
		for i in 8:
			var uv0 := i / 8.0
			var uv1 := (i + 1) / 8.0
			for pair: Array in [[-s, uv0], [s, uv0], [s, uv1], [-s, uv0], [s, uv1], [-s, uv1]]:
				st.set_uv(Vector2(0.0, pair[1]))
				st.add_vertex(pair[0])
	return st.commit()
