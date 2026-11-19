@tool
class_name MapMagicStream
extends Node3D
## A rope of liquid magic running along a path through the air, the way Empyrean
## Tower's river climbs its shaft: scenery only (no collision; you fly straight through
## it), drawn by this script as one glowing tube whose light runs along it.
##
## Path is the line it follows (points in the node's own frame, a metre or so apart;
## it runs from the first to the last). Colors, if given, are its colour at evenly
## spaced stops along the way (one colour: the same all along). If the map has a
## MapMagicField it runs faster and brighter during the map's event.

const SHADER := preload("res://game/arena/map_magic_stream.gdshader")
const SIDES := 8

## The line it follows.
@export var path := PackedVector3Array():
	set(v):
		path = v
		_rebuild()
## How thick (metres across).
@export var width := 0.9:
	set(v):
		width = v
		_rebuild()
## Its colour at stops along the way.
@export var colors := PackedColorArray([Color(0.4, 0.9, 1.0)]):
	set(v):
		colors = v
		_rebuild()
## Metres a second the light runs along it (toward the end of the path).
@export var speed := 2.2
## How bright.
@export var power := 1.2:
	set(v):
		power = v
		_rebuild()
## Thin to a point over this many metres at the start and at the end.
@export var taper := Vector2(4.0, 4.0):
	set(v):
		taper = v
		_rebuild()

var surge := 0.0      ## set by the field: 0..1
var _mat: ShaderMaterial
var _flow := 0.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _mat == null:
		return
	_flow = wrapf(_flow + delta * speed * (1.0 + 1.6 * surge), 0.0, 4096.0)
	_mat.set_shader_parameter("flow", _flow)
	_mat.set_shader_parameter("surge", surge)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.has_meta("magic"):
			remove_child(c)
			c.queue_free()
	_mat = null
	if path.size() < 2 or (DisplayServer.get_name() == "headless" and not Engine.is_editor_hint()):
		set_process(false)
		return
	set_process(true)
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		lengths.append(lengths[i - 1] + path[i].distance_to(path[i - 1]))
	var total := lengths[lengths.size() - 1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var side := Vector3.RIGHT
	for i in path.size():
		var along := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		side = (side - along * side.dot(along)).normalized()      # carried along the path, so the tube never twists
		if side.length() < 0.5:
			side = along.cross(Vector3.UP).normalized()
		var up := along.cross(side)
		var d := lengths[i]
		var thin := minf(smoothstep(0.0, maxf(taper.x, 0.01), d), smoothstep(0.0, maxf(taper.y, 0.01), total - d))
		var col := _colour(d / maxf(total, 0.01))
		col.a = clampf(thin * 1.5, 0.0, 1.0)
		var ring := []
		for k in SIDES + 1:
			var a := TAU * k / SIDES
			var n := side * cos(a) + up * sin(a)
			ring.append([path[i] + n * width * 0.5 * (0.25 + 0.75 * thin), n, Vector2(d, float(k) / SIDES), col])
		rings.append(ring)
	for i in range(1, rings.size()):
		for k in SIDES:
			for v: Array in [rings[i - 1][k], rings[i - 1][k + 1], rings[i][k + 1], rings[i - 1][k], rings[i][k + 1], rings[i][k]]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.set_color(v[3])
				st.add_vertex(v[0])
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("power", power)
	_mat.set_shader_parameter("wave", minf(0.18, width * 0.3))
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.set_meta("magic", true)
	add_child(inst, false, Node.INTERNAL_MODE_FRONT)


func _colour(u: float) -> Color:
	if colors.is_empty():
		return Color.WHITE
	var f := clampf(u, 0.0, 1.0) * (colors.size() - 1)
	var i := mini(int(f), colors.size() - 1)
	return colors[i].lerp(colors[mini(i + 1, colors.size() - 1)], f - i)
